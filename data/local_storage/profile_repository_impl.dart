import 'dart:async';
import 'dart:convert';

import '../../core/domain/models/proxy_profile.dart';
import '../../core/domain/repositories/i_profile_repository.dart';
import 'sqlite_database.dart';

/// SQLite-backed [IProfileRepository]. Persists each profile as a JSON blob and
/// broadcasts list changes so the UI stays live.
class ProfileRepositoryImpl implements IProfileRepository {
  final AppDatabase _db;
  final StreamController<List<ProxyProfile>> _changes =
      StreamController<List<ProxyProfile>>.broadcast();

  ProfileRepositoryImpl(this._db);

  @override
  Future<List<ProxyProfile>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableProfiles,
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((r) => ProxyProfile.fromJson(
            jsonDecode(r['data'] as String) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProxyProfile?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProxyProfile.fromJson(
        jsonDecode(rows.first['data'] as String) as Map<String, dynamic>);
  }

  @override
  Future<void> upsert(ProxyProfile profile) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.tableProfiles,
      {
        'id': profile.id,
        'name': profile.name,
        'protocol': profile.protocol.value,
        'data': jsonEncode(profile.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notify();
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notify();
  }

  @override
  Stream<List<ProxyProfile>> watchAll() async* {
    yield await getAll();
    yield* _changes.stream;
  }

  Future<void> _notify() async {
    if (_changes.hasListener) _changes.add(await getAll());
  }

  Future<void> dispose() => _changes.close();
}
