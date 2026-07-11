import '../enums/inbound_mode.dart';
import '../models/app_settings.dart';

/// Parameters for establishing the OS tunnel interface. On Android these feed
/// VpnService.Builder; on Windows-with-admin the core builds the wintun adapter
/// so most fields are advisory.
class TunRequest {
  final List<String> addresses; // e.g. ['172.19.0.1/28', 'fdfe:dcba:9876::1/126']
  final int mtu;
  final List<String> dnsServers;
  final List<String> routes; // ['0.0.0.0/0', '::/0'] for full dual-stack capture

  /// Whether IPv6 is allowed to *egress* the tunnel. This does NOT gate whether
  /// v6 is captured: the interface always carries a v6 address + `::/0` route so
  /// native IPv6 can never leak to the physical NIC. When false the engine
  /// blackholes captured v6 (see RoutingBuilder); when true it is proxied.
  final bool ipv6;

  /// Package names to exclude from the tunnel (Android split-tunnel). Empty =
  /// tunnel everything.
  final List<String> disallowedApps;

  const TunRequest({
    // Always dual-stack so IPv6 is captured into the tun rather than leaking.
    this.addresses = const ['172.19.0.1/28', 'fdfe:dcba:9876::1/126'],
    this.mtu = 9000,
    this.dnsServers = const ['172.19.0.2'],
    this.routes = const ['0.0.0.0/0', '::/0'],
    this.ipv6 = false,
    this.disallowedApps = const [],
  });
}

/// Cross-platform port for OS-level VPN integration that the engine itself can't
/// do: permission prompts, the TUN fd, the kill switch, elevation checks, and
/// the system-proxy fallback. Concrete implementations live in
/// infrastructure/os_android and infrastructure/os_windows.
abstract interface class IVpnPlatform {
  /// Decide whether this platform+config should capture traffic via a TUN
  /// adapter or fall back to the OS system proxy. Android is always TUN; Windows
  /// returns [InboundMode.systemProxy] when not elevated and the no-admin
  /// fallback is enabled.
  Future<InboundMode> resolveInboundMode(AppSettings settings);

  /// Request the OS VPN permission if needed (Android VpnService.prepare).
  /// Returns true when permission is granted. No-op → true on Windows.
  Future<bool> prepare();

  /// Establish the OS tunnel and, on Android, return the file descriptor to hand
  /// to the engine via `EngineController.setTunFd`. Returns null when the engine
  /// owns the adapter (Windows-with-admin), or when running in system-proxy mode.
  Future<int?> establishTun(TunRequest request);

  /// Tear down the OS tunnel / firewall state.
  Future<void> teardown();

  /// Block all non-VPN traffic (Android Always-on lockdown, Windows firewall).
  Future<void> setKillSwitch(bool enabled);

  /// True when the process can create a TUN adapter (Windows admin). Always true
  /// on Android (VpnService needs no elevation).
  Future<bool> isElevated();

  /// Point the OS system proxy at the given local endpoint (Windows no-admin
  /// fallback). No-op on Android.
  Future<void> setSystemProxy({required String host, required int port});

  Future<void> clearSystemProxy();
}
