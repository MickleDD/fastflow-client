import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// Application name shown in the OS task switcher and the mobile app bar. Brand name — usually left untranslated.
  ///
  /// In en, this message translates to:
  /// **'FastFlow VPN'**
  String get appTitle;

  /// Label for the Home destination in the bottom navigation bar / navigation rail.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Label for the Settings destination in the bottom navigation bar / navigation rail.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Tooltip on the '+' button that opens the profile editor to create a new proxy profile; also the editor's title in create mode.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// Profile editor app-bar title when editing an existing profile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Label on the connect FAB when the tunnel is disconnected.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Label on the connect FAB when the tunnel is connected.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Label on the connect FAB while the tunnel is establishing a connection.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// Label on the connect FAB while the tunnel is tearing down the connection.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get disconnecting;

  /// Label on the connect FAB after a connection error, prompting the user to try again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Title of the Routing tab in Settings.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get settingsRouting;

  /// Title of the DNS tab in Settings. Acronym — usually left untranslated.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get settingsDns;

  /// Title of the TUN / OS-integration tab in Settings.
  ///
  /// In en, this message translates to:
  /// **'TUN / OS'**
  String get settingsTunOs;

  /// Label for the app language selector in the global settings header.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language-selector option that follows the operating-system locale.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Title of the setting that blocks all non-VPN traffic when the tunnel drops.
  ///
  /// In en, this message translates to:
  /// **'Kill switch'**
  String get killSwitch;

  /// Title of the setting that selects the TUN stack implementation.
  ///
  /// In en, this message translates to:
  /// **'TUN mode'**
  String get tunMode;

  /// Button in the profile editor that fills the form from a vless:// link on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Import from Clipboard'**
  String get importFromClipboard;

  /// Snackbar shown when the user taps import but the clipboard has no text.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// Snackbar shown when the clipboard text is not a parseable vless:// share link.
  ///
  /// In en, this message translates to:
  /// **'No valid vless:// link on the clipboard'**
  String get clipboardNoVlessLink;

  /// Snackbar confirming the form was filled from a clipboard vless:// link.
  ///
  /// In en, this message translates to:
  /// **'Imported from clipboard'**
  String get importedFromClipboard;

  /// Fallback profile name used when the user saves a profile with an empty name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamedProfile;

  /// Text-field label: the profile's display name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// Text-field label: the proxy server host / address.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get fieldServerAddress;

  /// Text-field label: the proxy server port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get fieldPort;

  /// Text-field label: the VLESS user id (UUID). Acronym — usually untranslated.
  ///
  /// In en, this message translates to:
  /// **'UUID'**
  String get fieldUuid;

  /// Text-field label: the Hysteria2 auth password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Dropdown label: the outbound wire protocol (VLESS / Hysteria2).
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get fieldProtocol;

  /// Title of the collapsed section holding power-user knobs in the profile editor.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// Subtitle under the Advanced Settings section header.
  ///
  /// In en, this message translates to:
  /// **'Transport, MUX, TLS tricks — optional'**
  String get advancedSettingsSubtitle;

  /// Header for the TLS block inside Advanced Settings. Acronym — usually untranslated.
  ///
  /// In en, this message translates to:
  /// **'TLS'**
  String get sectionTls;

  /// Dropdown label: XTLS flow control for VLESS.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get fieldFlow;

  /// Dropdown label: the stream transport (tcp / ws / grpc / …).
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get fieldTransport;

  /// Text-field label: ws/http/httpupgrade request path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get fieldPath;

  /// Text-field label: HTTP Host header for ws/http transports.
  ///
  /// In en, this message translates to:
  /// **'Host header'**
  String get fieldHostHeader;

  /// Text-field label: the gRPC transport service name.
  ///
  /// In en, this message translates to:
  /// **'gRPC service name'**
  String get fieldGrpcServiceName;

  /// Switch label: enable connection multiplexing.
  ///
  /// In en, this message translates to:
  /// **'Multiplex (MUX)'**
  String get muxTitle;

  /// Subtitle explaining MUX is incompatible with XTLS Vision flow.
  ///
  /// In en, this message translates to:
  /// **'Disabled automatically with Vision flow'**
  String get muxSubtitle;

  /// Dropdown label: which multiplexing protocol to use (h2mux / smux / yamux).
  ///
  /// In en, this message translates to:
  /// **'MUX protocol'**
  String get muxProtocol;

  /// Text-field label: Hysteria2 salamander obfuscation password; empty disables it.
  ///
  /// In en, this message translates to:
  /// **'Obfs (salamander) password — empty to disable'**
  String get fieldObfsPassword;

  /// Text-field label: Hysteria2 upload bandwidth hint in Mbps.
  ///
  /// In en, this message translates to:
  /// **'Up (Mbps)'**
  String get fieldUpMbps;

  /// Text-field label: Hysteria2 download bandwidth hint in Mbps.
  ///
  /// In en, this message translates to:
  /// **'Down (Mbps)'**
  String get fieldDownMbps;

  /// Switch label: turn the TLS layer on for this profile.
  ///
  /// In en, this message translates to:
  /// **'Enable TLS'**
  String get tlsEnable;

  /// Text-field label: TLS server_name / SNI.
  ///
  /// In en, this message translates to:
  /// **'SNI / server name'**
  String get tlsSni;

  /// Hint under the SNI field: an empty value reuses the server address.
  ///
  /// In en, this message translates to:
  /// **'reuse server address if empty'**
  String get tlsSniHint;

  /// Text-field label: the uTLS ClientHello fingerprint to mimic.
  ///
  /// In en, this message translates to:
  /// **'uTLS fingerprint'**
  String get tlsFingerprint;

  /// Hint listing example uTLS fingerprint values.
  ///
  /// In en, this message translates to:
  /// **'chrome, firefox, safari, randomized…'**
  String get tlsFingerprintHint;

  /// Switch label: allow insecure TLS (do not verify the server certificate).
  ///
  /// In en, this message translates to:
  /// **'Skip certificate verification'**
  String get tlsSkipCertVerify;

  /// Switch label: use the Reality TLS variant. Proper noun — usually untranslated.
  ///
  /// In en, this message translates to:
  /// **'Reality'**
  String get tlsReality;

  /// Text-field label: the Reality public key handed out by the server.
  ///
  /// In en, this message translates to:
  /// **'Reality public key'**
  String get tlsRealityPublicKey;

  /// Text-field label: the Reality short id handed out by the server.
  ///
  /// In en, this message translates to:
  /// **'Reality short id'**
  String get tlsRealityShortId;

  /// Header for the DPI-evasion TLS tricks block.
  ///
  /// In en, this message translates to:
  /// **'TLS Tricks'**
  String get tlsTricks;

  /// Switch label: randomise the letter case of the SNI hostname.
  ///
  /// In en, this message translates to:
  /// **'Mixed-case SNI'**
  String get tlsMixedCaseSni;

  /// Subtitle explaining the mixed-case SNI trick.
  ///
  /// In en, this message translates to:
  /// **'Randomise SNI letter case to evade blocklists'**
  String get tlsMixedCaseSniSubtitle;

  /// Switch label: enable TLS ClientHello fragmentation.
  ///
  /// In en, this message translates to:
  /// **'Fragmentation'**
  String get tlsFragmentation;

  /// Subtitle explaining the fragmentation trick.
  ///
  /// In en, this message translates to:
  /// **'Split the ClientHello across TCP segments'**
  String get tlsFragmentationSubtitle;

  /// Text-field label: fragment size range (bytes).
  ///
  /// In en, this message translates to:
  /// **'Fragment size'**
  String get tlsFragmentSize;

  /// Text-field label: delay between fragments, in milliseconds.
  ///
  /// In en, this message translates to:
  /// **'Fragment delay (ms)'**
  String get tlsFragmentDelay;

  /// Switch label: enable TLS ClientHello padding.
  ///
  /// In en, this message translates to:
  /// **'Padding'**
  String get tlsPadding;

  /// Subtitle explaining the padding trick.
  ///
  /// In en, this message translates to:
  /// **'Pad the ClientHello to a randomised length'**
  String get tlsPaddingSubtitle;

  /// Text-field label: padding size range.
  ///
  /// In en, this message translates to:
  /// **'Padding size'**
  String get tlsPaddingSize;

  /// Title of the dialog shown when a newer GitHub release exists.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// Body of the update dialog; {version} is the latest release version, e.g. 1.0.1.
  ///
  /// In en, this message translates to:
  /// **'A new version of FastFlow is out! (v{version})'**
  String updateAvailableBody(String version);

  /// Update-dialog action that opens the GitHub release page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Update-dialog action that dismisses the dialog without updating.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// Settings list-tile that manually queries GitHub for a newer release.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// Snackbar shown after a manual update check when no newer release exists.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version'**
  String get upToDate;

  /// Snackbar shown when the manual update check fails (offline, rate-limited, …).
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get updateCheckFailed;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'pt', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.scriptCode) {
    case 'Hant': return AppLocalizationsZhHant();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'pt': return AppLocalizationsPt();
    case 'ru': return AppLocalizationsRu();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
