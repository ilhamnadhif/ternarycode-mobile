import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/companion_models.dart';
import '../models/host_models.dart';

class CompanionApiException implements Exception {
  const CompanionApiException(
    this.message, {
    this.statusCode,
    this.isUnauthorized = false,
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;
  final bool isUnauthorized;
  final bool isNetwork;

  @override
  String toString() => message;
}

class PairResult {
  const PairResult({
    required this.deviceId,
    required this.deviceToken,
  });

  final String deviceId;
  final String deviceToken;
}

class StateFetchResult {
  const StateFetchResult({
    required this.snapshot,
    required this.latencyMs,
  });

  final CompanionSnapshot snapshot;
  final int latencyMs;
}

/// Real HTTP + SSE client implementing the desktop `src/companion.rs` protocol.
class CompanionApi {
  CompanionApi({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);

  String _cleanBase(String baseUrl) =>
      baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<PairResult> pair({
    required String baseUrl,
    required String code,
    required String deviceName,
  }) async {
    final uri = Uri.parse('${_cleanBase(baseUrl)}/api/pair');
    http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': code.trim(),
              'device_name': deviceName.trim().isEmpty
                  ? 'Android Phone'
                  : deviceName.trim(),
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CompanionApiException(
        'Connection timed out — check the host address and Wi-Fi/tunnel.',
        isNetwork: true,
      );
    } catch (e) {
      throw CompanionApiException(
        'Could not reach host: $e',
        isNetwork: true,
      );
    }

    if (resp.statusCode == 200) {
      final data = _decodeJsonMap(resp.body, 'Malformed pairing response from host.');
      final id = (data['device_id'] as String?) ?? '';
      final tok = (data['device_token'] as String?) ?? '';
      if (id.isEmpty || tok.isEmpty) {
        throw const CompanionApiException('Malformed pairing response from host.');
      }
      return PairResult(deviceId: id, deviceToken: tok);
    }

    final err = _extractError(resp.body);
    if (resp.statusCode == 403) {
      throw CompanionApiException(
        err ?? 'Invalid or expired pairing code — check Settings → Phone.',
        statusCode: 403,
      );
    }
    if (resp.statusCode == 429) {
      throw CompanionApiException(
        err ?? 'Too many pairing attempts. Wait a minute and try again.',
        statusCode: 429,
      );
    }
    throw CompanionApiException(
      err ?? 'Pairing failed (HTTP ${resp.statusCode}).',
      statusCode: resp.statusCode,
    );
  }

  Future<StateFetchResult> fetchState({
    required String baseUrl,
    required String token,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${_cleanBase(baseUrl)}/api/state');
    final sw = Stopwatch()..start();
    http.Response resp;
    try {
      resp = await _client
          .get(uri, headers: _authHeaders(token))
          .timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw const CompanionApiException('Host timed out', isNetwork: true);
    } catch (e) {
      throw CompanionApiException('Host unreachable: $e', isNetwork: true);
    }
    sw.stop();

    if (resp.statusCode == 401) {
      throw const CompanionApiException(
        'Device token was revoked on desktop. Pair again.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    if (resp.statusCode != 200) {
      throw CompanionApiException(
        _extractError(resp.body) ?? 'State fetch failed (HTTP ${resp.statusCode}).',
        statusCode: resp.statusCode,
      );
    }

    final trimmed = resp.body.trim();
    if (trimmed.isEmpty || trimmed == '{}') {
      return StateFetchResult(
        snapshot: const CompanionSnapshot(),
        latencyMs: sw.elapsedMilliseconds,
      );
    }
    final map = _decodeJsonMap(trimmed, 'Unexpected non-JSON response from host.');
    return StateFetchResult(
      snapshot: CompanionSnapshot.fromJson(map),
      latencyMs: sw.elapsedMilliseconds,
    );
  }

  /// Opens a persistent real-time stream:
  /// - Uses hibernatable WebSocket (`GET /api/ws`) when connected through a
  ///   TernaryCode Cloudflare Relay (`/r/<hostId>`) so idle connections consume
  ///   zero Durable Object compute duration.
  /// - Uses Server-Sent Events (`GET /api/events`) on local Wi-Fi LAN / custom tunnels.
  Stream<CompanionSnapshot> subscribeEvents({
    required String baseUrl,
    required String token,
    void Function()? onKeepAlive,
    Duration watchdogTimeout = const Duration(seconds: 35),
  }) {
    if (PairedHost.isCloudflareRelayUrl(baseUrl)) {
      return subscribeRelayWebSocket(
        baseUrl: baseUrl,
        token: token,
        onKeepAlive: onKeepAlive,
        watchdogTimeout: watchdogTimeout,
      );
    }
    late StreamController<CompanionSnapshot> controller;
    HttpClient? ioClient;
    StreamSubscription<String>? lineSub;
    Timer? watchdog;
    var closed = false;

    void cleanup() {
      closed = true;
      watchdog?.cancel();
      watchdog = null;
      lineSub?.cancel();
      lineSub = null;
      ioClient?.close(force: true);
      ioClient = null;
    }

    void bumpWatchdog() {
      if (closed || watchdogTimeout <= Duration.zero) return;
      watchdog?.cancel();
      watchdog = Timer(watchdogTimeout, () {
        if (!closed) {
          controller.addError(
            const CompanionApiException(
              'Event stream stalled (no keepalive)',
              isNetwork: true,
            ),
          );
          controller.close();
          cleanup();
        }
      });
    }

    controller = StreamController<CompanionSnapshot>(
      onListen: () async {
        ioClient = HttpClient()
          ..connectionTimeout = _timeout
          ..autoUncompress = false;
        try {
          final uri = Uri.parse('${_cleanBase(baseUrl)}/api/events');
          final req = await ioClient!.getUrl(uri);
          req.bufferOutput = false;
          req.headers.set('Authorization', 'Bearer $token');
          req.headers.set('Accept', 'text/event-stream');
          req.headers.set('Cache-Control', 'no-cache');
          req.headers.set('Connection', 'keep-alive');
          final resp = await req.close().timeout(_timeout);

          if (resp.statusCode == 401) {
            if (!closed) {
              controller.addError(const CompanionApiException(
                'Device was revoked on desktop.',
                statusCode: 401,
                isUnauthorized: true,
              ));
              await controller.close();
            }
            cleanup();
            return;
          }
          if (resp.statusCode != 200) {
            if (!closed) {
              controller.addError(CompanionApiException(
                'Event stream rejected (HTTP ${resp.statusCode})',
                statusCode: resp.statusCode,
              ));
              await controller.close();
            }
            cleanup();
            return;
          }

          bumpWatchdog();
          lineSub = resp
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())
              .listen(
            (line) {
              if (closed) return;
              bumpWatchdog();
              if (line.startsWith(':')) {
                onKeepAlive?.call();
                return;
              }
              if (line.startsWith('data:')) {
                final payload = line.substring(5).trim();
                if (payload.isEmpty || payload == '{}') return;
                try {
                  final map = jsonDecode(payload);
                  if (map is Map<String, dynamic>) {
                    controller.add(CompanionSnapshot.fromJson(map));
                  }
                } catch (_) {
                  // Ignore malformed frames cleanly.
                }
              }
            },
            onError: (Object err, StackTrace st) {
              if (!closed) {
                controller.addError(
                  CompanionApiException('Stream dropped: $err', isNetwork: true),
                  st,
                );
                controller.close();
              }
              cleanup();
            },
            onDone: () {
              if (!closed) controller.close();
              cleanup();
            },
            cancelOnError: true,
          );
        } catch (e) {
          if (!closed) {
            controller.addError(
              CompanionApiException('Unable to open event stream: $e',
                  isNetwork: true),
            );
            await controller.close();
          }
          cleanup();
        }
      },
      onCancel: cleanup,
    );

    return controller.stream;
  }

  /// Opens a hibernatable WebSocket stream (`wss://<relay>/r/<hostId>/api/ws`)
  /// with zero-cost text `"ping"` / `"pong"` keepalives and instant `4401`
  /// revocation detection.
  Stream<CompanionSnapshot> subscribeRelayWebSocket({
    required String baseUrl,
    required String token,
    void Function()? onKeepAlive,
    Duration watchdogTimeout = const Duration(seconds: 65),
  }) {
    late StreamController<CompanionSnapshot> controller;
    WebSocket? socket;
    StreamSubscription<dynamic>? sub;
    Timer? pingTimer;
    Timer? watchdog;
    var closed = false;

    void cleanup() {
      closed = true;
      pingTimer?.cancel();
      pingTimer = null;
      watchdog?.cancel();
      watchdog = null;
      sub?.cancel();
      sub = null;
      try {
        socket?.close();
      } catch (_) {}
      socket = null;
    }

    void bumpWatchdog() {
      if (closed || watchdogTimeout <= Duration.zero) return;
      watchdog?.cancel();
      watchdog = Timer(watchdogTimeout, () {
        if (!closed) {
          controller.addError(
            const CompanionApiException(
              'Relay stream stalled (no heartbeat)',
              isNetwork: true,
            ),
          );
          controller.close();
          cleanup();
        }
      });
    }

    controller = StreamController<CompanionSnapshot>(
      onListen: () async {
        try {
          final clean = _cleanBase(baseUrl);
          final wsBase = clean.startsWith('https://')
              ? 'wss://${clean.substring(8)}'
              : clean.startsWith('http://')
                  ? 'ws://${clean.substring(7)}'
                  : 'wss://$clean';
          final wsUri = '$wsBase/api/ws';
          socket = await WebSocket.connect(
            wsUri,
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(_timeout);

          if (closed) {
            cleanup();
            return;
          }

          bumpWatchdog();
          pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
            if (!closed && socket != null) {
              try {
                socket!.add('ping');
              } catch (_) {}
            }
          });

          sub = socket!.listen(
            (raw) {
              if (closed) return;
              bumpWatchdog();
              if (raw is! String) return;
              if (raw == 'pong') {
                onKeepAlive?.call();
                return;
              }
              try {
                final frame = jsonDecode(raw);
                if (frame is! Map<String, dynamic>) return;
                final type = frame['t'];
                if (type == 'state') {
                  final d = frame['d'];
                  final map = d is String
                      ? jsonDecode(d)
                      : (d is Map<String, dynamic> ? d : null);
                  if (map is Map<String, dynamic>) {
                    controller.add(CompanionSnapshot.fromJson(map));
                  }
                } else if (type == 'offline') {
                  controller.addError(
                    const CompanionApiException(
                      'Computer went offline on relay',
                      isNetwork: true,
                    ),
                  );
                  controller.close();
                  cleanup();
                } else if (type == 'pong') {
                  onKeepAlive?.call();
                }
              } catch (_) {
                // Ignore malformed relay frames cleanly.
              }
            },
            onError: (Object err, StackTrace st) {
              if (!closed) {
                controller.addError(
                  CompanionApiException('Relay stream dropped: $err',
                      isNetwork: true),
                  st,
                );
                controller.close();
              }
              cleanup();
            },
            onDone: () {
              if (!closed) {
                final code = socket?.closeCode;
                if (code == 4401) {
                  controller.addError(const CompanionApiException(
                    'Device was revoked on desktop.',
                    statusCode: 401,
                    isUnauthorized: true,
                  ));
                }
                controller.close();
              }
              cleanup();
            },
            cancelOnError: true,
          );
        } catch (e) {
          if (!closed) {
            final msg = e.toString();
            final is401 = msg.contains('401');
            controller.addError(
              CompanionApiException(
                is401
                    ? 'Device was revoked on desktop.'
                    : 'Unable to open relay stream: $e',
                statusCode: is401 ? 401 : null,
                isUnauthorized: is401,
                isNetwork: !is401,
              ),
            );
            await controller.close();
          }
          cleanup();
        }
      },
      onCancel: cleanup,
    );

    return controller.stream;
  }

  Future<void> sendQuickAction({
    required String baseUrl,
    required String token,
    required int paneId,
    required String action,
  }) async {
    await _postJson(
      '${_cleanBase(baseUrl)}/api/pane/$paneId/input',
      token,
      {'action': action},
    );
  }

  Future<void> sendInput({
    required String baseUrl,
    required String token,
    required int paneId,
    required String text,
    bool enter = true,
  }) async {
    await _postJson(
      '${_cleanBase(baseUrl)}/api/pane/$paneId/input',
      token,
      {'text': text, 'enter': enter},
    );
  }

  Future<void> switchProfile({
    required String baseUrl,
    required String token,
    required int paneId,
    required String profileId,
  }) async {
    await _postJson(
      '${_cleanBase(baseUrl)}/api/pane/$paneId/switch-profile',
      token,
      {'profile_id': profileId},
    );
  }

  Future<void> resumeSession({
    required String baseUrl,
    required String token,
    required int projectId,
    required String agent,
    required String sessionId,
    String? profileId,
  }) async {
    await _postJson(
      '${_cleanBase(baseUrl)}/api/session/resume',
      token,
      {
        'project_id': projectId,
        'agent': agent,
        'session_id': sessionId,
        if (profileId != null && profileId.isNotEmpty) 'profile_id': profileId,
      },
    );
  }

  /// Spawns a new agent (or `'shell'` terminal) inside `projectId` on desktop (`v0.3.14+`).
  Future<void> spawnAgent({
    required String baseUrl,
    required String token,
    required int projectId,
    required String agent,
    String? profileId,
  }) async {
    try {
      await _postJson(
        '${_cleanBase(baseUrl)}/api/pane/spawn',
        token,
        {
          'project_id': projectId,
          'agent': agent,
          if (profileId != null && profileId.isNotEmpty)
            'profile_id': profileId,
        },
      );
    } on CompanionApiException catch (e) {
      if (e.statusCode == 404) {
        throw const CompanionApiException(
          'Update TernaryCode desktop to v0.3.14+ to spawn agents from phone.',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  /// Triggers an on-demand session history refresh on desktop (`v0.3.20+`) for
  /// `projectId` and its worktrees. Silently ignored on older desktops (404).
  Future<void> refreshProjectSessions({
    required String baseUrl,
    required String token,
    required int projectId,
  }) async {
    try {
      await _postJson(
        '${_cleanBase(baseUrl)}/api/project/$projectId/sessions/refresh',
        token,
        const {},
      );
    } on CompanionApiException catch (e) {
      if (e.statusCode == 404) return;
      rethrow;
    }
  }

  /// Closes a running/idle agent or terminal pane on desktop (`v0.3.16+`).
  Future<void> closePane({
    required String baseUrl,
    required String token,
    required int paneId,
  }) async {
    try {
      await _postJson(
        '${_cleanBase(baseUrl)}/api/pane/$paneId/close',
        token,
        const {},
      );
    } on CompanionApiException catch (e) {
      if (e.statusCode == 404) {
        throw const CompanionApiException(
          'Update TernaryCode desktop to v0.3.16+ to close panes from phone.',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  /// Probes local Wi-Fi `/24` subnet on port 7890 for running TernaryCode desktops.
  Future<List<DiscoveredHost>> discoverLanHosts({int port = 7890}) async {
    final candidates = <(int score, String prefix)>[];
    final seen = <String>{};
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        final lname = iface.name.toLowerCase();
        final isVpn = lname.startsWith('tun') ||
            lname.startsWith('utun') ||
            lname.startsWith('wg') ||
            lname.startsWith('ppp') ||
            lname.startsWith('rmnet');
        final isWifi = lname.startsWith('wlan') ||
            lname.startsWith('en') ||
            lname.startsWith('eth');
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final o0 = int.tryParse(parts[0]) ?? 0;
          final o1 = int.tryParse(parts[1]) ?? 0;
          final isPrivate = o0 == 192 && o1 == 168 ||
              o0 == 10 ||
              (o0 == 172 && o1 >= 16 && o1 <= 31);
          if (!isPrivate || isVpn) continue;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          if (seen.add(prefix)) {
            final score = (isWifi ? 10 : 0) + (o0 == 192 ? 3 : (o0 == 10 ? 2 : 1));
            candidates.add((score, prefix));
          }
        }
      }
    } catch (_) {
      return const [];
    }

    if (candidates.isEmpty) return const [];
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    final found = <DiscoveredHost>[];
    final prefix = candidates.first.$2;

    // Probe subnet in parallel chunks to stay responsive (< 1.5s total).
    const chunkSize = 32;
    for (var start = 1; start <= 254; start += chunkSize) {
      final end = (start + chunkSize - 1).clamp(1, 254);
      final futures = <Future<void>>[];
      for (var hostOctet = start; hostOctet <= end; hostOctet++) {
        final ip = '$prefix.$hostOctet';
        futures.add(_probeHost(ip, port).then((h) {
          if (h != null) found.add(h);
        }));
      }
      await Future.wait(futures);
      if (found.length >= 4) break;
    }

    found.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    return found;
  }

  Future<DiscoveredHost?> _probeHost(String ip, int port) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 220),
      );
      socket.destroy();
      sw.stop();

      final uri = Uri.parse('http://$ip:$port/');
      final resp =
          await _client.get(uri).timeout(const Duration(milliseconds: 500));
      if (resp.statusCode == 200 && resp.body.contains('TernaryCode')) {
        return DiscoveredHost(
          name: 'TernaryCode · $ip',
          baseUrl: 'http://$ip:$port',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
    } catch (_) {
      socket?.destroy();
    }
    return null;
  }

  Future<void> _postJson(
    String url,
    String token,
    Map<String, dynamic> body,
  ) async {
    http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse(url),
            headers: _authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CompanionApiException('Request timed out', isNetwork: true);
    } catch (e) {
      throw CompanionApiException('Network error: $e', isNetwork: true);
    }
    if (resp.statusCode == 401) {
      throw const CompanionApiException(
        'Device token was revoked on desktop.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CompanionApiException(
        _extractError(resp.body) ?? 'Command failed (HTTP ${resp.statusCode}).',
        statusCode: resp.statusCode,
      );
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body, String errorMessage) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    throw CompanionApiException(errorMessage);
  }

  String? _extractError(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map<String, dynamic> && map['error'] is String) {
        return map['error'] as String;
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _client.close();
  }
}
