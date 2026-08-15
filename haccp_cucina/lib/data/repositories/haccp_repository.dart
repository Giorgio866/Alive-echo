import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/cleaning_models.dart';
import '../models/document_models.dart';
import '../models/ingredient_models.dart';
import '../models/product_lot.dart';
import '../models/temperature_models.dart';

class HaccpRepository {
  HaccpRepository({AppDatabase? database}) : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<Database> get _database => _db.database;

  // --- Temperature ---

  Future<List<TemperaturePoint>> getTemperaturePoints({bool activeOnly = true}) async {
    final db = await _database;
    final rows = await db.query(
      'temperature_points',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'zone ASC, name ASC',
    );
    return rows.map(TemperaturePoint.fromMap).toList();
  }

  Future<void> upsertTemperaturePoint(TemperaturePoint point) async {
    final db = await _database;
    await db.insert(
      'temperature_points',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TemperatureReading> addTemperatureReading({
    required String pointId,
    required double valueC,
    required String operatorName,
    String? note,
    required double minC,
    required double maxC,
    String? photoPath,
  }) async {
    final reading = TemperatureReading(
      id: _uuid.v4(),
      pointId: pointId,
      valueC: valueC,
      recordedAt: DateTime.now(),
      operatorName: operatorName,
      note: note,
      outOfRange: valueC < minC || valueC > maxC,
      photoPath: photoPath,
    );
    final db = await _database;
    await db.insert('temperature_readings', reading.toMap());
    await AppDatabase.purgeOldTemperatureReadings(db);
    return reading;
  }

  Future<void> replaceTemperaturePoints(List<TemperaturePoint> points) async {
    final db = await _database;
    await db.delete('temperature_readings');
    await db.delete('temperature_points');
    for (final point in points) {
      await db.insert('temperature_points', point.toMap());
    }
  }

  Future<void> upsertCustomIngredient(IngredientCatalogItem item) async {
    final db = await _database;
    await db.insert(
      'ingredient_catalog',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TemperatureReading>> getReadingsForPoint(
    String pointId, {
    int? limit,
    int days = AppDatabase.temperatureRetentionDays,
  }) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query(
      'temperature_readings',
      where: 'point_id = ? AND recorded_at >= ?',
      whereArgs: [pointId, cutoff],
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows.map(TemperatureReading.fromMap).toList();
  }

  Future<List<TemperatureReading>> getReadingsLastDays({
    int days = AppDatabase.temperatureRetentionDays,
  }) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query(
      'temperature_readings',
      where: 'recorded_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(TemperatureReading.fromMap).toList();
  }

  Future<List<TemperatureReading>> getTodayReadings() async {
    final db = await _database;
    final start = DateTime.now();
    final dayStart = DateTime(start.year, start.month, start.day).toIso8601String();
    final rows = await db.query(
      'temperature_readings',
      where: 'recorded_at >= ?',
      whereArgs: [dayStart],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(TemperatureReading.fromMap).toList();
  }

  Future<Map<String, TemperatureReading?>> latestReadingByPoint() async {
    final points = await getTemperaturePoints();
    final result = <String, TemperatureReading?>{};
    for (final point in points) {
      final readings = await getReadingsForPoint(point.id, limit: 1);
      result[point.id] = readings.isEmpty ? null : readings.first;
    }
    return result;
  }

  // --- Cleaning ---

  Future<List<CleaningTask>> getCleaningTasks({bool activeOnly = true}) async {
    final db = await _database;
    final rows = await db.query(
      'cleaning_tasks',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'area ASC, title ASC',
    );
    return rows.map(CleaningTask.fromMap).toList();
  }

  Future<CleaningLog> completeCleaningTask({
    required String taskId,
    required String operatorName,
    String? note,
  }) async {
    final log = CleaningLog(
      id: _uuid.v4(),
      taskId: taskId,
      completedAt: DateTime.now(),
      operatorName: operatorName,
      note: note,
    );
    final db = await _database;
    await db.insert('cleaning_logs', log.toMap());
    return log;
  }

  Future<List<CleaningLog>> getCleaningLogsForTask(String taskId, {int limit = 20}) async {
    final db = await _database;
    final rows = await db.query(
      'cleaning_logs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return rows.map(CleaningLog.fromMap).toList();
  }

  Future<Set<String>> getTaskIdsCompletedToday() async {
    final db = await _database;
    final start = DateTime.now();
    final dayStart = DateTime(start.year, start.month, start.day).toIso8601String();
    final rows = await db.query(
      'cleaning_logs',
      columns: ['task_id'],
      where: 'completed_at >= ?',
      whereArgs: [dayStart],
    );
    return rows.map((r) => r['task_id']! as String).toSet();
  }

  // --- Lots ---

  Future<List<ProductLot>> getLots({bool includeExpired = true}) async {
    final db = await _database;
    final rows = await db.query('product_lots', orderBy: 'expiry_at ASC, product_name ASC');
    final lots = rows.map(ProductLot.fromMap).toList();
    if (includeExpired) return lots;
    return lots.where((l) => !l.isExpired).toList();
  }

  Future<ProductLot> upsertLot(ProductLot lot) async {
    final db = await _database;
    final withId = lot.id.isEmpty
        ? ProductLot(
            id: _uuid.v4(),
            productName: lot.productName,
            lotCode: lot.lotCode,
            supplier: lot.supplier,
            receivedAt: lot.receivedAt,
            expiryAt: lot.expiryAt,
            storageLocation: lot.storageLocation,
            allergens: lot.allergens,
            quantity: lot.quantity,
            unit: lot.unit,
            notes: lot.notes,
            opened: lot.opened,
            openedAt: lot.openedAt,
            useByAfterOpen: lot.useByAfterOpen,
          )
        : lot;
    await db.insert(
      'product_lots',
      withId.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return withId;
  }

  Future<void> deleteLot(String id) async {
    final db = await _database;
    await db.delete('product_lots', where: 'id = ?', whereArgs: [id]);
  }

  Future<ProductLot> markLotOpened(ProductLot lot, {int daysUsable = 3}) async {
    final now = DateTime.now();
    final updated = lot.copyWith(
      opened: true,
      openedAt: now,
      useByAfterOpen: DateTime(now.year, now.month, now.day).add(Duration(days: daysUsable)),
    );
    return upsertLot(updated);
  }

  // --- Documents ---

  Future<List<DocumentRecord>> getDocuments() async {
    final db = await _database;
    final rows = await db.query('documents', orderBy: 'scanned_at DESC');
    return rows.map(DocumentRecord.fromMap).toList();
  }

  Future<DocumentRecord> addDocument(DocumentRecord doc) async {
    final withId = doc.id.isEmpty
        ? DocumentRecord(
            id: _uuid.v4(),
            title: doc.title,
            category: doc.category,
            filePath: doc.filePath,
            scannedAt: doc.scannedAt,
            relatedLotId: doc.relatedLotId,
            notes: doc.notes,
            supplier: doc.supplier,
          )
        : doc;
    final db = await _database;
    await db.insert('documents', withId.toMap());
    return withId;
  }

  Future<void> deleteDocument(String id) async {
    final db = await _database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // --- Ingredients / preparati Blue Eyes ---

  Future<List<IngredientCatalogItem>> getIngredientCatalog({String? category}) async {
    final db = await _database;
    final rows = await db.query(
      'ingredient_catalog',
      where: category == null ? null : 'category = ?',
      whereArgs: category == null ? null : [category],
      orderBy: 'category ASC, name ASC',
    );
    return rows.map(IngredientCatalogItem.fromMap).toList();
  }

  Future<PreparedBatch> registerPreparedBatch({
    required IngredientCatalogItem ingredient,
    required String operatorName,
    DateTime? preparedAt,
    String? lotCode,
    String? note,
    int? overrideDays,
  }) async {
    final prep = preparedAt ?? DateTime.now();
    final days = overrideDays ?? ingredient.recommendedDays;
    final expiryDay = DateTime(prep.year, prep.month, prep.day).add(Duration(days: days));
    final expiresAt = DateTime(expiryDay.year, expiryDay.month, expiryDay.day, 23, 59);
    final batch = PreparedBatch(
      id: _uuid.v4(),
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      preparedAt: prep,
      expiresAt: expiresAt,
      operatorName: operatorName,
      lotCode: lotCode,
      note: note,
    );
    final db = await _database;
    await db.insert('prepared_batches', batch.toMap());
    return batch;
  }

  Future<List<PreparedBatch>> getPreparedBatches({bool activeOnly = true}) async {
    final db = await _database;
    final rows = await db.query('prepared_batches', orderBy: 'expires_at ASC');
    final batches = rows.map(PreparedBatch.fromMap).toList();
    if (!activeOnly) return batches;
    final now = DateTime.now().subtract(const Duration(days: 1));
    return batches.where((b) => b.expiresAt.isAfter(now)).toList();
  }

  Future<List<PreparedBatch>> getExpiringBatches({int withinHours = 24}) async {
    final batches = await getPreparedBatches(activeOnly: false);
    final limit = DateTime.now().add(Duration(hours: withinHours));
    return batches.where((b) => !b.isExpired && b.expiresAt.isBefore(limit)).toList();
  }

  Future<void> deletePreparedBatch(String id) async {
    final db = await _database;
    await db.delete('prepared_batches', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markBatchNotified(String id) async {
    final db = await _database;
    await db.update('prepared_batches', {'notified': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Dashboard helpers ---

  Future<DashboardSnapshot> getDashboardSnapshot() async {
    final points = await getTemperaturePoints();
    final latest = await latestReadingByPoint();
    final todayReadings = await getTodayReadings();
    final tasks = await getCleaningTasks();
    final doneToday = await getTaskIdsCompletedToday();
    final lots = await getLots();
    final docs = await getDocuments();
    final batches = await getPreparedBatches();
    final history = await getReadingsLastDays();
    final catalog = await getIngredientCatalog();

    final missingTemp =
        points.where((p) => latest[p.id] == null || !_isToday(latest[p.id]!.recordedAt)).length;
    final outOfRange = todayReadings.where((r) => r.outOfRange).length;
    final pendingCleaning =
        tasks.where((t) => t.frequency == 'daily' && !doneToday.contains(t.id)).length;
    final expiringLots = lots.where((l) => l.isExpired || l.expiresSoon).length;
    final expiringPrep = batches.where((b) => b.isExpired || b.expiresSoon).length;

    return DashboardSnapshot(
      activityLabel: 'Controllo giornaliero',
      temperaturePoints: points.length,
      missingTemperatureChecks: missingTemp,
      outOfRangeAlerts: outOfRange,
      pendingCleaningTasks: pendingCleaning,
      expiringLots: expiringLots + expiringPrep,
      documentCount: docs.length,
      lots: lots.take(5).toList(),
      recentReadings: todayReadings.take(5).toList(),
      temperatureHistoryCount: history.length,
      ingredientCatalogCount: catalog.length,
      activePreparedBatches: batches.length,
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}

class DashboardSnapshot {
  final String activityLabel;
  final int temperaturePoints;
  final int missingTemperatureChecks;
  final int outOfRangeAlerts;
  final int pendingCleaningTasks;
  final int expiringLots;
  final int documentCount;
  final List<ProductLot> lots;
  final List<TemperatureReading> recentReadings;
  final int temperatureHistoryCount;
  final int ingredientCatalogCount;
  final int activePreparedBatches;

  const DashboardSnapshot({
    required this.activityLabel,
    required this.temperaturePoints,
    required this.missingTemperatureChecks,
    required this.outOfRangeAlerts,
    required this.pendingCleaningTasks,
    required this.expiringLots,
    required this.documentCount,
    required this.lots,
    required this.recentReadings,
    this.temperatureHistoryCount = 0,
    this.ingredientCatalogCount = 0,
    this.activePreparedBatches = 0,
  });
}
