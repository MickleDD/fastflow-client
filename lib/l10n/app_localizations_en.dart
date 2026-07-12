import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get newProfile => 'New profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connecting => 'Connecting…';

  @override
  String get disconnecting => 'Disconnecting…';

  @override
  String get retry => 'Retry';

  @override
  String get settingsRouting => 'Routing';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / OS';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get killSwitch => 'Kill switch';

  @override
  String get tunMode => 'TUN mode';

  @override
  String get importFromClipboard => 'Import from Clipboard';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get clipboardNoVlessLink => 'No valid vless:// link on the clipboard';

  @override
  String get importedFromClipboard => 'Imported from clipboard';

  @override
  String get unnamedProfile => 'Unnamed';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldServerAddress => 'Server address';

  @override
  String get fieldPort => 'Port';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldProtocol => 'Protocol';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get advancedSettingsSubtitle => 'Transport, MUX, TLS tricks — optional';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => 'Flow';

  @override
  String get fieldTransport => 'Transport';

  @override
  String get fieldPath => 'Path';

  @override
  String get fieldHostHeader => 'Host header';

  @override
  String get fieldGrpcServiceName => 'gRPC service name';

  @override
  String get muxTitle => 'Multiplex (MUX)';

  @override
  String get muxSubtitle => 'Disabled automatically with Vision flow';

  @override
  String get muxProtocol => 'MUX protocol';

  @override
  String get fieldObfsPassword => 'Obfs (salamander) password — empty to disable';

  @override
  String get fieldUpMbps => 'Up (Mbps)';

  @override
  String get fieldDownMbps => 'Down (Mbps)';

  @override
  String get tlsEnable => 'Enable TLS';

  @override
  String get tlsSni => 'SNI / server name';

  @override
  String get tlsSniHint => 'reuse server address if empty';

  @override
  String get tlsFingerprint => 'uTLS fingerprint';

  @override
  String get tlsFingerprintHint => 'chrome, firefox, safari, randomized…';

  @override
  String get tlsSkipCertVerify => 'Skip certificate verification';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Reality public key';

  @override
  String get tlsRealityShortId => 'Reality short id';

  @override
  String get tlsTricks => 'TLS Tricks';

  @override
  String get tlsMixedCaseSni => 'Mixed-case SNI';

  @override
  String get tlsMixedCaseSniSubtitle => 'Randomise SNI letter case to evade blocklists';

  @override
  String get tlsFragmentation => 'Fragmentation';

  @override
  String get tlsFragmentationSubtitle => 'Split the ClientHello across TCP segments';

  @override
  String get tlsFragmentSize => 'Fragment size';

  @override
  String get tlsFragmentDelay => 'Fragment delay (ms)';

  @override
  String get tlsPadding => 'Padding';

  @override
  String get tlsPaddingSubtitle => 'Pad the ClientHello to a randomised length';

  @override
  String get tlsPaddingSize => 'Padding size';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String updateAvailableBody(String version) {
    return 'A new version of FastFlow is out! (v$version)';
  }

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateLater => 'Later';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get upToDate => 'You are using the latest version';

  @override
  String get updateCheckFailed => 'Could not check for updates';
}
