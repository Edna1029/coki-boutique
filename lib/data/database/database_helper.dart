import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables.dart';

/// Opens the local SQLite database (the app's source of truth, PRD §3).
///
/// A fresh install starts EMPTY: no sample products, sales, credit customers
/// or users. Users come from Firebase (cached here on login); everything else
/// is entered by the shop.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Tests set this (e.g. to `inMemoryDatabasePath`) to use a throwaway DB.
  @visibleForTesting
  static String? pathOverride;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('coki_store.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final path = pathOverride ?? join(await getDatabasesPath(), fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(DatabaseTables.createUsersTable);
    await db.execute(DatabaseTables.createProductsTable);
    await db.execute(DatabaseTables.createProductVariantsTable);
    await db.execute(DatabaseTables.createSalesTable);
    await db.execute(DatabaseTables.createSaleItemsTable);
    await db.execute(DatabaseTables.createCreditSalesTable);
    await db.execute(DatabaseTables.createPaymentsTable);
    await db.execute(DatabaseTables.createInventoryLogsTable);
    await db.execute(DatabaseTables.createSyncQueueTable);
    await db.execute(DatabaseTables.createSettingsTable);

    await _insertDefaultSettings(db);
  }

  /// Store-level defaults only — no demo/sample business data.
  Future<void> _insertDefaultSettings(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    const defaults = {
      'store_name': 'Coki Boutique',
      'currency': 'ETB',
      'language': 'en',
      'theme_mode': 'light',
    };
    for (final e in defaults.entries) {
      await db.insert(DatabaseTables.tableSettings, {'key': e.key, 'value': e.value});
    }
    await db.insert(DatabaseTables.tableSettings, {'key': 'last_sync_timestamp', 'value': now});
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  /// Tests: close and forget the current DB so the next access opens a new one.
  @visibleForTesting
  static Future<void> resetForTest() async {
    await instance.close();
  }
}
