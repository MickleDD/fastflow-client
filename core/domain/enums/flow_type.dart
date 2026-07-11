/// XTLS flow control. Only meaningful for VLESS over raw TCP or Reality; it must
/// be omitted for multiplexed or WebSocket/gRPC transports.
enum FlowType {
  none,
  xtlsRprxVision;

  /// Value emitted into the sing-box outbound `flow` field. An empty string
  /// signals the builder to omit the key entirely.
  String get singBoxValue {
    switch (this) {
      case FlowType.xtlsRprxVision:
        return 'xtls-rprx-vision';
      case FlowType.none:
        return '';
    }
  }

  String get label {
    switch (this) {
      case FlowType.xtlsRprxVision:
        return 'Vision (xtls-rprx-vision)';
      case FlowType.none:
        return 'None';
    }
  }

  static FlowType fromStorage(String? value) =>
      value == 'xtls-rprx-vision' ? FlowType.xtlsRprxVision : FlowType.none;

  String toStorage() => singBoxValue;
}
