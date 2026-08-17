import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TemperatureOcrResult {
  final double? valueC;
  final String rawText;
  final List<double> candidates;

  const TemperatureOcrResult({
    required this.valueC,
    required this.rawText,
    required this.candidates,
  });
}

/// Estrae una temperatura (°C) da una foto del display del termometro.
class TemperatureOcrService {
  TemperatureOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<TemperatureOcrResult> readFromFile(String path) async {
    if (kIsWeb) {
      return const TemperatureOcrResult(valueC: null, rawText: '', candidates: []);
    }
    final file = File(path);
    if (!file.existsSync()) {
      return const TemperatureOcrResult(valueC: null, rawText: '', candidates: []);
    }

    final input = InputImage.fromFilePath(path);
    final recognized = await _recognizer.processImage(input);
    final text = recognized.text;
    final candidates = _extractTemperatures(text);
    return TemperatureOcrResult(
      valueC: candidates.isEmpty ? null : candidates.first,
      rawText: text,
      candidates: candidates,
    );
  }

  /// Ordina candidati plausibili (range tipico HACCP cucina).
  List<double> _extractTemperatures(String text) {
    final normalized = text
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^\w.\-\s°]'), ' ');
    final matches = RegExp(r'(?<![\d.])(-?\d{1,2}(?:\.\d{1,2})?)').allMatches(normalized);
    final values = <double>[];
    for (final m in matches) {
      final v = double.tryParse(m.group(1)!);
      if (v == null) continue;
      if (v < -40 || v > 90) continue;
      if (v >= 1900) continue;
      values.add(v);
    }
    values.sort((a, b) {
      int score(double x) {
        if (x >= -2 && x <= 8) return 0;
        if (x >= -30 && x <= -10) return 1;
        if (x >= 55 && x <= 80) return 2;
        return 3;
      }

      final c = score(a).compareTo(score(b));
      if (c != 0) return c;
      return a.abs().compareTo(b.abs());
    });
    final seen = <String>{};
    final unique = <double>[];
    for (final v in values) {
      final key = v.toStringAsFixed(1);
      if (seen.add(key)) unique.add(v);
    }
    return unique;
  }

  /// Esposto per i test unitari del parser.
  @visibleForTesting
  List<double> extractForTest(String text) => _extractTemperatures(text);

  Future<void> dispose() => _recognizer.close();
}
