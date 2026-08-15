import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'lot_label_ocr_service.dart';
import 'vision_model_service.dart';

/// Legge etichette alimentari con SmolVLM on-device (visione vera, non solo OCR).
class VisionLabelService {
  VisionLabelService({VisionModelService? models}) : _models = models ?? VisionModelService();

  final VisionModelService _models;
  LlamaEngine? _engine;

  Future<bool> get isReady => _models.isReady();

  Future<void> ensureModel({void Function(VisionDownloadProgress)? onProgress}) {
    return _models.ensureDownloaded(onProgress: onProgress);
  }

  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    if (kIsWeb) throw UnsupportedError('Vision AI non disponibile sul web');
    if (!await _models.isReady()) {
      throw StateError('Scarica prima SmolVLM da Impostazioni → Vision AI');
    }
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('Vision AI supportata su Android (e desktop di sviluppo)');
    }

    // Su Android l'AAR espone le .so nel path JNI: basta il basename.
    final libraryPath = Platform.isAndroid ? 'libllama.so' : 'libllama.so';

    _engine = await LlamaEngine.spawn(
      libraryPath: libraryPath,
      modelParams: ModelParams(
        path: await _models.modelPath(),
        gpuLayers: 0,
      ),
      contextParams: const ContextParams(
        nCtx: 2048,
        nBatch: 512,
      ),
      multimodalParams: MultimodalParams(
        mmprojPath: await _models.mmprojPath(),
        useGpu: false,
        nThreads: 4,
        warmup: false,
      ),
    );

    if (!_engine!.multimodalLoaded) {
      await _engine!.dispose();
      _engine = null;
      throw StateError(
        'libmtmd non caricata: Vision AI non disponibile su questo dispositivo',
      );
    }
  }

  Future<LotLabelOcrResult> readLabelImage(String imagePath) async {
    await _ensureEngine();
    final engine = _engine!;
    final chat = await engine.createChat();

    const system =
        'You extract data from Italian food packaging labels. Reply with ONLY valid JSON, no markdown.';
    const userText = '''
Read this food product label photo and extract:
- productName: brand + product name (e.g. TASTASAL AL NATURALE)
- lotCode: value after LOTTO / LOTTO n. (e.g. L6071318005). Never invent fragments like ATTE from LATTE.
- expiryAt: date after "Da consumare entro" as YYYY-MM-DD (handle 02 08 26 as 2026-08-02)
- supplier: producer/stabilimento if present else null
- allergens: only if the label says allergens are PRESENT. If it says SENZA GLUTINE / SENZA LATTE, use "Nessuno (senza glutine/latte)".
- ingredients: list of individual ingredients from INGREDIENTI section

JSON schema:
{"productName":"","lotCode":"","expiryAt":"YYYY-MM-DD or null","supplier":null,"allergens":null,"ingredients":[]}
''';

    try {
      chat.addSystem(system);
      chat.addUser(
        userText,
        media: [LlamaMedia.imageFile(imagePath)],
      );

      final buf = StringBuffer();
      await for (final event in chat.generate(
        maxTokens: 256,
        sampler: const SamplerParams(temperature: 0.1, topP: 0.9),
      )) {
        switch (event) {
          case TokenEvent():
            buf.write(event.text);
          case DoneEvent():
            if (event.trailingText.isNotEmpty) buf.write(event.trailingText);
          case ShiftEvent():
            break;
        }
      }
      return parseModelJson(buf.toString());
    } finally {
      await chat.dispose();
    }
  }

  /// Esposto per i test unitari sul parsing JSON del modello.
  static LotLabelOcrResult parseModelJson(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'```$'), '');

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return LotLabelOcrResult(rawText: raw);
    }
    final jsonStr = text.substring(start, end + 1);
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      DateTime? expiry;
      final expRaw = map['expiryAt']?.toString();
      if (expRaw != null && expRaw.isNotEmpty && expRaw.toLowerCase() != 'null') {
        expiry = DateTime.tryParse(expRaw);
      }
      final ingredients = <String>[];
      final ing = map['ingredients'];
      if (ing is List) {
        for (final e in ing) {
          final s = e.toString().trim();
          if (s.isNotEmpty) ingredients.add(s);
        }
      }
      String? str(String key) {
        final v = map[key];
        if (v == null) return null;
        final s = v.toString().trim();
        if (s.isEmpty || s.toLowerCase() == 'null') return null;
        return s;
      }

      return LotLabelOcrResult(
        productName: str('productName'),
        lotCode: str('lotCode')?.toUpperCase(),
        supplier: str('supplier'),
        expiryAt: expiry,
        allergens: str('allergens'),
        ingredients: ingredients,
        rawText: raw,
      );
    } catch (_) {
      return LotLabelOcrResult(rawText: raw);
    }
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }
}
