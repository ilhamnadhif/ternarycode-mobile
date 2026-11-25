import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/services/apk_updater.dart';

void main() {
  group('ApkUpdater semver & asset selection', () {
    test('compares semver versions accurately', () {
      expect(ApkUpdater.isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(ApkUpdater.isNewerVersion('0.1.1', '0.1.0+1'), isTrue);
      expect(ApkUpdater.isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(ApkUpdater.isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(ApkUpdater.isNewerVersion('0.0.9', '0.1.0'), isFalse);
    });

    test('selects ABI-matched APK with universal fallback', () {
      final assets = [
        {'name': 'ternarycode-mobile-v0.2.0-armeabi-v7a.apk'},
        {'name': 'ternarycode-mobile-v0.2.0-arm64-v8a.apk'},
        {'name': 'ternarycode-mobile-v0.2.0-universal.apk'},
        {'name': 'SHA256SUMS.txt'},
      ];

      expect(
        ApkUpdater.pickBestApkAsset(assets, 'arm64-v8a')?['name'],
        'ternarycode-mobile-v0.2.0-arm64-v8a.apk',
      );
      expect(
        ApkUpdater.pickBestApkAsset(assets, 'armeabi-v7a')?['name'],
        'ternarycode-mobile-v0.2.0-armeabi-v7a.apk',
      );
      expect(
        ApkUpdater.pickBestApkAsset(assets, 'riscv64')?['name'],
        'ternarycode-mobile-v0.2.0-universal.apk',
      );
    });

    test('parses SHA256SUMS.txt format cleanly', () {
      final digest = sha256.convert(utf8.encode('fake-apk-bytes')).toString();
      final body = '$digest  ternarycode-mobile-v0.2.0-arm64-v8a.apk\n'
          '0000000000000000000000000000000000000000000000000000000000000000  other.apk\n';
      expect(
        ApkUpdater.parseSha256ForAsset(
            body, 'ternarycode-mobile-v0.2.0-arm64-v8a.apk'),
        digest,
      );
      expect(ApkUpdater.parseSha256ForAsset(body, 'missing.apk'), isNull);
    });
  });

  group('ApkUpdater live download & SHA-256 verification', () {
    late HttpServer server;
    late String baseUrl;
    final fakeApkBytes = utf8.encode('PK\x03\x04fake-signed-android-apk-payload');
    late String validSha;
    bool serveCorruptChecksum = false;

    setUp(() async {
      validSha = sha256.convert(fakeApkBytes).toString();
      serveCorruptChecksum = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';

      server.listen((req) async {
        final path = req.uri.path;
        if (path == '/repos/ilhamnadhif/ternarycode-mobile/releases/latest') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'tag_name': 'v0.2.0',
              'html_url': 'https://github.com/ilhamnadhif/ternarycode-mobile/releases/tag/v0.2.0',
              'body': '- Added instant self-updater\n- Improved SSE reconnect',
              'assets': [
                {
                  'name': 'ternarycode-mobile-v0.2.0-arm64-v8a.apk',
                  'size': fakeApkBytes.length,
                  'browser_download_url': '$baseUrl/dl/arm64.apk',
                },
                {
                  'name': 'SHA256SUMS.txt',
                  'browser_download_url': '$baseUrl/dl/SHA256SUMS.txt',
                },
              ],
            }));
          await req.response.close();
          return;
        }
        if (path == '/dl/arm64.apk') {
          req.response
            ..statusCode = 200
            ..contentLength = fakeApkBytes.length
            ..add(fakeApkBytes);
          await req.response.close();
          return;
        }
        if (path == '/dl/SHA256SUMS.txt') {
          final hash = serveCorruptChecksum
              ? 'f' * 64
              : validSha;
          req.response
            ..statusCode = 200
            ..write('$hash  ternarycode-mobile-v0.2.0-arm64-v8a.apk\n');
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('checks release, streams download with progress, and verifies SHA-256',
        () async {
      final updater = ApkUpdater(apiBaseUrl: baseUrl);
      final tmp = await Directory.systemTemp.createTemp('tc_upd_ok_');
      addTearDown(() async {
        updater.dispose();
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final info = await updater.checkForUpdate('0.1.0', abiOverride: 'arm64-v8a');
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '0.2.0');
      expect(info.assetName, 'ternarycode-mobile-v0.2.0-arm64-v8a.apk');
      expect(info.releaseNotes, contains('instant self-updater'));

      final stages = <String>[];
      final apk = await updater.downloadAndVerify(
        info,
        targetDir: tmp,
        onProgress: (p) => stages.add(p.stage),
      );

      expect(await apk.exists(), isTrue);
      expect(await apk.readAsBytes(), fakeApkBytes);
      expect(stages, contains('downloading'));
      expect(stages, contains('verifying'));
    });

    test('rejects and deletes APK when SHA-256 checksum mismatches', () async {
      serveCorruptChecksum = true;
      final updater = ApkUpdater(apiBaseUrl: baseUrl);
      final tmp = await Directory.systemTemp.createTemp('tc_upd_bad_');
      addTearDown(() async {
        updater.dispose();
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final info = await updater.checkForUpdate('0.1.0', abiOverride: 'arm64-v8a');
      await expectLater(
        updater.downloadAndVerify(info, targetDir: tmp),
        throwsA(isA<ApkUpdateException>()),
      );

      final updatesDir = Directory('${tmp.path}/updates');
      final remaining = await updatesDir.list().toList();
      expect(remaining, isEmpty);
    });
  });
}
