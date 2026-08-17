import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

/// Voce candidata estratta da foto/PDF del menu.
class MenuImportCandidate {
  MenuImportCandidate({
    required this.name,
    required this.recommendedDays,
    this.selected = true,
    this.category = 'custom',
    this.storageHint = 'In frigo 0-4 °C',
    this.allergens,
    this.isDish = false,
  });

  String name;
  int recommendedDays;
  bool selected;
  String category;
  String storageHint;
  String? allergens;
  bool isDish;
}

class MenuImportResult {
  const MenuImportResult({
    required this.candidates,
    required this.rawText,
    required this.sourceLabel,
  });

  final List<MenuImportCandidate> candidates;
  final String rawText;
  final String sourceLabel;
}

/// Importa ingredienti/preparati da foto del menu o da PDF (OCR).
class MenuCatalogImportService {
  MenuCatalogImportService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  static const _uuid = Uuid();

  static const _skipExact = {
    'menu',
    'menù',
    'lista',
    'allergeni',
    'allergene',
    'prezzo',
    'prezzi',
    'totale',
    'iva',
    'coperti',
    'coperto',
    'acqua',
    'bibite',
    'bevande',
    'vini',
    'birre',
    'caffetteria',
    'page',
    'pagina',
    'caffè',
    'caffe',
    'amaro',
    'whiskey',
    'grappe',
    'ginseng',
    'pepsi',
    'coca cola',
    'fanta',
    'sprite',
  };

  static const _skipContains = [
    'allergen',
    'contenenti glutine',
    'prodotti derivati',
    'intolleranz',
    'contiene',
    'www.',
    'http',
    'tel.',
    'telefono',
    'whatsapp',
    'facebook',
    'instagram',
    'partita iva',
    'p.iva',
    'via ',
    'produzione propria',
    'possono variare',
    'scegli il tuo',
  ];

  static const _categoryHeaders = {
    'pizze',
    'pizza',
    'rosse',
    'bianche',
    'speciali',
    'classiche',
    'antipasti',
    'antipasto',
    'primi',
    'secondi',
    'contorni',
    'insalate',
    'dolci',
    'dessert',
    'fritti',
    'taglieri',
    'bruschette',
    'calzoni',
    'focacce',
    'pinse',
    'panini',
    'hamburger',
    'kebab',
    'extra',
    'aggiunte',
    'supplementi',
    'bevande',
    'vino',
    'vini',
    'birre',
    'caffe',
    'caffè',
    'amari',
  };

  /// Stima giorni di scadenza tipici da parole chiave.
  int guessShelfDays(String name) {
    final n = name.toLowerCase();
    if (RegExp(r'\bpizza\b|\bpinsa\b|calzone|margherita|marinara|diavola|bufalina').hasMatch(n)) {
      return 1;
    }
    if (RegExp(r'rucola|basilico|insalata|misticanza|erba').hasMatch(n)) return 1;
    if (RegExp(r'salmone|tonno|gamber|pesce|acciug|carpaccio|crudo di').hasMatch(n)) return 1;
    if (RegExp(r'uovo|carbonara').hasMatch(n)) return 1;
    if (RegExp(r'mozzarella|bufala|stracciatella|ricotta|stracchino|impasto').hasMatch(n)) {
      return 2;
    }
    if (RegExp(r'salsa|pomodoro|crema|salsiccia|pollo|kebab|carne').hasMatch(n)) return 2;
    if (RegExp(r'prosciutto|speck|salame|pancetta|wurstel|salumi').hasMatch(n)) return 3;
    if (RegExp(r'gorgonzola|provola|scamorza|grana|formagg').hasMatch(n)) return 4;
    if (RegExp(r'olive|capperi|olio|miele|nutella').hasMatch(n)) return 7;
    return 3;
  }

  String guessCategory(String name) {
    final n = name.toLowerCase();
    if (RegExp(r'^impasto\b|biga').hasMatch(n)) return 'impasto';
    if (RegExp(r'\bpinsa\b').hasMatch(n) && !n.contains('impasto')) return 'pinsa';
    if (RegExp(r'\bpizza\b|calzone|margherita|marinara|diavola|bufalina').hasMatch(n)) {
      return 'pizza';
    }
    if (RegExp(r'tiramisu|cheesecake|torta|tartufo|nutellino').hasMatch(n)) return 'dolce';
    if (RegExp(r'salsa|pomodoro|crema').hasMatch(n)) return 'salsa';
    if (RegExp(r'mozzarella|bufala|ricotta|formagg|grana|gorgonzola|provola|brie').hasMatch(n)) {
      return 'latticini';
    }
    if (RegExp(r'prosciutto|speck|salame|pancetta|salsiccia|wurstel').hasMatch(n)) return 'salumi';
    if (RegExp(r'carne|angus|kebab|pollo').hasMatch(n)) return 'carni';
    if (RegExp(r'rucola|funghi|zucch|melanz|peperon|cipoll|pomodorin|basilic|carciof').hasMatch(n)) {
      return 'verdure';
    }
    if (RegExp(r'salmone|tonno|gamber|pesce|acciug').hasMatch(n)) return 'pesce';
    if (RegExp(r'noci|pistacchi').hasMatch(n)) return 'frutta_secca';
    return 'custom';
  }

  Future<MenuImportResult> importFromImagePath(String imagePath) async {
    final text = await _ocrImage(imagePath);
    return MenuImportResult(
      candidates: parseMenuText(text),
      rawText: text,
      sourceLabel: 'foto menu',
    );
  }

  Future<MenuImportResult> importFromPdfBytes(Uint8List bytes, {String? fileName}) async {
    if (kIsWeb) {
      return const MenuImportResult(candidates: [], rawText: '', sourceLabel: 'pdf');
    }
    final buffer = StringBuffer();
    final tmpDir = await getTemporaryDirectory();
    final work = Directory(p.join(tmpDir.path, 'menu_pdf_${_uuid.v4()}'));
    await work.create(recursive: true);

    try {
      var pageIndex = 0;
      await for (final page in Printing.raster(bytes, dpi: 160)) {
        pageIndex++;
        if (pageIndex > 12) break; // limite pratico
        final image = await page.toImage();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (byteData == null) continue;
        final pngPath = p.join(work.path, 'page_$pageIndex.png');
        await File(pngPath).writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        final pageText = await _ocrImage(pngPath);
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText);
          buffer.writeln();
        }
      }
    } finally {
      try {
        if (await work.exists()) await work.delete(recursive: true);
      } catch (_) {}
    }

    final text = buffer.toString();
    return MenuImportResult(
      candidates: parseMenuText(text),
      rawText: text,
      sourceLabel: fileName ?? 'pdf menu',
    );
  }

  Future<MenuImportResult?> pickAndImportPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Impossibile leggere il PDF selezionato');
    }
    return importFromPdfBytes(bytes, fileName: file.name);
  }

  Future<String> _ocrImage(String path) async {
    if (kIsWeb) return '';
    final file = File(path);
    if (!file.existsSync()) return '';
    final recognized = await _recognizer.processImage(InputImage.fromFilePath(path));
    return recognized.text;
  }

  /// Parser menu: estrae **solo gli ingredienti** delle pizze/pinse, non i nomi dei piatti.
  @visibleForTesting
  List<MenuImportCandidate> parseMenuText(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map(_cleanLine)
        .where((l) => l.isNotEmpty)
        .toList();

    final seen = <String>{};
    final out = <MenuImportCandidate>[];
    var skipSection = false;
    var inPizzaSection = false;

    void addIngredient(String? name) {
      if (name == null) return;
      final key = name.toLowerCase();
      if (!seen.add(key)) return;
      out.add(
        MenuImportCandidate(
          name: name,
          recommendedDays: guessShelfDays(name),
          category: guessCategory(name),
        ),
      );
    }

    void addFromIngredientLine(String line) {
      for (final part in line.split(RegExp(r'[,;/•·]| e | ed '))) {
        addIngredient(_extractIngredientName(part.trim()));
      }
    }

    bool isSkipSection(String line) {
      final compact = line.toLowerCase().replaceAll(RegExp(r'[^a-zàèéìòù]'), '');
      return {
            'bevande',
            'vino',
            'vini',
            'birre',
            'lenostrebirre',
            'birretradizionali',
            'caffeamaridessert',
            'caffetteria',
            'antipasti',
            'antipasto',
            'dolci',
            'dessert',
          }.contains(compact) ||
          compact.contains('dolc') ||
          compact.contains('dessert') ||
          compact.contains('caffe') ||
          compact.contains('amar');
    }

    bool isPizzaSection(String line) {
      final compact = line.toLowerCase().replaceAll(RegExp(r'[^a-zàèéìòù]'), '');
      return compact.contains('pizz') ||
          compact.contains('pins') ||
          compact.contains('calzon') ||
          compact.contains('classic') ||
          compact.contains('special');
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final lower = raw.toLowerCase();
      if (lower.contains('allergen') || lower.contains('produzione propria')) {
        continue;
      }

      if (isSkipSection(raw)) {
        skipSection = true;
        inPizzaSection = false;
        continue;
      }
      if (isPizzaSection(raw) && !raw.contains(',')) {
        skipSection = false;
        inPizzaSection = true;
        continue;
      }
      if (skipSection || !inPizzaSection) {
        // Fuori dalle pizze: prendi solo la riga topping sotto un nome piatto.
        final dishOutside = _extractDishHeader(raw);
        if (dishOutside != null &&
            i + 1 < lines.length &&
            _looksLikeIngredientLine(lines[i + 1])) {
          addFromIngredientLine(lines[i + 1]);
        }
        continue;
      }

      final dish = _extractDishHeader(raw);
      if (dish != null) {
        if (i + 1 < lines.length && _looksLikeIngredientLine(lines[i + 1])) {
          addFromIngredientLine(lines[i + 1]);
        }
        if (out.length >= 220) break;
        continue;
      }

      if (_looksLikeIngredientLine(raw)) {
        addFromIngredientLine(raw);
        continue;
      }

      if (RegExp(r'^ingredienti\b', caseSensitive: false).hasMatch(raw)) {
        final rest = raw.replaceFirst(RegExp(r'^ingredienti\s*[:\-]?\s*', caseSensitive: false), '');
        addFromIngredientLine(rest);
      }
      if (out.length >= 220) break;
    }

    return out.take(220).toList();
  }

  /// Riga tipo "MARGHERITA € 7,00" o "BERGA (BIANCA) 13,00".
  /// I prezzi italiani usano la virgola (`7,00`): va tolta prima di scartare le liste ingredienti.
  String? _extractDishHeader(String line) {
    var s = line.trim();
    final hasPrice = RegExp(r'€|\d+[.,]\d{2}').hasMatch(s);
    if (hasPrice) {
      s = s.replaceAll(RegExp(r'€\s*\d+[.,]?\d*'), ' ');
      s = s.replaceAll(RegExp(r'\d+[.,]\d{2}\s*€?'), ' ');
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.contains(',')) return null;
    if (!hasPrice) {
      if (s.length < 4 || s.length > 42) return null;
      if (s != s.toUpperCase()) return null;
      if (s.split(' ').length > 6) return null;
    }
    if (s.length < 3 || s.length > 50) return null;
    final lower = s.toLowerCase();
    if (_skipExact.contains(lower)) return null;
    for (final frag in _skipContains) {
      if (lower.contains(frag)) return null;
    }
    final compact = lower.replaceAll(RegExp(r'[^a-zàèéìòù]'), '');
    if (_categoryHeaders.contains(compact)) return null;
    return _titleCase(s);
  }

  bool _looksLikeIngredientLine(String line) {
    final s = line.toLowerCase();
    if (RegExp(r'€|\d+[.,]\d{2}').hasMatch(s)) return false;
    if (s == s.toUpperCase() && line.split(' ').length <= 4) return false;
    return s.contains(',') ||
        RegExp(r'pomodoro|mozzarella|bufala|olio|farina|impasto').hasMatch(s);
  }

  String? _extractIngredientName(String line) {
    var s = line.trim();
    s = s.replaceAll(RegExp(r"\bin cottura\b", caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r"all['’]?uscita\s*:?\s*", caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'\bdoc\b', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'[:"«»]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length < 3 || s.length > 60) return null;
    final lower = s.toLowerCase();
    if ({
      'scaglie',
      'bianca',
      'rossa',
      'picc',
      'cotto',
      'crudo',
      'halal',
      'giovanna',
    }.contains(lower)) {
      if (lower == 'cotto') return 'Prosciutto cotto';
      if (lower == 'crudo') return 'Prosciutto crudo';
      return null;
    }
    if (RegExp(r'^(pizza|pinsa|calzone)\b', caseSensitive: false).hasMatch(s)) return null;
    return _extractDishName(s);
  }

  String _cleanLine(String line) {
    return line
        .replaceAll(RegExp(r'[•·▪◦\-–—]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractDishName(String line) {
    var s = line.trim();
    if (s.length < 3 || s.length > 80) return null;

    // Rimuovi prezzi tipo 8,50 / €8.50 / 8.50€
    s = s.replaceAll(RegExp(r'€\s*\d+[.,]?\d*'), ' ');
    s = s.replaceAll(RegExp(r'\d+[.,]\d{2}\s*€?'), ' ');
    s = s.replaceAll(RegExp(r'\s+\d{1,3}$'), ' ');
    // Punti di riempimento .....
    s = s.replaceAll(RegExp(r'[.]{2,}'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length < 3) return null;

    final lower = s.toLowerCase();
    if (_skipExact.contains(lower)) return null;
    for (final frag in _skipContains) {
      if (lower.contains(frag)) return null;
    }

    // Solo numeri / codice
    if (RegExp(r'^[\d\s.,/]+$').hasMatch(s)) return null;

    // Intestazioni sezione (una o poche parole tutte maiuscole / note)
    final words = s.split(' ');
    if (words.length <= 3) {
      final compact = lower.replaceAll(RegExp(r'[^a-zàèéìòù]'), '');
      if (_categoryHeaders.contains(compact)) return null;
      if (words.every((w) => w == w.toUpperCase()) && words.length <= 2 && s.length <= 18) {
        if (_categoryHeaders.contains(lower) || _skipExact.contains(lower)) return null;
      }
    }

    // Troppo generico
    if (RegExp(r'^(il|la|lo|i|gli|le|un|una|di|e|con)\b', caseSensitive: false).hasMatch(s) &&
        words.length == 1) {
      return null;
    }

    // Capitalizza in modo leggibile
    return _titleCase(s);
  }

  String _titleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (w.length <= 2 && {'di', 'de', 'da', 'e', 'a', 'al', 'in', 'su'}.contains(w.toLowerCase())) {
        return w.toLowerCase();
      }
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  Future<void> dispose() => _recognizer.close();
}
