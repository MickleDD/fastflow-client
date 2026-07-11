import '../../domain/models/app_settings.dart';
import '../../domain/models/connection_state.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_vpn_engine.dart';
import '../../domain/repositories/i_vpn_platform.dart';

/// Persist the kill-switch preference and, if a tunnel is currently up, apply or
/// remove the OS-level block immediately.
class ToggleKillSwitchUseCase {
  final ISettingsRepository _settingsRepo;
  final IVpnPlatform _platform;
  final IVpnEngine _engine;

  ToggleKillSwitchUseCase(this._settingsRepo, this._platform, this._engine);

  Future<AppSettings> execute(bool enabled) async {
    final updated = (await _settingsRepo.load()).copyWith(killSwitch: enabled);
    await _settingsRepo.save(updated);

    if (_engine.status() == ConnectionStatus.connected) {
      await _platform.setKillSwitch(enabled);
    }
    return updated;
  }
}
