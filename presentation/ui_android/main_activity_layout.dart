import 'package:fastflow_vpn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/profile_list_mgr.dart';
import '../ui_shared/components/connection_fab.dart';
import '../ui_shared/components/home_view.dart';
import '../ui_shared/components/settings_view.dart';
import '../ui_shared/forms/profile_editor.dart';

/// Android shell: a bottom-navigation Scaffold with Home + Settings and the
/// connect FAB bound to the selected profile.
class MainActivityLayout extends ConsumerStatefulWidget {
  const MainActivityLayout({super.key});

  @override
  ConsumerState<MainActivityLayout> createState() => _MainActivityLayoutState();
}

class _MainActivityLayoutState extends ConsumerState<MainActivityLayout> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedProfileProvider);
    final isHome = _index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (isHome)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.newProfile,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileEditor()),
              ),
            ),
        ],
      ),
      body: isHome ? const HomeView() : const SettingsView(),
      floatingActionButton:
          isHome ? ConnectionFab(profile: selected) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined), label: l10n.navHome),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              label: l10n.navSettings),
        ],
      ),
    );
  }
}
