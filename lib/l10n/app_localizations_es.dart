import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get newProfile => 'Nuevo perfil';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get connect => 'Conectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get connecting => 'Conectando…';

  @override
  String get disconnecting => 'Desconectando…';

  @override
  String get retry => 'Reintentar';

  @override
  String get settingsRouting => 'Enrutamiento';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / SO';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get killSwitch => 'Interruptor de emergencia';

  @override
  String get tunMode => 'Modo TUN';

  @override
  String get importFromClipboard => 'Importar del portapapeles';

  @override
  String get clipboardEmpty => 'El portapapeles está vacío';

  @override
  String get clipboardNoVlessLink => 'No hay ningún enlace vless:// válido en el portapapeles';

  @override
  String get importedFromClipboard => 'Importado del portapapeles';

  @override
  String get unnamedProfile => 'Sin nombre';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldServerAddress => 'Dirección del servidor';

  @override
  String get fieldPort => 'Puerto';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get fieldProtocol => 'Protocolo';

  @override
  String get advancedSettings => 'Ajustes avanzados';

  @override
  String get advancedSettingsSubtitle => 'Transporte, MUX, trucos TLS — opcional';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => 'Flujo';

  @override
  String get fieldTransport => 'Transporte';

  @override
  String get fieldPath => 'Ruta';

  @override
  String get fieldHostHeader => 'Cabecera Host';

  @override
  String get fieldGrpcServiceName => 'Nombre del servicio gRPC';

  @override
  String get muxTitle => 'Multiplexación (MUX)';

  @override
  String get muxSubtitle => 'Se desactiva automáticamente con el flujo Vision';

  @override
  String get muxProtocol => 'Protocolo MUX';

  @override
  String get fieldObfsPassword => 'Contraseña de ofuscación (salamander) — vacío para desactivar';

  @override
  String get fieldUpMbps => 'Subida (Mbps)';

  @override
  String get fieldDownMbps => 'Bajada (Mbps)';

  @override
  String get tlsEnable => 'Activar TLS';

  @override
  String get tlsSni => 'SNI / nombre del servidor';

  @override
  String get tlsSniHint => 'se reutiliza la dirección del servidor si está vacío';

  @override
  String get tlsFingerprint => 'Huella uTLS';

  @override
  String get tlsFingerprintHint => 'chrome, firefox, safari, aleatorio…';

  @override
  String get tlsSkipCertVerify => 'Omitir verificación del certificado';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Clave pública de Reality';

  @override
  String get tlsRealityShortId => 'ID corto de Reality';

  @override
  String get tlsTricks => 'Trucos TLS';

  @override
  String get tlsMixedCaseSni => 'SNI con mayúsculas y minúsculas';

  @override
  String get tlsMixedCaseSniSubtitle => 'Aleatoriza las mayúsculas del SNI para evadir listas de bloqueo';

  @override
  String get tlsFragmentation => 'Fragmentación';

  @override
  String get tlsFragmentationSubtitle => 'Divide el ClientHello en segmentos TCP';

  @override
  String get tlsFragmentSize => 'Tamaño de fragmento';

  @override
  String get tlsFragmentDelay => 'Retardo entre fragmentos (ms)';

  @override
  String get tlsPadding => 'Relleno';

  @override
  String get tlsPaddingSubtitle => 'Rellena el ClientHello hasta una longitud aleatoria';

  @override
  String get tlsPaddingSize => 'Tamaño del relleno';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateAvailableBody(String version) {
    return '¡Ya está disponible una nueva versión de FastFlow! (v$version)';
  }

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get upToDate => 'Estás usando la última versión';

  @override
  String get updateCheckFailed => 'No se pudieron buscar actualizaciones';
}
