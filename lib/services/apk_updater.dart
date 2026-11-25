import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Metadata for a GitHub Release checked by [ApkUpdater].
class ApkReleaseInfo {
  const ApkReleaseInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseUrl,
    this.releaseNotes = '',
    this.assetName,
    this.apkDownloadUrl,
    this.apkSizeBytes,
    this.checksumsUrl,
    this.matchedAbi,
    this.statusMessage,
  });

  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseUrl;
  final String releaseNotes;
  final String? assetName;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
  final String? checksumsUrl;
  final String? matchedAbi;
  final String? statusMessage;
}

class ApkDownloadProgress {
  const ApkDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.stage,
  });

  final int receivedBytes;
  final int totalBytes;
  final String stage; // 'downloading' | 'verifying' | 'installing'

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

enum ApkInstallOutcome { launched, permissionRequired, unsupported }

class ApkUpdateException implements Exception {
  const ApkUpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Self-updater for sideloaded TernaryCode Android APKs distributed via GitHub Releases.
class ApkUpdater {
  ApkUpdater({
    http.Client? httpClient,
    this.repoSlug = defaultRepoSlug,
    String? apiBaseUrl,
  })  : _client = httpClient ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? 'https://api.github.com';

  static const String defaultRepoSlug = 'ilhamnadhif/ternarycode-mobile';
  static const MethodChannel _channel =
      MethodChannel('dev.ternarycode.mobile/updater');

  final http.Client _client;
  final String repoSlug;
  final String _apiBaseUrl;

  Future<String> getDeviceAbi() async {
    try {
      final abi = await _channel.invokeMethod<String>('getPrimaryAbi');
      if (abi != null && abi.isNotEmpty) return abi;
    } catch (_) {}
    return 'arm64-v8a';
  }

  /// Checks GitHub Releases `/latest` and selects the best APK matching the phone's ABI.
  Future<ApkReleaseInfo> checkForUpdate(
    String currentVersion, {
    String? abiOverride,
  }) async {
    final abi = abiOverride ?? await getDeviceAbi();
    final fallbackUrl = 'https://github.com/$repoSlug/releases';
    final uri = Uri.parse('$_apiBaseUrl/repos/$repoSlug/releases/latest');

    http.Response resp;
    try {
      resp = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'TernaryCode-Mobile-Updater',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return ApkReleaseInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        releaseUrl: fallbackUrl,
        matchedAbi: abi,
        statusMessage: 'Could not reach GitHub — check internet connection.',
      );
    }

    if (resp.statusCode == 404) {
      return ApkReleaseInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        releaseUrl: fallbackUrl,
        matchedAbi: abi,
        statusMessage: 'Up to date · v$currentVersion',
      );
    }

    if (resp.statusCode != 200) {
      return ApkReleaseInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        releaseUrl: fallbackUrl,
        matchedAbi: abi,
        statusMessage: 'Update check failed (HTTP ${resp.statusCode}).',
      );
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      data = decoded;
    } catch (_) {
      return ApkReleaseInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        releaseUrl: fallbackUrl,
        matchedAbi: abi,
        statusMessage: 'Invalid release response from GitHub.',
      );
    }
    final rawTag = (data['tag_name'] as String?) ?? currentVersion;
    final latest = normalizeVersion(rawTag);
    final htmlUrl = (data['html_url'] as String?) ?? fallbackUrl;
    final notes = ((data['body'] as String?) ?? '').trim();
    final assets = ((data['assets'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final picked = pickBestApkAsset(assets, abi);
    String? checksumsUrl;
    for (final a in assets) {
      final name = ((a['name'] as String?) ?? '').toLowerCase();
      if (name.contains('sha256') && name.endsWith('.txt')) {
        checksumsUrl = a['browser_download_url'] as String?;
        break;
      }
    }

    final newer = isNewerVersion(latest, currentVersion);
    return ApkReleaseInfo(
      currentVersion: normalizeVersion(currentVersion),
      latestVersion: latest,
      hasUpdate: newer,
      releaseUrl: htmlUrl,
      releaseNotes: notes,
      assetName: picked?['name'] as String?,
      apkDownloadUrl: picked?['browser_download_url'] as String?,
      apkSizeBytes: (picked?['size'] as num?)?.toInt(),
      checksumsUrl: checksumsUrl,
      matchedAbi: abi,
      statusMessage: newer
          ? 'Update available · v$latest'
          : 'Up to date · v${normalizeVersion(currentVersion)} ($abi)',
    );
  }

  /// Downloads the release APK with streaming progress and optional SHA-256 verification.
  Future<File> downloadAndVerify(
    ApkReleaseInfo release, {
    void Function(ApkDownloadProgress progress)? onProgress,
    Directory? targetDir,
  }) async {
    final url = release.apkDownloadUrl;
    if (url == null || url.isEmpty) {
      throw const ApkUpdateException(
        'No installable APK asset found on this release.',
      );
    }

    final baseDir = targetDir ?? await getTemporaryDirectory();
    final updatesDir = Directory('${baseDir.path}/updates');
    await updatesDir.create(recursive: true);

    // Clean up older cached APKs to keep storage tidy.
    await for (final entity in updatesDir.list()) {
      if (entity is File && entity.path.endsWith('.apk')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }

    final safeName = (release.assetName ?? 'ternarycode-${release.latestVersion}.apk')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${updatesDir.path}/$safeName');

    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = 'TernaryCode-Mobile-Updater';
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(req).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApkUpdateException('Download failed: $e');
    }

    if (streamed.statusCode != 200) {
      throw ApkUpdateException(
        'Download rejected (HTTP ${streamed.statusCode}).',
      );
    }

    final total = streamed.contentLength ?? release.apkSizeBytes ?? 0;
    var received = 0;

    final sink = file.openWrite();
    final digestCapture = _DigestSink();
    final shaSink = sha256.startChunkedConversion(digestCapture);

    try {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        shaSink.add(chunk);
        received += chunk.length;
        onProgress?.call(ApkDownloadProgress(
          receivedBytes: received,
          totalBytes: total,
          stage: 'downloading',
        ));
      }
      await sink.flush();
      await sink.close();
      shaSink.close();
    } catch (e) {
      await sink.close();
      if (await file.exists()) await file.delete();
      throw ApkUpdateException('Download interrupted: $e');
    }

    // Verify SHA-256 checksum if SHA256SUMS.txt is published on the release.
    if (release.checksumsUrl != null && release.assetName != null) {
      onProgress?.call(ApkDownloadProgress(
        receivedBytes: received,
        totalBytes: total,
        stage: 'verifying',
      ));
      final actualHash = digestCapture.digest.toString().toLowerCase();
      final expectedHash = await _fetchExpectedSha256(
        release.checksumsUrl!,
        release.assetName!,
      );
      if (expectedHash == null) {
        if (await file.exists()) await file.delete();
        throw const ApkUpdateException(
          'Could not verify SHA-256 checksum for this APK — please retry.',
        );
      }
      if (expectedHash != actualHash) {
        if (await file.exists()) await file.delete();
        throw const ApkUpdateException(
          'SHA-256 checksum mismatch — download corrupted. Please retry.',
        );
      }
    }

    return file;
  }

  Future<String?> _fetchExpectedSha256(String url, String assetName) async {
    try {
      final resp = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      return parseSha256ForAsset(resp.body, assetName);
    } catch (_) {
      return null;
    }
  }

  /// Launches Android's native PackageInstaller via FileProvider MethodChannel.
  Future<ApkInstallOutcome> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<String>(
        'installApk',
        {'path': filePath},
      );
      if (res == 'permission_required') {
        return ApkInstallOutcome.permissionRequired;
      }
      if (res == 'launched') {
        return ApkInstallOutcome.launched;
      }
      return ApkInstallOutcome.unsupported;
    } on PlatformException catch (e) {
      throw ApkUpdateException(e.message ?? 'Could not launch APK installer.');
    } on MissingPluginException {
      return ApkInstallOutcome.unsupported;
    }
  }

  static Map<String, dynamic>? pickBestApkAsset(
    List<Map<String, dynamic>> assets,
    String abi,
  ) {
    final apks = assets.where((a) {
      final name = ((a['name'] as String?) ?? '').toLowerCase();
      return name.endsWith('.apk');
    }).toList();
    if (apks.isEmpty) return null;

    final lowerAbi = abi.toLowerCase();
    for (final a in apks) {
      final name = ((a['name'] as String?) ?? '').toLowerCase();
      if (name.contains(lowerAbi)) return a;
    }
    // Fallback to universal APK (no arch tag in filename)
    for (final a in apks) {
      final name = ((a['name'] as String?) ?? '').toLowerCase();
      if (!name.contains('arm64') &&
          !name.contains('armeabi') &&
          !name.contains('x86')) {
        return a;
      }
    }
    return apks.first;
  }

  static String? parseSha256ForAsset(String body, String assetName) {
    for (final rawLine in const LineSplitter().convert(body)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hash = parts[0].toLowerCase();
        final file = parts.last.replaceFirst(RegExp(r'^\*'), '');
        if (file == assetName && RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
          return hash;
        }
      }
    }
    return null;
  }

  static String normalizeVersion(String raw) =>
      raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

  static bool isNewerVersion(String remote, String current) {
    List<int> parts(String s) => normalizeVersion(s)
        .split('-')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final r = parts(remote);
    final c = parts(current);
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv != cv) return rv > cv;
    }
    return false;
  }

  void dispose() {
    _client.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;
  Digest get digest => _digest!;

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
