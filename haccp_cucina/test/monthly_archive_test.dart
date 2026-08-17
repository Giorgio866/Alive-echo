import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:haccp_cucina/data/database/app_database.dart';
import 'package:haccp_cucina/data/repositories/haccp_repository.dart';
import 'package:haccp_cucina/services/monthly_archive_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('monthKeyOf formatta YYYY-MM', () {
    final service = MonthlyArchiveService();
    expect(service.monthKeyOf(DateTime(2026, 8, 15)), '2026-08');
    expect(service.monthKeyOf(DateTime(2026, 1, 1)), '2026-01');
  });

  test('primo avvio non archivia, marca solo il mese', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.instance;
    await db.close();
    await db.useDatabase(await AppDatabase.openInMemory());
    final repo = HaccpRepository(database: db);
    final service = MonthlyArchiveService();

    final result = await service.runIfNeeded(repo);
    expect(result, isNull);
    expect(await service.lastArchiveMonthKey(), isNotNull);
    await db.close();
  });
}
