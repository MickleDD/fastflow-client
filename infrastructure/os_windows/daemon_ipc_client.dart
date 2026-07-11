import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// JSON-RPC client to the elevated FastFlow helper daemon over a **named pipe**
/// (`\\.\pipe\FastFlowHelper`).
///
/// Privileged Windows operations — creating routes, editing the firewall for the
/// kill switch — require admin. Rather than elevate the whole GUI, an optional
/// helper service runs elevated and exposes a named-pipe command channel. When
/// the GUI is not elevated it forwards privileged requests here; when it is
/// elevated the route manager runs the commands directly and this client is
/// unused.
///
/// The pipe is opened on a dedicated worker isolate that owns the handle and
/// performs blocking `ReadFile`/`WriteFile` via FFI, so the UI isolate never
/// blocks. Requests are serialized (request → single response line), matching
/// the daemon's per-line protocol.
///
/// Wire format: one JSON object per line, `{ "id", "token", "method", "params" }`
/// → `{ "id", "ok", "result"|"error" }`.
class DaemonIpcClient {
  static const String pipeName = r'\\.\pipe\FastFlowHelper';

  final String token;

  DaemonIpcClient({required this.token});

  /// Builds a client using the shared secret the daemon wrote at first run
  /// (`%ProgramData%\FastFlow\daemon.token`). Returns null when the daemon isn't
  /// installed (no token) — callers then fall back to elevated-inline or skip.
  static DaemonIpcClient? fromInstalledToken() {
    try {
      final programData =
          Platform.environment['ProgramData'] ?? r'C:\ProgramData';
      final file = File('$programData\\FastFlow\\daemon.token');
      if (!file.existsSync()) return null;
      final token = file.readAsStringSync().trim();
      if (token.isEmpty) return null;
      return DaemonIpcClient(token: token);
    } catch (_) {
      return null;
    }
  }

  Isolate? _worker;
  SendPort? _commands;
  ReceivePort? _replies;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 1;

  bool get isConnected => _commands != null;

  Future<bool> connect({Duration timeout = const Duration(seconds: 2)}) async {
    if (_commands != null) return true;
    if (!Platform.isWindows) return false;

    final ready = ReceivePort();
    try {
      _worker = await Isolate.spawn(
        _pipeWorker,
        _PipeSetup(ready.sendPort, pipeName),
      );
    } catch (_) {
      ready.close();
      return false;
    }

    final handshake = Completer<SendPort?>();
    late StreamSubscription<dynamic> sub;
    sub = ready.listen((msg) {
      sub.cancel();
      ready.close();
      handshake.complete(msg is SendPort ? msg : null);
    });

    final cmd = await handshake.future.timeout(timeout, onTimeout: () => null);
    if (cmd == null) {
      _teardown(StateError('daemon pipe unavailable'));
      return false;
    }

    _commands = cmd;
    _replies = ReceivePort()..listen(_onReply);
    return true;
  }

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final cmd = _commands;
    final replies = _replies;
    if (cmd == null || replies == null) {
      throw StateError('daemon not connected');
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final line = '${jsonEncode({
          'id': id,
          'token': token,
          'method': method,
          'params': params,
        })}\n';
    cmd.send([id, replies.sendPort, line]);

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('daemon call "$method" timed out');
      },
    );
  }

  // ---- Typed convenience wrappers ----------------------------------------
  Future<void> setKillSwitch(bool enabled, {required String appPath}) =>
      call('killSwitch', {'enabled': enabled, 'appPath': appPath});

  Future<void> addRoute(String cidr, String gateway, {String? ifIndex}) =>
      call('addRoute', {'cidr': cidr, 'gateway': gateway, 'ifIndex': ifIndex});

  Future<void> removeRoute(String cidr) => call('removeRoute', {'cidr': cidr});

  void _onReply(dynamic msg) {
    final m = msg as List;
    final id = m[0] as int;
    final line = m[1] as String?;
    final err = m[2] as String?;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (err != null) {
      completer.completeError(StateError('daemon error: $err'));
      return;
    }
    try {
      final decoded = jsonDecode(line!) as Map<String, dynamic>;
      if (decoded['ok'] == true) {
        completer
            .complete((decoded['result'] as Map?)?.cast<String, dynamic>() ?? {});
      } else {
        completer.completeError(
            StateError('daemon error: ${decoded['error'] ?? 'unknown'}'));
      }
    } catch (_) {
      completer.completeError(StateError('malformed daemon response'));
    }
  }

  void _teardown(Object reason) {
    _commands = null;
    _replies?.close();
    _replies = null;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(reason);
    }
    _pending.clear();
  }

  Future<void> close() async {
    try {
      _commands?.send(const ['close']);
    } catch (_) {}
    _teardown(StateError('daemon disconnected'));
  }
}

// ---- Worker isolate: owns the pipe handle, blocking FFI I/O -----------------

class _PipeSetup {
  final SendPort ready;
  final String pipeName;
  const _PipeSetup(this.ready, this.pipeName);
}

// kernel32 signatures. HANDLE is pointer-sized (IntPtr).
typedef _CreateFileNative = IntPtr Function(Pointer<Utf16> name, Uint32 access,
    Uint32 share, Pointer<Void> sa, Uint32 disp, Uint32 flags, IntPtr template);
typedef _CreateFileDart = int Function(Pointer<Utf16> name, int access,
    int share, Pointer<Void> sa, int disp, int flags, int template);

typedef _RwNative = Int32 Function(IntPtr h, Pointer<Uint8> buf, Uint32 n,
    Pointer<Uint32> done, Pointer<Void> ov);
typedef _RwDart = int Function(
    int h, Pointer<Uint8> buf, int n, Pointer<Uint32> done, Pointer<Void> ov);

typedef _CloseNative = Int32 Function(IntPtr h);
typedef _CloseDart = int Function(int h);

typedef _WaitPipeNative = Int32 Function(Pointer<Utf16> name, Uint32 timeout);
typedef _WaitPipeDart = int Function(Pointer<Utf16> name, int timeout);

void _pipeWorker(_PipeSetup setup) {
  const genericRead = 0x80000000;
  const genericWrite = 0x40000000;
  const openExisting = 3;
  const invalidHandle = -1;
  const waitTimeoutMs = 2000;
  const bufSize = 65536;

  final k32 = DynamicLibrary.open('kernel32.dll');
  final createFile =
      k32.lookupFunction<_CreateFileNative, _CreateFileDart>('CreateFileW');
  final readFile = k32.lookupFunction<_RwNative, _RwDart>('ReadFile');
  final writeFile = k32.lookupFunction<_RwNative, _RwDart>('WriteFile');
  final closeHandle =
      k32.lookupFunction<_CloseNative, _CloseDart>('CloseHandle');
  final waitPipe =
      k32.lookupFunction<_WaitPipeNative, _WaitPipeDart>('WaitNamedPipeW');

  final namePtr = setup.pipeName.toNativeUtf16();
  var handle = invalidHandle;
  for (var attempt = 0; attempt < 3; attempt++) {
    handle = createFile(namePtr, genericRead | genericWrite, 0, nullptr,
        openExisting, 0, 0);
    if (handle != invalidHandle) break;
    if (waitPipe(namePtr, waitTimeoutMs) == 0) break; // no instance appeared
  }
  malloc.free(namePtr);

  if (handle == invalidHandle) {
    setup.ready.send('error');
    return;
  }

  final commands = ReceivePort();
  setup.ready.send(commands.sendPort);

  final readBuf = malloc<Uint8>(bufSize);
  final donePtr = malloc<Uint32>();
  final leftover = <int>[];

  void dispose() {
    malloc.free(readBuf);
    malloc.free(donePtr);
    closeHandle(handle);
    commands.close();
  }

  commands.listen((msg) {
    final m = msg as List;
    if (m.isNotEmpty && m[0] == 'close') {
      dispose();
      return;
    }
    final id = m[0] as int;
    final reply = m[1] as SendPort;
    final line = m[2] as String;

    // Write the request.
    final data = utf8.encode(line);
    final wbuf = malloc<Uint8>(data.length);
    wbuf.asTypedList(data.length).setAll(0, data);
    final wrote = writeFile(handle, wbuf, data.length, donePtr, nullptr);
    malloc.free(wbuf);
    if (wrote == 0) {
      reply.send([id, null, 'pipe write failed']);
      return;
    }

    // Read until we have one complete response line.
    var nl = leftover.indexOf(0x0A);
    while (nl == -1) {
      final ok = readFile(handle, readBuf, bufSize, donePtr, nullptr);
      final got = donePtr.value;
      if (ok == 0 || got == 0) {
        reply.send([id, null, 'pipe closed']);
        return;
      }
      leftover.addAll(readBuf.asTypedList(got));
      nl = leftover.indexOf(0x0A);
    }
    final lineBytes = leftover.sublist(0, nl);
    leftover.removeRange(0, nl + 1);
    reply.send([id, utf8.decode(lineBytes), null]);
  });
}
