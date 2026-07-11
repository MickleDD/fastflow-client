import '../../domain/models/app_settings.dart';
import '../../domain/models/routing_config.dart';
import '../../domain/repositories/i_settings_repository.dart';

/// Update the IPv6 handling mode. Takes effect on the next connect; the
/// presentation layer decides whether to prompt for a reconnect when a tunnel is
/// already up (changing the address family live requires rebuilding the config).
class ConfigureIpv6UseCase {
  final ISettingsRepository _settingsRepo;

  ConfigureIpv6UseCase(this._settingsRepo);

  Future<AppSettings> execute(Ipv6Mode mode) async {
    final current = await _settingsRepo.load();
    final updated =
        current.copyWith(routing: current.routing.copyWith(ipv6Mode: mode));
    await _settingsRepo.save(updated);
    return updated;
  }
}
