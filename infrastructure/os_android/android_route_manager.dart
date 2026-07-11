import 'package:flutter/services.dart';

/// Dart client for Android routing / kill-switch operations that live in the
/// native VpnService. Kept separate from [AndroidVpnPlatform] so the connection
/// and kill-switch use-cases can depend on just this narrow surface.
///
/// Native counterpart: the MethodChannel handler in FastFlowVpnService.kt.
class AndroidRouteManager {
  static const MethodChannel _channel = MethodChannel('fastflow/route');

  /// Enable/disable the kill switch. On Android this reconfigures the active
  /// tunnel to be blocking (VpnService.Builder.setBlocking(true), no
  /// allowBypass) so traffic cannot leak while the tunnel is (re)connecting, and
  /// nudges the user toward system Always-on + Lockdown for boot-time coverage.
  Future<void> setKillSwitch(bool enabled) =>
      _channel.invokeMethod('setKillSwitch', {'enabled': enabled});

  /// Deep-link the user to the system "Always-on VPN" settings for this app,
  /// which is the only way to get lockdown that survives reboots and app death.
  Future<void> openAlwaysOnSettings() =>
      _channel.invokeMethod('openAlwaysOnSettings');

  /// True when the OS reports this app is the configured always-on VPN.
  Future<bool> isAlwaysOnEnabled() async =>
      await _channel.invokeMethod<bool>('isAlwaysOnEnabled') ?? false;

  /// Re-bind the tunnel's underlying network after a roaming event so the
  /// upstream sockets follow the new physical interface.
  Future<void> refreshUnderlyingNetworks() =>
      _channel.invokeMethod('refreshNetworks');
}
