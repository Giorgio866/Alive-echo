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
  /// Ingredienti singoli letti dalla riga "Ingredienti: ..."
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

/// OCR etichette alimentari e bolle: prodotto, lotto, scadenza, ingredienti.
class LotLabelOcrService {
  LotLabelOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<LotLabelOcrResult> readFromFile(String path) async {
    if (kIsWeb) {
      return const LotLabelOcrResult(rawText: '');
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const LotLabelOcrResult(rawText: '');
    }
    final recognized = await _recognizer.processImage(InputImage.fromFilePath(path));
    return parseLabelText(recognized.text);
  }

  @visibleForTesting
  LotLabelOcrResult parseLabelText(String text) {
    // Normalizza errori OCR tipici
    final normalized = text
        .replaceAll(RegExp(r'[|!]'), 'I')
        .replaceAll(RegExp(r'\bIotto\b', caseSensitive: false), 'Lotto')
        .replaceAll(RegExp(r'\bl0tto\b', caseSensitive: false), 'Lotto')
        .replaceAll(RegExp(r'\bScadenz[ao]\b', caseSensitive: false), 'Scadenza');

    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final ingredients = _extractIngredients(normalized, lines);

    return LotLabelOcrResult(
      productName: _extractProductName(lines),
      lotCode: _extractLotCode(normalized, lines),
      supplier: _extractSupplier(lines),
      expiryAt: _extractExpiry(normalized, lines),
      allergens: _extractAllergens(normalized, lines),
      storageHint: _extractStorage(lines),
      ingredients: ingredients,
      rawText: text,
    );
  }

  String? _extractLotCode(String full, List<String> lines) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:n[°ºo.]?\s*)?(?:di\s+)?(?:lotto|lot\.?|batch)\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-/.]{2,})',
        caseSensitive: false,
      ),
      RegExp(r'\bL\.?\s*[:#]?\s*([A-Z0-9][A-Z0-9\-/.]{3,})\b', caseSensitive: false),
      RegExp(r'\bLOT\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-/.]{2,})', caseSensitive: false),
      RegExp(r'\bLotto\s+([A-Z0-9][A-Z0-9\-/.]{2,})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(full);
      if (m != null) {
        final code = m.group(1)!.toUpperCase();
        if (!_looksLikeDate(code)) return code;
      }
    }
    for (final line in lines) {
      final m = RegExp(
        r'^(?:L|LOT|LOTTO|L\.)\s*[:#.\-]?\s*([A-Z0-9\-/.]{3,})$',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        final code = m.group(1)!.toUpperCase();
        if (!_looksLikeDate(code)) return code;
      }
    }
    return null;
  }

  bool _looksLikeDate(String s) => RegExp(r'^\d{1,2}[/.\-]\d{1,2}').hasMatch(s);

  DateTime? _extractExpiry(String full, List<String> lines) {
    final labeled = RegExp(
      r'(?:scadenza|scad\.?|exp\.?|best before|da consumarsi(?:\s+preferibilmente)?\s+entro|'
      r'tmc|data\s+di\s+scadenza|consumare\s+entro)\s*[:\-]?\s*'
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2})',
      caseSensitive: false,
    ).firstMatch(full);
    if (labeled != null) {
      final d = _parseDate(labeled.group(1)!);
      if (d != null) return d;
    }

    final dateMatches = RegExp(r'\b(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})\b').allMatches(full);
    final candidates = <DateTime>[];
    for (final m in dateMatches) {
      final d = _parseDate(m.group(1)!);
      if (d != null) candidates.add(d);
    }
    if (candidates.isEmpty) return null;
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
    final parts = raw.split(RegExp(r'[/.\-]'));
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

  String? _extractProductName(List<String> lines) {
    const skip = {
      'ingredienti',
      'allergeni',
      'conservare',
      'conservazione',
      'prodotto',
      'italia',
      'made in italy',
      'netto',
      'peso',
      'energia',
      'valori',
      'documento',
      'bolla',
      'ddt',
      'fattura',
    };
    for (final line in lines.take(10)) {
      final lower = line.toLowerCase();
      if (line.length < 3 || line.length > 70) continue;
      if (RegExp(r'^[\d\s.,/%€kgKG]+$').hasMatch(line)) continue;
      if (skip.any((s) => lower == s || lower.startsWith('$s:'))) continue;
      if (RegExp(
        r'lotto|scadenza|exp\.|best before|fornitore|produttore|ingredienti|allergen',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }
      if (RegExp(r'\d{1,2}[/.\-]\d{1,2}[/.\-]').hasMatch(line) && line.length < 16) continue;
      return _title(line);
    }
    return null;
  }

  String? _extractSupplier(List<String> lines) {
    for (final line in lines) {
      final m = RegExp(
        r'(?:fornitore|produttore|prodotto da|fabbricato da|distributore|ragione sociale)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.length >= 2) return _title(v);
      }
    }
    return null;
  }

  String? _extractAllergens(String full, List<String> lines) {
    final m = RegExp(
      r'(?:allergeni|contiene|pu[oò] contenere)\s*[:\-]?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(full);
    if (m != null) {
      var v = m.group(1)!.split(RegExp(r'[\r\n]')).first.trim();
      v = v.replaceAll(RegExp(r'\s+'), ' ');
      // Taglia prima di "Ingredienti" se OCR ha attaccato tutto
      v = v.split(RegExp(r'ingredienti', caseSensitive: false)).first.trim();
      if (v.length > 120) v = v.substring(0, 120);
      if (v.length >= 2) return v;
    }
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
    final lower = full.toLowerCase();
    for (final a in known) {
      if (lower.contains(a)) found.add(_title(a));
    }
    if (found.isEmpty) return null;
    return found.join(', ');
  }

  /// Estrae lista ingredienti singoli da etichetta.
  List<String> _extractIngredients(String full, List<String> lines) {
    final out = <String>[];
    final seen = <String>{};

    void addOne(String raw) {
      var s = raw.trim();
      s = s.replaceAll(RegExp(r'^[\d.)\-\s]+'), '');
      s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Rimuovi percentuali
      s = s.replaceAll(RegExp(r'\d+[.,]?\d*\s*%'), '').trim();
      if (s.length < 2 || s.length > 50) return;
      final lower = s.toLowerCase();
      if (RegExp(r'^(e\d+|acqua|sale|zucchero)$').hasMatch(lower) && lower == 'e') return;
      if ({
        'ingredienti',
        'allergeni',
        'conservare',
        'prodotto',
        'lotto',
        'scadenza',
      }.contains(lower)) {
        return;
      }
      if (!seen.add(lower)) return;
      out.add(_title(s));
    }

    // Blocco "Ingredienti: a, b, c"
    final block = RegExp(
      r'ingredienti\s*[:\-]?\s*(.+?)(?=allergen|conserv|valori|energia|moda|produ|lotto|scadenz|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(full);
    if (block != null) {
      final chunk = block.group(1)!.replaceAll(RegExp(r'[\r\n]+'), ' ');
      for (final part in chunk.split(RegExp(r'[,;•·]| e | ed '))) {
        addOne(part);
      }
    }

    // Righe successive a "Ingredienti"
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'^ingredienti\b', caseSensitive: false).hasMatch(lines[i])) continue;
      final same = lines[i].replaceFirst(RegExp(r'^ingredienti\s*[:\-]?\s*', caseSensitive: false), '');
      if (same.isNotEmpty) {
        for (final part in same.split(RegExp(r'[,;•·]'))) {
          addOne(part);
        }
      }
      for (var j = i + 1; j < lines.length && j <= i + 6; j++) {
        final l = lines[j];
        if (RegExp(r'allergen|conserv|valori|energia|lotto|scadenz', caseSensitive: false).hasMatch(l)) {
          break;
        }
        if (l.contains(',')) {
          for (final part in l.split(RegExp(r'[,;•·]'))) {
            addOne(part);
          }
        } else {
          addOne(l);
        }
      }
      break;
    }

    return out.take(40).toList();
  }

  String? _extractStorage(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'conservare|in frigo|0\s*[–\-]\s*4|refrigerat', caseSensitive: false).hasMatch(line)) {
        return line.length > 80 ? '${line.substring(0, 80)}…' : line;
      }
    }
    return null;
  }

  String _title(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (w.length <= 2) return w.toLowerCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  Future<void> dispose() => _recognizer.close();
}
