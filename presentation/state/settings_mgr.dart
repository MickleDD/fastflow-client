import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/models/app_settings.dart';
import '../../core/domain/repositories/i_settings_repository.dart';
import '../../infrastructure/os_android/android_boot_config.dart';
import 'providers.dart';

/// Holds the live [AppSettings] and persists every change. Forms read this and
/// call [patch] to update one nested slice at a time.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final ISettingsRepository _repo;

  SettingsNotifier(this._repo) : super(const AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.load();
    _syncBootFlag(state);
  }

  /// Replace the whole settings object and persist.
  Future<void> update(AppSettings next) async {
    state = next;
    await _repo.save(next);
    _syncBootFlag(next);
  }

  /// Update via a transform on the current value.
  Future<void> patch(AppSettings Function(AppSettings current) transform) =>
      update(transform(state));

  /// Adopt a value already persisted by a use-case (e.g. ToggleKillSwitch) into
  /// the in-memory state, without re-saving it.
  void adopt(AppSettings next) {
    state = next;
    _syncBootFlag(next);
  }

  /// Mirror the "should re-arm after reboot" decision to the native side (Android
  /// only), so BootReceiver can read it without a Flutter engine.
  void _syncBootFlag(AppSettings s) {
    if (!Platform.isAndroid) return;
    AndroidBootConfig()
        .setAutoStart(s.killSwitch || s.autoConnectInsecureWifi);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});
