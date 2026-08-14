import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/cleaning_models.dart';
import '../models/ingredient_models.dart';
import '../models/temperature_models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// Conservazione minima letture temperatura (giorni).
  static const int temperatureRetentionDays = 30;

  Database? _db;
  static const _uuid = Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<void> useDatabase(Database db) async {
    _db = db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'haccp_cucina.db');
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createIngredientTables(db);
          await _seedIngredients(db);
        }
      },
    );
    await purgeOldTemperatureReadings(db);
    return db;
  }

  /// Elimina letture più vecchie di [temperatureRetentionDays].
  static Future<int> purgeOldTemperatureReadings(Database db) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: temperatureRetentionDays))
        .toIso8601String();
    return db.delete(
      'temperature_readings',
      where: 'recorded_at < ?',
      whereArgs: [cutoff],
    );
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE temperature_points (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        zone TEXT NOT NULL,
        min_c REAL NOT NULL,
        max_c REAL NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE temperature_readings (
        id TEXT PRIMARY KEY,
        point_id TEXT NOT NULL,
        value_c REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        operator_name TEXT NOT NULL,
        note TEXT,
        out_of_range INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(point_id) REFERENCES temperature_points(id)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_readings_recorded_at ON temperature_readings(recorded_at)
    ''');
    await db.execute('''
      CREATE TABLE cleaning_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        area TEXT NOT NULL,
        frequency TEXT NOT NULL,
        instructions TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE cleaning_logs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        operator_name TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY(task_id) REFERENCES cleaning_tasks(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE product_lots (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        lot_code TEXT NOT NULL,
        supplier TEXT NOT NULL,
        received_at TEXT NOT NULL,
        expiry_at TEXT,
        storage_location TEXT NOT NULL,
        allergens TEXT,
        quantity REAL,
        unit TEXT,
        notes TEXT,
        opened INTEGER NOT NULL DEFAULT 0,
        opened_at TEXT,
        use_by_after_open TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        file_path TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        related_lot_id TEXT,
        notes TEXT,
        supplier TEXT
      )
    ''');
    await _createIngredientTables(db);
  }

  static Future<void> _createIngredientTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredient_catalog (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        recommended_days INTEGER NOT NULL,
        storage_hint TEXT NOT NULL,
        allergens TEXT,
        source TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prepared_batches (
        id TEXT PRIMARY KEY,
        ingredient_id TEXT NOT NULL,
        ingredient_name TEXT NOT NULL,
        prepared_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        operator_name TEXT NOT NULL,
        lot_code TEXT,
        note TEXT,
        notified INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ingredient_id) REFERENCES ingredient_catalog(id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_batches_expires_at ON prepared_batches(expires_at)
    ''');
  }

  static Future<void> _seed(Database db) async {
    final points = [
      TemperaturePoint(id: _uuid.v4(), name: 'Frigo verdure', zone: 'frigo', minC: 0, maxC: 4),
      TemperaturePoint(id: _uuid.v4(), name: 'Frigo latticini', zone: 'frigo', minC: 0, maxC: 4),
      TemperaturePoint(id: _uuid.v4(), name: 'Congelatore surgelati', zone: 'freezer', minC: -25, maxC: -18),
      TemperaturePoint(id: _uuid.v4(), name: 'Abbattitore', zone: 'abbattitore', minC: -40, maxC: 3),
      TemperaturePoint(id: _uuid.v4(), name: 'Banco pizza caldo', zone: 'banco_caldo', minC: 60, maxC: 75),
      TemperaturePoint(id: _uuid.v4(), name: 'Vetrina mozzarella', zone: 'frigo', minC: 0, maxC: 4),
    ];
    for (final point in points) {
      await db.insert('temperature_points', point.toMap());
    }

    final tasks = [
      CleaningTask(
        id: _uuid.v4(),
        title: 'Sanificazione banco pizza',
        area: 'pizzeria',
        frequency: 'daily',
        instructions: 'Rimuovere residui, detergere, risciacquare e sanificare.',
      ),
      CleaningTask(
        id: _uuid.v4(),
        title: 'Pulizia forno a legna / elettrico',
        area: 'pizzeria',
        frequency: 'daily',
        instructions: 'Rimuovere cenere/residui a freddo, pulire piano e bocca forno.',
      ),
      CleaningTask(
        id: _uuid.v4(),
        title: 'Svuotamento e sanificazione frigoriferi',
        area: 'cucina',
        frequency: 'weekly',
        instructions: 'Controllare scadenze, pulire ripiani e guarnizioni.',
      ),
      CleaningTask(
        id: _uuid.v4(),
        title: 'Pulizia pavimenti e scarichi',
        area: 'cucina',
        frequency: 'daily',
        instructions: 'Spazzare, lavare con detergente e sanificare gli scarichi.',
      ),
      CleaningTask(
        id: _uuid.v4(),
        title: 'Controllo trappole e pest control',
        area: 'magazzino',
        frequency: 'weekly',
        instructions: 'Verificare stato delle trappole e annotare anomalie.',
      ),
      CleaningTask(
        id: _uuid.v4(),
        title: 'Pulizia servizi igienici staff',
        area: 'servizi',
        frequency: 'daily',
        instructions: 'Sanificare superfici, rifornire sapone e asciugamani.',
      ),
    ];
    for (final task in tasks) {
      await db.insert('cleaning_tasks', task.toMap());
    }

    await _seedIngredients(db);
  }

  static Future<void> _seedIngredients(Database db) async {
    for (final item in blueEyesIngredientCatalog()) {
      await db.insert(
        'ingredient_catalog',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<Database> openInMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
    );
    return db;
  }
}
