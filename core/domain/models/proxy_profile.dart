import '../enums/flow_type.dart';
import '../enums/tun_mode.dart';
import 'routing_config.dart';
import 'tls_config.dart';

/// Wire protocol of a profile.
enum ProxyProtocol {
  vless,
  hysteria2;

  String get value => this == ProxyProtocol.vless ? 'vless' : 'hysteria2';

  static ProxyProtocol fromStorage(String? v) =>
      v == 'hysteria2' ? ProxyProtocol.hysteria2 : ProxyProtocol.vless;
}

/// Stream transport carrying the protocol. `tcp` uses no transport object;
/// the rest map to sing-box `transport.type`.
enum TransportType {
  tcp,
  ws,
  grpc,
  http,
  httpUpgrade,
  quic;

  /// sing-box transport type string ("" means no transport block / raw TCP).
  String get singBoxValue {
    switch (this) {
      case TransportType.tcp:
        return '';
      case TransportType.ws:
        return 'ws';
      case TransportType.grpc:
        return 'grpc';
      case TransportType.http:
        return 'http';
      case TransportType.httpUpgrade:
        return 'httpupgrade';
      case TransportType.quic:
        return 'quic';
    }
  }

  String get label => this == TransportType.httpUpgrade ? 'HTTPUpgrade' : name.toUpperCase();

  static TransportType fromStorage(String? v) => TransportType.values
      .firstWhere((e) => e.name == v, orElse: () => TransportType.tcp);
}

/// Multiplexing (sing-box `multiplex`). Not valid together with Vision flow.
enum MuxProtocol {
  h2mux,
  smux,
  yamux;

  String get value => name;

  static MuxProtocol fromStorage(String? v) =>
      MuxProtocol.values.firstWhere((e) => e.name == v, orElse: () => MuxProtocol.h2mux);
}

class MuxConfig {
  final bool enabled;
  final MuxProtocol protocol;
  final int maxConnections;
  final int maxStreams;
  final bool padding;

  const MuxConfig({
    this.enabled = false,
    this.protocol = MuxProtocol.h2mux,
    this.maxConnections = 4,
    this.maxStreams = 0,
    this.padding = false,
  });

  MuxConfig copyWith({
    bool? enabled,
    MuxProtocol? protocol,
    int? maxConnections,
    int? maxStreams,
    bool? padding,
  }) {
    return MuxConfig(
      enabled: enabled ?? this.enabled,
      protocol: protocol ?? this.protocol,
      maxConnections: maxConnections ?? this.maxConnections,
      maxStreams: maxStreams ?? this.maxStreams,
      padding: padding ?? this.padding,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'protocol': protocol.name,
        'maxConnections': maxConnections,
        'maxStreams': maxStreams,
        'padding': padding,
      };

  factory MuxConfig.fromJson(Map<String, dynamic> j) => MuxConfig(
        enabled: j['enabled'] as bool? ?? false,
        protocol: MuxProtocol.fromStorage(j['protocol'] as String?),
        maxConnections: j['maxConnections'] as int? ?? 4,
        maxStreams: j['maxStreams'] as int? ?? 0,
        padding: j['padding'] as bool? ?? false,
      );
}

/// Transport-specific parameters. Unused fields for a given [type] are ignored
/// by the outbound builder.
class TransportConfig {
  final TransportType type;

  /// ws / http / httpupgrade path.
  final String path;

  /// Host header (ws/http/httpupgrade). Empty reuses SNI/server.
  final String host;

  /// gRPC service name.
  final String serviceName;

  const TransportConfig({
    this.type = TransportType.tcp,
    this.path = '/',
    this.host = '',
    this.serviceName = '',
  });

  TransportConfig copyWith({
    TransportType? type,
    String? path,
    String? host,
    String? serviceName,
  }) {
    return TransportConfig(
      type: type ?? this.type,
      path: path ?? this.path,
      host: host ?? this.host,
      serviceName: serviceName ?? this.serviceName,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'path': path,
        'host': host,
        'serviceName': serviceName,
      };

  factory TransportConfig.fromJson(Map<String, dynamic> j) => TransportConfig(
        type: TransportType.fromStorage(j['type'] as String?),
        path: j['path'] as String? ?? '/',
        host: j['host'] as String? ?? '',
        serviceName: j['serviceName'] as String? ?? '',
      );
}

/// A single server connection profile (FastFlow / VLESS / Hysteria2).
///
/// Holds everything protocol-specific needed to build one sing-box outbound.
/// App-wide behaviour (DNS, routing detail, automation, TUN sharing) lives in
/// [AppSettings]; the routing *preferences* kept here (balancer, ipv6, strict,
/// tunMode) seed those globals and preserve the original skeleton's shape.
class ProxyProfile {
  final String id;
  final String name;
  final String serverAddress;
  final int port;
  final ProxyProtocol protocol;

  /// VLESS user id.
  final String uuid;

  /// Hysteria2 auth password (unused for VLESS).
  final String password;

  final FlowType flow;
  final TransportConfig transport;
  final MuxConfig mux;
  final TlsConfig tls;

  // ---- Hysteria2 tuning ---------------------------------------------------
  final int hysteriaUpMbps;
  final int hysteriaDownMbps;
  final String hysteriaObfsPassword; // salamander obfuscation; empty = off

  // ---- Routing preferences (from skeleton) --------------------------------
  final TunMode tunMode;
  final bool strictRouting;
  final BalancerStrategy balancer;
  final Ipv6Mode ipv6Mode;

  ProxyProfile({
    required this.id,
    required this.name,
    required this.serverAddress,
    required this.port,
    required this.protocol,
    required this.uuid,
    this.password = '',
    this.flow = FlowType.none,
    this.transport = const TransportConfig(),
    this.mux = const MuxConfig(),
    this.tls = const TlsConfig(),
    this.hysteriaUpMbps = 50,
    this.hysteriaDownMbps = 200,
    this.hysteriaObfsPassword = '',
    this.tunMode = TunMode.mixed,
    this.strictRouting = true,
    this.balancer = BalancerStrategy.roundRobin,
    this.ipv6Mode = Ipv6Mode.disable,
  });

  bool get isHysteria2 => protocol == ProxyProtocol.hysteria2;

  ProxyProfile copyWith({
    String? id,
    String? name,
    String? serverAddress,
    int? port,
    ProxyProtocol? protocol,
    String? uuid,
    String? password,
    FlowType? flow,
    TransportConfig? transport,
    MuxConfig? mux,
    TlsConfig? tls,
    int? hysteriaUpMbps,
    int? hysteriaDownMbps,
    String? hysteriaObfsPassword,
    TunMode? tunMode,
    bool? strictRouting,
    BalancerStrategy? balancer,
    Ipv6Mode? ipv6Mode,
  }) {
    return ProxyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAddress: serverAddress ?? this.serverAddress,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      uuid: uuid ?? this.uuid,
      password: password ?? this.password,
      flow: flow ?? this.flow,
      transport: transport ?? this.transport,
      mux: mux ?? this.mux,
      tls: tls ?? this.tls,
      hysteriaUpMbps: hysteriaUpMbps ?? this.hysteriaUpMbps,
      hysteriaDownMbps: hysteriaDownMbps ?? this.hysteriaDownMbps,
      hysteriaObfsPassword: hysteriaObfsPassword ?? this.hysteriaObfsPassword,
      tunMode: tunMode ?? this.tunMode,
      strictRouting: strictRouting ?? this.strictRouting,
      balancer: balancer ?? this.balancer,
      ipv6Mode: ipv6Mode ?? this.ipv6Mode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverAddress': serverAddress,
        'port': port,
        'protocol': protocol.value,
        'uuid': uuid,
        'password': password,
        'flow': flow.toStorage(),
        'transport': transport.toJson(),
        'mux': mux.toJson(),
        'tls': tls.toJson(),
        'hysteriaUpMbps': hysteriaUpMbps,
        'hysteriaDownMbps': hysteriaDownMbps,
        'hysteriaObfsPassword': hysteriaObfsPassword,
        'tunMode': tunMode.toStorage(),
        'strictRouting': strictRouting,
        'balancer': balancer.name,
        'ipv6Mode': ipv6Mode.name,
      };

  factory ProxyProfile.fromJson(Map<String, dynamic> j) => ProxyProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Unnamed',
        serverAddress: j['serverAddress'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? 443,
        protocol: ProxyProtocol.fromStorage(j['protocol'] as String?),
        uuid: j['uuid'] as String? ?? '',
        password: j['password'] as String? ?? '',
        flow: FlowType.fromStorage(j['flow'] as String?),
        transport: j['transport'] is Map
            ? TransportConfig.fromJson((j['transport'] as Map).cast<String, dynamic>())
            : const TransportConfig(),
        mux: j['mux'] is Map
            ? MuxConfig.fromJson((j['mux'] as Map).cast<String, dynamic>())
            : const MuxConfig(),
        tls: j['tls'] is Map
            ? TlsConfig.fromJson((j['tls'] as Map).cast<String, dynamic>())
            : const TlsConfig(),
        hysteriaUpMbps: (j['hysteriaUpMbps'] as num?)?.toInt() ?? 50,
        hysteriaDownMbps: (j['hysteriaDownMbps'] as num?)?.toInt() ?? 200,
        hysteriaObfsPassword: j['hysteriaObfsPassword'] as String? ?? '',
        tunMode: TunMode.fromStorage(j['tunMode'] as String?),
        strictRouting: j['strictRouting'] as bool? ?? true,
        balancer: BalancerStrategy.fromStorage(j['balancer'] as String?),
        ipv6Mode: Ipv6Mode.fromStorage(j['ipv6Mode'] as String?),
      );
}
