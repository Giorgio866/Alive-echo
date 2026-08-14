import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:haccp_cucina/data/database/app_database.dart';
import 'package:haccp_cucina/data/models/product_lot.dart';
import 'package:haccp_cucina/data/repositories/haccp_repository.dart';
import 'package:haccp_cucina/services/thermal_print_service.dart';
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

    test('seed crea punti temperatura e checklist', () async {
      final points = await repo.getTemperaturePoints();
      final tasks = await repo.getCleaningTasks();
      expect(points.length, greaterThanOrEqualTo(5));
      expect(tasks.length, greaterThanOrEqualTo(5));
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
      expect(opened.expiresSoon || !opened.isExpired, isTrue);
    });

    test('dashboard snapshot aggrega alert', () async {
      final snap = await repo.getDashboardSnapshot();
      expect(snap.temperaturePoints, greaterThan(0));
      expect(snap.missingTemperatureChecks, greaterThan(0));
      expect(snap.pendingCleaningTasks, greaterThan(0));
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
      expect(text, contains('Lotto: A1'));
      expect(text, contains('Allergeni: Sedano'));
      expect(text, contains('Marco'));
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
}
