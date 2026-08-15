import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'lot_label_ocr_service.dart';
import 'vision_model_service.dart';

/// Legge etichette alimentari con SmolVLM2-2.2B on-device.
/// Opzionale: [ocrHint] (testo ML Kit) guida il modello su lotto/scadenza.
class VisionLabelService {
  VisionLabelService({VisionModelService? models}) : _models = models ?? VisionModelService();

  final VisionModelService _models;
  LlamaEngine? _engine;
  String? _loadedModelPath;

  Future<bool> get isReady => _models.isReady();

  Future<void> ensureModel({void Function(VisionDownloadProgress)? onProgress}) {
    return _models.ensureDownloaded(onProgress: onProgress);
  }

  Future<void> _ensureEngine() async {
    if (kIsWeb) throw UnsupportedError('Vision AI non disponibile sul web');
    if (!await _models.isReady()) {
      throw StateError('Scarica prima SmolVLM2 da Impostazioni → Vision AI');
    }
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('Vision AI supportata su Android (e desktop di sviluppo)');
    }

    final modelPath = await _models.modelPath();
    if (_engine != null && _loadedModelPath == modelPath) return;
    await dispose();

    final threads = Platform.numberOfProcessors.clamp(2, 6);

    _engine = await LlamaEngine.spawn(
      libraryPath: 'libllama.so',
      modelParams: ModelParams(
        path: modelPath,
        gpuLayers: 0,
      ),
      contextParams: ContextParams(
        nCtx: 4096,
        nBatch: 512,
        nThreads: threads,
        nThreadsBatch: threads,
      ),
      multimodalParams: MultimodalParams(
        mmprojPath: await _models.mmprojPath(),
        useGpu: false,
        nThreads: threads,
        warmup: false,
      ),
    );
    _loadedModelPath = modelPath;

    if (!_engine!.multimodalLoaded) {
      await dispose();
      throw StateError(
        'libmtmd non caricata: Vision AI non disponibile su questo dispositivo',
      );
    }
  }

  Future<LotLabelOcrResult> readLabelImage(
    String imagePath, {
    String? ocrHint,
  }) async {
    await _ensureEngine();
    final engine = _engine!;
    final chat = await engine.createChat();

    const system = '''
Sei un assistente HACCP per etichette alimentari italiane.
Rispondi SOLO con JSON valido (niente markdown, niente testo extra).
Regole:
1) lotCode = valore dopo LOTTO / Lotto n. / LOT (es. L6071318005). Non inventare frammenti da LATTE (ATTE), GLUTINE, ecc.
2) expiryAt = data dopo "Da consumare entro" / "Scad." in YYYY-MM-DD. "02 08 26" o "02.08.26" → 2026-08-02.
3) allergens: se c'è "SENZA GLUTINE" / "SENZA LATTE" / "senza derivati del latte" → "Nessuno (senza glutine/latte)". Solo allergeni PRESENTI.
4) productName = marca + nome prodotto, senza ingredienti.
5) ingredients = lista dalla sezione INGREDIENTI, elementi singoli.
''';

    final hintBlock = (ocrHint != null && ocrHint.trim().isNotEmpty)
        ? '''

Testo OCR di supporto (può contenere errori; preferisci ciò che vedi nell'immagine per lotto e date):
---
${ocrHint.trim()}
---
'''
        : '';

    final userText = '''
Estrai i campi da questa foto di etichetta alimentare.
$hintBlock
Esempio output:
{"productName":"TASTASAL AL NATURALE","lotCode":"L6071318005","expiryAt":"2026-08-02","supplier":null,"allergens":"Nessuno (senza glutine/latte)","ingredients":["carne di suino","sale","aromi naturali"]}

Schema:
{"productName":"","lotCode":"","expiryAt":"YYYY-MM-DD o null","supplier":null,"allergens":null,"ingredients":[]}
''';

    try {
      chat.addSystem(system);
      chat.addUser(
        userText,
        media: [LlamaMedia.imageFile(imagePath)],
      );

      final buf = StringBuffer();
      await for (final event in chat.generate(
        maxTokens: 384,
        sampler: const SamplerParams(temperature: 0.05, topP: 0.85),
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

  /// Unisce Vision + OCR: Vision per semantica, OCR per codici letterali se Vision fallisce.
  static LotLabelOcrResult mergeWithOcr(LotLabelOcrResult vision, LotLabelOcrResult ocr) {
    String? pick(String? a, String? b) {
      if (a != null && a.trim().isNotEmpty) return a.trim();
      if (b != null && b.trim().isNotEmpty) return b.trim();
      return null;
    }

    final lot = _preferLotCode(vision.lotCode, ocr.lotCode);
    final allergens = _preferAllergens(vision.allergens, ocr.allergens);
    final ingredients = vision.ingredients.isNotEmpty ? vision.ingredients : ocr.ingredients;

    return LotLabelOcrResult(
      productName: pick(vision.productName, ocr.productName),
      lotCode: lot,
      supplier: pick(vision.supplier, ocr.supplier),
      expiryAt: vision.expiryAt ?? ocr.expiryAt,
      allergens: allergens,
      ingredients: ingredients,
      rawText: 'VISION:\n${vision.rawText}\n\nOCR:\n${ocr.rawText}',
    );
  }

  static String? _preferLotCode(String? vision, String? ocr) {
    bool looksReal(String? c) {
      if (c == null) return false;
      final s = c.trim().toUpperCase();
      if (s.length < 5) return false;
      // Scarta frammenti tipici da parole (LATTE→ATTE, GLUTINE→…)
      const bad = {'ATTE', 'LATTE', 'GLUTINE', 'SALE', 'ACQUA', 'CARNE'};
      if (bad.contains(s)) return false;
      return RegExp(r'^[A-Z0-9][A-Z0-9./-]{4,}$').hasMatch(s);
    }

    if (looksReal(vision)) return vision!.trim().toUpperCase();
    if (looksReal(ocr)) return ocr!.trim().toUpperCase();
    return vision?.trim().toUpperCase() ?? ocr?.trim().toUpperCase();
  }

  static String? _preferAllergens(String? vision, String? ocr) {
    final v = vision?.toLowerCase() ?? '';
    final o = ocr?.toLowerCase() ?? '';
    if (v.contains('nessuno') || v.contains('senza')) return vision;
    if (o.contains('nessuno') || o.contains('senza')) return ocr;
    if (vision != null && vision.trim().isNotEmpty) return vision;
    return ocr;
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _loadedModelPath = null;
  }
}
