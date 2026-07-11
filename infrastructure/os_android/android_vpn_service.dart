import 'package:flutter/services.dart';

import '../../core/domain/enums/inbound_mode.dart';
import '../../core/domain/models/app_settings.dart';
import '../../core/domain/repositories/i_vpn_platform.dart';
import 'android_route_manager.dart';

/// Android implementation of [IVpnPlatform].
///
/// The native VpnService (FastFlowVpnService.kt) owns the tunnel fd: it prepares
/// the VPN permission, builds the interface, and returns a *detached* file
/// descriptor over the method channel. That int is handed to the Go engine via
/// `EngineController.setTunFd`, and the engine runs sing-box over it. Socket
/// "protect" (so upstream sockets bypass the tunnel) is bridged in native code.
class AndroidVpnPlatform implements IVpnPlatform {
  static const MethodChannel _channel = MethodChannel('fastflow/vpn');

  final AndroidRouteManager _routes;

  AndroidVpnPlatform({AndroidRouteManager? routeManager})
      : _routes = routeManager ?? AndroidRouteManager();

  @override
  Future<InboundMode> resolveInboundMode(AppSettings settings) async =>
      InboundMode.tun; // Android always tunnels over the VpnService fd

  @override
  Future<bool> prepare() async =>
      await _channel.invokeMethod<bool>('prepare') ?? false;

  @override
  Future<int?> establishTun(TunRequest request) async {
    // Returns ParcelFileDescriptor.detachFd() from the native side, or null if
    // establish() failed (e.g. permission revoked between prepare and establish).
    return _channel.invokeMethod<int>('establish', {
      'addresses': request.addresses,
      'mtu': request.mtu,
      'dns': request.dnsServers,
      'routes': request.routes,
      'ipv6': request.ipv6,
      'disallowedApps': request.disallowedApps,
    });
  }

  @override
  Future<void> teardown() => _channel.invokeMethod('stop');

  @override
  Future<void> setKillSwitch(bool enabled) => _routes.setKillSwitch(enabled);

  @override
  Future<bool> isElevated() async => true; // VpnService needs no elevation

  // System proxy is a Windows-only fallback; irrelevant on Android.
  @override
  Future<void> setSystemProxy({required String host, required int port}) async {}

  @override
  Future<void> clearSystemProxy() async {}
}
