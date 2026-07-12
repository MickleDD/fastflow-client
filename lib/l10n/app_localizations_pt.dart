import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => 'Início';

  @override
  String get navSettings => 'Configurações';

  @override
  String get newProfile => 'Novo perfil';

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
  String get retry => 'Tentar novamente';

  @override
  String get settingsRouting => 'Roteamento';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / SO';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get killSwitch => 'Interruptor de emergência';

  @override
  String get tunMode => 'Modo TUN';

  @override
  String get importFromClipboard => 'Importar da área de transferência';

  @override
  String get clipboardEmpty => 'A área de transferência está vazia';

  @override
  String get clipboardNoVlessLink => 'Nenhum link vless:// válido na área de transferência';

  @override
  String get importedFromClipboard => 'Importado da área de transferência';

  @override
  String get unnamedProfile => 'Sem nome';

  @override
  String get fieldName => 'Nome';

  @override
  String get fieldServerAddress => 'Endereço do servidor';

  @override
  String get fieldPort => 'Porta';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => 'Senha';

  @override
  String get fieldProtocol => 'Protocolo';

  @override
  String get advancedSettings => 'Configurações avançadas';

  @override
  String get advancedSettingsSubtitle => 'Transporte, MUX, truques de TLS — opcional';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => 'Fluxo';

  @override
  String get fieldTransport => 'Transporte';

  @override
  String get fieldPath => 'Caminho';

  @override
  String get fieldHostHeader => 'Cabeçalho Host';

  @override
  String get fieldGrpcServiceName => 'Nome do serviço gRPC';

  @override
  String get muxTitle => 'Multiplexação (MUX)';

  @override
  String get muxSubtitle => 'Desativado automaticamente com o fluxo Vision';

  @override
  String get muxProtocol => 'Protocolo MUX';

  @override
  String get fieldObfsPassword => 'Senha de ofuscação (salamander) — vazio para desativar';

  @override
  String get fieldUpMbps => 'Upload (Mbps)';

  @override
  String get fieldDownMbps => 'Download (Mbps)';

  @override
  String get tlsEnable => 'Ativar TLS';

  @override
  String get tlsSni => 'SNI / nome do servidor';

  @override
  String get tlsSniHint => 'reutiliza o endereço do servidor se estiver vazio';

  @override
  String get tlsFingerprint => 'Impressão digital uTLS';

  @override
  String get tlsFingerprintHint => 'chrome, firefox, safari, aleatório…';

  @override
  String get tlsSkipCertVerify => 'Ignorar verificação do certificado';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Chave pública do Reality';

  @override
  String get tlsRealityShortId => 'ID curto do Reality';

  @override
  String get tlsTricks => 'Truques de TLS';

  @override
  String get tlsMixedCaseSni => 'SNI com maiúsculas e minúsculas';

  @override
  String get tlsMixedCaseSniSubtitle => 'Aleatoriza as maiúsculas do SNI para evadir listas de bloqueio';

  @override
  String get tlsFragmentation => 'Fragmentação';

  @override
  String get tlsFragmentationSubtitle => 'Divide o ClientHello em segmentos TCP';

  @override
  String get tlsFragmentSize => 'Tamanho do fragmento';

  @override
  String get tlsFragmentDelay => 'Atraso entre fragmentos (ms)';

  @override
  String get tlsPadding => 'Preenchimento';

  @override
  String get tlsPaddingSubtitle => 'Preenche o ClientHello até um comprimento aleatório';

  @override
  String get tlsPaddingSize => 'Tamanho do preenchimento';

  @override
  String get updateAvailableTitle => 'Atualização disponível';

  @override
  String updateAvailableBody(String version) {
    return 'Uma nova versão do FastFlow foi lançada! (v$version)';
  }

  @override
  String get updateNow => 'Atualizar agora';

  @override
  String get updateLater => 'Mais tarde';

  @override
  String get checkForUpdates => 'Verificar atualizações';

  @override
  String get upToDate => 'Você está usando a versão mais recente';

  @override
  String get updateCheckFailed => 'Não foi possível verificar atualizações';
}
