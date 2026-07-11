import 'package:flutter/services.dart';

/// Persists, on the native side, whether the tunnel should be re-armed after a
/// reboot. The value is read by BootReceiver without a running Flutter engine, so
/// it lives in Android SharedPreferences rather than the app's SQLite database.
///
/// Channel: fastflow/boot → setAutoStart (handled by VpnChannels.kt).
class AndroidBootConfig {
  static const MethodChannel _channel = MethodChannel('fastflow/boot');

  Future<void> setAutoStart(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoStart', {'enabled': enabled});
    } on MissingPluginException {
      // Channel not registered (non-Android host or unit test) — ignore.
    } on PlatformException {
      // Best-effort; a failure here only affects boot re-arm, not this session.
    }
  }
}
