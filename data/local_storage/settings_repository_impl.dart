import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../core/domain/models/app_settings.dart';
import '../../core/domain/repositories/i_settings_repository.dart';
import 'sqlite_database.dart';

/// SQLite-backed [ISettingsRepository]. AppSettings live under a single JSON key;
/// the active profile id under another.
class SettingsRepositoryImpl implements ISettingsRepository {
  static const String _keySettings = 'app_settings';
  static const String _keyActiveProfile = 'active_profile_id';

  final AppDatabase _db;
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();

  SettingsRepositoryImpl(this._db);

  @override
  Future<AppSettings> load() async {
    final raw = await _read(_keySettings);
    if (raw == null) return const AppSettings.defaults();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt row → fall back to defaults rather than crash on startup.
      return const AppSettings.defaults();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _write(_keySettings, jsonEncode(settings.toJson()));
    if (_changes.hasListener) _changes.add(settings);
  }

  @override
  Future<String?> getActiveProfileId() => _read(_keyActiveProfile);

  @override
  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      final db = await _db.database;
      await db.delete(
        AppDatabase.tableSettings,
        where: 'key = ?',
        whereArgs: [_keyActiveProfile],
      );
    } else {
      await _write(_keyActiveProfile, id);
    }
  }

  @override
  Stream<AppSettings> watch() async* {
    yield await load();
    yield* _changes.stream;
  }

  // --------------------------------------------------------------- primitives
  Future<String?> _read(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _write(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> dispose() => _changes.close();
}
