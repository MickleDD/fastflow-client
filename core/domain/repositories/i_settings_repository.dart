import '../models/app_settings.dart';

/// Persistence contract for app-global settings and the currently selected
/// profile id.
abstract interface class ISettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);

  /// Id of the profile the user last selected / connected with.
  Future<String?> getActiveProfileId();

  Future<void> setActiveProfileId(String? id);

  Stream<AppSettings> watch();
}
