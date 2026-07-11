import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/routing_config.dart';
import 'outbound_builder.dart';

/// Builds the sing-box `route` object: DNS hijack, ad-block, LAN bypass, and the
/// final proxy. Also emits the `geosite-ads` rule-set shared with [DnsBuilder].
class RoutingBuilder {
  static Map<String, dynamic> build(AppSettings s) {
    final r = s.routing;

    final rules = <Map<String, dynamic>>[
      // Capture DNS and send it to the internal dns outbound so fake-IP works.
      {'protocol': 'dns', 'outbound': OutboundBuilder.dnsTag},
      {'port': 53, 'outbound': OutboundBuilder.dnsTag},

      // IPv6 blackhole: when IPv6 is disabled, drop every v6 packet the tun
      // captured (the tun always has a v6 address + `::/0` route, see
      // InboundBuilder._tun) instead of letting the OS route native IPv6 out the
      // physical NIC. DNS (v4, to 172.19.0.2) is matched above first, so it is
      // unaffected.
      if (r.ipv6Mode == Ipv6Mode.disable)
        {'ip_version': 6, 'outbound': OutboundBuilder.blockTag},

      // Ad blocking at the routing layer (DNS sinkhole covers the rest).
      if (r.adBlock)
        {'rule_set': 'geosite-ads', 'outbound': OutboundBuilder.blockTag},

      // Bypass LAN — send RFC1918 / link-local straight out the physical NIC.
      if (r.bypassLan)
        {'ip_is_private': true, 'outbound': OutboundBuilder.directTag},

      // Clash-mode overrides from the UI / clash_api.
      {'clash_mode': 'Direct', 'outbound': OutboundBuilder.directTag},
      {'clash_mode': 'Global', 'outbound': OutboundBuilder.proxyTag},
    ];

    final route = <String, dynamic>{
      'rules': rules,
      'final': OutboundBuilder.proxyTag,
      // Bind outbounds to the default interface and follow interface changes;
      // essential for kill-switch correctness and roaming between networks.
      'auto_detect_interface': true,
    };

    if (r.adBlock) {
      route['rule_set'] = [
        {
          'tag': 'geosite-ads',
          'type': 'remote',
          'format': 'binary',
          'url':
              'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
          // Download directly so ad rules don't depend on the tunnel being up.
          'download_detour': OutboundBuilder.directTag,
        },
      ];
    }

    return route;
  }
}
