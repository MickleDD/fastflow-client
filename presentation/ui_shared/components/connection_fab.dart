import 'package:fastflow_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/connection_state.dart';
import '../../../core/domain/models/proxy_profile.dart';
import '../../state/connection_state_mgr.dart';

/// Primary connect/disconnect control. Reflects the live [ConnectionState] and
/// toggles the tunnel for the given [profile].
class ConnectionFab extends ConsumerWidget {
  final ProxyProfile? profile;

  const ConnectionFab({super.key, this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conn = ref.watch(connectionProvider);
    final notifier = ref.read(connectionProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color bg, String label) = switch (conn.status) {
      ConnectionStatus.connected => (Icons.stop, scheme.error, l10n.disconnect),
      ConnectionStatus.connecting => (Icons.hourglass_top, scheme.secondary, l10n.connecting),
      ConnectionStatus.disconnecting => (Icons.hourglass_bottom, scheme.secondary, l10n.disconnecting),
      ConnectionStatus.error => (Icons.error_outline, scheme.error, l10n.retry),
      ConnectionStatus.disconnected => (Icons.power_settings_new, scheme.primary, l10n.connect),
    };

    final canPress = profile != null && !conn.isBusy;

    return FloatingActionButton.extended(
      backgroundColor: bg,
      onPressed: canPress ? () => notifier.toggle(profile!) : null,
      icon: conn.isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
