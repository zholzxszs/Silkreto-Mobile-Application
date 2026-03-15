import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_result_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'silkreto.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_image_path TEXT NOT NULL,
        annotated_image_path TEXT,
        status TEXT NOT NULL,
        scan_date TEXT NOT NULL,
        scan_time TEXT NOT NULL,
        healthy_count INTEGER DEFAULT 0,
        diseased_count INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE scan_history ADD COLUMN diseased_count INTEGER DEFAULT 0',
      );

      await db.execute('''
        UPDATE scan_history
        SET diseased_count = COALESCE(grasserie_count, 0) + COALESCE(flacherie_count, 0)
      ''');
    }
  }

  // Insert scan result
  Future<int> insertScanResult(ScanResult scanResult) async {
    final db = await database;
    return await db.insert('scan_history', scanResult.toMap());
  }

  // Get all scan results
  Future<List<ScanResult>> getAllScanResults() async {
    final db = await database;
    final maps = await db.query('scan_history', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => ScanResult.fromMap(maps[i]));
  }

  // Get scan result by id
  Future<ScanResult?> getScanResultById(int id) async {
    final db = await database;
    final maps = await db.query(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ScanResult.fromMap(maps.first);
    }
    return null;
  }

  // Update scan result
  Future<int> updateScanResult(ScanResult scanResult) async {
    final db = await database;
    return await db.update(
      'scan_history',
      scanResult.toMap(),
      where: 'id = ?',
      whereArgs: [scanResult.id],
    );
  }

  // Delete scan result
  Future<int> deleteScanResult(int id) async {
    final db = await database;
    return await db.delete('scan_history', where: 'id = ?', whereArgs: [id]);
  }

  // Get scan results by status
  Future<List<ScanResult>> getScanResultsByStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      'scan_history',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => ScanResult.fromMap(maps[i]));
  }

  // Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
