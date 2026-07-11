import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/models/proxy_profile.dart';
import '../../core/domain/repositories/i_profile_repository.dart';
import 'providers.dart';

/// Live list of saved profiles, streamed from the repository.
final profileListProvider = StreamProvider<List<ProxyProfile>>((ref) {
  return ref.watch(profileRepositoryProvider).watchAll();
});

/// Imperative operations on the profile store (add / edit / delete), separated
/// from the read stream so widgets can mutate without holding the list.
class ProfileListController {
  final IProfileRepository _repo;
  ProfileListController(this._repo);

  Future<void> save(ProxyProfile profile) => _repo.upsert(profile);

  Future<void> delete(String id) => _repo.delete(id);

  Future<ProxyProfile?> getById(String id) => _repo.getById(id);
}

final profileListControllerProvider = Provider<ProfileListController>(
  (ref) => ProfileListController(ref.watch(profileRepositoryProvider)),
);

/// Id of the profile the user has selected in the list (the connect target).
final selectedProfileIdProvider = StateProvider<String?>((_) => null);

/// The selected [ProxyProfile] resolved against the live list. Falls back to the
/// first profile when nothing is explicitly selected.
final selectedProfileProvider = Provider<ProxyProfile?>((ref) {
  final list = ref.watch(profileListProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedProfileIdProvider);
  return list.firstWhere(
    (p) => p.id == id,
    orElse: () => list.first,
  );
});
