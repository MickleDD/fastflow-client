/// Exposure level of the optional local SOCKS/HTTP proxy inbound.
///
/// Security context: Android's VpnService does not isolate 127.0.0.1, so any
/// app on the device can reach a loopback listener and use it to bypass the
/// per-app split-tunnel rules (masking its traffic behind the tunnel) — and on
/// Windows every process in the user session can do the same. The local proxy
/// therefore defaults to [disabled], and every enabled mode requires
/// per-connection authentication.
enum LocalProxyMode {
  /// No local proxy inbound at all (default). In TUN mode the tunnel already
  /// captures the device's traffic; an open loopback proxy would only serve
  /// as a split-tunnel bypass for other software on the machine.
  disabled,

  /// Loopback-only inbound for local tooling (curl, dev proxies, browsers with
  /// an explicit proxy config). Authentication is mandatory.
  loopback,

  /// LAN gateway ("Share VPN on local network"). Binds 0.0.0.0 and is
  /// reachable by every device on the network, so authentication is mandatory
  /// and a pinned port is supported so peers can be configured once.
  lan;

  String toStorage() => name;

  static LocalProxyMode fromStorage(String? v) => LocalProxyMode.values
      .firstWhere((m) => m.name == v, orElse: () => LocalProxyMode.disabled);
}

/// Configuration of the optional local proxy inbound.
///
/// The credentials live here (app-private storage) because tooling and LAN
/// peers need them to stay stable across sessions; they are generated with
/// `SecretGenerator` when the feature is first enabled and can be rotated from
/// the settings UI at any time. The *port*, by contrast, is ephemeral by
/// default ([pinnedPort] == 0): with authentication as the security boundary a
/// stable port is a usability opt-in, not a hole.
class LocalProxyConfig {
  final LocalProxyMode mode;

  /// 0 (default) = allocate a fresh ephemeral port on every connection.
  /// A fixed value in 1024–65535 may be set so LAN peers / tooling can be
  /// configured once. Privileged ports (<1024) are rejected on read.
  final int pinnedPort;

  /// SOCKS5 / HTTP-proxy credentials. Both must be non-empty before the
  /// config builder will emit the inbound — an enabled mode without
  /// credentials fails closed (no listener) rather than falling back to an
  /// unauthenticated one.
  final String username;
  final String password;

  const LocalProxyConfig({
    this.mode = LocalProxyMode.disabled,
    this.pinnedPort = 0,
    this.username = '',
    this.password = '',
  });

  const LocalProxyConfig.disabled() : this();

  bool get enabled => mode != LocalProxyMode.disabled;

  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  /// True when the builder may actually open the inbound.
  bool get canListen => enabled && hasCredentials;

  LocalProxyConfig copyWith({
    LocalProxyMode? mode,
    int? pinnedPort,
    String? username,
    String? password,
  }) {
    return LocalProxyConfig(
      mode: mode ?? this.mode,
      pinnedPort: pinnedPort ?? this.pinnedPort,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.toStorage(),
        'pinnedPort': pinnedPort,
        'username': username,
        'password': password,
      };

  factory LocalProxyConfig.fromJson(Map<String, dynamic> j) {
    final port = (j['pinnedPort'] as num?)?.toInt() ?? 0;
    return LocalProxyConfig(
      mode: LocalProxyMode.fromStorage(j['mode'] as String?),
      // Reject privileged/nonsense values from storage; 0 = ephemeral.
      pinnedPort: (port >= 1024 && port <= 65535) ? port : 0,
      username: j['username'] as String? ?? '',
      password: j['password'] as String? ?? '',
    );
  }
}
