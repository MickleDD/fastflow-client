import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/repositories/i_profile_repository.dart';
import '../../core/domain/repositories/i_settings_repository.dart';
import '../../core/domain/repositories/i_vpn_engine.dart';
import '../../core/domain/repositories/i_vpn_platform.dart';
import '../../core/domain/repositories/i_wifi_monitor.dart';
import '../../core/use_cases/automation/handle_wifi_change.dart';
import '../../core/use_cases/connection/start_vpn_usecase.dart';
import '../../core/use_cases/connection/stop_vpn_usecase.dart';
import '../../core/use_cases/connection/toggle_kill_switch.dart';
import '../../core/use_cases/routing/configure_ipv6.dart';
import '../../core/use_cases/routing/update_balancer.dart';
import '../../data/local_storage/profile_repository_impl.dart';
import '../../data/local_storage/settings_repository_impl.dart';
import '../../data/local_storage/sqlite_database.dart';
import '../../data/vpn_engine/vpn_engine_service.dart';
import '../../infrastructure/network/wifi_monitor_android.dart';
import '../../infrastructure/network/wifi_monitor_windows.dart';
import '../../infrastructure/os_android/android_vpn_service.dart';
import '../../infrastructure/os_windows/windows_vpn_platform.dart';
import '../../infrastructure/updates/github_updater_service.dart';

/// Dependency-injection graph. Everything downstream is wired from these
/// providers so the widget tree only depends on abstractions.

// ---- Infrastructure singletons --------------------------------------------
final appDatabaseProvider = Provider<AppDatabase>((_) => AppDatabase.instance);

final profileRepositoryProvider = Provider<IProfileRepository>((ref) {
  final repo = ProfileRepositoryImpl(ref.watch(appDatabaseProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final settingsRepositoryProvider = Provider<ISettingsRepository>((ref) {
  final repo = SettingsRepositoryImpl(ref.watch(appDatabaseProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final vpnEngineProvider = Provider<IVpnEngine>((_) => VpnEngineService());

final vpnPlatformProvider = Provider<IVpnPlatform>((_) {
  if (Platform.isAndroid) return AndroidVpnPlatform();
  if (Platform.isWindows) return WindowsVpnPlatform();
  throw UnsupportedError('Unsupported platform for VPN');
});

final updaterServiceProvider = Provider<GithubUpdaterService>((ref) {
  final service = GithubUpdaterService();
  ref.onDispose(service.dispose);
  return service;
});

final wifiMonitorProvider = Provider<IWifiMonitor>((ref) {
  final IWifiMonitor monitor =
      Platform.isAndroid ? WifiMonitorAndroid() : WifiMonitorWindows();
  ref.onDispose(monitor.dispose);
  return monitor;
});

// ---- Use-cases ------------------------------------------------------------
final startVpnUseCaseProvider = Provider(
  (ref) => StartVpnUseCase(
    ref.watch(vpnEngineProvider),
    ref.watch(vpnPlatformProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final stopVpnUseCaseProvider = Provider(
  (ref) => StopVpnUseCase(
    ref.watch(vpnEngineProvider),
    ref.watch(vpnPlatformProvider),
  ),
);

final toggleKillSwitchUseCaseProvider = Provider(
  (ref) => ToggleKillSwitchUseCase(
    ref.watch(settingsRepositoryProvider),
    ref.watch(vpnPlatformProvider),
    ref.watch(vpnEngineProvider),
  ),
);

final configureIpv6UseCaseProvider = Provider(
  (ref) => ConfigureIpv6UseCase(ref.watch(settingsRepositoryProvider)),
);

final updateBalancerUseCaseProvider = Provider(
  (ref) => UpdateBalancerUseCase(ref.watch(settingsRepositoryProvider)),
);

final handleWifiChangeUseCaseProvider = Provider(
  (ref) => HandleWifiChangeUseCase(
    ref.watch(settingsRepositoryProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(vpnEngineProvider),
  ),
);
