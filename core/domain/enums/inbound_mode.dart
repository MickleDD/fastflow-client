/// How local traffic is captured into the tunnel.
enum InboundMode {
  /// Create a TUN adapter and capture all traffic. Android (over the VpnService
  /// fd) and Windows-with-admin.
  tun,

  /// No TUN — expose a mixed SOCKS/HTTP inbound and point the OS system proxy at
  /// it. The Windows "no-admin" fallback.
  systemProxy,
}
