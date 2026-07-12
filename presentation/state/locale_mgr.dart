import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_mgr.dart';

/// UI languages the switcher offers, in menu order. Declared once here so the
/// settings dropdown and [localeProvider] can never drift apart.
///
/// [AppLanguage.system] carries an empty [tag], which means "follow the OS
/// locale". The other entries are shown by their [endonym] (the language's own
/// name), which is intentionally identical in every locale.
enum AppLanguage {
  system('', 'System'),
  english('en', 'English'),
  russian('ru', 'Русский');

  const AppLanguage(this.tag, this.endonym);

  /// Persisted language subtag; empty for [AppLanguage.system].
  final String tag;

  /// The language's own name, rendered verbatim regardless of the active locale.
  final String endonym;

  /// Maps a persisted tag back to an option, defaulting to [system] for unknown
  /// or empty tags so a stale/foreign tag can never wedge the UI.
  static AppLanguage fromTag(String tag) =>
      values.firstWhere((l) => l.tag == tag, orElse: () => AppLanguage.system);

  /// `null` for [system] (MaterialApp then follows the OS locale).
  Locale? get locale => tag.isEmpty ? null : Locale(tag);
}

/// The app's active [Locale] — the read side of the language state manager.
///
/// Derived from the persisted `localeTag` on [settingsProvider], so it
/// recomputes whenever settings change and is restored on the next launch. A
/// `null` value tells `MaterialApp` to resolve the system locale against
/// `supportedLocales`. Bound to `MaterialApp.locale` in `main.dart`.
final localeProvider = Provider<Locale?>((ref) {
  final tag = ref.watch(settingsProvider.select((s) => s.localeTag));
  return AppLanguage.fromTag(tag).locale;
});

/// The currently selected option, for driving the settings dropdown value.
final appLanguageProvider = Provider<AppLanguage>((ref) {
  final tag = ref.watch(settingsProvider.select((s) => s.localeTag));
  return AppLanguage.fromTag(tag);
});

/// Write side: persist a new UI language through the existing settings pipeline.
/// Passing [AppLanguage.system] clears the override.
Future<void> setAppLanguage(WidgetRef ref, AppLanguage language) {
  return ref
      .read(settingsProvider.notifier)
      .patch((s) => s.copyWith(localeTag: language.tag));
}
