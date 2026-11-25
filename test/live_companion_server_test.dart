import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/services/companion_api.dart';
import 'package:ternarycode_mobile/services/notification_service.dart';
import 'package:ternarycode_mobile/services/interactive_prompt_parser.dart';
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
  bool serveHtml200 = false;
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
        'worktrees': [
          {
            'id': 101,
            'name': 'feat-checkout',
            'branch': 'tc/feat-checkout',
            'merged': true,
            'status': 'idle',
            'sessions': [
              {
                'id': 'sess-wt-99',
                'title': 'Add promo code validation',
                'agent': 'codex',
                'profile': 'codex1',
                'status': 'done',
                'age': '20m ago',
                'live_pane': null,
              }
            ],
          }
        ],
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
    serveHtml200 = false;
    receivedActions.clear();
    sseSinks.clear();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen((req) async {
      final path = req.uri.path;
      final bodyStr = await utf8.decoder.bind(req).join();

      if (req.method == 'POST' && path == '/api/pair') {
        if (serveHtml200) {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('<html><body>Captive portal</body></html>');
          await req.response.close();
          return;
        }
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
          'ts': DateTime.now().millisecondsSinceEpoch,
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
      enterDelay: const Duration(milliseconds: 60),
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

    // 4. Send Approve, text prompt (must split text + delayed Enter to avoid TUI paste-burst newline!),
    //    standalone Enter key, switch-profile, resume-session, and spawn-agent.
    await ctrl.sendQuickAction(1, 'approve');
    await ctrl.sendTerminalInput(1, 'run tests\n', enter: true);
    await ctrl.sendTerminalInput(1, 'line 1\nline 2', enter: true);
    await ctrl.sendTerminalInput(1, '', enter: true);
    await ctrl.switchProfile(1, 'claude2');
    await ctrl.resumeSession(
      project: ctrl.snapshot.projects.first,
      session: ctrl.snapshot.projects.first.sessions.first,
    );
    await ctrl.spawnAgent(
      project: ctrl.snapshot.projects.first,
      agent: 'claude',
      profileId: 'claude2',
    );

    expect(receivedActions.length, 9);
    expect(receivedActions[0]['path'], '/api/pane/1/input');
    expect(receivedActions[0]['body'], {'action': 'approve'});
    // Single-line prompt sent first with enter: false, trailing newline trimmed
    expect(receivedActions[1]['path'], '/api/pane/1/input');
    expect(receivedActions[1]['body'], {'text': 'run tests', 'enter': false});
    // Standalone Enter sent after enterDelay so Codex/Claude TUIs submit cleanly
    expect(receivedActions[2]['path'], '/api/pane/1/input');
    expect(receivedActions[2]['body'], {'text': '', 'enter': true});
    final gapMs = (receivedActions[2]['ts'] as int) -
        (receivedActions[1]['ts'] as int);
    expect(gapMs, greaterThanOrEqualTo(45));
    // Multi-line prompt wrapped in ANSI bracketed paste + delayed Enter
    expect(receivedActions[3]['path'], '/api/pane/1/input');
    expect(receivedActions[3]['body'], {
      'text': '\x1B[200~line 1\nline 2\x1B[201~',
      'enter': false,
    });
    expect(receivedActions[4]['path'], '/api/pane/1/input');
    expect(receivedActions[4]['body'], {'text': '', 'enter': true});
    // Standalone Enter quick key sends one single request
    expect(receivedActions[5]['path'], '/api/pane/1/input');
    expect(receivedActions[5]['body'], {'text': '', 'enter': true});
    expect(receivedActions[6]['path'], '/api/pane/1/switch-profile');
    expect(receivedActions[6]['body'], {'profile_id': 'claude2'});
    expect(receivedActions[7]['path'], '/api/session/resume');
    expect(receivedActions[7]['body']['session_id'], 'sess-99');
    expect(receivedActions[8]['path'], '/api/pane/spawn');
    expect(receivedActions[8]['body'], {
      'project_id': 1,
      'agent': 'claude',
      'profile_id': 'claude2',
    });

    // 4b. Worktree spawn/resume, on-demand session refresh, and rate-limit dismiss
    receivedActions.clear();
    final proj = ctrl.snapshot.projects.first;
    final wt = proj.worktrees.first;
    expect(wt.id, 101);
    expect(wt.merged, isTrue);
    expect(wt.sessions.first.id, 'sess-wt-99');

    await ctrl.refreshProjectSessions(proj.id);
    await ctrl.spawnAgent(project: proj, worktree: wt, agent: 'codex');
    await ctrl.resumeSession(
      project: proj,
      worktree: wt,
      session: wt.sessions.first,
    );
    await ctrl.dismissRateLimit(1);

    expect(receivedActions.length, 4);
    expect(receivedActions[0]['path'], '/api/project/1/sessions/refresh');
    expect(receivedActions[1]['path'], '/api/pane/spawn');
    expect(receivedActions[1]['body']['project_id'], 101);
    expect(receivedActions[2]['path'], '/api/session/resume');
    expect(receivedActions[2]['body']['project_id'], 101);
    expect(receivedActions[2]['body']['session_id'], 'sess-wt-99');
    expect(receivedActions[3]['path'], '/api/pane/1/input');
    expect(receivedActions[3]['body'], {'action': 'dismiss_limit'});

    // 5. Interactive TUI prompt selection (Claude Trust / Permission menus & [Y/n])
    final trustPrompt = InteractivePromptParser.parse('''
Do you trust the files in this folder?
❯ 1. Yes, I trust this folder
  2. No, exit
Enter to confirm · Esc to cancel
''')!;
    receivedActions.clear();
    // Tapping already-selected option 0 sends ONLY standalone Enter
    await ctrl.selectInteractiveOption(1, trustPrompt, trustPrompt.options[0]);
    // Tapping option 1 (delta +1) sends Down arrow + Enter
    await ctrl.selectInteractiveOption(1, trustPrompt, trustPrompt.options[1]);
    // Unnumbered menu with option 1 selected -> tapping option 0 (delta -1) sends Up arrow + Enter
    final reverseTrust = InteractivePromptParser.parse('''
Do you trust the files in this folder?
  Yes, I trust this folder
❯ No, exit
Enter to confirm · Esc to cancel
''')!;
    await ctrl.selectInteractiveOption(1, reverseTrust, reverseTrust.options[0]);

    expect(receivedActions.length, 5);
    expect(receivedActions[0]['body'], {'text': '', 'enter': true});
    expect(receivedActions[1]['body'], {'text': '\x1B[B', 'enter': false});
    expect(receivedActions[2]['body'], {'text': '', 'enter': true});
    expect(receivedActions[3]['body'], {'text': '\x1B[A', 'enter': false});
    expect(receivedActions[4]['body'], {'text': '', 'enter': true});

    // 6. Revoke token on server and retry -> enters ConnectionPhase.revoked & shows offline wall
    tokenRevoked = true;
    await ctrl.retryConnection();
    expect(ctrl.phase, ConnectionPhase.revoked);
    expect(ctrl.showOfflineWall, isTrue);

    ctrl.dispose();
  });

  test('silently heals transient SSE drops without offline wall and reconnects on app resume', () async {
    final storage = InMemoryStorageService();
    final notifications = NoopNotificationService();
    final ctrl = AppController(
      api: CompanionApi(),
      storage: storage,
      notifications: notifications,
    );
    await ctrl.init();

    final err = await ctrl.pairHost(
      rawUrl: baseUrl,
      code: expectedPairCode,
      deviceName: 'Xiaomi Test',
    );
    expect(err, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(sseSinks.length, 1);

    // 1. Keepalive comment keeps stream healthy
    sseSinks.first.add(utf8.encode(': keepalive\n\n'));
    await sseSinks.first.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ctrl.phase, ConnectionPhase.connected);
    expect(ctrl.showOfflineWall, isFalse);

    // 2. Simulate transient SSE socket drop -> soft reconnect (no full-screen Retry now!)
    await sseSinks.first.close();
    sseSinks.clear();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(ctrl.showOfflineWall, isFalse);

    // First auto-retry fires at 350ms and restores live SSE seamlessly
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(ctrl.phase, ConnectionPhase.connected);
    expect(ctrl.showOfflineWall, isFalse);
    expect(sseSinks.length, 1);

    // 3. Simulate Android backgrounding + OS killing background TCP socket -> resume heals immediately
    ctrl.onAppLifecycleChanged(AppLifecycleState.paused);
    await sseSinks.first.close();
    sseSinks.clear();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(ctrl.phase, ConnectionPhase.reconnecting);
    // While paused, it does NOT spam reconnects
    expect(sseSinks, isEmpty);

    // Returning to foreground immediately reconnects with zero manual Retry click
    ctrl.onAppLifecycleChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(ctrl.phase, ConnectionPhase.connected);
    expect(ctrl.showOfflineWall, isFalse);
    expect(sseSinks.length, 1);

    // 4. Resuming a historical session auto-focuses the newly created pane via SSE
    await ctrl.resumeSession(
      project: ctrl.snapshot.projects.first,
      session: ctrl.snapshot.projects.first.sessions.first,
    );
    final withResumedPane = Map<String, dynamic>.from(currentSnapshot);
    withResumedPane['panes'] = [
      ...(currentSnapshot['panes'] as List),
      {
        'id': 2,
        'project_id': 1,
        'project_name': 'storefront',
        'label': 'Claude Code',
        'branch': 'main',
        'provider': 'Claude Code',
        'profile': 'claude2',
        'supports_profiles': true,
        'status': 'running',
        'status_label': 'Running',
        'message': 'Resumed session',
        'output': 'Resuming Fix checkout tax…',
        'rate_limit': null,
      },
      // Untouched idle default shell MUST be filtered out from ACTIVE/Live!
      {
        'id': 99,
        'project_id': 2,
        'project_name': 'unused-repo',
        'label': 'zsh',
        'branch': 'main',
        'provider': null,
        'profile': null,
        'supports_profiles': false,
        'status': 'idle',
        'status_label': 'Idle',
        'message': null,
        'output': '',
        'rate_limit': null,
      },
      // Running foreground shell process (e.g. npm run dev) MUST stay in ACTIVE!
      {
        'id': 100,
        'project_id': 3,
        'project_name': 'dev-server-app',
        'label': 'npm',
        'branch': 'main',
        'provider': null,
        'profile': null,
        'supports_profiles': false,
        'status': 'running',
        'status_label': 'Running',
        'message': 'Listening on :3000',
        'output': 'ready on http://localhost:3000',
        'rate_limit': null,
      },
      // Explicitly opened remote shell MUST stay in ACTIVE even while idle!
      {
        'id': 101,
        'project_id': 4,
        'project_name': 'remote-shell-app',
        'label': 'zsh',
        'branch': 'main',
        'provider': null,
        'profile': null,
        'supports_profiles': false,
        'status': 'idle',
        'status_label': 'Idle',
        'message': null,
        'output': '~/code ❯ ',
        'rate_limit': null,
        'remote_opened': true,
      },
    ];
    pushSse(withResumedPane);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(ctrl.selectedPane?.id, 2);
    expect(ctrl.snapshot.panes.map((p) => p.id).toList(), [1, 2, 100, 101]);
    expect(ctrl.snapshot.panes.any((p) => p.id == 99), isFalse);

    // 5. Closing a pane dispatches POST /api/pane/101/close and removes it cleanly
    final shellPane = ctrl.snapshot.panes.firstWhere((p) => p.id == 101);
    await ctrl.closePane(shellPane);
    expect(
      receivedActions.any((a) => a['path'] == '/api/pane/101/close'),
      isTrue,
    );
    expect(ctrl.snapshot.panes.any((p) => p.id == 101), isFalse);

    // 6. Malformed UTF-8 bytes in SSE stream must NOT crash or tear down SSE
    sseSinks.first.add([
      ...utf8.encode('data: {"host_os":"Mac","failover_mode":"auto","projects":[],"panes":[{"id":1,"project_id":1,"project_name":"storefront","label":"Claude Code","provider":"Claude Code","status":"running","status_label":"Running","output":"ok '),
      0xFF,
      0xFE,
      ...utf8.encode(' still-alive"}],"profiles":[],"alerts":[]}\n\n'),
    ]);
    await sseSinks.first.flush();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(ctrl.phase, ConnectionPhase.connected);
    expect(ctrl.snapshot.panes.first.output, contains('still-alive'));

    // 7. Disabling keepAlive disconnects SSE on pause and reconnects cleanly on resume
    await ctrl.updateSettings(ctrl.settings.copyWith(keepAlive: false));
    ctrl.onAppLifecycleChanged(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    ctrl.onAppLifecycleChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(ctrl.phase, ConnectionPhase.connected);

    // 8. Non-JSON HTTP 200 HTML response on /api/pair returns clean error instead of crashing
    serveHtml200 = true;
    final htmlErr = await ctrl.pairHost(
      rawUrl: baseUrl,
      code: expectedPairCode,
      deviceName: 'Captive Test',
    );
    expect(htmlErr, contains('Malformed pairing response'));

    ctrl.dispose();
  });
}
