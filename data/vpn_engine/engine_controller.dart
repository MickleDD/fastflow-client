import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

// ---- FFI signatures (kept in lockstep with engine_controller.go) -----------
typedef _StartEngineC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> configJson);
typedef _StartEngineDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> configJson);

typedef _VoidC = ffi.Void Function();
typedef _VoidDart = void Function();

typedef _StringGetterC = ffi.Pointer<Utf8> Function();
typedef _StringGetterDart = ffi.Pointer<Utf8> Function();

typedef _SetTunFdC = ffi.Void Function(ffi.Int32 fd);
typedef _SetTunFdDart = void Function(int fd);

typedef _FreeStringC = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(ffi.Pointer<Utf8> ptr);

/// Live throughput snapshot decoded from `GetStats`.
class EngineStats {
  final int uplink; // bytes/sec
  final int downlink; // bytes/sec
  final int uplinkTotal; // bytes
  final int downlinkTotal; // bytes

  const EngineStats({
    this.uplink = 0,
    this.downlink = 0,
    this.uplinkTotal = 0,
    this.downlinkTotal = 0,
  });

  factory EngineStats.fromJson(Map<String, dynamic> j) => EngineStats(
        uplink: (j['uplink'] as num?)?.toInt() ?? 0,
        downlink: (j['downlink'] as num?)?.toInt() ?? 0,
        uplinkTotal: (j['uplinkTotal'] as num?)?.toInt() ?? 0,
        downlinkTotal: (j['downlinkTotal'] as num?)?.toInt() ?? 0,
      );
}

/// Thin, safe wrapper over the Go c-shared engine.
///
/// The one call that can block (StartEngine — it may create the instance, bind
/// the TUN and download rule-sets) is offloaded to a worker isolate. Every other
/// call is fast and runs inline. Because the Go side is a process-global
/// singleton, the isolate re-`dlopen`-ing the same library shares the very same
/// engine state, so stop/status/stats from the main isolate stay coherent.
class EngineController {
  late final ffi.DynamicLibrary _lib;
  late final _VoidDart _stopEngine;
  late final _StringGetterDart _getStatus;
  late final _StringGetterDart _getLastError;
  late final _StringGetterDart _getStats;
  late final _SetTunFdDart _setTunFd;
  late final _FreeStringDart _freeString;

  EngineController() {
    _lib = _open();
    _stopEngine = _lib.lookupFunction<_VoidC, _VoidDart>('StopEngine');
    _getStatus =
        _lib.lookupFunction<_StringGetterC, _StringGetterDart>('GetStatus');
    _getLastError =
        _lib.lookupFunction<_StringGetterC, _StringGetterDart>('GetEngineLastError');
    _getStats =
        _lib.lookupFunction<_StringGetterC, _StringGetterDart>('GetStats');
    _setTunFd = _lib.lookupFunction<_SetTunFdC, _SetTunFdDart>('SetTunFd');
    _freeString =
        _lib.lookupFunction<_FreeStringC, _FreeStringDart>('FreeString');
  }

  static ffi.DynamicLibrary _open() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libvpn_engine.so');
    } else if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('vpn_engine.dll');
    } else if (Platform.isLinux) {
      // Handy for desktop-Linux dev builds of the same core.
      return ffi.DynamicLibrary.open('libvpn_engine.so');
    }
    throw UnsupportedError('Unsupported platform for VPN engine');
  }

  /// Android: hand the engine the VpnService fd before [start]. Pass -1 to clear.
  /// No-op on other platforms.
  void setTunFd(int fd) => _setTunFd(fd);

  /// Starts the engine with the given sing-box config JSON. Returns null on
  /// success or the error message from the core on failure.
  Future<String?> start(String configJson) async {
    // Offload the blocking native call; SetTunFd (if needed) was already set on
    // the shared Go singleton from the main isolate.
    final result = await Isolate.run(() => _StartWorker.run(configJson));
    if (result == 'SUCCESS') return null;
    if (result.startsWith('ERROR: ')) return result.substring('ERROR: '.length);
    return result; // unexpected shape — surface verbatim
  }

  void stop() => _stopEngine();

  /// Raw engine status: stopped | starting | running | stopping | error.
  String status() => _consume(_getStatus());

  String lastError() => _consume(_getLastError());

  EngineStats stats() {
    final raw = _consume(_getStats());
    try {
      return EngineStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const EngineStats();
    }
  }

  /// Reads a Go-owned C string and frees it via the engine's FreeString so the
  /// Go allocator (not Dart's) releases it — matching the ownership contract.
  String _consume(ffi.Pointer<Utf8> ptr) {
    if (ptr == ffi.nullptr) return '';
    try {
      return ptr.toDartString();
    } finally {
      _freeString(ptr);
    }
  }
}

/// Isolate-side helper for [EngineController.start]. Re-opens the library (same
/// process image → same engine) and performs the one blocking call.
class _StartWorker {
  static String run(String configJson) {
    final lib = EngineController._open();
    final startEngine =
        lib.lookupFunction<_StartEngineC, _StartEngineDart>('StartEngine');
    final freeString =
        lib.lookupFunction<_FreeStringC, _FreeStringDart>('FreeString');

    final nativeConfig = configJson.toNativeUtf8();
    try {
      final resultPtr = startEngine(nativeConfig);
      if (resultPtr == ffi.nullptr) return 'ERROR: null result from engine';
      try {
        return resultPtr.toDartString();
      } finally {
        freeString(resultPtr);
      }
    } finally {
      malloc.free(nativeConfig); // Dart-allocated input, freed by Dart.
    }
  }
}
