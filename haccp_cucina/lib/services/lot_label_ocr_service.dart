import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Dati estratti da foto di etichetta prodotto / lotto / bolla.
class LotLabelOcrResult {
  final String? productName;
  final String? lotCode;
  final String? supplier;
  final DateTime? expiryAt;
  final String? allergens;
  final String? storageHint;
  final List<String> ingredients;
  final String rawText;

  const LotLabelOcrResult({
    this.productName,
    this.lotCode,
    this.supplier,
    this.expiryAt,
    this.allergens,
    this.storageHint,
    this.ingredients = const [],
    required this.rawText,
  });

  bool get hasUsefulData =>
      (productName != null && productName!.isNotEmpty) ||
      (lotCode != null && lotCode!.isNotEmpty) ||
      expiryAt != null ||
      ingredients.isNotEmpty;
}

/// OCR etichette alimentari italiane (es. Tastasal / salumi / latticini).
class LotLabelOcrService {
  LotLabelOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Parole che NON sono codici lotto (evita "ATTE" da "LATTE").
  static const _lotBlacklist = {
    'ATTE',
    'ATTE.',
    'OTTO',
    'OTTO.',
    'OTTONE',
    'ITALIA',
    'ITALY',
    'FRESCO',
    'SUINO',
    'CARNE',
    'CARNEO',
    'NATURALE',
    'GLUTINE',
    'LATTE',
    'SALE',
    'PESO',
    'NETTO',
    'DATA',
    'ENTRO',
    'CONFEZIONATO',
    'CONSUMARE',
    'INGREDIENTI',
    'ALLERGENI',
    'CONSERVARE',
    'FRIGORIFERO',
    'ORIGINE',
    'SENZA',
    'DERIVATI',
  };

  Future<LotLabelOcrResult> readFromFile(String path) async {
    if (kIsWeb) {
      return const LotLabelOcrResult(rawText: '');
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const LotLabelOcrResult(rawText: '');
    }
    final recognized = await _recognizer.processImage(InputImage.fromFilePath(path));
    // Usa anche i blocchi ML Kit se disponibili (ordine di lettura migliore)
    final buffer = StringBuffer(recognized.text);
    if (recognized.blocks.isNotEmpty) {
      buffer.writeln();
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
    }
    return parseLabelText(buffer.toString());
  }

  @visibleForTesting
  LotLabelOcrResult parseLabelText(String text) {
    final normalized = _normalize(text);
    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final ingredients = _extractIngredients(normalized, lines);
    final product = _extractProductName(lines, normalized);
    final lot = _extractLotCode(normalized, lines);
    final expiry = _extractExpiry(normalized);
    final allergens = _extractAllergens(normalized);
    final supplier = _extractSupplier(normalized, lines);

    return LotLabelOcrResult(
      productName: product,
      lotCode: lot,
      supplier: supplier,
      expiryAt: expiry,
      allergens: allergens,
      storageHint: _extractStorage(lines),
      ingredients: ingredients,
      rawText: text,
    );
  }

  String _normalize(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[|!]'), 'I')
        .replaceAll(RegExp(r'\bIotto\b', caseSensitive: false), 'LOTTO')
        .replaceAll(RegExp(r'\bl0tto\b', caseSensitive: false), 'LOTTO')
        .replaceAll(RegExp(r'\bIOTTO\b'), 'LOTTO')
        .replaceAll(RegExp(r'\bn\.\s*', caseSensitive: false), 'n. ')
        .replaceAll(RegExp(r'[–—]'), '-');
  }

  String? _extractLotCode(String full, List<String> lines) {
    // Priorità alta: "LOTTO n. L6071318005" / "LOTTO: L607..." / "LOTTO n L607..."
    final primary = <RegExp>[
      RegExp(
        r'LOTTO\s*n\.?\s*[:#]?\s*(L?\d{6,})',
        caseSensitive: false,
      ),
      RegExp(
        r'LOTTO\s*[:#.]?\s*(L?\d{6,})',
        caseSensitive: false,
      ),
      RegExp(
        r'LOTTO\s*n\.?\s*[:#]?\s*([A-Z0-9\-]{5,})',
        caseSensitive: false,
      ),
      RegExp(
        r'LOTTO\s*[:#.]?\s*([A-Z]{0,4}\d{3,}[A-Z0-9\-]*)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bLOT\s*[:#.]?\s*([A-Z0-9\-]{5,})\b',
        caseSensitive: false,
      ),
      // Codice tipo L + molte cifre anche senza parola LOTTO vicina
      RegExp(r'\b(L\d{7,18})\b', caseSensitive: false),
    ];

    for (final p in primary) {
      final m = p.firstMatch(full);
      if (m != null) {
        final code = _cleanLot(m.group(1)!);
        if (code != null) return code;
      }
    }

    // Vicino alla riga che contiene LOTTO
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'lotto', caseSensitive: false).hasMatch(lines[i])) continue;
      final same = RegExp(
        r'lotto\s*n\.?\s*[:#]?\s*([A-Z0-9\-]{5,})',
        caseSensitive: false,
      ).firstMatch(lines[i]);
      if (same != null) {
        final code = _cleanLot(same.group(1)!);
        if (code != null) return code;
      }
      // Codice sulla riga dopo
      if (i + 1 < lines.length) {
        final next = RegExp(r'\b(L?\d{6,18})\b', caseSensitive: false).firstMatch(lines[i + 1]);
        if (next != null) {
          final code = _cleanLot(next.group(1)!);
          if (code != null) return code;
        }
      }
    }

    return null;
  }

  String? _cleanLot(String raw) {
    var code = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
    if (code.isEmpty) return null;
    if (_lotBlacklist.contains(code)) return null;
    // Mai accettare pezzi di parole tipo ATTE (da LATTE)
    if (!RegExp(r'\d').hasMatch(code)) return null;
    if (code.length < 5) return null;
    if (_looksLikeDate(code)) return null;
    // Preferisci codici con molte cifre
    final digits = RegExp(r'\d').allMatches(code).length;
    if (digits < 4) return null;
    return code;
  }

  bool _looksLikeDate(String s) =>
      RegExp(r'^\d{1,2}[/.\-]\d{1,2}').hasMatch(s) || RegExp(r'^\d{6}$').hasMatch(s) && false;

  DateTime? _extractExpiry(String full) {
    // "Da consumare entro il 02 08 26" / "Da consumarsi entro il: 02/08/2026"
    final labeled = <RegExp>[
      RegExp(
        r'da\s+consumare(?:si)?\s+entro(?:\s+il)?\s*[:\-]?\s*'
        r'(\d{1,2}\s+\d{1,2}\s+\d{2,4}|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:scadenza|scad\.?|tmc|exp\.?|best before|data\s+di\s+scadenza)\s*[:\-]?\s*'
        r'(\d{1,2}\s+\d{1,2}\s+\d{2,4}|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})',
        caseSensitive: false,
      ),
    ];
    for (final p in labeled) {
      final m = p.firstMatch(full);
      if (m != null) {
        final d = _parseDate(m.group(1)!);
        if (d != null) return d;
      }
    }

    // Evita di prendere "confezionato il" come scadenza se c'è anche "consumare entro"
    final packaged = RegExp(
      r'confezionat[oa]\s+il\s*[:\-]?\s*(\d{1,2}\s+\d{1,2}\s+\d{2,4}|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})',
      caseSensitive: false,
    ).firstMatch(full);
    DateTime? packDate;
    if (packaged != null) packDate = _parseDate(packaged.group(1)!);

    final dateMatches = RegExp(
      r'\b(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{1,2}\s+\d{1,2}\s+\d{2,4})\b',
    ).allMatches(full);
    final candidates = <DateTime>[];
    for (final m in dateMatches) {
      final d = _parseDate(m.group(1)!);
      if (d == null) continue;
      if (packDate != null && d == packDate) continue;
      candidates.add(d);
    }
    if (candidates.isEmpty) return packDate;
    final now = DateTime.now();
    candidates.sort((a, b) {
      final af = a.isBefore(now.subtract(const Duration(days: 1))) ? 1 : 0;
      final bf = b.isBefore(now.subtract(const Duration(days: 1))) ? 1 : 0;
      if (af != bf) return af.compareTo(bf);
      return a.compareTo(b);
    });
    return candidates.first;
  }

  DateTime? _parseDate(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    List<String> parts;
    if (cleaned.contains(RegExp(r'[/\-.]'))) {
      parts = cleaned.split(RegExp(r'[/\-.]'));
    } else {
      parts = cleaned.split(' ');
    }
    if (parts.length != 3) return null;
    int? day;
    int? month;
    int? year;
    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    } else {
      day = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      year = int.tryParse(parts[2]);
      if (year != null && year < 100) year += 2000;
    }
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String? _extractProductName(List<String> lines, String full) {
    // Preferisci marchio in maiuscolo tipo "TASTASAL AL NATURALE"
    for (final line in lines.take(12)) {
      final upper = line.toUpperCase();
      if (line.length < 4 || line.length > 60) continue;
      if (RegExp(r'INGREDIENTI|LOTTO|SCADEN|CONSUM|CONFEZ|ENERGIA|VALORI|ALLERGEN|CONSERV|QUANTIT',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      if (RegExp(r'^[\d\s.,/%€]+$').hasMatch(line)) continue;
      // Marchio tutto maiuscolo / quasi
      final letters = upper.replaceAll(RegExp(r'[^A-Z]'), '');
      if (letters.length >= 5 && upper == line && !upper.contains('INGREDIENTI')) {
        return _title(line);
      }
    }

    // Descrizione tipo "Impasto carneo fresco di suino" (prima di Ingredienti)
    for (final line in lines.take(15)) {
      final lower = line.toLowerCase();
      if (lower.startsWith('impasto') ||
          lower.startsWith('carne') ||
          lower.contains('fresco di') ||
          lower.contains('fior di')) {
        var name = line;
        // Taglia se OCR ha attaccato "Ingredienti..."
        name = name.split(RegExp(r'\s*[-–]?\s*ingredienti', caseSensitive: false)).first.trim();
        if (name.length >= 5) return _title(name);
      }
    }

    for (final line in lines.take(8)) {
      final lower = line.toLowerCase();
      if (line.length < 3 || line.length > 70) continue;
      if (RegExp(r'ingredienti|lotto|scadenz|consum|confez|allergen|conserv|energia|valori|origine',
              caseSensitive: false)
          .hasMatch(lower)) {
        continue;
      }
      if (RegExp(r'^[\d\s.,/%€kg]+$', caseSensitive: false).hasMatch(line)) continue;
      var name = line.split(RegExp(r'\s*[-–]?\s*ingredienti', caseSensitive: false)).first.trim();
      if (name.length >= 3) return _title(name);
    }
    return null;
  }

  String? _extractSupplier(String full, List<String> lines) {
    final stab = RegExp(
      r'(?:prodotto\s+nello\s+stabilimento\s+di|stabilimento\s+di)\s*[:\-]?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(full);
    if (stab != null) {
      var v = stab.group(1)!.split(RegExp(r'[\r\n]|conservare', caseSensitive: false)).first.trim();
      if (v.length > 80) v = v.substring(0, 80);
      if (v.length >= 5) return _title(v);
    }
    for (final line in lines) {
      final m = RegExp(
        r'(?:fornitore|produttore|prodotto da|fabbricato da|distributore)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.length >= 2 && !v.toLowerCase().startsWith('nello stabilimento')) {
          return _title(v);
        }
      }
    }
    return null;
  }

  String? _extractAllergens(String full) {
    final lower = full.toLowerCase();

    // Claim "SENZA GLUTINE E DERIVATI DEL LATTE" → nessun allergene dichiarato
    if (RegExp(r'senza\s+glutine', caseSensitive: false).hasMatch(lower) &&
        RegExp(r'(latte|derivati\s+del\s+latte)', caseSensitive: false).hasMatch(lower) &&
        !RegExp(r'allergeni\s*:\s*(?!nessun)', caseSensitive: false).hasMatch(lower)) {
      // Se dice esplicitamente SENZA entrambi, non inventare allergeni
      if (RegExp(r'senza\s+glutine.{0,40}(latte|derivati)', caseSensitive: false).hasMatch(lower) ||
          RegExp(r'senza.{0,20}glutine.{0,20}e.{0,20}(derivati\s+del\s+)?latte', caseSensitive: false)
              .hasMatch(lower)) {
        return 'Nessuno (senza glutine/latte)';
      }
    }

    final explicit = RegExp(
      r'allergeni\s*[:\-]?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(full);
    if (explicit != null) {
      var v = explicit.group(1)!.split(RegExp(r'[\r\n]')).first.trim();
      v = v.replaceAll(RegExp(r'\s+'), ' ');
      v = v.split(RegExp(r'ingredienti|conservare|valori', caseSensitive: false)).first.trim();
      if (RegExp(r'^nessun', caseSensitive: false).hasMatch(v)) {
        return 'Nessuno';
      }
      if (v.length >= 2 && v.length < 120) return v;
    }

    // Contiene X solo se NON preceduto da "senza"
    const known = [
      'glutine',
      'latte',
      'uova',
      'soia',
      'frutta a guscio',
      'arachidi',
      'sesamo',
      'pesce',
      'crostacei',
      'molluschi',
      'sedano',
      'senape',
      'lupini',
      'solfiti',
    ];
    final found = <String>[];
    for (final a in known) {
      final re = RegExp(r'(?<!senza\s)(?<!senza\s.{0,30})\b' + a + r'\b', caseSensitive: false);
      // Approccio più semplice: cerca "contiene ..." oppure parola non in contesto "senza"
      if (RegExp('senza[\\s\\w]{0,40}$a', caseSensitive: false).hasMatch(lower)) {
        continue;
      }
      if (RegExp(r'contiene[\\s\\w,:/]{0,40}' + a, caseSensitive: false).hasMatch(lower) ||
          RegExp(r'allergeni[\\s\\w,:/]{0,40}' + a, caseSensitive: false).hasMatch(lower)) {
        found.add(_title(a));
      }
    }
    if (found.isEmpty) return null;
    return found.join(', ');
  }

  List<String> _extractIngredients(String full, List<String> lines) {
    final out = <String>[];
    final seen = <String>{};

    void addOne(String raw) {
      var s = raw.trim();
      s = s.replaceAll(RegExp(r'^[\d.)\-\s]+'), '');
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      s = s.replaceAll(RegExp(r'\d+[.,]?\d*\s*%'), '').trim();
      // Taglia claim successivi
      s = s.split(RegExp(r'carne origine|senza glutine|da consumarsi|antiossidante', caseSensitive: false)).first.trim();
      if (s.length < 2 || s.length > 45) return;
      final lower = s.toLowerCase();
      if ({
        'ingredienti',
        'allergeni',
        'conservare',
        'prodotto',
        'lotto',
        'scadenza',
        'aromi e spezie',
      }.contains(lower)) {
        if (lower == 'aromi e spezie') {
          if (seen.add(lower)) out.add(_title(s));
        }
        return;
      }
      if (RegExp(r'^(e\d{3,4})$', caseSensitive: false).hasMatch(s)) {
        if (seen.add(lower)) out.add(s.toUpperCase());
        return;
      }
      if (!seen.add(lower)) return;
      out.add(_title(s));
    }

    final block = RegExp(
      r'INGREDIENTI\s*[:\-]?\s*(.+?)(?=SENZA\s+GLUTINE|ALLERGEN|CONSERV|VALORI|ENERGIA|DA\s+CONSUM|CARNE\s+ORIGINE|LOTTO|QUANTIT|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(full);
    if (block != null) {
      var chunk = block.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ' ');
      // "Antiossidante: E300" → tieni E300
      chunk = chunk.replaceAllMapped(
        RegExp(r'antiossidante\s*:\s*(E\d+)', caseSensitive: false),
        (m) => m.group(1)!,
      );
      for (final part in chunk.split(RegExp(r'[,;•·.]|\s+e\s+'))) {
        addOne(part);
      }
    }

    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'^ingredienti\b', caseSensitive: false).hasMatch(lines[i])) continue;
      final same = lines[i].replaceFirst(RegExp(r'^ingredienti\s*[:\-]?\s*', caseSensitive: false), '');
      if (same.isNotEmpty) {
        for (final part in same.split(RegExp(r'[,;•·]'))) {
          addOne(part);
        }
      }
      for (var j = i + 1; j < lines.length && j <= i + 8; j++) {
        final l = lines[j];
        if (RegExp(
          r'senza glutine|allergen|conserv|valori|energia|lotto|scadenz|da consum|quantit|carne origine',
          caseSensitive: false,
        ).hasMatch(l)) {
          break;
        }
        for (final part in l.split(RegExp(r'[,;•·]'))) {
          addOne(part);
        }
      }
      break;
    }

    return out.take(40).toList();
  }

  String? _extractStorage(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'conservare|in frigo|0\s*[–\-a]\s*4|refrigerat', caseSensitive: false).hasMatch(line)) {
        return line.length > 80 ? '${line.substring(0, 80)}…' : line;
      }
    }
    return null;
  }

  String _title(String s) {
    // Mantieni marchi tutto maiuscolo corti
    if (s == s.toUpperCase() && s.length <= 40 && RegExp(r'[A-Z]').hasMatch(s)) {
      return s.trim();
    }
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (w.length <= 2) return w.toLowerCase();
      if (RegExp(r'^E\d+$', caseSensitive: false).hasMatch(w)) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  Future<void> dispose() => _recognizer.close();
}
