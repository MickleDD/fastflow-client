import 'dart:async';
import 'dart:io';

import '../../core/domain/models/wifi_state.dart';
import '../../core/domain/repositories/i_wifi_monitor.dart';

/// Windows [IWifiMonitor].
///
/// Reachability/association changes are surfaced by polling `netsh wlan show
/// interfaces`, which wraps the native WLAN API and reports both the SSID and
/// the `Authentication` mode (Open vs WPA2/WPA3). For richer connectivity state
/// (has-internet, network category) the app can additionally observe
/// INetworkListManager COM events; for the open-Wi-Fi trigger the auth field is
/// what matters, so we keep this dependency-free.
///
/// Localization note: `netsh` output is localized. We match the SSID/auth field
/// labels for common locales and, as a fallback, treat any recognizably
/// non-"open" authentication token as secure (fail-safe: assume secure).
class WifiMonitorWindows implements IWifiMonitor {
  final Duration interval;
  final StreamController<WifiState> _controller =
      StreamController<WifiState>.broadcast();
  Timer? _timer;
  WifiState _last = const WifiState.none();

  WifiMonitorWindows({this.interval = const Duration(seconds: 5)}) {
    _controller.onListen = _start;
    _controller.onCancel = _stop;
  }

  @override
  Stream<WifiState> watch() => _controller.stream;

  @override
  Future<WifiState> current() async {
    try {
      final result = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      return _parse(result.stdout.toString());
    } catch (_) {
      return const WifiState.none();
    }
  }

  void _start() {
    _poll();
    _timer ??= Timer.periodic(interval, (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final state = await current();
    if (state != _last) {
      _last = state;
      if (!_controller.isClosed) _controller.add(state);
    }
  }

  WifiState _parse(String output) {
    // No associated interface → not on Wi-Fi.
    if (!RegExp(r'State\s*:\s*connected', caseSensitive: false).hasMatch(output)) {
      return const WifiState.none();
    }

    String? ssid;
    final ssidMatch =
        RegExp(r'^\s*SSID\s*:\s*(.+)$', multiLine: true).firstMatch(output);
    if (ssidMatch != null) ssid = ssidMatch.group(1)?.trim();

    // Authentication : Open | WPA2-Personal | WPA3-Personal | ...
    final authMatch = RegExp(
      r'(Authentication|Authentifizierung|Authentification)\s*:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(output);
    final auth = authMatch?.group(2)?.trim().toLowerCase() ?? '';

    // Fail-safe: only "open"/"none" (no encryption) counts as insecure.
    final isSecure = !(auth.contains('open') || auth == 'none' || auth.isEmpty);

    return WifiState(isWifi: true, ssid: ssid, isSecure: isSecure);
  }

  @override
  Future<void> dispose() async {
    _stop();
    await _controller.close();
  }
}
