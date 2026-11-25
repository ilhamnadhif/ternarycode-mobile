import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/host_models.dart';

/// Persistence contract storing sensitive bearer tokens separately in Android Keystore.
abstract class StorageBackend {
  Future<List<PairedHost>> loadHosts();
  Future<void> saveHosts(List<PairedHost> hosts);
  Future<String?> loadActiveHostId();
  Future<void> saveActiveHostId(String? hostId);
  Future<String?> readToken(String hostId);
  Future<void> writeToken(String hostId, String token);
  Future<void> deleteToken(String hostId);
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

/// Production Android storage using Keystore-backed [FlutterSecureStorage] for
/// device tokens and [SharedPreferences] for host metadata & UI preferences.
class DeviceStorageService implements StorageBackend {
  DeviceStorageService()
      : _secure = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _secure;
  static const _hostsKey = 'tc_hosts_v1';
  static const _activeHostKey = 'tc_active_host_v1';
  static const _settingsKey = 'tc_settings_v1';

  @override
  Future<List<PairedHost>> loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hostsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PairedHost.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveHosts(List<PairedHost> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _hostsKey,
      jsonEncode(hosts.map((h) => h.toJson()).toList()),
    );
  }

  @override
  Future<String?> loadActiveHostId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeHostKey);
  }

  @override
  Future<void> saveActiveHostId(String? hostId) async {
    final prefs = await SharedPreferences.getInstance();
    if (hostId == null || hostId.isEmpty) {
      await prefs.remove(_activeHostKey);
    } else {
      await prefs.setString(_activeHostKey, hostId);
    }
  }

  @override
  Future<String?> readToken(String hostId) =>
      _secure.read(key: 'tc_token_$hostId');

  @override
  Future<void> writeToken(String hostId, String token) =>
      _secure.write(key: 'tc_token_$hostId', value: token);

  @override
  Future<void> deleteToken(String hostId) =>
      _secure.delete(key: 'tc_token_$hostId');

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings.decode(prefs.getString(_settingsKey));
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, settings.encode());
  }
}

/// Deterministic in-memory storage for unit and widget tests.
class InMemoryStorageService implements StorageBackend {
  List<PairedHost> _hosts = [];
  String? _activeHostId;
  final Map<String, String> _tokens = {};
  AppSettings _settings = const AppSettings();

  @override
  Future<List<PairedHost>> loadHosts() async => List.of(_hosts);

  @override
  Future<void> saveHosts(List<PairedHost> hosts) async {
    _hosts = List.of(hosts);
  }

  @override
  Future<String?> loadActiveHostId() async => _activeHostId;

  @override
  Future<void> saveActiveHostId(String? hostId) async {
    _activeHostId = hostId;
  }

  @override
  Future<String?> readToken(String hostId) async => _tokens[hostId];

  @override
  Future<void> writeToken(String hostId, String token) async {
    _tokens[hostId] = token;
  }

  @override
  Future<void> deleteToken(String hostId) async {
    _tokens.remove(hostId);
  }

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}
