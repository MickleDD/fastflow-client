/// Domain resolution strategy for a DNS server / rule.
enum DnsDomainStrategy {
  asIs,
  preferIpv4,
  preferIpv6,
  ipv4Only,
  ipv6Only;

  String get value {
    switch (this) {
      case DnsDomainStrategy.asIs:
        return '';
      case DnsDomainStrategy.preferIpv4:
        return 'prefer_ipv4';
      case DnsDomainStrategy.preferIpv6:
        return 'prefer_ipv6';
      case DnsDomainStrategy.ipv4Only:
        return 'ipv4_only';
      case DnsDomainStrategy.ipv6Only:
        return 'ipv6_only';
    }
  }

  String get label {
    switch (this) {
      case DnsDomainStrategy.asIs:
        return 'As-is';
      case DnsDomainStrategy.preferIpv4:
        return 'Prefer IPv4';
      case DnsDomainStrategy.preferIpv6:
        return 'Prefer IPv6';
      case DnsDomainStrategy.ipv4Only:
        return 'IPv4 only';
      case DnsDomainStrategy.ipv6Only:
        return 'IPv6 only';
    }
  }

  static DnsDomainStrategy fromStorage(String? v) => DnsDomainStrategy.values
      .firstWhere((e) => e.name == v, orElse: () => DnsDomainStrategy.preferIpv4);
}

/// DNS behaviour for the tunnel. Consumed by the DNS config builder.
class DnsConfig {
  /// Resolver used for proxied/remote traffic. Accepts any sing-box DNS URL:
  /// `https://1.1.1.1/dns-query`, `tls://8.8.8.8`, `h3://dns.google/dns-query`,
  /// `udp://8.8.8.8`.
  final String remoteDns;

  /// Resolver used for direct/bypassed traffic (e.g. LAN, geosite:cn). `local`
  /// uses the system resolver.
  final String directDns;

  /// Fake-IP DNS: hand out synthetic addresses so no real lookup leaks before
  /// the connection is proxied. Strongly recommended with TUN.
  final bool enableFakeDns;

  /// IPv4 CIDR pool for fake-IP responses.
  final String fakeIpv4Range;

  /// IPv6 CIDR pool for fake-IP responses.
  final String fakeIpv6Range;

  /// Keep a per-server cache instead of a shared one (avoids poisoning between
  /// remote and direct resolvers).
  final bool independentCache;

  /// Default resolution strategy applied to DNS answers.
  final DnsDomainStrategy domainStrategy;

  const DnsConfig({
    this.remoteDns = 'https://1.1.1.1/dns-query',
    this.directDns = 'local',
    this.enableFakeDns = true,
    this.fakeIpv4Range = '198.18.0.0/15',
    this.fakeIpv6Range = 'fc00::/18',
    this.independentCache = true,
    this.domainStrategy = DnsDomainStrategy.preferIpv4,
  });

  DnsConfig copyWith({
    String? remoteDns,
    String? directDns,
    bool? enableFakeDns,
    String? fakeIpv4Range,
    String? fakeIpv6Range,
    bool? independentCache,
    DnsDomainStrategy? domainStrategy,
  }) {
    return DnsConfig(
      remoteDns: remoteDns ?? this.remoteDns,
      directDns: directDns ?? this.directDns,
      enableFakeDns: enableFakeDns ?? this.enableFakeDns,
      fakeIpv4Range: fakeIpv4Range ?? this.fakeIpv4Range,
      fakeIpv6Range: fakeIpv6Range ?? this.fakeIpv6Range,
      independentCache: independentCache ?? this.independentCache,
      domainStrategy: domainStrategy ?? this.domainStrategy,
    );
  }

  Map<String, dynamic> toJson() => {
        'remoteDns': remoteDns,
        'directDns': directDns,
        'enableFakeDns': enableFakeDns,
        'fakeIpv4Range': fakeIpv4Range,
        'fakeIpv6Range': fakeIpv6Range,
        'independentCache': independentCache,
        'domainStrategy': domainStrategy.name,
      };

  factory DnsConfig.fromJson(Map<String, dynamic> j) => DnsConfig(
        remoteDns: j['remoteDns'] as String? ?? 'https://1.1.1.1/dns-query',
        directDns: j['directDns'] as String? ?? 'local',
        enableFakeDns: j['enableFakeDns'] as bool? ?? true,
        fakeIpv4Range: j['fakeIpv4Range'] as String? ?? '198.18.0.0/15',
        fakeIpv6Range: j['fakeIpv6Range'] as String? ?? 'fc00::/18',
        independentCache: j['independentCache'] as bool? ?? true,
        domainStrategy: DnsDomainStrategy.fromStorage(j['domainStrategy'] as String?),
      );
}
