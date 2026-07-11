import 'dart:convert';
import 'dart:math';

/// CSPRNG-backed secrets for the local inbound layer.
///
/// Every secret produced here defends against a *local* attacker: spyware that
/// shares the loopback interface with us (Android VpnService does not isolate
/// 127.0.0.1, and on Windows every same-user process can reach it). Ports and
/// bind addresses only add friction against such an attacker; these credentials
/// are the actual security boundary, so they come from [Random.secure] and are
/// sized far beyond what localhost-speed brute force can cover.
class SecretGenerator {
  SecretGenerator._();

  static final Random _rng = Random.secure();

  /// URL-safe random token with `bytes * 8` bits of entropy (default 256).
  static String token({int bytes = 32}) {
    final raw = List<int>.generate(bytes, (_) => _rng.nextInt(256));
    return base64UrlEncode(raw).replaceAll('=', '');
  }

  /// Username for local proxy auth. Randomised as well, so a port scanner that
  /// does find the inbound cannot even confirm which app owns it.
  static String username() => 'u_${token(bytes: 9)}';

  /// Password for local proxy auth: 128 bits. Shorter than [token] because it
  /// gets copied into tooling configs by hand, still hopeless to brute-force.
  static String password() => token(bytes: 16);
}
