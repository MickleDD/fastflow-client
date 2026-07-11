import 'package:fastflow_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/profile_list_mgr.dart';
import '../ui_shared/components/connection_fab.dart';
import '../ui_shared/components/home_view.dart';
import '../ui_shared/components/settings_view.dart';
import '../ui_shared/forms/profile_editor.dart';

/// Windows/desktop shell: a NavigationRail beside the content pane. Home carries
/// the connect FAB bound to the selected profile.
class MainWindowLayout extends ConsumerStatefulWidget {
  const MainWindowLayout({super.key});

  @override
  ConsumerState<MainWindowLayout> createState() => _MainWindowLayoutState();
}

class _MainWindowLayoutState extends ConsumerState<MainWindowLayout> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedProfileProvider);
    final isHome = _index == 0;

    return Scaffold(
      floatingActionButton:
          isHome ? ConnectionFab(profile: selected) : null,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: IconButton(
                tooltip: l10n.newProfile,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileEditor()),
                ),
              ),
            ),
            destinations: [
              NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l10n.navHome)),
              NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(l10n.navSettings)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: isHome ? const HomeView() : const SettingsView(),
          ),
        ],
      ),
    );
  }
}
