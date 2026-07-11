import 'dart:ffi';
import 'dart:io';

import 'daemon_ipc_client.dart';

/// Windows routing + kill-switch via the Windows Firewall (`netsh advfirewall`).
///
/// Kill-switch model: set the default outbound policy to *block* and add a single
/// allow rule for the engine executable. Because every tunnelled packet egresses
/// from the engine process, this both permits normal VPN traffic and guarantees
/// that if the engine stops, nothing leaves the machine — a true kill switch.
///
/// These operations require admin. When the GUI isn't elevated they are
/// forwarded to the elevated [DaemonIpcClient]; otherwise they run inline.
class WindowsRouteManager {
  static const String _ruleName = 'FastFlow-Engine-Out';

  final DaemonIpcClient? daemon;

  WindowsRouteManager({this.daemon});

  /// True when the current process has an elevated (admin) token.
  bool isElevated() {
    try {
      final shell32 = DynamicLibrary.open('shell32.dll');
      final isUserAnAdmin = shell32
          .lookupFunction<Int32 Function(), int Function()>('IsUserAnAdmin');
      return isUserAnAdmin() != 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> enableKillSwitch({required String appPath}) async {
    if (!isElevated()) {
      final d = daemon;
      if (d != null && await d.connect()) {
        await d.setKillSwitch(true, appPath: appPath);
      }
      return;
    }
    await _netsh([
      'advfirewall', 'set', 'allprofiles',
      'firewallpolicy', 'blockinbound,blockoutbound',
    ]);
    await _netsh([
      'advfirewall', 'firewall', 'add', 'rule',
      'name=$_ruleName', 'dir=out', 'action=allow',
      'program=$appPath', 'enable=yes',
    ]);
    // Keep loopback working (local inbounds, DNS to the engine).
    await _netsh([
      'advfirewall', 'firewall', 'add', 'rule',
      'name=$_ruleName-Loopback', 'dir=out', 'action=allow',
      'remoteip=127.0.0.1', 'enable=yes',
    ]);
  }

  Future<void> disableKillSwitch({required String appPath}) async {
    if (!isElevated()) {
      final d = daemon;
      if (d != null && await d.connect()) {
        await d.setKillSwitch(false, appPath: appPath);
      }
      return;
    }
    await _netsh([
      'advfirewall', 'set', 'allprofiles',
      'firewallpolicy', 'blockinbound,allowoutbound',
    ]);
    await _netsh(['advfirewall', 'firewall', 'delete', 'rule', 'name=$_ruleName']);
    await _netsh([
      'advfirewall', 'firewall', 'delete', 'rule', 'name=$_ruleName-Loopback',
    ]);
  }

  Future<void> addRoute(String cidr, String gateway) async {
    if (!isElevated()) {
      final d = daemon;
      if (d != null && await d.connect()) await d.addRoute(cidr, gateway);
      return;
    }
    final parts = cidr.split('/');
    if (parts.length != 2) throw ArgumentError('invalid cidr $cidr');
    final addr = InternetAddress.tryParse(parts.first);
    final prefix = int.tryParse(parts.last);
    if (addr == null ||
        addr.type != InternetAddressType.IPv4 ||
        prefix == null ||
        prefix < 0 ||
        prefix > 32) {
      throw ArgumentError('invalid cidr $cidr');
    }
    final gw = InternetAddress.tryParse(gateway);
    if (gw == null || gw.type != InternetAddressType.IPv4) {
      throw ArgumentError('invalid gateway $gateway');
    }
    await Process.run(_system32('route.exe'),
        ['ADD', addr.address, 'MASK', _maskFromPrefix(prefix), gw.address]);
  }

  Future<void> removeRoute(String cidr) async {
    if (!isElevated()) {
      final d = daemon;
      if (d != null && await d.connect()) await d.removeRoute(cidr);
      return;
    }
    final addr = InternetAddress.tryParse(cidr.split('/').first);
    if (addr == null || addr.type != InternetAddressType.IPv4) {
      throw ArgumentError('invalid cidr $cidr');
    }
    await Process.run(_system32('route.exe'), ['DELETE', addr.address]);
  }

  Future<void> _netsh(List<String> args) =>
      Process.run(_system32('netsh.exe'), args);

  /// Absolute path to a Windows system tool. Invoking `netsh`/`route` by bare
  /// name would resolve through PATH, letting a writable PATH entry shadow them
  /// with a trojan that this (potentially elevated) process would execute.
  static String _system32(String tool) {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return '$root\\System32\\$tool';
  }

  static String _maskFromPrefix(int prefix) {
    final mask = prefix == 0 ? 0 : (0xffffffff << (32 - prefix)) & 0xffffffff;
    return '${(mask >> 24) & 0xff}.${(mask >> 16) & 0xff}.'
        '${(mask >> 8) & 0xff}.${mask & 0xff}';
  }
}
