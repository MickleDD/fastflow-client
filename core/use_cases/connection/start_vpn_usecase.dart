import '../../domain/enums/inbound_mode.dart';
import '../../domain/models/proxy_profile.dart';
import '../../domain/models/routing_config.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../../domain/repositories/i_vpn_engine.dart';
import '../../domain/repositories/i_vpn_platform.dart';

/// Outcome of a start attempt.
class StartVpnResult {
  final bool ok;
  final String? error;
  final InboundMode? mode;

  const StartVpnResult._(this.ok, this.error, this.mode);
  factory StartVpnResult.success(InboundMode mode) =>
      StartVpnResult._(true, null, mode);
  factory StartVpnResult.failure(String error) =>
      StartVpnResult._(false, error, null);
}

/// Orchestrates a full connect: resolve mode → OS permission → establish tunnel
/// → start engine → apply system proxy / kill switch. Rolls back the OS state if
/// the engine fails to start.
class StartVpnUseCase {
  final IVpnEngine _engine;
  final IVpnPlatform _platform;
  final ISettingsRepository _settingsRepo;

  StartVpnUseCase(this._engine, this._platform, this._settingsRepo);

  Future<StartVpnResult> execute(ProxyProfile profile) async {
    final settings = await _settingsRepo.load();
    final mode = await _platform.resolveInboundMode(settings);

    // 1. OS VPN permission (Android consent dialog).
    if (!await _platform.prepare()) {
      return StartVpnResult.failure('VPN permission was denied');
    }

    // 2. Establish the OS tunnel. On Android this yields the fd to feed the
    //    engine; on Windows-with-admin the core owns the adapter (null fd).
    if (mode == InboundMode.tun) {
      final ipv6Enabled = settings.routing.ipv6Mode != Ipv6Mode.disable;
      final fd = await _platform.establishTun(TunRequest(
        // The v6 address and `::/0` route are ALWAYS added so the OS captures
        // IPv6 into the tun; when IPv6 is disabled the engine blackholes it
        // (see RoutingBuilder). Omitting them would leak native IPv6 out the
        // physical NIC, bypassing the tunnel and the kill switch.
        addresses: const ['172.19.0.1/28', 'fdfe:dcba:9876::1/126'],
        mtu: 9000,
        dnsServers: const ['172.19.0.2'],
        routes: const ['0.0.0.0/0', '::/0'],
        ipv6: ipv6Enabled, // now informs egress semantics only, not capture
      ));
      if (fd != null) _engine.setTunFd(fd);
    }

    // 3. Start the core (config + per-session ports are built inside the
    //    engine service).
    final result = await _engine.start(profile, settings, mode);
    if (!result.ok) {
      await _platform.teardown();
      return StartVpnResult.failure(result.error!);
    }

    // 4. Windows no-admin fallback: point the OS proxy at this session's
    //    ephemeral fallback inbound. The endpoint comes from the start result —
    //    ports are allocated per connection, never stored in settings.
    final systemProxy = result.systemProxy;
    if (mode == InboundMode.systemProxy && systemProxy != null) {
      await _platform.setSystemProxy(
        host: systemProxy.host,
        port: systemProxy.port,
      );
    }

    // 5. Kill switch (default-block firewall / VpnService lockdown).
    if (settings.killSwitch) {
      await _platform.setKillSwitch(true);
    }

    await _settingsRepo.setActiveProfileId(profile.id);
    return StartVpnResult.success(mode);
  }
}
