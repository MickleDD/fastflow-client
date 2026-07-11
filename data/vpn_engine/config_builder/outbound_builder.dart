import '../../../core/domain/enums/flow_type.dart';
import '../../../core/domain/models/proxy_profile.dart';

/// Builds the sing-box `outbounds` array from a [ProxyProfile].
///
/// TARGET CORE: the generated config targets a sing-box *fork* (hiddify /
/// FastFlow-style) that understands the DPI-evasion extensions `tls_tricks`
/// (mixed-case SNI, padding) and `tls_fragment`. Stock sagernet/sing-box is
/// strict and would reject those keys — see go.mod for the pinned core. Every
/// other field here is valid stock sing-box.
class OutboundBuilder {
  static const String proxyTag = 'proxy';
  static const String directTag = 'direct';
  static const String blockTag = 'block';
  static const String dnsTag = 'dns-out';

  /// Full outbound list: the proxy plus the direct/block/dns sinks the routing
  /// rules reference.
  static List<Map<String, dynamic>> build(ProxyProfile p) => [
        buildProxy(p),
        {'type': 'direct', 'tag': directTag},
        {'type': 'block', 'tag': blockTag},
        {'type': 'dns', 'tag': dnsTag},
      ];

  static Map<String, dynamic> buildProxy(ProxyProfile p) {
    switch (p.protocol) {
      case ProxyProtocol.vless:
        return _vless(p);
      case ProxyProtocol.hysteria2:
        return _hysteria2(p);
    }
  }

  /// Optional load-balancing group over multiple member tags. With a single
  /// server this is unused; the multi-server path wraps members in a `selector`
  /// (stock) — the custom core interprets [BalancerStrategy] to switch between
  /// round-robin / consistent-hash / sticky behaviour.
  static Map<String, dynamic> buildGroup(String tag, List<String> members) => {
        'type': 'selector',
        'tag': tag,
        'outbounds': members,
        'default': members.isNotEmpty ? members.first : proxyTag,
      };

  // --------------------------------------------------------------------- VLESS
  static Map<String, dynamic> _vless(ProxyProfile p) {
    final visionFlow = p.flow == FlowType.xtlsRprxVision;
    final out = <String, dynamic>{
      'type': 'vless',
      'tag': proxyTag,
      'server': p.serverAddress,
      'server_port': p.port,
      'uuid': p.uuid,
      // xudp gives correct UDP-over-VLESS packet framing; required for Vision.
      'packet_encoding': 'xudp',
    };

    if (visionFlow) {
      out['flow'] = FlowType.xtlsRprxVision.singBoxValue;
    }

    final tls = _tls(p);
    if (tls != null) out['tls'] = tls;

    final transport = _transport(p.transport);
    if (transport != null) out['transport'] = transport;

    // MUX and Vision are mutually exclusive — Vision needs a raw stream. Prefer
    // the explicit flow and drop MUX when both are requested.
    if (p.mux.enabled && !visionFlow && p.transport.type != TransportType.quic) {
      out['multiplex'] = _mux(p.mux);
    }

    return out;
  }

  // ----------------------------------------------------------------- Hysteria2
  static Map<String, dynamic> _hysteria2(ProxyProfile p) {
    final out = <String, dynamic>{
      'type': 'hysteria2',
      'tag': proxyTag,
      'server': p.serverAddress,
      'server_port': p.port,
      'password': p.password,
      'up_mbps': p.hysteriaUpMbps,
      'down_mbps': p.hysteriaDownMbps,
    };

    if (p.hysteriaObfsPassword.isNotEmpty) {
      out['obfs'] = {'type': 'salamander', 'password': p.hysteriaObfsPassword};
    }

    // Hysteria2 is QUIC/TLS end-to-end; TLS is mandatory. ALPN defaults to h3.
    final tls = _tls(p, defaultAlpn: const ['h3'], forceEnabled: true);
    if (tls != null) out['tls'] = tls;

    return out;
  }

  // -------------------------------------------------------------------- Helpers
  static Map<String, dynamic>? _tls(
    ProxyProfile p, {
    List<String>? defaultAlpn,
    bool forceEnabled = false,
  }) {
    final t = p.tls;
    if (!t.enabled && !forceEnabled) return null;

    final serverName = t.sni.isNotEmpty ? t.sni : p.serverAddress;
    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': serverName,
      'insecure': t.allowInsecure,
      'alpn': t.alpn.isNotEmpty ? t.alpn : (defaultAlpn ?? const ['h2', 'http/1.1']),
    };

    // uTLS — required whenever Reality is on; otherwise honour the profile.
    final wantUtls = t.utlsFingerprint.isNotEmpty || t.reality.enabled;
    if (wantUtls) {
      tls['utls'] = {
        'enabled': true,
        'fingerprint':
            t.utlsFingerprint.isNotEmpty ? t.utlsFingerprint : 'chrome',
      };
    }

    if (t.reality.enabled) {
      tls['reality'] = {
        'enabled': true,
        'public_key': t.reality.publicKey,
        'short_id': t.reality.shortId,
      };
    }

    // ---- TLS tricks (fork extensions) -------------------------------------
    final tricks = <String, dynamic>{};
    if (t.mixedCaseSni) tricks['mixed_case_sni'] = true;
    if (t.padding.enabled) tricks['padding_size'] = t.padding.size;
    if (tricks.isNotEmpty) tls['tls_tricks'] = tricks;

    if (t.fragment.enabled) {
      tls['tls_fragment'] = {
        'enabled': true,
        'size': t.fragment.size,
        'sleep': t.fragment.delay,
      };
    }

    return tls;
  }

  static Map<String, dynamic>? _transport(TransportConfig tr) {
    switch (tr.type) {
      case TransportType.tcp:
        return null; // raw TCP has no transport object
      case TransportType.ws:
        return {
          'type': 'ws',
          'path': tr.path,
          if (tr.host.isNotEmpty) 'headers': {'Host': tr.host},
        };
      case TransportType.grpc:
        return {'type': 'grpc', 'service_name': tr.serviceName};
      case TransportType.http:
        return {
          'type': 'http',
          'path': tr.path,
          if (tr.host.isNotEmpty) 'host': [tr.host],
        };
      case TransportType.httpUpgrade:
        return {
          'type': 'httpupgrade',
          'path': tr.path,
          if (tr.host.isNotEmpty) 'host': tr.host,
        };
      case TransportType.quic:
        return {'type': 'quic'};
    }
  }

  static Map<String, dynamic> _mux(MuxConfig m) => {
        'enabled': true,
        'protocol': m.protocol.value,
        'max_connections': m.maxConnections,
        if (m.maxStreams > 0) 'max_streams': m.maxStreams,
        'padding': m.padding,
      };
}
