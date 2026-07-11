import '../models/proxy_profile.dart';

/// Persistence contract for connection profiles. Implemented by the SQLite
/// data layer; depended on by use-cases and presentation via DI.
abstract interface class IProfileRepository {
  Future<List<ProxyProfile>> getAll();

  Future<ProxyProfile?> getById(String id);

  /// Insert or update by [ProxyProfile.id].
  Future<void> upsert(ProxyProfile profile);

  Future<void> delete(String id);

  /// Emits the full profile list whenever it changes (add/update/delete), so the
  /// UI list stays live without polling.
  Stream<List<ProxyProfile>> watchAll();
}
