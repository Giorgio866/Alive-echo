import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Dati estratti da foto di etichetta prodotto / lotto.
class LotLabelOcrResult {
  final String? productName;
  final String? lotCode;
  final String? supplier;
  final DateTime? expiryAt;
  final String? allergens;
  final String? storageHint;
  final String rawText;

  const LotLabelOcrResult({
    this.productName,
    this.lotCode,
    this.supplier,
    this.expiryAt,
    this.allergens,
    this.storageHint,
    required this.rawText,
  });

  bool get hasUsefulData =>
      (productName != null && productName!.isNotEmpty) ||
      (lotCode != null && lotCode!.isNotEmpty) ||
      expiryAt != null;
}

/// OCR etichette alimentari: prodotto, lotto, scadenza, fornitore, allergeni.
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
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return LotLabelOcrResult(
      productName: _extractProductName(lines),
      lotCode: _extractLotCode(text, lines),
      supplier: _extractSupplier(lines),
      expiryAt: _extractExpiry(text, lines),
      allergens: _extractAllergens(text, lines),
      storageHint: _extractStorage(lines),
      rawText: text,
    );
  }

  String? _extractLotCode(String full, List<String> lines) {
    final patterns = <RegExp>[
      RegExp(r'(?:lotto|lot\.?|l\.?ot\.?|batch|n[°º.]?\s*lotto)\s*[:#.]?\s*([A-Z0-9][A-Z0-9\-/.]{2,})',
          caseSensitive: false),
      RegExp(r'\bL\s*[:#]\s*([A-Z0-9][A-Z0-9\-/.]{2,})', caseSensitive: false),
      RegExp(r'\bLOT\s*([A-Z0-9][A-Z0-9\-/.]{2,})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(full);
      if (m != null) return m.group(1)!.toUpperCase();
    }
    for (final line in lines) {
      final m = RegExp(r'^(?:L|LOT|LOTTO)\s*[:#]?\s*([A-Z0-9\-/.]{3,})$', caseSensitive: false)
          .firstMatch(line);
      if (m != null) return m.group(1)!.toUpperCase();
    }
    return null;
  }

  DateTime? _extractExpiry(String full, List<String> lines) {
    final labeled = RegExp(
      r'(?:scadenza|scad\.?|exp\.?|best before|da consumarsi(?:\s+preferibilmente)?\s+entro|tmc|data\s+di\s+scadenza)\s*[:\-]?\s*'
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}|\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2})',
      caseSensitive: false,
    ).firstMatch(full);
    if (labeled != null) {
      final d = _parseDate(labeled.group(1)!);
      if (d != null) return d;
    }

    // Date generiche: preferisci future / vicine
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
    };
    for (final line in lines.take(8)) {
      final lower = line.toLowerCase();
      if (line.length < 3 || line.length > 60) continue;
      if (RegExp(r'^[\d\s.,/%€]+$').hasMatch(line)) continue;
      if (skip.any((s) => lower.contains(s))) continue;
      if (RegExp(r'lotto|scadenza|exp\.|best before|fornitore|produttore', caseSensitive: false)
          .hasMatch(line)) {
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
        r'(?:fornitore|produttore|prodotto da|fabbricato da|distributore)\s*[:\-]?\s*(.+)$',
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
