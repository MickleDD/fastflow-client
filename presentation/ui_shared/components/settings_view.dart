import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fastflow_vpn/l10n/app_localizations.dart';

import '../../../infrastructure/updates/github_updater_service.dart';
import '../../state/locale_mgr.dart';
import '../../state/providers.dart';
import '../forms/dns_settings_form.dart';
import '../forms/routing_settings_form.dart';
import '../forms/tun_settings_form.dart';
import 'update_flow.dart';

/// Tabbed container for the app-global settings forms (routing, DNS, TUN/OS),
/// topped by an app-wide language selector. Per-profile TLS tricks live in the
/// profile editor, not here.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const _LanguageSelector(),
          const _CheckForUpdatesTile(),
          TabBar(
            tabs: [
              Tab(text: l10n.settingsRouting),
              Tab(text: l10n.settingsDns),
              Tab(text: l10n.settingsTunOs),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                RoutingSettingsForm(),
                DnsSettingsForm(),
                TunSettingsForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual "Check for updates" entry. Unlike the silent startup check, this one
/// is user-initiated, so every outcome gets feedback: the update dialog, an
/// "up to date" snackbar, or a failure snackbar.
class _CheckForUpdatesTile extends ConsumerStatefulWidget {
  const _CheckForUpdatesTile();

  @override
  ConsumerState<_CheckForUpdatesTile> createState() =>
      _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends ConsumerState<_CheckForUpdatesTile> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final update = await ref.read(updaterServiceProvider).checkForUpdates();
      if (!mounted) return;
      if (update != null) {
        await showUpdateDialog(context, update);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.upToDate)));
      }
    } on UpdateCheckException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.updateCheckFailed)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: Text(l10n.checkForUpdates),
      trailing: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      enabled: !_checking,
      onTap: _check,
    );
  }
}

/// App-wide language switcher: System / English / Русский. The write goes
/// through [setAppLanguage], which persists the choice via the settings
/// pipeline; `MaterialApp` rebuilds into the new locale as soon as it lands.
class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(appLanguageProvider);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.settingsLanguage),
      trailing: DropdownButton<AppLanguage>(
        value: current,
        onChanged: (lang) {
          if (lang != null) setAppLanguage(ref, lang);
        },
        items: [
          for (final lang in AppLanguage.values)
            DropdownMenuItem(
              value: lang,
              // "System" is translated; the language names are endonyms shown
              // the same way in every locale.
              child: Text(
                lang == AppLanguage.system
                    ? l10n.languageSystem
                    : lang.endonym,
              ),
            ),
        ],
      ),
    );
  }
}
