import 'dart:convert';

import '../../../core/domain/enums/inbound_mode.dart';
import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/proxy_profile.dart';
import '../inbound_session.dart';
import 'dns_builder.dart';
import 'inbound_builder.dart';
import 'outbound_builder.dart';
import 'routing_builder.dart';

/// Assembles a full sing-box config from a [ProxyProfile] + [AppSettings] +
/// the per-connection [InboundSession] (ephemeral ports / session secrets).
///
/// This is the single entry point the engine layer calls; the four section
/// builders (dns / inbound / outbound / routing) stay independently testable.
class SingBoxConfigBuilder {
  static Map<String, dynamic> buildMap(
    ProxyProfile profile,
    AppSettings settings, {
    required InboundMode mode,
    required InboundSession session,
  }) {
    final config = <String, dynamic>{
      'log': {'level': 'warn', 'timestamp': true},
      'dns': DnsBuilder.build(settings, profile),
      'inbounds': InboundBuilder.build(settings, mode: mode, session: session),
      'outbounds': OutboundBuilder.build(profile),
      'route': RoutingBuilder.build(settings),
      'experimental': _experimental(settings, session),
    };
    return config;
  }

  /// Serialized config ready to hand to `EngineController.start`.
  static String build(
    ProxyProfile profile,
    AppSettings settings, {
    required InboundMode mode,
    required InboundSession session,
  }) =>
      jsonEncode(buildMap(profile, settings, mode: mode, session: session));

  /// Pretty-printed variant for the "export config" / debug screens. Secrets
  /// (proxy credentials, clash-api secret) are redacted by default so an
  /// exported config can be shared without handing out live credentials.
  static String buildPretty(
    ProxyProfile profile,
    AppSettings settings, {
    required InboundMode mode,
    InboundSession session = const InboundSession.none(),
    bool redactSecrets = true,
  }) {
    final map = buildMap(profile, settings, mode: mode, session: session);
    if (redactSecrets) _redactInPlace(map);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Map<String, dynamic> _experimental(
    AppSettings s,
    InboundSession session,
  ) {
    final exp = <String, dynamic>{
      // Persist fake-IP mappings across restarts so cached apps keep working.
      'cache_file': {'enabled': true, 'store_fakeip': true},
    };

    if (s.enableStats) {
      // Per-outbound counters for the UI traffic meter. An empty `listen`
      // means the stats service is created but NO TCP listener is bound: the
      // Go wrapper reads the service in-process and the UI polls it over FFI
      // (GetStats). The old 127.0.0.1:8080 listener let any local process
      // read live traffic data and server addresses — gone entirely.
      exp['v2ray_api'] = {
        'listen': '',
        'stats': {
          'enabled': true,
          'outbounds': [OutboundBuilder.proxyTag, OutboundBuilder.directTag],
        },
      };
    }

    // Clash control API: opt-in debug tool only. Never a fixed port, never
    // unauthenticated — the secret rotates every session, so a credential
    // captured by local malware dies with the connection.
    if (session.clashApiPort != null) {
      exp['clash_api'] = {
        'external_controller': '127.0.0.1:${session.clashApiPort}',
        'secret': session.clashApiSecret,
      };
    }

    return exp;
  }

  /// Blanks credential-bearing fields for export: inbound `users` passwords
  /// and the clash-api secret.
  static void _redactInPlace(Map<String, dynamic> config) {
    const placeholder = '<redacted>';
    final inbounds = config['inbounds'];
    if (inbounds is List) {
      for (final inbound in inbounds.whereType<Map<String, dynamic>>()) {
        final users = inbound['users'];
        if (users is List) {
          for (final user in users.whereType<Map<String, dynamic>>()) {
            if (user.containsKey('password')) user['password'] = placeholder;
          }
        }
      }
    }
    final experimental = config['experimental'];
    if (experimental is Map<String, dynamic>) {
      final clash = experimental['clash_api'];
      if (clash is Map<String, dynamic> && clash.containsKey('secret')) {
        clash['secret'] = placeholder;
      }
    }
  }
}
