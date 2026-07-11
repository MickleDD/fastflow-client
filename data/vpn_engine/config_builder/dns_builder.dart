import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/routing_config.dart';
import '../../../core/domain/models/proxy_profile.dart';

/// Builds the sing-box `dns` object. References the `geosite-ads` rule-set that
/// [RoutingBuilder] defines when ad-blocking is on.
class DnsBuilder {
  static Map<String, dynamic> build(AppSettings s, ProxyProfile p) {
    final d = s.dns;
    final ipv6 = s.routing.ipv6Mode != Ipv6Mode.disable;

    final servers = <Map<String, dynamic>>[
      // Remote resolver: queried through the tunnel; its own host is resolved by
      // the direct server to avoid a chicken-and-egg lookup.
      {
        'tag': 'remote',
        'address': d.remoteDns,
        'address_resolver': 'direct',
        'detour': 'proxy',
      },
      {'tag': 'direct', 'address': d.directDns, 'detour': 'direct'},
      {'tag': 'block', 'address': 'rcode://success'},
      if (d.enableFakeDns) {'tag': 'fakeip', 'address': 'fakeip'},
    ];

    final rules = <Map<String, dynamic>>[
      // Resolve the proxy server's own hostname directly, never through itself.
      if (_isDomain(p.serverAddress))
        {
          'domain': [p.serverAddress],
          'server': 'direct',
        },
      // Ad blocking as a DNS sinkhole (cheaper than routing every request).
      if (s.routing.adBlock)
        {'rule_set': 'geosite-ads', 'server': 'block', 'disable_cache': true},
      // Honour Clash mode overrides coming from the UI / clash_api.
      {'clash_mode': 'Direct', 'server': 'direct'},
      {'clash_mode': 'Global', 'server': 'remote'},
      // Fake-IP for proxied A/AAAA queries so no real lookup leaks pre-tunnel.
      if (d.enableFakeDns)
        {
          'query_type': ['A', 'AAAA'],
          'server': 'fakeip',
        },
    ];

    final strategy = d.domainStrategy.value.isNotEmpty
        ? d.domainStrategy.value
        : s.routing.ipv6Mode.domainStrategy;

    final dns = <String, dynamic>{
      'servers': servers,
      'rules': rules,
      'independent_cache': d.independentCache,
      'strategy': strategy,
      'final': 'remote',
    };

    if (d.enableFakeDns) {
      dns['fakeip'] = {
        'enabled': true,
        'inet4_range': d.fakeIpv4Range,
        if (ipv6) 'inet6_range': d.fakeIpv6Range,
      };
    }

    return dns;
  }

  /// True when [host] is a hostname (not a literal IPv4/IPv6 address), so it
  /// needs a DNS rule; IP literals are left to the router.
  static bool _isDomain(String host) {
    if (host.isEmpty) return false;
    if (host.contains(':')) return false; // IPv6 literal
    final v4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (v4.hasMatch(host)) return false;
    return true;
  }
}
