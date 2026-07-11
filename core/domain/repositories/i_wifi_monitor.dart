import '../models/wifi_state.dart';

/// Port for observing Wi-Fi association changes across platforms. Implemented by
/// [WifiMonitorAndroid] (ConnectivityManager) and [WifiMonitorWindows]
/// (NetworkListManager / netsh).
abstract interface class IWifiMonitor {
  /// Emits whenever the network association changes.
  Stream<WifiState> watch();

  /// One-shot read of the current association.
  Future<WifiState> current();

  Future<void> dispose();
}
