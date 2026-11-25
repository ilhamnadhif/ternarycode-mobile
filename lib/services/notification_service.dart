import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';

typedef NotificationActionHandler = Future<void> Function(
  String actionId,
  int paneId, {
  String? profileId,
});

/// Notification + biometric contract so Android OS channels and tests share one clean API.
abstract class NotificationBackend {
  Future<void> init(NotificationActionHandler onAction);
  Future<void> showApprovalAlert({
    required int paneId,
    required String project,
    required String agent,
    required String command,
  });
  Future<void> showRateLimitAlert({
    required int paneId,
    required String project,
    required String fromProfile,
    required String resetsIn,
    String? nextProfileId,
  });
  Future<void> showFailedAlert({
    required int paneId,
    required String project,
    required String title,
    required String message,
  });
  Future<bool> authenticateBiometric(String reason);
}

class AndroidNotificationService implements NotificationBackend {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _initialized = false;

  static const _urgentChannelId = 'tc_agent_urgent';

  @override
  Future<void> init(NotificationActionHandler onAction) async {
    if (_initialized || kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (resp) async {
          final payloadStr = resp.payload;
          if (payloadStr == null || payloadStr.isEmpty) return;
          try {
            final map = jsonDecode(payloadStr) as Map<String, dynamic>;
            final paneId = (map['paneId'] as num?)?.toInt() ?? 0;
            final nextProfile = map['profileId'] as String?;
            final act = resp.actionId ?? 'open';
            await onAction(act, paneId, profileId: nextProfile);
          } catch (_) {}
        },
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _urgentChannelId,
          'Agent Approvals & Limits',
          description:
              'Alerts when an AI coding agent requests approval, hits a rate limit, or fails.',
          importance: Importance.high,
        ),
      );
      _initialized = true;
    } catch (_) {
      // Safe no-op on platforms/tests without native plugin binding.
    }
  }

  @override
  Future<void> showApprovalAlert({
    required int paneId,
    required String project,
    required String agent,
    required String command,
  }) async {
    if (!_initialized) return;
    final details = AndroidNotificationDetails(
      _urgentChannelId,
      'Agent Approvals & Limits',
      importance: Importance.high,
      priority: Priority.high,
      subText: project,
      actions: const [
        AndroidNotificationAction('approve', 'Approve',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('reject', 'Reject',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction('open', 'Open',
            showsUserInterface: true, cancelNotification: true),
      ],
    );
    await _plugin.show(
      1000 + paneId,
      '$agent wants to run a command',
      command,
      NotificationDetails(android: details),
      payload: jsonEncode({'paneId': paneId}),
    );
  }

  @override
  Future<void> showRateLimitAlert({
    required int paneId,
    required String project,
    required String fromProfile,
    required String resetsIn,
    String? nextProfileId,
  }) async {
    if (!_initialized) return;
    final actions = <AndroidNotificationAction>[
      if (nextProfileId != null)
        AndroidNotificationAction(
          'failover',
          'Resume on $nextProfileId',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      const AndroidNotificationAction('open', 'Open',
          showsUserInterface: true, cancelNotification: true),
    ];
    final details = AndroidNotificationDetails(
      _urgentChannelId,
      'Agent Approvals & Limits',
      importance: Importance.high,
      priority: Priority.high,
      subText: project,
      actions: actions,
    );
    await _plugin.show(
      2000 + paneId,
      '$fromProfile hit its usage limit',
      'Resets in $resetsIn${nextProfileId != null ? ' · $nextProfileId ready' : ''}',
      NotificationDetails(android: details),
      payload: jsonEncode({'paneId': paneId, 'profileId': nextProfileId}),
    );
  }

  @override
  Future<void> showFailedAlert({
    required int paneId,
    required String project,
    required String title,
    required String message,
  }) async {
    if (!_initialized) return;
    const details = AndroidNotificationDetails(
      _urgentChannelId,
      'Agent Approvals & Limits',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      3000 + paneId,
      '$project · $title',
      message,
      const NotificationDetails(android: details),
      payload: jsonEncode({'paneId': paneId}),
    );
  }

  @override
  Future<bool> authenticateBiometric(String reason) async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return true;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return true;
    }
  }
}

/// No-op notification backend for widget and unit tests.
class NoopNotificationService implements NotificationBackend {
  final List<String> sentAlerts = [];

  @override
  Future<void> init(NotificationActionHandler onAction) async {}

  @override
  Future<void> showApprovalAlert({
    required int paneId,
    required String project,
    required String agent,
    required String command,
  }) async {
    sentAlerts.add('approve:$paneId:$project');
  }

  @override
  Future<void> showRateLimitAlert({
    required int paneId,
    required String project,
    required String fromProfile,
    required String resetsIn,
    String? nextProfileId,
  }) async {
    sentAlerts.add('limit:$paneId:$fromProfile->$nextProfileId');
  }

  @override
  Future<void> showFailedAlert({
    required int paneId,
    required String project,
    required String title,
    required String message,
  }) async {
    sentAlerts.add('failed:$paneId:$project');
  }

  @override
  Future<bool> authenticateBiometric(String reason) async => true;
}
