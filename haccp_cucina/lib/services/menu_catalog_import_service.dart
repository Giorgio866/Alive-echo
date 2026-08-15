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
  });

  String name;
  int recommendedDays;
  bool selected;
  String category;
  String storageHint;
  String? allergens;
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
  };

  static const _skipContains = [
    'allergen',
    'glutine',
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
    'panini',
    'hamburger',
    'kebab',
    'extra',
    'aggiunte',
    'supplementi',
  };

  /// Stima giorni di scadenza tipici da parole chiave.
  int guessShelfDays(String name) {
    final n = name.toLowerCase();
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
    if (RegExp(r'impasto|pinsa|biga').hasMatch(n)) return 'impasto';
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

  /// Parser menu: estrae nomi piatti/ingredienti da testo OCR.
  @visibleForTesting
  List<MenuImportCandidate> parseMenuText(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map(_cleanLine)
        .where((l) => l.isNotEmpty)
        .toList();

    final seen = <String>{};
    final out = <MenuImportCandidate>[];

    void addName(String? name) {
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

    // Estrai anche liste "Ingredienti: a, b, c" e "(pomodoro, mozzarella)"
    for (final raw in lines) {
      final paren = RegExp(r'\(([^)]{3,})\)').firstMatch(raw);
      if (paren != null) {
        for (final part in paren.group(1)!.split(RegExp(r'[,;/]| e | ed '))) {
          addName(_extractDishName(part.trim()));
        }
      }
      if (RegExp(r'^ingredienti\b', caseSensitive: false).hasMatch(raw)) {
        final rest = raw.replaceFirst(RegExp(r'^ingredienti\s*[:\-]?\s*', caseSensitive: false), '');
        for (final part in rest.split(RegExp(r'[,;/•·]| e | ed '))) {
          addName(_extractDishName(part.trim()));
        }
        continue;
      }
      addName(_extractDishName(raw));
      if (out.length >= 120) break;
    }

    // Blocco multilinea ingredienti nel testo intero
    final block = RegExp(
      r'ingredienti\s*[:\-]?\s*(.+?)(?=\n\s*[A-Z][A-Z ]{3,}|\n\s*allergen|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (block != null) {
      final chunk = block.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ',');
      for (final part in chunk.split(RegExp(r'[,;/•·]'))) {
        addName(_extractDishName(part.trim()));
      }
    }

    return out.take(120).toList();
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
