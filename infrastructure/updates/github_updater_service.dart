import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// A newer published release on GitHub.
class UpdateInfo {
  const UpdateInfo({required this.latestVersion, required this.releaseUrl});

  /// Latest release version with any leading "v" stripped, e.g. "1.0.1".
  final String latestVersion;

  /// The release's `html_url` — the page holding the .apk / .exe assets.
  final String releaseUrl;
}

/// Thrown when the update check could not produce an answer (network down,
/// rate-limited, malformed payload). Callers decide whether to surface it:
/// the silent startup check swallows it, the manual settings check shows it.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);
  final String message;

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// Checks GitHub Releases of the public distribution repo for a version newer
/// than the running build.
class GithubUpdaterService {
  GithubUpdaterService({
    http.Client? client,
    Future<String> Function()? currentVersionLoader,
  })  : _client = client ?? http.Client(),
        _currentVersionLoader = currentVersionLoader ?? _installedVersion;

  static const _owner = 'MickleDD';
  static const _repo = 'fastflow-client';
  static final _latestReleaseUri =
      Uri.https('api.github.com', '/repos/$_owner/$_repo/releases/latest');

  final http.Client _client;
  final Future<String> Function() _currentVersionLoader;

  /// `PackageInfo.version` is the semver part of pubspec's `version:` field
  /// (build metadata after "+" already excluded).
  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Returns the newer release if one exists, or `null` when this build is
  /// already the latest. A repo with no published releases yet (HTTP 404)
  /// counts as up to date, not as an error.
  Future<UpdateInfo?> checkForUpdates() async {
    final http.Response response;
    try {
      response = await _client.get(_latestReleaseUri, headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      throw UpdateCheckException('Request failed: $e');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw UpdateCheckException('GitHub API returned ${response.statusCode}');
    }

    final String tagName;
    final String htmlUrl;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      tagName = body['tag_name'] as String;
      htmlUrl = body['html_url'] as String;
    } catch (e) {
      throw UpdateCheckException('Malformed release payload: $e');
    }

    final latest = stripTagPrefix(tagName);
    final current = await _currentVersionLoader();
    if (!isNewerVersion(latest, current)) return null;
    return UpdateInfo(latestVersion: latest, releaseUrl: htmlUrl);
  }

  /// "v1.0.1" -> "1.0.1"; tags without the prefix pass through unchanged.
  static String stripTagPrefix(String tag) =>
      tag.trim().replaceFirst(RegExp(r'^[vV]'), '');

  /// Numeric dot-segment comparison ("1.10.0" > "1.9.9"). Pre-release /
  /// build suffixes ("-beta", "+5") are ignored; unparseable segments count
  /// as 0, so a malformed tag can never nag users about a fake update.
  static bool isNewerVersion(String candidate, String current) {
    List<int> parse(String v) => v
        .split(RegExp(r'[-+]'))
        .first
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();

    final a = parse(candidate);
    final b = parse(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai > bi;
    }
    return false;
  }

  void dispose() => _client.close();
}
