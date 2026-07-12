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
  russian('ru', 'Русский'),
  spanish('es', 'Español'),
  portuguese('pt', 'Português'),
  chineseSimplified('zh', '简体中文'),
  chineseTraditional('zh_Hant', '繁體中文');

  const AppLanguage(this.tag, this.endonym);

  /// Persisted language subtag; empty for [AppLanguage.system]. A `language_Script`
  /// form (e.g. `zh_Hant`) encodes a script subtag — see [locale].
  final String tag;

  /// The language's own name, rendered verbatim regardless of the active locale.
  final String endonym;

  /// Maps a persisted tag back to an option, defaulting to [system] for unknown
  /// or empty tags so a stale/foreign tag can never wedge the UI.
  static AppLanguage fromTag(String tag) =>
      values.firstWhere((l) => l.tag == tag, orElse: () => AppLanguage.system);

  /// `null` for [system] (MaterialApp then follows the OS locale). A `_`-separated
  /// tag becomes a language + script Locale so entries like `zh_Hant` resolve to
  /// `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')` — the exact
  /// shape `flutter gen-l10n` emits into `supportedLocales`. Building `Locale(tag)`
  /// instead would make `zh_Hant` its own bogus languageCode and never match.
  Locale? get locale {
    if (tag.isEmpty) return null;
    final parts = tag.split('_');
    return parts.length == 1
        ? Locale(parts.first)
        : Locale.fromSubtags(languageCode: parts.first, scriptCode: parts[1]);
  }
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
