import '../../domain/models/connection_state.dart';
import '../../domain/models/proxy_profile.dart';
import '../../domain/models/wifi_state.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_vpn_engine.dart';

enum WifiAction {
  none, // feature off, or network is safe
  alreadyActive, // a tunnel is already up/connecting
  noProfile, // nothing selected to connect
  shouldConnect, // caller should connect [WifiChangeDecision.profile]
}

class WifiChangeDecision {
  final WifiAction action;
  final ProxyProfile? profile;
  const WifiChangeDecision(this.action, [this.profile]);
}

/// Decides whether joining a network should auto-trigger a connect. It performs
/// no side effects itself — it returns a decision so the connection notifier can
/// drive the actual connect and keep the UI state coherent.
class HandleWifiChangeUseCase {
  final ISettingsRepository _settingsRepo;
  final IProfileRepository _profileRepo;
  final IVpnEngine _engine;

  HandleWifiChangeUseCase(this._settingsRepo, this._profileRepo, this._engine);

  Future<WifiChangeDecision> evaluate(WifiState wifi) async {
    final settings = await _settingsRepo.load();
    if (!settings.autoConnectInsecureWifi) {
      return const WifiChangeDecision(WifiAction.none);
    }
    if (!wifi.isOpenWifi) return const WifiChangeDecision(WifiAction.none);

    final status = _engine.status();
    if (status == ConnectionStatus.connected ||
        status == ConnectionStatus.connecting) {
      return const WifiChangeDecision(WifiAction.alreadyActive);
    }

    final activeId = await _settingsRepo.getActiveProfileId();
    if (activeId == null) return const WifiChangeDecision(WifiAction.noProfile);
    final profile = await _profileRepo.getById(activeId);
    if (profile == null) return const WifiChangeDecision(WifiAction.noProfile);

    return WifiChangeDecision(WifiAction.shouldConnect, profile);
  }
}
