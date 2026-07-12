import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../infrastructure/updates/github_updater_service.dart';

GithubUpdaterService serviceWith({
  required http.Client client,
  String installedVersion = '1.0.0',
}) =>
    GithubUpdaterService(
      client: client,
      currentVersionLoader: () async => installedVersion,
    );

MockClient releaseResponse(String tagName, {String? htmlUrl}) => MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tag_name': tagName,
          'html_url': htmlUrl ??
              'https://github.com/MickleDD/fastflow-client/releases/tag/$tagName',
        }),
        200,
      ),
    );

void main() {
  group('isNewerVersion', () {
    test('detects newer patch / minor / major', () {
      expect(GithubUpdaterService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(GithubUpdaterService.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(GithubUpdaterService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('compares segments numerically, not lexically', () {
      expect(GithubUpdaterService.isNewerVersion('1.10.0', '1.9.9'), isTrue);
      expect(GithubUpdaterService.isNewerVersion('1.9.9', '1.10.0'), isFalse);
    });

    test('equal and older versions are not newer', () {
      expect(GithubUpdaterService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(GithubUpdaterService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('handles missing segments and suffixes', () {
      expect(GithubUpdaterService.isNewerVersion('1.1', '1.0.5'), isTrue);
      expect(GithubUpdaterService.isNewerVersion('1.0.1-beta', '1.0.0'), isTrue);
      expect(GithubUpdaterService.isNewerVersion('1.0.0+7', '1.0.0'), isFalse);
      expect(GithubUpdaterService.isNewerVersion('garbage', '1.0.0'), isFalse);
    });
  });

  group('stripTagPrefix', () {
    test('strips a single leading v of either case', () {
      expect(GithubUpdaterService.stripTagPrefix('v1.0.1'), '1.0.1');
      expect(GithubUpdaterService.stripTagPrefix('V1.0.1'), '1.0.1');
      expect(GithubUpdaterService.stripTagPrefix('1.0.1'), '1.0.1');
    });
  });

  group('checkForUpdates', () {
    test('returns UpdateInfo when the release tag is newer', () async {
      final service = serviceWith(client: releaseResponse('v1.0.1'));
      final update = await service.checkForUpdates();
      expect(update, isNotNull);
      expect(update!.latestVersion, '1.0.1');
      expect(
        update.releaseUrl,
        'https://github.com/MickleDD/fastflow-client/releases/tag/v1.0.1',
      );
    });

    test('returns null when already on the latest version', () async {
      final service = serviceWith(client: releaseResponse('v1.0.0'));
      expect(await service.checkForUpdates(), isNull);
    });

    test('treats 404 (no releases published yet) as up to date', () async {
      final service = serviceWith(
        client: MockClient((_) async => http.Response('{"message":"Not Found"}', 404)),
      );
      expect(await service.checkForUpdates(), isNull);
    });

    test('throws UpdateCheckException on other HTTP errors', () async {
      final service = serviceWith(
        client: MockClient((_) async => http.Response('rate limited', 403)),
      );
      expect(service.checkForUpdates, throwsA(isA<UpdateCheckException>()));
    });

    test('throws UpdateCheckException on malformed payload', () async {
      final service = serviceWith(
        client: MockClient((_) async => http.Response('not json', 200)),
      );
      expect(service.checkForUpdates, throwsA(isA<UpdateCheckException>()));
    });
  });
}
