import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Configures the Windows (WinINET) system proxy. This is the engine-independent
/// path for the "no-admin" fallback: when the app can't create a TUN adapter it
/// points the OS proxy at the engine's per-session fallback inbound (the
/// ephemeral port comes from the engine start result, never from settings).
///
/// This manager is the *sole* owner of the proxy registry state — the config
/// builder intentionally does not set sing-box's `set_system_proxy`, so there
/// is exactly one writer and teardown always reverts the OS even if the engine
/// dies without unsetting it.
class WindowsSystemProxyManager {
  static const String _regPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  Future<void> enable({required String host, required int port}) async {
    await _reg('ProxyServer', 'REG_SZ', '$host:$port');
    await _reg('ProxyOverride', 'REG_SZ', '<local>');
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    _notifyWinInet();
  }

  Future<void> disable() async {
    await _reg('ProxyEnable', 'REG_DWORD', '0');
    _notifyWinInet();
  }

  Future<bool> isEnabled() async {
    final r = await Process.run('reg', ['query', _regPath, '/v', 'ProxyEnable']);
    final out = r.stdout.toString();
    return RegExp(r'ProxyEnable\s+REG_DWORD\s+0x1').hasMatch(out);
  }

  Future<void> _reg(String name, String type, String data) async {
    await Process.run(
      'reg',
      ['add', _regPath, '/v', name, '/t', type, '/d', data, '/f'],
    );
  }

  /// Registry edits don't take effect until WinINET is told settings changed.
  /// InternetSetOption(NULL, INTERNET_OPTION_SETTINGS_CHANGED/REFRESH, NULL, 0).
  void _notifyWinInet() {
    const int internetOptionSettingsChanged = 39;
    const int internetOptionRefresh = 37;
    try {
      final wininet = DynamicLibrary.open('wininet.dll');
      final internetSetOption = wininet.lookupFunction<
          Int32 Function(Pointer, Uint32, Pointer, Uint32),
          int Function(Pointer, Uint32, Pointer, Uint32)>('InternetSetOptionW');
      internetSetOption(nullptr, internetOptionSettingsChanged, nullptr, 0);
      internetSetOption(nullptr, internetOptionRefresh, nullptr, 0);
    } catch (_) {
      // wininet unavailable (non-Windows dev host) — registry values still stick.
    }
  }
}
