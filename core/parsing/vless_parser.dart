import '../domain/enums/flow_type.dart';
import '../domain/models/proxy_profile.dart';
import '../domain/models/tls_config.dart';

/// Parses standard `vless://` share links into a [ProxyProfile].
///
/// Accepts the widely-used Xray / v2rayN share format:
///
///   vless://<uuid>@<host>:<port>?type=ws&security=reality&pbk=<key>
///           &sni=<sni>&sid=<shortId>&fp=chrome&flow=xtls-rprx-vision
///           &path=/ws&host=<hostHeader>&serviceName=<grpc>&alpn=h2,http/1.1#<name>
///
/// Unknown query keys are ignored; the fragment (`#...`) becomes the profile
/// name. Nothing here talks to storage — callers decide whether to persist or
/// pre-fill an editor.
class VlessParser {
  /// Parses [uri], throwing [FormatException] when it is not a valid VLESS link.
  static ProxyProfile parse(String uri) {
    final trimmed = uri.trim();
    if (!trimmed.toLowerCase().startsWith('vless://')) {
      throw const FormatException('Not a vless:// link');
    }

    final Uri parsed;
    try {
      parsed = Uri.parse(trimmed);
    } on FormatException {
      throw const FormatException('Malformed vless:// URI');
    }

    final uuid = Uri.decodeComponent(parsed.userInfo);
    if (uuid.isEmpty) {
      throw const FormatException('Missing UUID before "@"');
    }

    final host = parsed.host;
    if (host.isEmpty) {
      throw const FormatException('Missing server host');
    }

    final port = parsed.hasPort ? parsed.port : 443;
    final q = parsed.queryParameters;

    final security = (q['security'] ?? 'none').toLowerCase();
    final isReality = security == 'reality';
    final tlsEnabled = security == 'tls' || isReality;

    final sni = q['sni'] ?? q['peer'] ?? '';
    final fingerprint = q['fp'] ?? '';
    final alpn = _splitCsv(q['alpn']);
    final allowInsecure = _isTruthy(q['allowInsecure']) || _isTruthy(q['insecure']);

    final tls = TlsConfig(
      enabled: tlsEnabled,
      sni: sni,
      alpn: alpn.isNotEmpty ? alpn : const ['h2', 'http/1.1'],
      utlsFingerprint: fingerprint.isNotEmpty
          ? fingerprint
          : (isReality ? 'chrome' : ''),
      allowInsecure: allowInsecure,
      reality: RealityConfig(
        enabled: isReality,
        publicKey: q['pbk'] ?? '',
        shortId: q['sid'] ?? '',
      ),
    );

    final transportType = _transportFrom(q['type']);
    final transport = TransportConfig(
      type: transportType,
      path: (q['path'] != null && q['path']!.isNotEmpty) ? q['path']! : '/',
      host: q['host'] ?? '',
      serviceName: q['serviceName'] ?? q['servicename'] ?? '',
    );

    final flow = FlowType.fromStorage(q['flow']);

    // `Uri.fragment` is already percent-decoded; use it as-is for the name.
    final name = parsed.fragment.isNotEmpty ? parsed.fragment : host;

    return ProxyProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      serverAddress: host,
      port: port,
      protocol: ProxyProtocol.vless,
      uuid: uuid,
      flow: flow,
      transport: transport,
      tls: tls,
    );
  }

  /// Like [parse] but returns `null` instead of throwing on invalid input.
  static ProxyProfile? tryParse(String uri) {
    try {
      return parse(uri);
    } on FormatException {
      return null;
    }
  }

  static TransportType _transportFrom(String? raw) {
    switch ((raw ?? 'tcp').toLowerCase()) {
      case 'ws':
        return TransportType.ws;
      case 'grpc':
        return TransportType.grpc;
      case 'http':
      case 'h2':
        return TransportType.http;
      case 'httpupgrade':
        return TransportType.httpUpgrade;
      case 'quic':
        return TransportType.quic;
      case 'tcp':
      default:
        return TransportType.tcp;
    }
  }

  static List<String> _splitCsv(String? raw) =>
      (raw == null || raw.isEmpty)
          ? const []
          : raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

  static bool _isTruthy(String? v) {
    final s = (v ?? '').toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}
