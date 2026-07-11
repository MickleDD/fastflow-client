import '../../core/domain/enums/inbound_mode.dart';
import '../../core/domain/models/app_settings.dart';
import '../../core/domain/models/connection_state.dart';
import '../../core/domain/models/proxy_profile.dart';
import '../../core/domain/repositories/i_vpn_engine.dart';
import 'config_builder/sing_box_config_builder.dart';
import 'engine_controller.dart';
import 'inbound_session.dart';

/// Data-layer [IVpnEngine]: bridges the domain use-cases to the sing-box config
/// builder and the FFI [EngineController].
///
/// Each start allocates a fresh [InboundSession] — ephemeral ports and
/// per-session secrets — so nothing about the local listener surface survives
/// a reconnect or is predictable across devices.
class VpnEngineService implements IVpnEngine {
  final EngineController _engine;

  VpnEngineService({EngineController? engine})
      : _engine = engine ?? EngineController();

  @override
  Future<EngineStartResult> start(
    ProxyProfile profile,
    AppSettings settings,
    InboundMode mode,
  ) async {
    final session = await InboundSessionFactory.allocate(settings, mode);
    final config = SingBoxConfigBuilder.build(
      profile,
      settings,
      mode: mode,
      session: session,
    );
    final error = await _engine.start(config);
    if (error != null) return EngineStartResult.failure(error);

    final sysPort = session.systemProxyPort;
    return EngineStartResult.success(
      systemProxy: sysPort == null ? null : (host: '127.0.0.1', port: sysPort),
    );
  }

  @override
  Future<void> stop() async => _engine.stop();

  @override
  ConnectionStatus status() => ConnectionStatus.fromEngine(_engine.status());

  @override
  String lastError() => _engine.lastError();

  @override
  TrafficSnapshot traffic() {
    final s = _engine.stats();
    return (
      up: s.uplink,
      down: s.downlink,
      upTotal: s.uplinkTotal,
      downTotal: s.downlinkTotal,
    );
  }

  @override
  void setTunFd(int fd) => _engine.setTunFd(fd);
}
