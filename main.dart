import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fastflow_vpn/l10n/app_localizations.dart';

import 'presentation/state/locale_mgr.dart';
import 'presentation/state/providers.dart';
import 'presentation/ui_android/main_activity_layout.dart';
import 'presentation/ui_shared/components/update_flow.dart';
import 'presentation/ui_windows/main_window_layout.dart';

// NOTE: this project keeps its Clean-Architecture packages at the repo root
// (core/, data/, infrastructure/, presentation/) per the fixed layout, so files
// use relative imports and this entrypoint lives at the root. Build/run with an
// explicit target:  flutter run -t main.dart   /   flutter build <platform> -t main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FastFlowApp()));
}

class FastFlowApp extends ConsumerWidget {
  const FastFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = Colors.indigo;
    // `null` (the "System" choice) lets Flutter resolve the OS locale against
    // supportedLocales; a concrete Locale forces the user's chosen language.
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      // `onGenerateTitle` (not `title`) so the OS-level app title is localized:
      // it runs with a context that sits under the localization delegates.
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: seed,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      // Windows/desktop gets the rail layout; Android (and other mobile) the
      // bottom-nav layout. UpdateGate fires the once-per-launch release check
      // without blocking first paint.
      home: UpdateGate(
        child: Platform.isWindows
            ? const MainWindowLayout()
            : const MainActivityLayout(),
      ),
    );
  }
}

/// Headless boot entrypoint executed by AutoConnectService after a reboot.
///
/// No widgets: it reads persisted settings and, if Always-On / Auto-Connect is
/// enabled and a profile is selected, reconnects using the same use-case the UI
/// uses. The container is intentionally kept alive — the engine must keep running
/// under the AutoConnectService foreground notification.
@pragma('vm:entry-point')
Future<void> vpnBoot() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  try {
    final settingsRepo = container.read(settingsRepositoryProvider);
    final settings = await settingsRepo.load();

    // Re-arm only when the user opted into always-on-style behaviour.
    if (!settings.killSwitch && !settings.autoConnectInsecureWifi) {
      container.dispose();
      return;
    }

    final activeId = await settingsRepo.getActiveProfileId();
    if (activeId == null) {
      container.dispose();
      return;
    }
    final profile = await container.read(profileRepositoryProvider).getById(activeId);
    if (profile == null) {
      container.dispose();
      return;
    }

    await container.read(startVpnUseCaseProvider).execute(profile);
    // Keep [container] alive: disposing it would tear down the engine.
  } catch (_) {
    container.dispose();
  }
}
