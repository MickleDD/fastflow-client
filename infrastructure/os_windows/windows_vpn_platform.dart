import 'dart:io';

import '../../core/domain/enums/inbound_mode.dart';
import '../../core/domain/models/app_settings.dart';
import '../../core/domain/repositories/i_vpn_platform.dart';
import 'daemon_ipc_client.dart';
import 'system_proxy_manager.dart';
import 'windows_route_manager.dart';

/// Windows implementation of [IVpnPlatform], composing the route/kill-switch,
/// system-proxy, and elevated-daemon services.
///
/// On Windows the sing-box core owns the wintun adapter directly (when elevated),
/// so [establishTun] returns null — there is no fd to hand back. The no-admin
/// fallback is selected upstream by [isElevated]: the start use-case then runs
/// the engine in system-proxy mode and calls [setSystemProxy].
class WindowsVpnPlatform implements IVpnPlatform {
  final WindowsRouteManager routes;
  final WindowsSystemProxyManager proxy;

  /// Path of the engine host process, used as the kill-switch firewall allow
  /// target. Defaults to the running Flutter executable.
  final String engineExecutablePath;

  WindowsVpnPlatform({
    WindowsRouteManager? routes,
    WindowsSystemProxyManager? proxy,
    DaemonIpcClient? daemon,
    String? engineExecutablePath,
  })  : routes = routes ??
            WindowsRouteManager(
              // When not elevated, route privileged ops to the helper daemon if
              // it is installed (token present); otherwise inline ops run when
              // the GUI itself is elevated.
              daemon: daemon ?? DaemonIpcClient.fromInstalledToken(),
            ),
        proxy = proxy ?? WindowsSystemProxyManager(),
        engineExecutablePath =
            engineExecutablePath ?? Platform.resolvedExecutable;

  @override
  Future<InboundMode> resolveInboundMode(AppSettings settings) async {
    // Elevated → the core can create a wintun adapter. Otherwise fall back to the
    // system proxy if the user allows it; if not, still attempt TUN (which will
    // fail loudly rather than silently degrade).
    if (await isElevated()) return InboundMode.tun;
    return settings.windowsNoAdminFallback
        ? InboundMode.systemProxy
        : InboundMode.tun;
  }

  @override
  Future<bool> prepare() async => true; // no consent dialog on Windows

  @override
  Future<int?> establishTun(TunRequest request) async => null;

  @override
  Future<void> teardown() async {
    // Best-effort: always drop the system proxy in case we were in fallback mode.
    await proxy.disable();
  }

  @override
  Future<void> setKillSwitch(bool enabled) async {
    if (enabled) {
      await routes.enableKillSwitch(appPath: engineExecutablePath);
    } else {
      await routes.disableKillSwitch(appPath: engineExecutablePath);
    }
  }

  @override
  Future<bool> isElevated() async => routes.isElevated();

  @override
  Future<void> setSystemProxy({required String host, required int port}) =>
      proxy.enable(host: host, port: port);

  @override
  Future<void> clearSystemProxy() => proxy.disable();
}
