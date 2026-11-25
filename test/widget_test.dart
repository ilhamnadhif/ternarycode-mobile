import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/app.dart';
import 'package:ternarycode_mobile/models/host_models.dart';
import 'package:ternarycode_mobile/screens/notification_preview_screen.dart';
import 'package:ternarycode_mobile/services/companion_api.dart';
import 'package:ternarycode_mobile/services/notification_service.dart';
import 'package:ternarycode_mobile/services/interactive_prompt_parser.dart';
import 'package:ternarycode_mobile/services/storage_service.dart';
import 'package:ternarycode_mobile/state/app_controller.dart';
import 'package:ternarycode_mobile/theme/slate_theme.dart';
import 'package:ternarycode_mobile/widgets/terminal_view.dart';

void main() {
  Future<AppController> buildController() async {
    final ctrl = AppController(
      api: CompanionApi(),
      storage: InMemoryStorageService(),
      notifications: NoopNotificationService(),
    );
    await ctrl.init();
    return ctrl;
  }

  Future<void> pumpRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('Full 14-screen user flow across Slate Dark and Light themes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ctrl = await buildController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      TernaryCodeApp(controller: ctrl, disableCameraForTests: true),
    );
    await tester.pumpAndSettle();

    // Screen 01 · Welcome & Pair
    expect(find.text('Pair with TernaryCode'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Enter address & code'), findsOneWidget);

    // Screen 02 · QR Scanner (camera disabled in test env) — caption strictly below reticle
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter code manually'), findsOneWidget);
    final captionTop = tester.getTopLeft(find.textContaining('Point at the QR code')).dy;
    final reticleBottom = 844 * 0.39 + 114;
    expect(captionTop, greaterThanOrEqualTo(reticleBottom + 16));

    // Screen 03 · Manual Pairing & draft preservation on validation error
    await tester.tap(find.text('Enter code manually'));
    await tester.pumpAndSettle();
    expect(find.text('Manual pairing'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid host address'), findsOneWidget);

    // Back to Welcome and launch interactive Demo Mode
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Preview interactive demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Screen 05 · Live Raw Terminal (Needs input) — wrap/copy controls & collapsible terminal keys
    expect(find.text('Live'), findsWidgets);
    expect(find.text('storefront'), findsWidgets);
    expect(find.text('4 active'), findsOneWidget);
    expect(find.byTooltip('Toggle line wrap'), findsOneWidget);
    expect(find.byTooltip('Copy terminal output'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // Toggle line wrap directly from Live control bar
    final initialWrap = ctrl.settings.termWrap;
    await tester.tap(find.byTooltip('Toggle line wrap'));
    await tester.pump();
    expect(ctrl.settings.termWrap, !initialWrap);
    await tester.tap(find.byTooltip('Toggle line wrap'));
    await tester.pump();

    // Toggle collapsible Terminal keys via keyboard button
    await tester.tap(find.byTooltip('Terminal keys'));
    await tester.pump();
    expect(find.text('Esc'), findsOneWidget);
    await tester.tap(find.byTooltip('Terminal keys'));
    await tester.pump();
    expect(find.text('Esc'), findsNothing);

    // Tap active context bar -> jumps straight to Projects tab with Desktop-style ACTIVE / IDLE tree
    await tester.tap(find.text('4 active'));
    await tester.pump();
    expect(find.text('ACTIVE · 3'), findsOneWidget);
    expect(find.text('IDLE · 2'), findsOneWidget);
    expect(find.text('codex-export'), findsOneWidget);
    expect(find.text('merged'), findsOneWidget);
    // Idle projects must NOT expand session history cards inline (history lives inside New agent popup!)
    expect(find.text('Polish landing hero typography'), findsNothing);

    // Screen 06 · Select api-gateway's live agent from ACTIVE tree and perform 1-tap failover
    await tester.tap(find.text('Rate-limit /v1/search per API key'));
    await tester.pump();
    expect(find.text('Resume claude2'), findsOneWidget);
    expect(find.byTooltip('Dismiss rate limit'), findsOneWidget);
    await tester.tap(find.text('Resume claude2'));
    await tester.pump();
    expect(find.textContaining('Resuming api-gateway on claude2'), findsOneWidget);

    // Screen 07 · Select ternarycode's live agent from ACTIVE tree (Running + Switch account chips)
    await tester.tap(find.text('Projects'));
    await tester.pump();
    await tester.tap(find.text('Add companion worktree tree'));
    await tester.pump();
    expect(find.text('SWITCH ACCOUNT'), findsOneWidget);

    // Screen 08 · Fullscreen Terminal zoom & wrap toggle
    await tester.tap(find.byTooltip('Fullscreen terminal'));
    await pumpRoute(tester);
    expect(find.text('A+'), findsOneWidget);
    await tester.tap(find.text('A+'));
    await tester.pump();
    expect(ctrl.settings.termFontSize, 12.5);
    await tester.tap(find.byTooltip('Back'));
    await pumpRoute(tester);

    // Screen 04 · Host Switcher bottom sheet + Offline state + Retry recovery
    await tester.tap(find.text('MacBook Pro'));
    await pumpRoute(tester);
    expect(find.text('Computers'), findsOneWidget);
    await tester.tap(find.text('Desktop PC'));
    await pumpRoute(tester);
    expect(find.text('Desktop PC is unreachable'), findsOneWidget);
    await tester.tap(find.text('Retry now'));
    await tester.pump();
    expect(find.text('Desktop PC is unreachable'), findsNothing);

    // Verify 1-tap Dismiss on a rate-limited pane clears both banner and profile cooldown cleanly
    await tester.tap(find.text('Projects'));
    await tester.pump();
    await tester.tap(find.text('Rate-limit /v1/search per API key'));
    await tester.pump();
    await tester.tap(find.byTooltip('Dismiss rate limit'));
    await tester.pump();
    expect(find.byTooltip('Dismiss rate limit'), findsNothing);
    expect(
      ctrl.snapshot.profiles.firstWhere((p) => p.id == 'claude1').state,
      'idle',
    );

    // Screen 09 · Inbox Queue + segmented filters + Screen 10 Detail
    await tester.tap(find.text('Inbox'));
    await tester.pump();
    expect(find.text('NEEDS YOU · OLDEST FIRST'), findsOneWidget);
    await tester.tap(find.text('Finished'));
    await tester.pump();
    expect(find.text('FINISHED'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pump();

    // Open Screen 10 (Inbox Item Detail for storefront)
    await tester.tap(find.text('Bash · npm test -- auth'));
    await pumpRoute(tester);
    expect(find.text('LAST LINES'), findsOneWidget);
    expect(find.text('Open Live'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await pumpRoute(tester);

    // Screen 11 · Projects search + tap idle project (docs-site) -> New / Resume Agent popup with history!
    await tester.tap(find.text('Projects'));
    await tester.pump();
    expect(find.text('ACTIVE · 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'docs-site');
    await tester.pump();
    expect(find.text('IDLE · 1'), findsOneWidget);
    expect(find.text('onboarding-copy'), findsOneWidget);
    await tester.tap(find.text('docs-site').last);
    await pumpRoute(tester);
    expect(find.text('New agent'), findsOneWidget);
    expect(find.text('New Claude Code session'), findsOneWidget);
    expect(find.text('RESUME SESSION · 1'), findsOneWidget);
    expect(find.text('Polish landing hero typography'), findsOneWidget);
    // Resume historical session right from the popup
    await tester.tap(find.text('Polish landing hero typography'));
    await pumpRoute(tester);
    expect(ctrl.tabIndex, 0);
    expect(ctrl.selectedPane?.projectName, 'docs-site');
    expect(ctrl.selectedPane?.task, 'Polish landing hero typography');
    expect(ctrl.snapshot.panes.length, 5);

    // Also test spawning a fresh session on idle project with 0 history (zain-iq)
    await tester.tap(find.text('Projects'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'zain-iq');
    await tester.pump();
    await tester.tap(find.text('zain-iq').last);
    await pumpRoute(tester);
    expect(find.text('New Claude Code session'), findsOneWidget);
    expect(find.textContaining('No previous Claude Code sessions'), findsOneWidget);
    await tester.tap(find.text('New Claude Code session'));
    await pumpRoute(tester);
    expect(ctrl.tabIndex, 0);
    expect(ctrl.selectedPane?.projectName, 'zain-iq');
    expect(ctrl.snapshot.panes.length, 6);

    // Clear filter, verify closing an active pane in ACTIVE tree, and switch to Accounts
    await tester.tap(find.text('Projects'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    expect(find.text('ACTIVE · 5'), findsOneWidget);
    // Close a running pane (shows confirmation dialog for running agent)
    await tester.tap(find.byTooltip('Close pane').first);
    await pumpRoute(tester);
    if (find.text('Close').evaluate().isNotEmpty) {
      await tester.tap(find.text('Close'));
      await pumpRoute(tester);
    }
    expect(ctrl.snapshot.panes.length, 5);

    // Screen 12 · Accounts & Quotas
    await tester.tap(find.text('Accounts'));
    await tester.pump();
    expect(find.text('FAILOVER ORDER'), findsOneWidget);
    expect(find.text('claude1'), findsOneWidget);
    expect(find.text('claude2'), findsOneWidget);

    // Screen 13 · Settings + Light Theme switch + Screen 14 Notification Shade Preview
    await tester.tap(find.byTooltip('Settings').last);
    await pumpRoute(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Background keep-alive'), findsOneWidget);

    // Switch to Slate Light theme and confirm zero layout errors
    await tester.tap(find.text('Light'));
    await pumpRoute(tester);
    expect(ctrl.settings.themeMode, ThemeMode.light);

    // Open Screen 14 · Android Notification Shade preview
    await tester.tap(find.text('Shade preview'));
    await pumpRoute(tester);
    expect(find.text('Conversations & Alerts'), findsOneWidget);
    expect(find.text('Send real Android test notification'), findsOneWidget);
    await tester.tap(find.text('Back to app'));
    await pumpRoute(tester);

    // Switch back to Dark and unpair cleanly
    await tester.tap(find.text('Dark'));
    await pumpRoute(tester);
    await tester.scrollUntilVisible(
      find.text('Unpair this device'),
      200,
    );
    await tester.tap(find.text('Unpair this device'));
    await pumpRoute(tester);
    expect(ctrl.hosts.length, 2); // Unpaired Desktop PC, auto-switched to MacBook Pro

    // Drain final toast timer cleanly
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('InteractivePromptDock renders Claude Trust choices cleanly with 0 overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final prompt = InteractivePromptParser.parse('''
╭────────────────────────────────────────────────────────╮
│ Do you trust the files in this folder?                 │
│                                                        │
│ /Users/ilham/Developments/demo                         │
│                                                        │
│ ❯ 1. Yes, I trust this folder                          │
│   2. No, exit                                          │
│                                                        │
│ Enter to confirm · Esc to cancel                       │
╰────────────────────────────────────────────────────────╯
''');
    expect(prompt, isNotNull);

    InteractivePromptOption? tapped;
    var cancelled = false;

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: SlateTheme.build(Brightness.light),
          darkTheme: SlateTheme.build(Brightness.dark),
          themeMode: mode,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: InteractivePromptDock(
                  prompt: prompt!,
                  onSelect: (opt) => tapped = opt,
                  onCancel: () => cancelled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Do you trust the files in this folder?'), findsOneWidget);
      expect(find.text('1. Yes, I trust this folder'), findsOneWidget);
      expect(find.text('2. No, exit'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
    }

    await tester.tap(find.text('1. Yes, I trust this folder'));
    await tester.pump();
    expect(tapped?.index, 0);

    await tester.tap(find.text('Esc'));
    await tester.pump();
    expect(cancelled, isTrue);
  });

  testWidgets('Deep audit regression: Projects search sync/clear, live preview safety & last-host unpair',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Projects search field syncs with openAlertProject() and clears cleanly
    final ctrl = await buildController();
    addTearDown(ctrl.dispose);
    await ctrl.enterDemoMode();

    await tester.pumpWidget(
      TernaryCodeApp(controller: ctrl, disableCameraForTests: true),
    );
    await tester.pump();

    ctrl.openAlertProject('docs-site');
    await tester.pump();
    expect(ctrl.tabIndex, 2);
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller?.text, 'docs-site');
    expect(find.text('IDLE · 1'), findsOneWidget);

    // 2. Unpairing ALL remaining hosts from Settings cleanly returns to Welcome with 0 deactivated-context crash
    for (var i = 0; i < 2; i++) {
      await ctrl.unpairActiveHost();
    }
    expect(ctrl.hosts.length, 1);
    await tester.pump();
    await tester.tap(find.byTooltip('Settings').last);
    await pumpRoute(tester);
    await tester.scrollUntilVisible(find.text('Unpair this device'), 200);
    await tester.tap(find.text('Unpair this device'));
    await pumpRoute(tester);
    expect(ctrl.isPaired, isFalse);
    expect(find.text('Pair with TernaryCode'), findsOneWidget);

    // 3. NotificationPreviewScreen on a live (non-demo) host NEVER sends real quick actions
    final liveStorage = InMemoryStorageService();
    await liveStorage.saveHosts([
      const PairedHost(
        id: 'live-1',
        name: 'Real Mac',
        baseUrl: 'http://127.0.0.1:1',
        deviceId: 'dev-1',
        online: true,
        isDemo: false,
      ),
    ]);
    await liveStorage.saveActiveHostId('live-1');
    final liveCtrl = AppController(
      api: CompanionApi(),
      storage: liveStorage,
      notifications: NoopNotificationService(),
    );
    addTearDown(liveCtrl.dispose);
    await liveCtrl.init();

    await tester.pumpWidget(
      MaterialApp(
        theme: SlateTheme.build(Brightness.dark),
        home: NotificationPreviewScreen(controller: liveCtrl),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(liveCtrl.toastMessage, contains('Preview only'));

    await tester.pump(const Duration(seconds: 3));
  });
}
