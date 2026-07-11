import '../enums/inbound_mode.dart';
import '../models/app_settings.dart';
import '../models/connection_state.dart';
import '../models/proxy_profile.dart';

/// Live throughput, in bytes. Domain-level so use-cases don't touch the FFI type.
typedef TrafficSnapshot = ({int up, int down, int upTotal, int downTotal});

/// A local listener endpoint the engine opened for this session.
typedef LocalEndpoint = ({String host, int port});

/// Outcome of an engine start. Because local listen ports are allocated fresh
/// per connection (never persisted), callers that need one — the Windows
/// no-admin fallback pointing the OS proxy at the engine — must take it from
/// here rather than from settings.
class EngineStartResult {
  final String? error;

  /// Loopback endpoint of the system-proxy fallback inbound for this session.
  /// Null in TUN mode or on failure.
  final LocalEndpoint? systemProxy;

  const EngineStartResult.success({this.systemProxy}) : error = null;
  const EngineStartResult.failure(String this.error) : systemProxy = null;

  bool get ok => error == null;
}

/// Domain port over the native VPN engine. The data layer's `VpnEngineService`
/// implements it by building a sing-box config and driving the FFI controller,
/// keeping the use-cases free of any sing-box / FFI knowledge.
abstract interface class IVpnEngine {
  /// Build the config for [profile]+[settings]+[mode] (allocating this
  /// session's ephemeral ports and secrets) and start the core.
  Future<EngineStartResult> start(
    ProxyProfile profile,
    AppSettings settings,
    InboundMode mode,
  );

  Future<void> stop();

  ConnectionStatus status();

  String lastError();

  TrafficSnapshot traffic();

  /// Android only: inject the VpnService fd before [start]. No-op elsewhere.
  void setTunFd(int fd);
}
