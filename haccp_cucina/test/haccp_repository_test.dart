import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:haccp_cucina/data/database/app_database.dart';
import 'package:haccp_cucina/data/models/ingredient_models.dart';
import 'package:haccp_cucina/data/models/product_lot.dart';
import 'package:haccp_cucina/data/repositories/haccp_repository.dart';
import 'package:haccp_cucina/services/thermal_print_service.dart';
import 'package:haccp_cucina/services/pdf_export_service.dart';
import 'package:haccp_cucina/data/models/document_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HaccpRepository', () {
    late AppDatabase db;
    late HaccpRepository repo;

    setUp(() async {
      db = AppDatabase.instance;
      await db.close();
      final memory = await AppDatabase.openInMemory();
      await db.useDatabase(memory);
      repo = HaccpRepository(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('seed crea 5 frigo e 1 congelatore', () async {
      final points = await repo.getTemperaturePoints();
      expect(points.where((p) => p.zone == 'frigo').length, 5);
      expect(points.where((p) => p.zone == 'freezer').length, 1);
      final tasks = await repo.getCleaningTasks();
      expect(tasks.length, greaterThanOrEqualTo(5));
    });

    test('catalogo Blue Eyes precaricato con scadenze', () async {
      final catalog = await repo.getIngredientCatalog();
      expect(catalog.length, greaterThanOrEqualTo(40));
      final mozzarella = catalog.firstWhere((c) => c.id == 'mozzarella');
      expect(mozzarella.recommendedDays, 2);
      expect(catalog.any((c) => c.name.toLowerCase().contains('pomodoro')), isTrue);
      expect(catalog.any((c) => c.name.toLowerCase().contains('speck')), isTrue);
    });

    test('preparato calcola scadenza consigliata', () async {
      final catalog = await repo.getIngredientCatalog();
      final item = catalog.firstWhere((c) => c.id == 'bufala');
      final batch = await repo.registerPreparedBatch(
        ingredient: item,
        operatorName: 'Marco',
        preparedAt: DateTime(2026, 8, 14, 10),
      );
      expect(batch.ingredientName, contains('bufala'));
      expect(batch.expiresAt.difference(DateTime(2026, 8, 14)).inDays, item.recommendedDays);
    });

    test('storico temperature conserva fino a 30 giorni', () async {
      final points = await repo.getTemperaturePoints();
      final frigo = points.first;
      await repo.addTemperatureReading(
        pointId: frigo.id,
        valueC: 3,
        operatorName: 'Test',
        minC: frigo.minC,
        maxC: frigo.maxC,
      );
      final history = await repo.getReadingsLastDays(days: 30);
      expect(history, isNotEmpty);
      expect(AppDatabase.temperatureRetentionDays, 30);
    });

    test('lettura temperatura marca fuori range', () async {
      final points = await repo.getTemperaturePoints();
      final frigo = points.firstWhere((p) => p.zone == 'frigo');
      final reading = await repo.addTemperatureReading(
        pointId: frigo.id,
        valueC: 12,
        operatorName: 'Test',
        minC: frigo.minC,
        maxC: frigo.maxC,
      );
      expect(reading.outOfRange, isTrue);
    });

    test('lotto aperto calcola use-by', () async {
      final lot = await repo.upsertLot(
        ProductLot(
          id: 'lot-1',
          productName: 'Mozzarella',
          lotCode: 'L123',
          supplier: 'Caseificio',
          receivedAt: DateTime.now(),
          expiryAt: DateTime.now().add(const Duration(days: 20)),
          storageLocation: 'Frigo',
        ),
      );
      final opened = await repo.markLotOpened(lot, daysUsable: 3);
      expect(opened.opened, isTrue);
      expect(opened.useByAfterOpen, isNotNull);
    });

    test('dashboard snapshot aggrega alert', () async {
      final snap = await repo.getDashboardSnapshot();
      expect(snap.temperaturePoints, greaterThan(0));
      expect(snap.ingredientCatalogCount, greaterThan(0));
    });
  });

  group('ThermalPrintService', () {
    test('preview etichetta contiene campi chiave', () async {
      final service = ThermalPrintService();
      final text = await service.previewText(
        LabelDraft(
          productName: 'Sugo pomodoro',
          lotCode: 'A1',
          preparedAt: DateTime(2026, 8, 14, 10, 30),
          useBy: DateTime(2026, 8, 16),
          allergens: 'Sedano',
          operatorName: 'Marco',
          storageHint: 'In frigo',
        ),
        activityName: 'Pizzeria Test',
      );
      expect(text, contains('PIZZERIA TEST'));
      expect(text, contains('Sugo pomodoro'));
    });
  });

  group('ProductLot', () {
    test('effectiveExpiry preferisce use-by dopo apertura se più breve', () {
      final lot = ProductLot(
        id: '1',
        productName: 'Pesto',
        lotCode: 'X',
        supplier: 'Y',
        receivedAt: DateTime(2026, 1, 1),
        expiryAt: DateTime(2026, 12, 31),
        storageLocation: 'Frigo',
        opened: true,
        openedAt: DateTime(2026, 8, 1),
        useByAfterOpen: DateTime(2026, 8, 4),
      );
      expect(lot.effectiveExpiry, DateTime(2026, 8, 4));
    });
  });

  group('Blue Eyes catalog', () {
    test('lista ingredienti menu non vuota', () {
      final items = blueEyesIngredientCatalog();
      expect(items.length, greaterThan(50));
      expect(items.every((i) => i.recommendedDays > 0), isTrue);
    });
  });
group('PdfExportService', () {
    test('genera PDF non vuoto', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      await db.close();
      await db.useDatabase(await AppDatabase.openInMemory());
      final repo = HaccpRepository(database: db);
      final points = await repo.getTemperaturePoints();
      final pdf = PdfExportService();
      final bytes = await pdf.buildHaccpReport(
        activityName: 'Blue Eyes',
        operatorName: 'Test',
        points: points,
        readings: const [],
        batches: const [],
        lots: const [],
      );
      expect(bytes.length, greaterThan(100));
      await db.close();
    });
  });
}