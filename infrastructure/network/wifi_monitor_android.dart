import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/domain/models/wifi_state.dart';
import '../../core/domain/repositories/i_wifi_monitor.dart';

/// Android [IWifiMonitor] backed by ConnectivityManager.NetworkCallback +
/// WifiManager on the native side.
///
/// Security detection: on API 31+ the native side reads
/// WifiInfo.getCurrentSecurityType() and reports SECURITY_TYPE_OPEN as insecure;
/// on older APIs it inspects the matched WifiConfiguration's key management.
/// Requires ACCESS_FINE_LOCATION to read the SSID at runtime.
///
/// Channels:
///  * EventChannel `fastflow/wifi_events` — pushes a {isWifi, ssid, isSecure} map
///    on every network change.
///  * MethodChannel `fastflow/wifi` — `current` returns the same map once.
class WifiMonitorAndroid implements IWifiMonitor {
  static const EventChannel _events = EventChannel('fastflow/wifi_events');
  static const MethodChannel _methods = MethodChannel('fastflow/wifi');

  Stream<WifiState>? _stream;

  @override
  Stream<WifiState> watch() =>
      _stream ??= _events.receiveBroadcastStream().map(_map).distinct();

  @override
  Future<WifiState> current() async {
    final map = await _methods.invokeMapMethod<String, dynamic>('current');
    return map == null ? const WifiState.none() : _map(map);
  }

  WifiState _map(dynamic event) {
    final m = (event as Map).cast<String, dynamic>();
    return WifiState(
      isWifi: m['isWifi'] as bool? ?? false,
      ssid: m['ssid'] as String?,
      isSecure: m['isSecure'] as bool? ?? true,
    );
  }

  @override
  Future<void> dispose() async {
    _stream = null;
  }
}
