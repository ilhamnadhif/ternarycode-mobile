import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/app.dart';
import 'package:ternarycode_mobile/services/companion_api.dart';
import 'package:ternarycode_mobile/services/notification_service.dart';
import 'package:ternarycode_mobile/services/storage_service.dart';
import 'package:ternarycode_mobile/state/app_controller.dart';

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

    // Screen 05 · Live Terminal (Needs input)
    expect(find.text('Live'), findsWidgets);
    expect(find.text('storefront'), findsWidgets);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // Screen 06 · Switch to api-gateway (Rate limited) and perform 1-tap failover
    await tester.drag(find.byType(ListView).first, const Offset(-160, 0));
    await tester.pump();
    await tester.tap(find.text('api-gateway'));
    await tester.pump();
    expect(find.text('Resume claude2'), findsOneWidget);
    await tester.tap(find.text('Resume claude2'));
    await tester.pump();
    expect(find.textContaining('Resuming api-gateway on claude2'), findsOneWidget);

    // Screen 07 · Switch to ternarycode (Running + Switch account chips)
    await tester.drag(find.byType(ListView).first, const Offset(-320, 0));
    await tester.pump();
    await tester.tap(find.text('ternarycode'));
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

    // Screen 11 · Projects & search filter
    await tester.tap(find.text('Projects'));
    await tester.pump();
    expect(find.text('storefront'), findsWidgets);
    await tester.enterText(
        find.byType(TextField).last, 'ternarycode');
    await tester.pump();
    expect(find.text('Audit 53 bugs across workspace'), findsOneWidget);

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
}
