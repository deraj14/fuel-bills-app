import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/bill.dart';
import '../models/fuel_entry.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fuel_bills.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE fuel_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            odometer REAL NOT NULL,
            liters REAL,
            price_per_liter REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            due_day INTEGER NOT NULL,
            amount REAL,
            notification_id INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ---------- Fuel entries ----------

  Future<int> insertFuelEntry(FuelEntry entry) async {
    final db = await database;
    return db.insert('fuel_entries', entry.toMap()..remove('id'));
  }

  Future<List<FuelEntry>> getFuelEntries() async {
    final db = await database;
    final rows = await db.query('fuel_entries', orderBy: 'date ASC, odometer ASC');
    return rows.map((r) => FuelEntry.fromMap(r)).toList();
  }

  Future<void> deleteFuelEntry(int id) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Bills ----------

  Future<int> insertBill(Bill bill) async {
    final db = await database;
    return db.insert('bills', bill.toMap()..remove('id'));
  }

  Future<List<Bill>> getBills() async {
    final db = await database;
    final rows = await db.query('bills', orderBy: 'due_day ASC');
    return rows.map((r) => Bill.fromMap(r)).toList();
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }
}
