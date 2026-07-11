/// Load-balancing strategy used when a profile fans out to several outbounds
/// (sing-box `type: "urltest"` / `load_balance` selectors).
enum BalancerStrategy {
  roundRobin,
  consistentHash,
  stickySession;

  /// Value for sing-box's balancer `strategy` field.
  String get singBoxValue {
    switch (this) {
      case BalancerStrategy.roundRobin:
        return 'round_robin';
      case BalancerStrategy.consistentHash:
        return 'consistent_hashing';
      case BalancerStrategy.stickySession:
        return 'sticky_sessions';
    }
  }

  String get label {
    switch (this) {
      case BalancerStrategy.roundRobin:
        return 'Round robin';
      case BalancerStrategy.consistentHash:
        return 'Consistent hash';
      case BalancerStrategy.stickySession:
        return 'Sticky session';
    }
  }

  static BalancerStrategy fromStorage(String? v) => BalancerStrategy.values
      .firstWhere((e) => e.name == v, orElse: () => BalancerStrategy.roundRobin);
}

/// How IPv6 is handled end-to-end. Maps onto sing-box `domain_strategy`
/// resolution and route rules.
enum Ipv6Mode {
  /// Never use IPv6 — resolve A records only.
  disable,

  /// Allow IPv6 but prefer IPv4.
  enable,

  /// Allow both, prefer IPv6.
  prefer,

  /// IPv6 only — resolve AAAA records only.
  only;

  /// sing-box domain strategy string driven by the IPv6 preference.
  String get domainStrategy {
    switch (this) {
      case Ipv6Mode.disable:
        return 'ipv4_only';
      case Ipv6Mode.enable:
        return 'prefer_ipv4';
      case Ipv6Mode.prefer:
        return 'prefer_ipv6';
      case Ipv6Mode.only:
        return 'ipv6_only';
    }
  }

  String get label {
    switch (this) {
      case Ipv6Mode.disable:
        return 'Disable';
      case Ipv6Mode.enable:
        return 'Enable';
      case Ipv6Mode.prefer:
        return 'Prefer';
      case Ipv6Mode.only:
        return 'Only';
    }
  }

  static Ipv6Mode fromStorage(String? v) =>
      Ipv6Mode.values.firstWhere((e) => e.name == v, orElse: () => Ipv6Mode.disable);
}

/// App-global routing behaviour. Owned by [AppSettings], consumed by the
/// routing config builder.
class RoutingConfig {
  final BalancerStrategy balancer;
  final Ipv6Mode ipv6Mode;

  /// sing-box route `auto_detect_interface` + strict address family checks.
  final bool strictRouting;

  /// Route the `geosite:category-ads-all` rule set to a block outbound.
  final bool adBlock;

  /// Send private/LAN destinations directly instead of through the tunnel.
  final bool bypassLan;

  /// Inbound sniffing — inspect the first packet to determine the real
  /// destination domain (TLS SNI / HTTP Host) for domain-based routing.
  final bool enableSniffing;

  const RoutingConfig({
    this.balancer = BalancerStrategy.roundRobin,
    this.ipv6Mode = Ipv6Mode.disable,
    this.strictRouting = true,
    this.adBlock = true,
    this.bypassLan = true,
    this.enableSniffing = true,
  });

  RoutingConfig copyWith({
    BalancerStrategy? balancer,
    Ipv6Mode? ipv6Mode,
    bool? strictRouting,
    bool? adBlock,
    bool? bypassLan,
    bool? enableSniffing,
  }) {
    return RoutingConfig(
      balancer: balancer ?? this.balancer,
      ipv6Mode: ipv6Mode ?? this.ipv6Mode,
      strictRouting: strictRouting ?? this.strictRouting,
      adBlock: adBlock ?? this.adBlock,
      bypassLan: bypassLan ?? this.bypassLan,
      enableSniffing: enableSniffing ?? this.enableSniffing,
    );
  }

  Map<String, dynamic> toJson() => {
        'balancer': balancer.name,
        'ipv6Mode': ipv6Mode.name,
        'strictRouting': strictRouting,
        'adBlock': adBlock,
        'bypassLan': bypassLan,
        'enableSniffing': enableSniffing,
      };

  factory RoutingConfig.fromJson(Map<String, dynamic> j) => RoutingConfig(
        balancer: BalancerStrategy.fromStorage(j['balancer'] as String?),
        ipv6Mode: Ipv6Mode.fromStorage(j['ipv6Mode'] as String?),
        strictRouting: j['strictRouting'] as bool? ?? true,
        adBlock: j['adBlock'] as bool? ?? true,
        bypassLan: j['bypassLan'] as bool? ?? true,
        enableSniffing: j['enableSniffing'] as bool? ?? true,
      );
}
