/// Snapshot of the current Wi-Fi association, used by the insecure-Wi-Fi
/// auto-connect feature.
class WifiState {
  /// Whether the active transport is Wi-Fi at all (vs. cellular/ethernet).
  final bool isWifi;

  final String? ssid;

  /// True when the network uses any link-layer encryption (WEP/WPA/WPA2/WPA3).
  /// False means an open, unencrypted hotspot.
  final bool isSecure;

  const WifiState({required this.isWifi, this.ssid, this.isSecure = true});

  const WifiState.none() : isWifi = false, ssid = null, isSecure = true;

  /// The trigger condition for auto-connect: on Wi-Fi and unencrypted.
  bool get isOpenWifi => isWifi && !isSecure;

  @override
  String toString() =>
      'WifiState(isWifi: $isWifi, ssid: $ssid, isSecure: $isSecure)';

  @override
  bool operator ==(Object other) =>
      other is WifiState &&
      other.isWifi == isWifi &&
      other.ssid == ssid &&
      other.isSecure == isSecure;

  @override
  int get hashCode => Object.hash(isWifi, ssid, isSecure);
}
