import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'FastFlow VPN';

  @override
  String get navHome => 'Главная';

  @override
  String get navSettings => 'Настройки';

  @override
  String get newProfile => 'Новый профиль';

  @override
  String get editProfile => 'Изменить профиль';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get connecting => 'Подключение…';

  @override
  String get disconnecting => 'Отключение…';

  @override
  String get retry => 'Повторить';

  @override
  String get settingsRouting => 'Маршрутизация';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsTunOs => 'TUN / ОС';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get killSwitch => 'Аварийное отключение';

  @override
  String get tunMode => 'Режим TUN';

  @override
  String get importFromClipboard => 'Импорт из буфера';

  @override
  String get clipboardEmpty => 'Буфер обмена пуст';

  @override
  String get clipboardNoVlessLink => 'В буфере нет корректной ссылки vless://';

  @override
  String get importedFromClipboard => 'Импортировано из буфера';

  @override
  String get unnamedProfile => 'Без названия';

  @override
  String get fieldName => 'Название';

  @override
  String get fieldServerAddress => 'Адрес сервера';

  @override
  String get fieldPort => 'Порт';

  @override
  String get fieldUuid => 'UUID';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldProtocol => 'Протокол';

  @override
  String get advancedSettings => 'Расширенные настройки';

  @override
  String get advancedSettingsSubtitle => 'Транспорт, MUX, TLS-трюки — необязательно';

  @override
  String get sectionTls => 'TLS';

  @override
  String get fieldFlow => 'Flow';

  @override
  String get fieldTransport => 'Транспорт';

  @override
  String get fieldPath => 'Путь';

  @override
  String get fieldHostHeader => 'Заголовок Host';

  @override
  String get fieldGrpcServiceName => 'Имя gRPC-сервиса';

  @override
  String get muxTitle => 'Мультиплекс (MUX)';

  @override
  String get muxSubtitle => 'Автоматически отключается при Vision flow';

  @override
  String get muxProtocol => 'Протокол MUX';

  @override
  String get fieldObfsPassword => 'Пароль obfs (salamander) — пусто, чтобы отключить';

  @override
  String get fieldUpMbps => 'Исходящий (Мбит/с)';

  @override
  String get fieldDownMbps => 'Входящий (Мбит/с)';

  @override
  String get tlsEnable => 'Включить TLS';

  @override
  String get tlsSni => 'SNI / имя сервера';

  @override
  String get tlsSniHint => 'если пусто — использовать адрес сервера';

  @override
  String get tlsFingerprint => 'Отпечаток uTLS';

  @override
  String get tlsFingerprintHint => 'chrome, firefox, safari, randomized…';

  @override
  String get tlsSkipCertVerify => 'Пропустить проверку сертификата';

  @override
  String get tlsReality => 'Reality';

  @override
  String get tlsRealityPublicKey => 'Публичный ключ Reality';

  @override
  String get tlsRealityShortId => 'Short ID Reality';

  @override
  String get tlsTricks => 'TLS-трюки';

  @override
  String get tlsMixedCaseSni => 'SNI в смешанном регистре';

  @override
  String get tlsMixedCaseSniSubtitle => 'Случайный регистр букв SNI для обхода блокировок';

  @override
  String get tlsFragmentation => 'Фрагментация';

  @override
  String get tlsFragmentationSubtitle => 'Разбивать ClientHello на TCP-сегменты';

  @override
  String get tlsFragmentSize => 'Размер фрагмента';

  @override
  String get tlsFragmentDelay => 'Задержка фрагмента (мс)';

  @override
  String get tlsPadding => 'Заполнение';

  @override
  String get tlsPaddingSubtitle => 'Дополнять ClientHello до случайной длины';

  @override
  String get tlsPaddingSize => 'Размер заполнения';

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateAvailableBody(String version) {
    return 'Вышла новая версия FastFlow! (v$version)';
  }

  @override
  String get updateNow => 'Обновить';

  @override
  String get updateLater => 'Позже';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get upToDate => 'У вас последняя версия';

  @override
  String get updateCheckFailed => 'Не удалось проверить обновления';
}
