import '../../../core/domain/enums/inbound_mode.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/local_proxy_config.dart';
import '../inbound_session.dart';

/// Builds the sing-box `inbounds` array.
///
/// Threat model: Android's VpnService does not isolate 127.0.0.1, and on
/// Windows every same-user process shares it, so ANY loopback listener is
/// reachable by co-resident spyware and becomes a split-tunnel bypass and an
/// external-IP oracle. The rules this builder enforces:
///
///   1. TUN mode opens no proxy listeners by default — the TUN captures the
///      device's traffic, so a loopback proxy serves only attackers.
///   2. A proxy inbound exists only for an explicit reason: the Windows
///      no-admin system-proxy fallback, or the user-enabled local proxy.
///   3. Every user-facing proxy inbound authenticates (`users`); an enabled
///      local proxy without credentials fails closed (no listener).
///   4. Ports come from [InboundSession] — ephemeral per connection unless the
///      user pinned the authenticated local-proxy port.
class InboundBuilder {
  static const String tunTag = 'tun-in';

  /// Windows no-admin fallback (unauthenticated by necessity: WinINET cannot
  /// attach proxy credentials silently). Loopback-only, ephemeral port, and
  /// present only while the app runs in system-proxy mode.
  static const String systemProxyTag = 'sysproxy-in';

  /// The opt-in authenticated local proxy (tooling / LAN sharing).
  static const String localProxyTag = 'proxy-in';

  static List<Map<String, dynamic>> build(
    AppSettings s, {
    required InboundMode mode,
    required InboundSession session,
  }) {
    return [
      if (mode == InboundMode.tun) _tun(s),
      if (mode == InboundMode.systemProxy) _systemProxyFallback(s, session),
      if (session.localProxyPort != null) _localProxy(s, session),
    ];
  }

  static Map<String, dynamic> _tun(AppSettings s) {
    return {
      'type': 'tun',
      'tag': tunTag,
      'interface_name': 'fastflow-tun',
      // The v6 ULA is ALWAYS present so the OS installs a `::/0` route INTO the
      // tun (auto_route derives it from this address). When IPv6 is disabled the
      // routing layer blackholes that traffic — dropping the v6 address here
      // instead would let native IPv6 leak straight out the physical NIC.
      'address': [
        '172.19.0.1/28',
        'fdfe:dcba:9876::1/126',
      ],
      'mtu': 9000,
      // Android manages routes through the VpnService; on desktop sing-box owns
      // them. auto_route works in both because the platform interface bridges it.
      'auto_route': true,
      'strict_route': s.routing.strictRouting,
      'stack': s.tunMode.stackValue,
      'endpoint_independent_nat': true,
      'sniff': s.routing.enableSniffing,
      'sniff_override_destination': false,
    };
  }

  /// Windows no-admin fallback inbound. The system proxy registry entry is
  /// owned by WindowsSystemProxyManager (not sing-box's `set_system_proxy`),
  /// so there is exactly one writer and teardown always reverts it even if the
  /// engine dies.
  ///
  /// Residual risk, accepted deliberately: this listener cannot require auth
  /// because WinINET has no way to attach credentials without prompting every
  /// app. In this mode the proxy is *advertised* to all apps via HKCU anyway —
  /// it is the capture mechanism, not a bypass of it. The ephemeral port and
  /// session-only lifetime keep it from becoming ambient infrastructure.
  static Map<String, dynamic> _systemProxyFallback(
    AppSettings s,
    InboundSession session,
  ) {
    final port = session.systemProxyPort;
    if (port == null) {
      throw StateError(
          'systemProxy mode requires an allocated system-proxy port');
    }
    return {
      'type': 'mixed',
      'tag': systemProxyTag,
      'listen': '127.0.0.1',
      'listen_port': port,
      'sniff': s.routing.enableSniffing,
    };
  }

  /// The opt-in local proxy. One `mixed` inbound covers both SOCKS5 and HTTP —
  /// the old separate plain-socks listener was redundant attack surface.
  /// Credentials are mandatory: sing-box rejects unauthenticated clients with
  /// the standard SOCKS5/407 handshake, so a port scan yields no usable proxy
  /// and no app identification.
  static Map<String, dynamic> _localProxy(
    AppSettings s,
    InboundSession session,
  ) {
    final lp = s.localProxy;
    if (!lp.canListen) {
      // build() only emits this inbound when a port was allocated, and the
      // session factory only allocates one when canListen — enforce the pair.
      throw StateError('local proxy port allocated without credentials');
    }
    return {
      'type': 'mixed',
      'tag': localProxyTag,
      // 0.0.0.0 only for the explicit LAN-sharing mode; otherwise loopback.
      'listen': lp.mode == LocalProxyMode.lan ? '0.0.0.0' : '127.0.0.1',
      'listen_port': session.localProxyPort,
      'sniff': s.routing.enableSniffing,
      'users': [
        {'username': lp.username, 'password': lp.password},
      ],
    };
  }
}
