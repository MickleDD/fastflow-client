/// TUN networking stack passed to sing-box as `inbound.stack`.
///
/// * [system] — kernel networking stack; fastest, needs full routing privileges.
/// * [gvisor] — user-space netstack; safer, works in more sandboxed contexts.
/// * [mixed]  — system for TCP, gVisor for UDP; a pragmatic default.
enum TunMode {
  system,
  gvisor,
  mixed;

  /// sing-box stack identifier ("system" | "gvisor" | "mixed").
  String get stackValue => name;

  String get label {
    switch (this) {
      case TunMode.system:
        return 'System';
      case TunMode.gvisor:
        return 'gVisor';
      case TunMode.mixed:
        return 'Mixed';
    }
  }

  static TunMode fromStorage(String? value) => TunMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TunMode.mixed,
      );

  String toStorage() => name;
}
