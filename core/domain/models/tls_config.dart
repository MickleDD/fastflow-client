/// TLS fragmentation trick — split the ClientHello across multiple TCP segments
/// to defeat SNI-based DPI. `size`/`delay` are inclusive ranges "min-max".
class FragmentConfig {
  final bool enabled;
  final String size; // e.g. "10-100" (bytes per fragment)
  final String delay; // e.g. "10-20" (ms between fragments)

  const FragmentConfig({
    this.enabled = false,
    this.size = '10-100',
    this.delay = '10-20',
  });

  FragmentConfig copyWith({bool? enabled, String? size, String? delay}) =>
      FragmentConfig(
        enabled: enabled ?? this.enabled,
        size: size ?? this.size,
        delay: delay ?? this.delay,
      );

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'size': size, 'delay': delay};

  factory FragmentConfig.fromJson(Map<String, dynamic> j) => FragmentConfig(
        enabled: j['enabled'] as bool? ?? false,
        size: j['size'] as String? ?? '10-100',
        delay: j['delay'] as String? ?? '10-20',
      );
}

/// TLS record padding trick — pad the ClientHello up to a size in [size] range
/// so its length no longer fingerprints the client.
class PaddingConfig {
  final bool enabled;
  final String size; // e.g. "100-200"

  const PaddingConfig({this.enabled = false, this.size = '100-200'});

  PaddingConfig copyWith({bool? enabled, String? size}) =>
      PaddingConfig(enabled: enabled ?? this.enabled, size: size ?? this.size);

  Map<String, dynamic> toJson() => {'enabled': enabled, 'size': size};

  factory PaddingConfig.fromJson(Map<String, dynamic> j) => PaddingConfig(
        enabled: j['enabled'] as bool? ?? false,
        size: j['size'] as String? ?? '100-200',
      );
}

/// VLESS Reality parameters. When [enabled] the outbound uses Reality instead of
/// ordinary TLS; [publicKey] and [shortId] are handed out by the server.
class RealityConfig {
  final bool enabled;
  final String publicKey;
  final String shortId;

  const RealityConfig({
    this.enabled = false,
    this.publicKey = '',
    this.shortId = '',
  });

  RealityConfig copyWith({bool? enabled, String? publicKey, String? shortId}) =>
      RealityConfig(
        enabled: enabled ?? this.enabled,
        publicKey: publicKey ?? this.publicKey,
        shortId: shortId ?? this.shortId,
      );

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'publicKey': publicKey, 'shortId': shortId};

  factory RealityConfig.fromJson(Map<String, dynamic> j) => RealityConfig(
        enabled: j['enabled'] as bool? ?? false,
        publicKey: j['publicKey'] as String? ?? '',
        shortId: j['shortId'] as String? ?? '',
      );
}

/// Full TLS layer for an outbound, including Reality and the DPI-evasion
/// "TLS tricks" (mixed-case SNI, fragmentation, padding).
class TlsConfig {
  final bool enabled;

  /// SNI / `server_name`. Empty means reuse the server address.
  final String sni;

  final List<String> alpn;

  /// uTLS fingerprint to mimic ("chrome", "firefox", "safari", "randomized"…).
  /// Empty disables uTLS.
  final String utlsFingerprint;

  /// Skip certificate verification. Never enable in production.
  final bool allowInsecure;

  final RealityConfig reality;

  // ---- TLS tricks ---------------------------------------------------------
  /// Randomise the case of the SNI hostname (`gooGLe.CoM`) to slip past
  /// case-sensitive SNI blocklists.
  final bool mixedCaseSni;

  final FragmentConfig fragment;
  final PaddingConfig padding;

  const TlsConfig({
    this.enabled = true,
    this.sni = '',
    this.alpn = const ['h2', 'http/1.1'],
    this.utlsFingerprint = 'chrome',
    this.allowInsecure = false,
    this.reality = const RealityConfig(),
    this.mixedCaseSni = false,
    this.fragment = const FragmentConfig(),
    this.padding = const PaddingConfig(),
  });

  TlsConfig copyWith({
    bool? enabled,
    String? sni,
    List<String>? alpn,
    String? utlsFingerprint,
    bool? allowInsecure,
    RealityConfig? reality,
    bool? mixedCaseSni,
    FragmentConfig? fragment,
    PaddingConfig? padding,
  }) {
    return TlsConfig(
      enabled: enabled ?? this.enabled,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      utlsFingerprint: utlsFingerprint ?? this.utlsFingerprint,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      reality: reality ?? this.reality,
      mixedCaseSni: mixedCaseSni ?? this.mixedCaseSni,
      fragment: fragment ?? this.fragment,
      padding: padding ?? this.padding,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sni': sni,
        'alpn': alpn,
        'utlsFingerprint': utlsFingerprint,
        'allowInsecure': allowInsecure,
        'reality': reality.toJson(),
        'mixedCaseSni': mixedCaseSni,
        'fragment': fragment.toJson(),
        'padding': padding.toJson(),
      };

  factory TlsConfig.fromJson(Map<String, dynamic> j) => TlsConfig(
        enabled: j['enabled'] as bool? ?? true,
        sni: j['sni'] as String? ?? '',
        alpn: (j['alpn'] as List?)?.cast<String>() ?? const ['h2', 'http/1.1'],
        utlsFingerprint: j['utlsFingerprint'] as String? ?? 'chrome',
        allowInsecure: j['allowInsecure'] as bool? ?? false,
        reality: j['reality'] is Map
            ? RealityConfig.fromJson((j['reality'] as Map).cast<String, dynamic>())
            : const RealityConfig(),
        mixedCaseSni: j['mixedCaseSni'] as bool? ?? false,
        fragment: j['fragment'] is Map
            ? FragmentConfig.fromJson((j['fragment'] as Map).cast<String, dynamic>())
            : const FragmentConfig(),
        padding: j['padding'] is Map
            ? PaddingConfig.fromJson((j['padding'] as Map).cast<String, dynamic>())
            : const PaddingConfig(),
      );
}
