import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Download on-device di SmolVLM-256M (visione) da Hugging Face.
/// I pesi NON sono nell'APK (troppo grandi): si scaricano al primo uso (~280 MB).
class VisionModelService {
  static const modelId = 'ggml-org/SmolVLM-256M-Instruct-GGUF';
  static const modelFileName = 'SmolVLM-256M-Instruct-Q8_0.gguf';
  static const mmprojFileName = 'mmproj-SmolVLM-256M-Instruct-Q8_0.gguf';
  static const _prefReady = 'vision_smolvlm256_ready';

  static const _base =
      'https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main';

  final _progress = StreamController<VisionDownloadProgress>.broadcast();
  Stream<VisionDownloadProgress> get progressStream => _progress.stream;

  Future<Directory> modelDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models', 'smolvlm256'));
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
    // File non vuoti
    // Q8 ≈ 175 MB modello + ≈ 104 MB mmproj
    if (model.lengthSync() < 100 * 1024 * 1024) return false;
    if (mmproj.lengthSync() < 50 * 1024 * 1024) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefReady) == true;
  }

  Future<void> deleteModel() async {
    final dir = await modelDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReady, false);
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

    final dir = await modelDirectory();
    await _downloadFile(
      url: '$_base/$modelFileName',
      dest: File(p.join(dir.path, modelFileName)),
      label: 'modello SmolVLM-256M',
      onProgress: onProgress,
    );
    await _downloadFile(
      url: '$_base/$mmprojFileName',
      dest: File(p.join(dir.path, mmprojFileName)),
      label: 'vision projector',
      onProgress: onProgress,
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
  }) async {
    final tmp = File('${dest.path}.part');
    if (await dest.exists() && dest.lengthSync() > 1024 * 1024) {
      return;
    }
    if (await tmp.exists()) await tmp.delete();

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'HACCP-Cucina/1.7';
      final res = await client.send(req);
      if (res.statusCode < 200 || res.statusCode >= 400) {
        throw StateError('Download HF fallito ($label): HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream) {
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
      await sink.close();
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
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
