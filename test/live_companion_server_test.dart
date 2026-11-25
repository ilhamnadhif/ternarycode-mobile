import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/services/companion_api.dart';
import 'package:ternarycode_mobile/services/notification_service.dart';
import 'package:ternarycode_mobile/services/storage_service.dart';
import 'package:ternarycode_mobile/state/app_controller.dart';

/// End-to-end integration test against a real local HTTP/1.1 + SSE server
/// mirroring desktop `src/companion.rs`.
void main() {
  late HttpServer server;
  late String baseUrl;
  String expectedPairCode = 'K7M9-P2X4-Q8R2';
  String? issuedToken;
  bool tokenRevoked = false;
  final receivedActions = <Map<String, dynamic>>[];
  final sseSinks = <HttpResponse>[];

  Map<String, dynamic> currentSnapshot = {
    'host_os': 'Mac',
    'failover_mode': 'auto',
    'projects': [
      {
        'id': 1,
        'name': 'storefront',
        'branch': 'main',
        'sessions': [
          {
            'id': 'sess-99',
            'title': 'Fix checkout tax',
            'agent': 'claude',
            'profile': 'claude2',
            'status': 'done',
            'age': '1h ago',
            'live_pane': null,
          }
        ],
      }
    ],
    'panes': [
      {
        'id': 1,
        'project_id': 1,
        'project_name': 'storefront',
        'label': 'Claude Code',
        'branch': 'main',
        'provider': 'Claude Code',
        'profile': 'claude1',
        'supports_profiles': true,
        'status': 'running',
        'status_label': 'Running',
        'message': 'Building',
        'output': 'Compiling…',
        'rate_limit': null,
      }
    ],
    'profiles': [
      {
        'id': 'claude1',
        'name': 'claude1',
        'provider': 'Claude Code',
        'state': 'running',
        'enabled': true,
        'tokens_in': 1000,
        'tokens_out': 500,
      },
      {
        'id': 'claude2',
        'name': 'claude2',
        'provider': 'Claude Code',
        'state': 'idle',
        'enabled': true,
        'tokens_in': 200,
        'tokens_out': 100,
      },
    ],
    'alerts': [],
  };

  void pushSse(Map<String, dynamic> snap) {
    currentSnapshot = snap;
    final frame = utf8.encode('data: ${jsonEncode(snap)}\n\n');
    for (final res in List.of(sseSinks)) {
      try {
        res.add(frame);
        res.flush();
      } catch (_) {}
    }
  }

  setUp(() async {
    issuedToken = null;
    tokenRevoked = false;
    receivedActions.clear();
    sseSinks.clear();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen((req) async {
      final path = req.uri.path;
      final bodyStr = await utf8.decoder.bind(req).join();

      if (req.method == 'POST' && path == '/api/pair') {
        final data = jsonDecode(bodyStr) as Map<String, dynamic>;
        final code = (data['token'] as String? ?? '').toUpperCase().replaceAll('-', '');
        final exp = expectedPairCode.replaceAll('-', '');
        if (code != exp) {
          req.response
            ..statusCode = 403
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'Invalid or expired pairing code'}));
          await req.response.close();
          return;
        }
        issuedToken = 'tok-live-secret-123456';
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'device_id': 'dev-test01',
            'device_token': issuedToken,
          }));
        await req.response.close();
        return;
      }

      // Auth check
      final auth = req.headers.value('authorization') ?? '';
      if (tokenRevoked || issuedToken == null || auth != 'Bearer $issuedToken') {
        req.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'unauthorized'}));
        await req.response.close();
        return;
      }

      if (req.method == 'GET' && path == '/api/state') {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(currentSnapshot));
        await req.response.close();
        return;
      }

      if (req.method == 'GET' && path == '/api/events') {
        req.response
          ..statusCode = 200
          ..headers.set('content-type', 'text/event-stream; charset=utf-8')
          ..headers.set('cache-control', 'no-cache')
          ..bufferOutput = false;
        req.response.add(utf8.encode('data: ${jsonEncode(currentSnapshot)}\n\n'));
        await req.response.flush();
        sseSinks.add(req.response);
        return;
      }

      if (req.method == 'POST') {
        receivedActions.add({
          'path': path,
          'body': jsonDecode(bodyStr),
        });
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}));
        await req.response.close();
        return;
      }

      req.response.statusCode = 404;
      await req.response.close();
    });
  });

  tearDown(() async {
    for (final s in sseSinks) {
      try {
        await s.close();
      } catch (_) {}
    }
    await server.close(force: true);
  });

  test('pairs, streams SSE updates, dispatches notifications & commands, and detects 401 revocation', () async {
    final storage = InMemoryStorageService();
    final notifications = NoopNotificationService();
    final ctrl = AppController(
      api: CompanionApi(),
      storage: storage,
      notifications: notifications,
    );
    await ctrl.init();

    // 1. Invalid code fails cleanly with error message
    final badErr = await ctrl.pairHost(
      rawUrl: baseUrl,
      code: 'WRONG-CODE',
      deviceName: 'Pixel 9 Pro',
    );
    expect(badErr, contains('Invalid or expired pairing code'));
    expect(ctrl.isPaired, isFalse);

    // 2. Valid code pairs, stores Keystore token, connects SSE
    final okErr = await ctrl.pairHost(
      rawUrl: baseUrl,
      code: expectedPairCode,
      deviceName: 'Pixel 9 Pro',
    );
    expect(okErr, isNull);
    expect(ctrl.isPaired, isTrue);
    expect(ctrl.phase, ConnectionPhase.connected);
    expect(ctrl.snapshot.panes.first.projectName, 'storefront');

    final storedTok = await storage.readToken(ctrl.activeHost!.id);
    expect(storedTok, issuedToken);

    // Wait briefly for SSE subscription registration
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(sseSinks, isNotEmpty);

    // 3. Push live SSE transition to `needs_input` -> triggers notification!
    final updated = Map<String, dynamic>.from(currentSnapshot);
    updated['panes'] = [
      {
        ...(currentSnapshot['panes'] as List).first as Map<String, dynamic>,
        'status': 'needs_input',
        'status_label': 'Needs input',
        'message': 'Bash · npm test',
      }
    ];
    pushSse(updated);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(ctrl.snapshot.panes.first.status, 'needs_input');
    expect(notifications.sentAlerts, contains('approve:1:storefront'));

    // 4. Send Approve, text prompt, switch-profile, and resume-session
    await ctrl.sendQuickAction(1, 'approve');
    await ctrl.sendTerminalInput(1, 'run tests', enter: true);
    await ctrl.switchProfile(1, 'claude2');
    await ctrl.resumeSession(
      project: ctrl.snapshot.projects.first,
      session: ctrl.snapshot.projects.first.sessions.first,
    );

    expect(receivedActions.length, 4);
    expect(receivedActions[0]['path'], '/api/pane/1/input');
    expect(receivedActions[0]['body'], {'action': 'approve'});
    expect(receivedActions[1]['body'], {'text': 'run tests', 'enter': true});
    expect(receivedActions[2]['path'], '/api/pane/1/switch-profile');
    expect(receivedActions[2]['body'], {'profile_id': 'claude2'});
    expect(receivedActions[3]['path'], '/api/session/resume');
    expect(receivedActions[3]['body']['session_id'], 'sess-99');

    // 5. Revoke token on server and retry -> enters ConnectionPhase.revoked
    tokenRevoked = true;
    await ctrl.retryConnection();
    expect(ctrl.phase, ConnectionPhase.revoked);

    ctrl.dispose();
  });
}
