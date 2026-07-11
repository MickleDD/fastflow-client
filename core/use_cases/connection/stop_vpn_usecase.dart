import '../../domain/repositories/i_vpn_engine.dart';
import '../../domain/repositories/i_vpn_platform.dart';

/// Clean disconnect: stop the core, drop the system proxy, lift the kill-switch
/// firewall block, and tear down the OS tunnel.
///
/// Note: the kill switch is intentionally lifted only on an *explicit* stop. If
/// the engine dies unexpectedly the firewall block stays in place and continues
/// to prevent leaks — that is the whole point of the kill switch.
class StopVpnUseCase {
  final IVpnEngine _engine;
  final IVpnPlatform _platform;

  StopVpnUseCase(this._engine, this._platform);

  Future<void> execute() async {
    await _engine.stop();
    await _platform.clearSystemProxy();
    await _platform.setKillSwitch(false);
    await _platform.teardown();
  }
}
