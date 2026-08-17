import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Download on-device di SmolVLM2-2.2B (visione) da Hugging Face.
/// I pesi NON sono nell'APK: si scaricano al primo uso (~1.7 GB).
class VisionModelService {
  static const modelId = 'ggml-org/SmolVLM2-2.2B-Instruct-GGUF';
  static const displayName = 'SmolVLM2-2.2B';
  static const approxSizeLabel = '~1,7 GB';
  static const modelFileName = 'SmolVLM2-2.2B-Instruct-Q4_K_M.gguf';
  static const mmprojFileName = 'mmproj-SmolVLM2-2.2B-Instruct-Q8_0.gguf';
  static const _prefReady = 'vision_smolvlm2_2b_ready';

  static const _base =
      'https://huggingface.co/ggml-org/SmolVLM2-2.2B-Instruct-GGUF/resolve/main';

  /// Cartelle di modelli precedenti da ripulire dopo upgrade.
  static const _legacyDirs = ['smolvlm256', 'smolvlm500', 'smolvlm2_500'];
  static const _legacyPrefs = [
    'vision_smolvlm256_ready',
    'vision_smolvlm500_ready',
    'vision_smolvlm2_500_ready',
  ];

  final _progress = StreamController<VisionDownloadProgress>.broadcast();
  Stream<VisionDownloadProgress> get progressStream => _progress.stream;

  Future<Directory> modelDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models', 'smolvlm2_2b'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> modelPath() async => p.join((await modelDirectory()).path, modelFileName);
  Future<String> mmprojPath() async => p.join((await modelDirectory()).path, mmprojFileName);

  Future<bool> isReady() async {
    if (kIsWeb) return false;
    final model = File(await modelPath());
    final mmproj = File(await mmprojPath());
    if (!model.existsSync() || !mmproj.existsSync()) return false;
    // Q4_K_M ≈ 1.1 GB + mmproj Q8 ≈ 590 MB
    if (model.lengthSync() < 800 * 1024 * 1024) return false;
    if (mmproj.lengthSync() < 400 * 1024 * 1024) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefReady) == true;
  }

  Future<void> deleteModel() async {
    final dir = await modelDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReady, false);
  }

  Future<void> _cleanupLegacy() async {
    final docs = await getApplicationDocumentsDirectory();
    for (final name in _legacyDirs) {
      final dir = Directory(p.join(docs.path, 'models', name));
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyPrefs) {
      await prefs.remove(key);
    }
  }

  Future<void> ensureDownloaded({void Function(VisionDownloadProgress)? onProgress}) async {
    if (await isReady()) {
      final done = VisionDownloadProgress(phase: 'pronto', received: 1, total: 1, fileLabel: 'ok');
      onProgress?.call(done);
      _progress.add(done);
      return;
    }
    if (kIsWeb) {
      throw UnsupportedError('Vision AI on-device non disponibile sul web');
    }

    await _cleanupLegacy();
    final dir = await modelDirectory();
    await _downloadFile(
      url: '$_base/$modelFileName',
      dest: File(p.join(dir.path, modelFileName)),
      label: 'modello SmolVLM2-2.2B',
      onProgress: onProgress,
      minBytes: 800 * 1024 * 1024,
    );
    await _downloadFile(
      url: '$_base/$mmprojFileName',
      dest: File(p.join(dir.path, mmprojFileName)),
      label: 'vision projector',
      onProgress: onProgress,
      minBytes: 400 * 1024 * 1024,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReady, true);
    final done = VisionDownloadProgress(phase: 'pronto', received: 1, total: 1, fileLabel: 'ok');
    onProgress?.call(done);
    _progress.add(done);
  }

  Future<void> _downloadFile({
    required String url,
    required File dest,
    required String label,
    void Function(VisionDownloadProgress)? onProgress,
    required int minBytes,
  }) async {
    final tmp = File('${dest.path}.part');
    if (await dest.exists() && dest.lengthSync() >= minBytes) {
      return;
    }
    if (await tmp.exists()) await tmp.delete();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'HACCP-Cucina/1.8';
      final res = await client.send(req).timeout(const Duration(minutes: 2));
      if (res.statusCode < 200 || res.statusCode >= 400) {
        throw StateError('Download HF fallito ($label): HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream.timeout(const Duration(minutes: 30))) {
          sink.add(chunk);
          received += chunk.length;
          final prog = VisionDownloadProgress(
            phase: 'download',
            received: received,
            total: total,
            fileLabel: label,
          );
          onProgress?.call(prog);
          if (!_progress.isClosed) _progress.add(prog);
        }
      } finally {
        await sink.close();
      }
      if (received < minBytes) {
        if (await tmp.exists()) await tmp.delete();
        throw StateError('Download incompleto ($label): ${received ~/ (1024 * 1024)} MB');
      }
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  void dispose() {
    _progress.close();
  }
}

class VisionDownloadProgress {
  final String phase; // download | pronto
  final int received;
  final int total;
  final String fileLabel;

  const VisionDownloadProgress({
    required this.phase,
    required this.received,
    required this.total,
    required this.fileLabel,
  });

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);

  String get labelMb {
    if (phase == 'pronto') return 'Modello pronto';
    final r = received / (1024 * 1024);
    if (total <= 0) return '$fileLabel: ${r.toStringAsFixed(0)} MB…';
    final t = total / (1024 * 1024);
    return '$fileLabel: ${r.toStringAsFixed(0)} / ${t.toStringAsFixed(0)} MB';
  }
}
