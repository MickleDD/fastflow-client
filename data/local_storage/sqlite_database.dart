import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens and migrates the local SQLite database, transparently selecting the
/// native sqflite backend on Android and the FFI backend on Windows/desktop.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String dbName = 'fastflow.db';
  static const int dbVersion = 1;

  static const String tableProfiles = 'profiles';
  static const String tableSettings = 'settings';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final DatabaseFactory factory;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory; // Android native
    }

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, dbName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Profiles are stored as a serialized JSON blob plus a few indexed columns
    // for cheap listing/filtering — the schema stays stable as the model grows.
    await db.execute('''
      CREATE TABLE $tableProfiles (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        protocol   TEXT NOT NULL,
        data       TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Simple key/value store for AppSettings and the active profile pointer.
    await db.execute('''
      CREATE TABLE $tableSettings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
