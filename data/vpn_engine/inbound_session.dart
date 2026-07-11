import 'dart:io';

import '../../core/domain/enums/inbound_mode.dart';
import '../../core/domain/models/app_settings.dart';
import '../../core/domain/models/local_proxy_config.dart';
import '../../core/security/secret_generator.dart';

/// Per-connection runtime material for the inbound layer: which local ports
/// this session listens on and the secrets guarding them.
///
/// Nothing in here is ever persisted. Ports are re-drawn from the OS ephemeral
/// range on every connect (except a user-pinned local-proxy port) and the
/// clash-api secret is regenerated per session, so a port/secret harvested by
/// local spyware from one session is worthless for the next — and scanning for
/// well-known ports finds nothing at all.
class InboundSession {
  /// Loopback port of the unauthenticated Windows no-admin system-proxy
  /// inbound. Only set in [InboundMode.systemProxy]; always ephemeral.
  final int? systemProxyPort;

  /// Port of the authenticated user-facing local proxy (loopback or LAN).
  /// Set only when the feature is enabled *and* credentials exist.
  final int? localProxyPort;

  /// Loopback port + per-session secret of the opt-in Clash debug API.
  final int? clashApiPort;
  final String? clashApiSecret;

  const InboundSession({
    this.systemProxyPort,
    this.localProxyPort,
    this.clashApiPort,
    this.clashApiSecret,
  });

  /// A session with no local listeners at all — the default TUN-mode shape.
  const InboundSession.none() : this();
}

/// Allocates an [InboundSession] for one engine start.
class InboundSessionFactory {
  /// Draws every ephemeral port this session needs by binding port 0 and
  /// reading back the OS choice. All probe sockets stay open until every port
  /// is drawn (so two draws can't return the same port), then are released for
  /// sing-box to bind. The small close→rebind race is accepted: if another
  /// process steals a port in that window the engine start fails loudly and a
  /// reconnect draws fresh ports.
  static Future<InboundSession> allocate(
    AppSettings settings,
    InboundMode mode,
  ) async {
    final held = <ServerSocket>[];
    Future<int> draw(InternetAddress addr) async {
      final probe = await ServerSocket.bind(addr, 0);
      held.add(probe);
      return probe.port;
    }

    try {
      int? systemProxyPort;
      int? localProxyPort;
      int? clashApiPort;
      String? clashApiSecret;

      if (mode == InboundMode.systemProxy) {
        systemProxyPort = await draw(InternetAddress.loopbackIPv4);
      }

      final lp = settings.localProxy;
      if (lp.canListen) {
        localProxyPort = lp.pinnedPort != 0
            ? lp.pinnedPort
            : await draw(lp.mode == LocalProxyMode.lan
                ? InternetAddress.anyIPv4
                : InternetAddress.loopbackIPv4);
      }

      if (settings.debugApiEnabled) {
        clashApiPort = await draw(InternetAddress.loopbackIPv4);
        clashApiSecret = SecretGenerator.token();
      }

      return InboundSession(
        systemProxyPort: systemProxyPort,
        localProxyPort: localProxyPort,
        clashApiPort: clashApiPort,
        clashApiSecret: clashApiSecret,
      );
    } finally {
      for (final probe in held) {
        await probe.close();
      }
    }
  }
}
