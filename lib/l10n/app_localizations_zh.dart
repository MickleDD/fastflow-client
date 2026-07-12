import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => '主页';

  @override
  String get navSettings => '设置';

  @override
  String get newProfile => '新建配置';

  @override
  String get editProfile => '编辑配置';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get connecting => '正在连接…';

  @override
  String get disconnecting => '正在断开…';

  @override
  String get retry => '重试';

  @override
  String get settingsRouting => '路由';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / 系统';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get killSwitch => '断网保护';

  @override
  String get tunMode => 'TUN 模式';

  @override
  String get importFromClipboard => '从剪贴板导入';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get clipboardNoVlessLink => '剪贴板中没有有效的 vless:// 链接';

  @override
  String get importedFromClipboard => '已从剪贴板导入';

  @override
  String get unnamedProfile => '未命名';

  @override
  String get fieldName => '名称';

  @override
  String get fieldServerAddress => '服务器地址';

  @override
  String get fieldPort => '端口';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldProtocol => '协议';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get advancedSettingsSubtitle => '传输、MUX、TLS 技巧 — 可选';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => '流控';

  @override
  String get fieldTransport => '传输方式';

  @override
  String get fieldPath => '路径';

  @override
  String get fieldHostHeader => 'Host 头';

  @override
  String get fieldGrpcServiceName => 'gRPC 服务名称';

  @override
  String get muxTitle => '多路复用 (MUX)';

  @override
  String get muxSubtitle => '使用 Vision 流控时自动禁用';

  @override
  String get muxProtocol => 'MUX 协议';

  @override
  String get fieldObfsPassword => '混淆 (salamander) 密码 — 留空则禁用';

  @override
  String get fieldUpMbps => '上行 (Mbps)';

  @override
  String get fieldDownMbps => '下行 (Mbps)';

  @override
  String get tlsEnable => '启用 TLS';

  @override
  String get tlsSni => 'SNI / 服务器名称';

  @override
  String get tlsSniHint => '留空则复用服务器地址';

  @override
  String get tlsFingerprint => 'uTLS 指纹';

  @override
  String get tlsFingerprintHint => 'chrome、firefox、safari、randomized…';

  @override
  String get tlsSkipCertVerify => '跳过证书验证';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Reality 公钥';

  @override
  String get tlsRealityShortId => 'Reality 短 ID';

  @override
  String get tlsTricks => 'TLS 技巧';

  @override
  String get tlsMixedCaseSni => '大小写混合 SNI';

  @override
  String get tlsMixedCaseSniSubtitle => '随机化 SNI 字母大小写以规避封锁列表';

  @override
  String get tlsFragmentation => '分片';

  @override
  String get tlsFragmentationSubtitle => '将 ClientHello 拆分到多个 TCP 分段';

  @override
  String get tlsFragmentSize => '分片大小';

  @override
  String get tlsFragmentDelay => '分片延迟 (ms)';

  @override
  String get tlsPadding => '填充';

  @override
  String get tlsPaddingSubtitle => '将 ClientHello 填充到随机长度';

  @override
  String get tlsPaddingSize => '填充大小';

  @override
  String get updateAvailableTitle => '有可用更新';

  @override
  String updateAvailableBody(String version) {
    return 'FastFlow 有新版本啦！(v$version)';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍后';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get upToDate => '您正在使用最新版本';

  @override
  String get updateCheckFailed => '无法检查更新';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant(): super('zh_Hant');

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => '首頁';

  @override
  String get navSettings => '設定';

  @override
  String get newProfile => '新增設定檔';

  @override
  String get editProfile => '編輯設定檔';

  @override
  String get connect => '連線';

  @override
  String get disconnect => '中斷連線';

  @override
  String get connecting => '正在連線…';

  @override
  String get disconnecting => '正在中斷…';

  @override
  String get retry => '重試';

  @override
  String get settingsRouting => '路由';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / 系統';

  @override
  String get settingsLanguage => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get killSwitch => '斷網保護';

  @override
  String get tunMode => 'TUN 模式';

  @override
  String get importFromClipboard => '從剪貼簿匯入';

  @override
  String get clipboardEmpty => '剪貼簿是空的';

  @override
  String get clipboardNoVlessLink => '剪貼簿中沒有有效的 vless:// 連結';

  @override
  String get importedFromClipboard => '已從剪貼簿匯入';

  @override
  String get unnamedProfile => '未命名';

  @override
  String get fieldName => '名稱';

  @override
  String get fieldServerAddress => '伺服器位址';

  @override
  String get fieldPort => '連接埠';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => '密碼';

  @override
  String get fieldProtocol => '通訊協定';

  @override
  String get advancedSettings => '進階設定';

  @override
  String get advancedSettingsSubtitle => '傳輸、MUX、TLS 技巧 — 選填';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => '流控';

  @override
  String get fieldTransport => '傳輸方式';

  @override
  String get fieldPath => '路徑';

  @override
  String get fieldHostHeader => 'Host 標頭';

  @override
  String get fieldGrpcServiceName => 'gRPC 服務名稱';

  @override
  String get muxTitle => '多工 (MUX)';

  @override
  String get muxSubtitle => '使用 Vision 流控時自動停用';

  @override
  String get muxProtocol => 'MUX 通訊協定';

  @override
  String get fieldObfsPassword => '混淆 (salamander) 密碼 — 留空則停用';

  @override
  String get fieldUpMbps => '上行 (Mbps)';

  @override
  String get fieldDownMbps => '下行 (Mbps)';

  @override
  String get tlsEnable => '啟用 TLS';

  @override
  String get tlsSni => 'SNI / 伺服器名稱';

  @override
  String get tlsSniHint => '留空則沿用伺服器位址';

  @override
  String get tlsFingerprint => 'uTLS 指紋';

  @override
  String get tlsFingerprintHint => 'chrome、firefox、safari、randomized…';

  @override
  String get tlsSkipCertVerify => '略過憑證驗證';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Reality 公鑰';

  @override
  String get tlsRealityShortId => 'Reality 短 ID';

  @override
  String get tlsTricks => 'TLS 技巧';

  @override
  String get tlsMixedCaseSni => '大小寫混合 SNI';

  @override
  String get tlsMixedCaseSniSubtitle => '隨機化 SNI 字母大小寫以規避封鎖清單';

  @override
  String get tlsFragmentation => '分片';

  @override
  String get tlsFragmentationSubtitle => '將 ClientHello 拆分至多個 TCP 分段';

  @override
  String get tlsFragmentSize => '分片大小';

  @override
  String get tlsFragmentDelay => '分片延遲 (ms)';

  @override
  String get tlsPadding => '填充';

  @override
  String get tlsPaddingSubtitle => '將 ClientHello 填充至隨機長度';

  @override
  String get tlsPaddingSize => '填充大小';

  @override
  String get updateAvailableTitle => '有可用更新';

  @override
  String updateAvailableBody(String version) {
    return 'FastFlow 有新版本了！(v$version)';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍後';

  @override
  String get checkForUpdates => '檢查更新';

  @override
  String get upToDate => '您使用的已是最新版本';

  @override
  String get updateCheckFailed => '無法檢查更新';
}
