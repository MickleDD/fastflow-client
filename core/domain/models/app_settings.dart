import '../enums/tun_mode.dart';
import 'dns_config.dart';
import 'local_proxy_config.dart';
import 'routing_config.dart';

/// App-global configuration, persisted as a single row. Combined with the active
/// [ProxyProfile] by the config builder to produce the sing-box config, and read
/// by the OS-integration services (kill switch, auto-connect, proxy fallback).
///
/// Deliberately absent from this model: listen ports. All local listeners
/// (system-proxy fallback, debug API) use ephemeral per-session ports allocated
/// at connect time — persisted static ports made localhost port-scanning by
/// spyware instantaneous. The one survivor is [LocalProxyConfig.pinnedPort],
/// which is only honoured together with mandatory authentication.
class AppSettings {
  // ---- TUN ----------------------------------------------------------------
  final TunMode tunMode;

  /// Optional authenticated local proxy inbound (off by default). Replaces the
  /// old always-on mixed/socks loopback listeners, which any co-resident app
  /// could use to bypass split-tunnel routing.
  final LocalProxyConfig localProxy;

  // ---- DNS / routing ------------------------------------------------------
  final DnsConfig dns;
  final RoutingConfig routing;

  // ---- OS automation ------------------------------------------------------
  /// Block all non-VPN traffic (Android Always-on/lockdown, Windows firewall).
  final bool killSwitch;

  /// Auto-connect when joining an open/unencrypted Wi-Fi network.
  final bool autoConnectInsecureWifi;

  /// Windows only: if launched without admin rights, configure the system proxy
  /// instead of creating a TUN adapter.
  final bool windowsNoAdminFallback;

  /// Collect per-outbound traffic counters so the UI can show live throughput.
  /// Stats are read in-process (FFI GetStats); enabling this opens no socket.
  final bool enableStats;

  /// Debug/advanced: expose the Clash control API. When on, it binds
  /// 127.0.0.1 on an ephemeral port with a fresh per-session secret — there is
  /// no unauthenticated or fixed-port variant.
  final bool debugApiEnabled;

  const AppSettings({
    this.tunMode = TunMode.mixed,
    this.localProxy = const LocalProxyConfig.disabled(),
    this.dns = const DnsConfig(),
    this.routing = const RoutingConfig(),
    this.killSwitch = false,
    this.autoConnectInsecureWifi = false,
    this.windowsNoAdminFallback = true,
    this.enableStats = true,
    this.debugApiEnabled = false,
  });

  const AppSettings.defaults() : this();

  AppSettings copyWith({
    TunMode? tunMode,
    LocalProxyConfig? localProxy,
    DnsConfig? dns,
    RoutingConfig? routing,
    bool? killSwitch,
    bool? autoConnectInsecureWifi,
    bool? windowsNoAdminFallback,
    bool? enableStats,
    bool? debugApiEnabled,
  }) {
    return AppSettings(
      tunMode: tunMode ?? this.tunMode,
      localProxy: localProxy ?? this.localProxy,
      dns: dns ?? this.dns,
      routing: routing ?? this.routing,
      killSwitch: killSwitch ?? this.killSwitch,
      autoConnectInsecureWifi:
          autoConnectInsecureWifi ?? this.autoConnectInsecureWifi,
      windowsNoAdminFallback:
          windowsNoAdminFallback ?? this.windowsNoAdminFallback,
      enableStats: enableStats ?? this.enableStats,
      debugApiEnabled: debugApiEnabled ?? this.debugApiEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'tunMode': tunMode.toStorage(),
        'localProxy': localProxy.toJson(),
        'dns': dns.toJson(),
        'routing': routing.toJson(),
        'killSwitch': killSwitch,
        'autoConnectInsecureWifi': autoConnectInsecureWifi,
        'windowsNoAdminFallback': windowsNoAdminFallback,
        'enableStats': enableStats,
        'debugApiEnabled': debugApiEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        tunMode: TunMode.fromStorage(j['tunMode'] as String?),
        localProxy: j['localProxy'] is Map
            ? LocalProxyConfig.fromJson(
                (j['localProxy'] as Map).cast<String, dynamic>())
            // Migration: legacy rows carried shareOnLan/mixedPort/... instead.
            : _migrateLegacyProxy(j),
        dns: j['dns'] is Map
            ? DnsConfig.fromJson((j['dns'] as Map).cast<String, dynamic>())
            : const DnsConfig(),
        routing: j['routing'] is Map
            ? RoutingConfig.fromJson((j['routing'] as Map).cast<String, dynamic>())
            : const RoutingConfig(),
        killSwitch: j['killSwitch'] as bool? ?? false,
        autoConnectInsecureWifi: j['autoConnectInsecureWifi'] as bool? ?? false,
        windowsNoAdminFallback: j['windowsNoAdminFallback'] as bool? ?? true,
        enableStats: j['enableStats'] as bool? ?? true,
        debugApiEnabled: j['debugApiEnabled'] as bool? ?? false,
      );

  /// Fail-secure migration from the pre-hardening schema. Users who had LAN
  /// sharing on keep the intent (mode = lan) but with no credentials the
  /// builder will not open the listener until they generate credentials in
  /// settings — a broken LAN share beats silently re-opening an
  /// unauthenticated 0.0.0.0 proxy. Old static ports are dropped outright.
  static LocalProxyConfig _migrateLegacyProxy(Map<String, dynamic> j) {
    final sharedOnLan = j['shareOnLan'] as bool? ?? false;
    if (!sharedOnLan) return const LocalProxyConfig.disabled();
    return const LocalProxyConfig(mode: LocalProxyMode.lan);
  }
}
