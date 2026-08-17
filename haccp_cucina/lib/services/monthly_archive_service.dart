import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../data/repositories/haccp_repository.dart';
import 'pdf_export_service.dart';
import 'settings_service.dart';

class MonthlyArchiveResult {
  final String monthKey;
  final String pdfPath;
  final String jsonPath;
  final int purgedReadings;

  const MonthlyArchiveResult({
    required this.monthKey,
    required this.pdfPath,
    required this.jsonPath,
    required this.purgedReadings,
  });
}

/// Prima di cancellare i dati vecchi (ogni nuovo mese), salva PDF+JSON sul telefono.
class MonthlyArchiveService {
  MonthlyArchiveService({
    PdfExportService? pdfExport,
    SettingsService? settings,
  })  : _pdf = pdfExport ?? PdfExportService(),
        _settings = settings ?? SettingsService();

  final PdfExportService _pdf;
  final SettingsService _settings;

  static const _prefMonthKey = 'last_monthly_archive_key';
  static const _prefPathKey = 'last_monthly_archive_path';
  static const archiveFolderName = 'HACCP_Archivi';

  String monthKeyOf(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  Future<Directory> archiveDirectory() async {
    // Cartella nell'app (sempre scrivibile) + copia su storage esterno se disponibile
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, archiveFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory?> _externalArchiveDirectory() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final ext = await getExternalStorageDirectory();
      if (ext == null) return null;
      // es. .../Android/data/.../files/HACCP_Archivi (visibile via file manager app)
      final dir = Directory(p.join(ext.path, archiveFolderName));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> listArchives() async {
    final dir = await archiveDirectory();
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && (e.path.endsWith('.pdf') || e.path.endsWith('.json')))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String?> lastArchivePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefPathKey);
  }

  Future<String?> lastArchiveMonthKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefMonthKey);
  }

  /// Da chiamare all'avvio app. Archivia se e iniziato un nuovo mese, poi pulisce.
  Future<MonthlyArchiveResult?> runIfNeeded(HaccpRepository repo) async {
    if (kIsWeb) return null;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentKey = monthKeyOf(now);
    final lastKey = prefs.getString(_prefMonthKey);

    if (lastKey == null) {
      // Primo avvio: non cancellare, solo marca il mese
      await prefs.setString(_prefMonthKey, currentKey);
      return null;
    }

    if (lastKey == currentKey) {
      // Stesso mese: solo retention 30 gg (dopo eventuali archivi gia fatti)
      await AppDatabase.purgeOldTemperatureReadings(await AppDatabase.instance.database);
      await _purgeOldBatches(repo);
      return null;
    }

    // Nuovo mese rispetto all'ultimo archivio -> salva TUTTO, poi cancella i vecchi
    final result = await saveFullArchive(repo, archiveLabel: lastKey);
    await prefs.setString(_prefMonthKey, currentKey);
    await prefs.setString(_prefPathKey, result.pdfPath);
    return result;
  }

  /// Salva archivio completo (forzabile anche a mano).
  Future<MonthlyArchiveResult> saveFullArchive(
    HaccpRepository repo, {
    String? archiveLabel,
  }) async {
    final settings = await _settings.load();
    final label = archiveLabel ?? monthKeyOf(DateTime.now());
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final baseName = 'HACCP_archivio_${label}_$stamp';

    final points = await repo.getTemperaturePoints(activeOnly: false);
    // Tutte le letture ancora in DB (fino a 30+ gg)
    final readings = await repo.getReadingsLastDays(days: 400);
    final batches = await repo.getPreparedBatches(activeOnly: false);
    final lots = await repo.getLots();
    final catalog = await repo.getIngredientCatalog();
    final cleaningTasks = await repo.getCleaningTasks(activeOnly: false);

    final pdfBytes = await _pdf.buildHaccpReport(
      activityName: settings.activityName,
      operatorName: settings.defaultOperator,
      points: points,
      readings: readings,
      batches: batches,
      lots: lots,
      days: readings.isEmpty ? 0 : 30,
      titleSuffix: 'ARCHIVIO MENSILE $label',
    );

    final jsonMap = {
      'tipo': 'archivio_mensile_haccp',
      'mese_riferimento': label,
      'generato_il': DateTime.now().toIso8601String(),
      'attivita': settings.activityName,
      'operatore': settings.defaultOperator,
      'punti_temperatura': points.map((e) => e.toMap()).toList(),
      'letture_temperatura': readings.map((e) => e.toMap()).toList(),
      'preparati': batches.map((e) => e.toMap()).toList(),
      'lotti': lots.map((e) => e.toMap()).toList(),
      'catalogo_ingredienti': catalog.map((e) => e.toMap()).toList(),
      'pulizie': cleaningTasks.map((e) => e.toMap()).toList(),
    };
    final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(jsonMap));

    final primary = await archiveDirectory();
    final pdfFile = File(p.join(primary.path, '$baseName.pdf'));
    final jsonFile = File(p.join(primary.path, '$baseName.json'));
    await pdfFile.writeAsBytes(pdfBytes, flush: true);
    await jsonFile.writeAsBytes(jsonBytes, flush: true);

    // Copia anche su storage app esterno (Android) se disponibile
    final external = await _externalArchiveDirectory();
    if (external != null) {
      await File(p.join(external.path, '$baseName.pdf')).writeAsBytes(pdfBytes, flush: true);
      await File(p.join(external.path, '$baseName.json')).writeAsBytes(jsonBytes, flush: true);
    }

    final purged = await AppDatabase.purgeOldTemperatureReadings(await AppDatabase.instance.database);
    await _purgeOldBatches(repo);

    return MonthlyArchiveResult(
      monthKey: label,
      pdfPath: pdfFile.path,
      jsonPath: jsonFile.path,
      purgedReadings: purged,
    );
  }

  Future<void> _purgeOldBatches(HaccpRepository repo) async {
    final batches = await repo.getPreparedBatches(activeOnly: false);
    final cutoff = DateTime.now().subtract(const Duration(days: AppDatabase.temperatureRetentionDays));
    for (final b in batches) {
      if (b.expiresAt.isBefore(cutoff)) {
        await repo.deletePreparedBatch(b.id);
      }
    }
  }
}
