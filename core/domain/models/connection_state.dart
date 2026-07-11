/// High-level lifecycle of the tunnel, mirrored from the Go engine's status
/// string plus UI-driven transitional states.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  static ConnectionStatus fromEngine(String s) {
    switch (s) {
      case 'starting':
        return ConnectionStatus.connecting;
      case 'running':
        return ConnectionStatus.connected;
      case 'stopping':
        return ConnectionStatus.disconnecting;
      case 'error':
        return ConnectionStatus.error;
      default:
        return ConnectionStatus.disconnected;
    }
  }
}

/// Immutable snapshot of the connection surfaced to the UI.
class ConnectionState {
  final ConnectionStatus status;
  final String? message;
  final String? activeProfileId;
  final DateTime? since;

  /// Cumulative bytes for the current session.
  final int uploadBytes;
  final int downloadBytes;

  /// Instantaneous rate in bytes/sec.
  final int uploadRate;
  final int downloadRate;

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.message,
    this.activeProfileId,
    this.since,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.uploadRate = 0,
    this.downloadRate = 0,
  });

  const ConnectionState.initial() : this();

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isBusy =>
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.disconnecting;
  bool get isActive => isConnected || isBusy;

  Duration? get uptime =>
      since == null ? null : DateTime.now().difference(since!);

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? message,
    String? activeProfileId,
    DateTime? since,
    int? uploadBytes,
    int? downloadBytes,
    int? uploadRate,
    int? downloadRate,
    bool clearMessage = false,
    bool clearProfile = false,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      activeProfileId:
          clearProfile ? null : (activeProfileId ?? this.activeProfileId),
      since: since ?? this.since,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      uploadRate: uploadRate ?? this.uploadRate,
      downloadRate: downloadRate ?? this.downloadRate,
    );
  }
}
