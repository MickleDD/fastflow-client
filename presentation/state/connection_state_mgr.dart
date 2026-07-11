import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/models/connection_state.dart';
import '../../core/domain/models/proxy_profile.dart';
import '../../core/domain/models/wifi_state.dart';
import '../../core/domain/repositories/i_vpn_engine.dart';
import '../../core/use_cases/automation/handle_wifi_change.dart';
import '../../core/use_cases/connection/start_vpn_usecase.dart';
import '../../core/use_cases/connection/stop_vpn_usecase.dart';
import 'providers.dart';

/// Owns the live [ConnectionState]: drives connect/disconnect through the
/// use-cases, polls the engine for status + throughput while active, and hosts
/// the insecure-Wi-Fi auto-connect subscription.
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final StartVpnUseCase _start;
  final StopVpnUseCase _stop;
  final IVpnEngine _engine;
  final HandleWifiChangeUseCase _wifi;
  final Stream<WifiState> _wifiStream;

  Timer? _poll;
  StreamSubscription<WifiState>? _wifiSub;

  ConnectionNotifier(
    this._start,
    this._stop,
    this._engine,
    this._wifi,
    this._wifiStream,
  ) : super(const ConnectionState.initial()) {
    _listenWifi();
  }

  Future<void> connect(ProxyProfile profile) async {
    if (state.isBusy) return;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      activeProfileId: profile.id,
      clearMessage: true,
    );

    final result = await _start.execute(profile);
    if (!result.ok) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        message: result.error,
      );
      return;
    }

    state = state.copyWith(
      status: ConnectionStatus.connected,
      since: DateTime.now(),
      uploadBytes: 0,
      downloadBytes: 0,
    );
    _startPolling();
  }

  Future<void> disconnect() async {
    if (state.status == ConnectionStatus.disconnected) return;
    state = state.copyWith(status: ConnectionStatus.disconnecting);
    _stopPolling();
    await _stop.execute();
    state = const ConnectionState.initial();
  }

  Future<void> toggle(ProxyProfile profile) =>
      state.isActive ? disconnect() : connect(profile);

  // ---- polling ------------------------------------------------------------
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final status = _engine.status();
    final t = _engine.traffic();
    state = state.copyWith(
      status: status,
      uploadBytes: t.upTotal,
      downloadBytes: t.downTotal,
      uploadRate: t.up,
      downloadRate: t.down,
    );
    if (status == ConnectionStatus.error) {
      state = state.copyWith(message: _engine.lastError());
      _stopPolling();
    } else if (status == ConnectionStatus.disconnected) {
      _stopPolling();
    }
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  // ---- auto-connect on insecure Wi-Fi -------------------------------------
  void _listenWifi() {
    _wifiSub = _wifiStream.listen((wifi) async {
      final decision = await _wifi.evaluate(wifi);
      if (decision.action == WifiAction.shouldConnect &&
          decision.profile != null) {
        await connect(decision.profile!);
      }
    });
  }

  @override
  void dispose() {
    _stopPolling();
    _wifiSub?.cancel();
    super.dispose();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier(
    ref.watch(startVpnUseCaseProvider),
    ref.watch(stopVpnUseCaseProvider),
    ref.watch(vpnEngineProvider),
    ref.watch(handleWifiChangeUseCaseProvider),
    ref.watch(wifiMonitorProvider).watch(),
  );
});
