import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fastflow_vpn/l10n/app_localizations.dart';

import '../../../infrastructure/updates/github_updater_service.dart';
import '../../state/providers.dart';

/// Wraps the home shell and runs one silent update check per app launch,
/// scheduled after the first frame so startup is never blocked. Errors are
/// swallowed here — a user who just opened the app to connect should not be
/// greeted by a network-error popup; the Settings tile surfaces them instead.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSilently());
  }

  Future<void> _checkSilently() async {
    final UpdateInfo? update;
    try {
      update = await ref.read(updaterServiceProvider).checkForUpdates();
    } on UpdateCheckException {
      return;
    }
    if (update != null && mounted) {
      await showUpdateDialog(context, update);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Update prompt shared by the startup check and the manual Settings check.
/// "Update Now" opens the GitHub release page (where the .apk / .exe assets
/// live) in the external browser.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text(l10n.updateAvailableTitle),
      content: Text(l10n.updateAvailableBody(update.latestVersion)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.updateLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            launchUrl(
              Uri.parse(update.releaseUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Text(l10n.updateNow),
        ),
      ],
    ),
  );
}
