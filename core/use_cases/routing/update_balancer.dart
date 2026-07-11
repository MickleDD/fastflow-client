import '../../domain/models/app_settings.dart';
import '../../domain/models/routing_config.dart';
import '../../domain/repositories/i_settings_repository.dart';

/// Update the load-balancing strategy used across proxy members. Applied on the
/// next connect (single-server profiles are unaffected until multiple outbounds
/// are grouped).
class UpdateBalancerUseCase {
  final ISettingsRepository _settingsRepo;

  UpdateBalancerUseCase(this._settingsRepo);

  Future<AppSettings> execute(BalancerStrategy strategy) async {
    final current = await _settingsRepo.load();
    final updated =
        current.copyWith(routing: current.routing.copyWith(balancer: strategy));
    await _settingsRepo.save(updated);
    return updated;
  }
}
