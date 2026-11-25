import 'dart:convert';
import 'package:flutter/material.dart';

/// A paired TernaryCode desktop computer (Wi-Fi LAN, Tailscale, Cloudflare, or ngrok).
class PairedHost {
  const PairedHost({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.deviceId,
    this.hostOs = 'Mac',
    this.via = 'Wi-Fi LAN',
    this.online = false,
    this.latencyMs,
    this.paneCount = 0,
    this.lastSeenUnix = 0,
    this.isDemo = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String deviceId;
  final String hostOs;
  final String via;
  final bool online;
  final int? latencyMs;
  final int paneCount;
  final int lastSeenUnix;
  final bool isDemo;

  PairedHost copyWith({
    String? name,
    String? baseUrl,
    String? deviceId,
    String? hostOs,
    String? via,
    bool? online,
    int? latencyMs,
    int? paneCount,
    int? lastSeenUnix,
  }) {
    return PairedHost(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      deviceId: deviceId ?? this.deviceId,
      hostOs: hostOs ?? this.hostOs,
      via: via ?? this.via,
      online: online ?? this.online,
      latencyMs: latencyMs ?? this.latencyMs,
      paneCount: paneCount ?? this.paneCount,
      lastSeenUnix: lastSeenUnix ?? this.lastSeenUnix,
      isDemo: isDemo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'deviceId': deviceId,
        'hostOs': hostOs,
        'via': via,
        'lastSeenUnix': lastSeenUnix,
        'isDemo': isDemo,
      };

  factory PairedHost.fromJson(Map<String, dynamic> json) => PairedHost(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? 'Computer',
        baseUrl: (json['baseUrl'] as String?) ?? '',
        deviceId: (json['deviceId'] as String?) ?? '',
        hostOs: (json['hostOs'] as String?) ?? 'Mac',
        via: (json['via'] as String?) ??
            inferTransport((json['baseUrl'] as String?) ?? ''),
        lastSeenUnix: (json['lastSeenUnix'] as num?)?.toInt() ?? 0,
        isDemo: (json['isDemo'] as bool?) ?? false,
      );

  static String inferTransport(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.ts.net') || lower.contains('://100.')) {
      return 'Tailscale';
    }
    if (lower.contains('trycloudflare') ||
        lower.contains('cloudflare') ||
        (lower.startsWith('https://') && !lower.contains('ngrok'))) {
      return 'Cloudflare';
    }
    if (lower.contains('ngrok')) return 'ngrok';
    return 'Wi-Fi LAN';
  }

  String get lastSeenLabel {
    if (lastSeenUnix <= 0) return 'never';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - lastSeenUnix;
    if (diff < 60) return 'just now';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    if (diff < 86400) return '${diff ~/ 3600}h ago';
    return '${diff ~/ 86400}d ago';
  }
}

/// Discovered TernaryCode desktop on the same Wi-Fi network.
class DiscoveredHost {
  const DiscoveredHost({
    required this.name,
    required this.baseUrl,
    required this.latencyMs,
  });

  final String name;
  final String baseUrl;
  final int latencyMs;
}

/// Parsed QR payload from TernaryCode desktop `Settings -> Phone`.
class ParsedPairingQr {
  const ParsedPairingQr({
    required this.baseUrl,
    required this.code,
    this.hostLabel,
  });

  final String baseUrl;
  final String code;
  final String? hostLabel;

  /// Accepts:
  /// - `http://192.168.1.5:7890/?pair=K7M9-P2X4-Q8R2`
  /// - `https://tc.ilham.dev/?pair=K7M9-P2X4-Q8R2`
  /// - `ternarycode://pair?url=http://192.168.1.5:7890&token=K7M9-P2X4-Q8R2`
  static ParsedPairingQr? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;

    if (uri.scheme == 'ternarycode') {
      final target = uri.queryParameters['url'] ?? '';
      final code =
          uri.queryParameters['pair'] ?? uri.queryParameters['token'] ?? '';
      if (target.isEmpty || code.isEmpty) return null;
      final normalized = normalizeBaseUrl(target);
      if (normalized == null) return null;
      final parsedTarget = Uri.tryParse(normalized);
      return ParsedPairingQr(
        baseUrl: normalized,
        code: code.trim().toUpperCase(),
        hostLabel: parsedTarget?.authority,
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final code =
        uri.queryParameters['pair'] ?? uri.queryParameters['token'] ?? '';
    if (code.trim().length < 4) return null;

    final base = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path == '/' ? '' : uri.path.replaceAll(RegExp(r'/+$'), ''),
    ).toString();

    return ParsedPairingQr(
      baseUrl: base,
      code: code.trim().toUpperCase(),
      hostLabel: uri.authority,
    );
  }

  static String? normalizeBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) {
      s = 'http://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return s.replaceAll(RegExp(r'/+$'), '');
  }
}

/// Persisted mobile app preferences.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.keepAlive = true,
    this.notifInput = true,
    this.notifLimit = true,
    this.notifFailed = true,
    this.haptics = true,
    this.biometric = false,
    this.termFontSize = 11.5,
    this.termWrap = true,
  });

  final ThemeMode themeMode;
  final bool keepAlive;
  final bool notifInput;
  final bool notifLimit;
  final bool notifFailed;
  final bool haptics;
  final bool biometric;
  final double termFontSize;
  final bool termWrap;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? keepAlive,
    bool? notifInput,
    bool? notifLimit,
    bool? notifFailed,
    bool? haptics,
    bool? biometric,
    double? termFontSize,
    bool? termWrap,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      keepAlive: keepAlive ?? this.keepAlive,
      notifInput: notifInput ?? this.notifInput,
      notifLimit: notifLimit ?? this.notifLimit,
      notifFailed: notifFailed ?? this.notifFailed,
      haptics: haptics ?? this.haptics,
      biometric: biometric ?? this.biometric,
      termFontSize: termFontSize ?? this.termFontSize,
      termWrap: termWrap ?? this.termWrap,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': themeMode == ThemeMode.light ? 'light' : 'dark',
        'keepAlive': keepAlive,
        'notifInput': notifInput,
        'notifLimit': notifLimit,
        'notifFailed': notifFailed,
        'haptics': haptics,
        'biometric': biometric,
        'termFontSize': termFontSize,
        'termWrap': termWrap,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: (json['theme'] as String?) == 'light'
            ? ThemeMode.light
            : ThemeMode.dark,
        keepAlive: (json['keepAlive'] as bool?) ?? true,
        notifInput: (json['notifInput'] as bool?) ?? true,
        notifLimit: (json['notifLimit'] as bool?) ?? true,
        notifFailed: (json['notifFailed'] as bool?) ?? true,
        haptics: (json['haptics'] as bool?) ?? true,
        biometric: (json['biometric'] as bool?) ?? false,
        termFontSize: ((json['termFontSize'] as num?)?.toDouble() ?? 11.5)
            .clamp(9.0, 16.0),
        termWrap: (json['termWrap'] as bool?) ?? true,
      );

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return AppSettings.fromJson(map);
    } catch (_) {}
    return const AppSettings();
  }
}
