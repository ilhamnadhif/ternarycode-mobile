import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/companion_models.dart';
import '../models/demo_fixtures.dart';
import '../models/host_models.dart';
import '../services/apk_updater.dart';
import '../services/companion_api.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

enum ConnectionPhase { disconnected, connecting, connected, reconnecting, revoked }

enum InboxFilter { all, needsYou, finished }

/// Central application state controller coordinating paired hosts, real-time SSE
/// streaming, agent control actions, inbox triage, quotas, and settings.
class AppController extends ChangeNotifier {
  AppController({
    required CompanionApi api,
    required StorageBackend storage,
    required NotificationBackend notifications,
    ApkUpdater? updater,
    this.autoCheckUpdates = false,
    this.loadPlatformInfo = false,
  })  : _api = api,
        _storage = storage,
        _notifications = notifications,
        updater = updater ?? ApkUpdater();

  final CompanionApi _api;
  final StorageBackend _storage;
  final NotificationBackend _notifications;
  final ApkUpdater updater;
  final bool autoCheckUpdates;
  final bool loadPlatformInfo;

  ApkReleaseInfo? _availableUpdate;
  ApkReleaseInfo? get availableUpdate => _availableUpdate;

  String _appVersion = '0.1.0';
  String get appVersion => _appVersion;

  bool _bootstrapped = false;
  bool get bootstrapped => _bootstrapped;

  List<PairedHost> _hosts = [];
  List<PairedHost> get hosts => List.unmodifiable(_hosts);

  String? _activeHostId;
  PairedHost? get activeHost {
    if (_hosts.isEmpty) return null;
    for (final h in _hosts) {
      if (h.id == _activeHostId) return h;
    }
    return _hosts.first;
  }

  bool get isPaired => _hosts.isNotEmpty;
  bool get isDemoMode => activeHost?.isDemo ?? false;

  ConnectionPhase _phase = ConnectionPhase.disconnected;
  ConnectionPhase get phase => _phase;

  String? _connectionError;
  String? get connectionError => _connectionError;

  int _retryCountdownSec = 0;
  int get retryCountdownSec => _retryCountdownSec;

  CompanionSnapshot _snapshot = const CompanionSnapshot();
  CompanionSnapshot get snapshot => _snapshot;

  int? _selectedPaneId;
  CompanionPane? get selectedPane {
    if (_snapshot.panes.isEmpty) return null;
    for (final p in _snapshot.panes) {
      if (p.id == _selectedPaneId) return p;
    }
    return _snapshot.panes.first;
  }

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  InboxFilter _inboxFilter = InboxFilter.all;
  InboxFilter get inboxFilter => _inboxFilter;

  String _projectQuery = '';
  String get projectQuery => _projectQuery;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  List<DiscoveredHost> _discoveredHosts = const [];
  List<DiscoveredHost> get discoveredHosts => _discoveredHosts;

  bool _discoveringLan = false;
  bool get discoveringLan => _discoveringLan;

  String? _toastMessage;
  String? get toastMessage => _toastMessage;
  Timer? _toastTimer;

  StreamSubscription<CompanionSnapshot>? _sseSub;
  Timer? _reconnectTimer;
  Timer? _countdownTimer;
  int _backoffAttempt = 0;
  bool _disposed = false;

  // Deduplication map: paneId -> last notified status signature
  final Map<int, String> _notifiedSignatures = {};

  Future<void> init() async {
    if (_bootstrapped) return;
    _settings = await _storage.loadSettings();
    _hosts = await _storage.loadHosts();
    _activeHostId = await _storage.loadActiveHostId();
    await _notifications.init(_handleNotificationAction);
    if (loadPlatformInfo) {
      try {
        final info = await PackageInfo.fromPlatform()
            .timeout(const Duration(seconds: 2));
        if (info.version.isNotEmpty) _appVersion = info.version;
      } catch (_) {}
    }
    _bootstrapped = true;
    notifyListeners();

    if (autoCheckUpdates) {
      unawaited(checkForApkUpdates(silent: true));
    }

    if (_hosts.isNotEmpty) {
      await _connectActiveHost();
    }
  }

  Future<void> _handleNotificationAction(
    String actionId,
    int paneId, {
    String? profileId,
  }) async {
    if (actionId == 'approve') {
      await sendQuickAction(paneId, 'approve', skipBiometric: true);
    } else if (actionId == 'reject') {
      await sendQuickAction(paneId, 'reject', skipBiometric: true);
    } else if (actionId == 'failover' && profileId != null) {
      await switchProfile(paneId, profileId);
    } else {
      focusPane(paneId);
    }
  }

  void setTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }

  void selectPane(int paneId) {
    _selectedPaneId = paneId;
    notifyListeners();
  }

  void focusPane(int paneId) {
    _selectedPaneId = paneId;
    _tabIndex = 0;
    notifyListeners();
  }

  void setInboxFilter(InboxFilter filter) {
    _inboxFilter = filter;
    notifyListeners();
  }

  void setProjectQuery(String query) {
    _projectQuery = query;
    notifyListeners();
  }

  void showToast(String msg) {
    _toastMessage = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      _toastMessage = null;
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
  }

  void _triggerHaptic({bool strong = false}) {
    if (!_settings.haptics) return;
    try {
      final fut = strong
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact();
      fut.catchError((_) {});
    } catch (_) {
      // Safe no-op in headless/background contexts without a ServicesBinding.
    }
  }

  /// Launches the interactive Slate demo workspace so users can preview every screen immediately.
  Future<void> enterDemoMode() async {
    _cancelStream();
    _hosts = DemoFixtures.hosts();
    _activeHostId = _hosts.first.id;
    _snapshot = DemoFixtures.snapshot();
    _selectedPaneId = _snapshot.panes.first.id;
    _phase = ConnectionPhase.connected;
    _connectionError = null;
    _tabIndex = 0;
    showToast('Demo mode active · MacBook Pro');
    notifyListeners();
  }

  /// Pairs with a real TernaryCode desktop host via `POST /api/pair` and stores
  /// the revocable Bearer token securely in Android Keystore.
  Future<String?> pairHost({
    required String rawUrl,
    required String code,
    required String deviceName,
  }) async {
    final normalized = ParsedPairingQr.normalizeBaseUrl(rawUrl);
    if (normalized == null) {
      return 'Enter a valid host address (e.g. http://192.168.1.5:7890).';
    }
    if (code.trim().length < 4) {
      return 'Enter the pairing code shown in Settings → Phone.';
    }

    try {
      final result = await _api.pair(
        baseUrl: normalized,
        code: code,
        deviceName: deviceName,
      );

      // Fetch initial state right away to populate host OS & panes.
      String hostOs = 'Mac';
      CompanionSnapshot initialSnap = const CompanionSnapshot();
      int? latencyMs;
      try {
        final fetched = await _api.fetchState(
          baseUrl: normalized,
          token: result.deviceToken,
        );
        initialSnap = fetched.snapshot;
        hostOs = fetched.snapshot.hostOs;
        latencyMs = fetched.latencyMs;
      } catch (_) {}

      final uri = Uri.parse(normalized);
      final hostName = hostOs == 'Mac'
          ? 'Mac · ${uri.host}'
          : (uri.host.isNotEmpty ? uri.host : 'TernaryCode');

      final hostId = 'host-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final newHost = PairedHost(
        id: hostId,
        name: hostName,
        baseUrl: normalized,
        deviceId: result.deviceId,
        hostOs: hostOs,
        via: PairedHost.inferTransport(normalized),
        online: true,
        latencyMs: latencyMs,
        paneCount: initialSnap.panes.length,
        lastSeenUnix: now,
      );

      // Remove demo hosts if switching to a real paired host.
      _hosts = _hosts.where((h) => !h.isDemo).toList();
      _hosts.removeWhere((h) => h.baseUrl == normalized);
      _hosts.insert(0, newHost);
      _activeHostId = hostId;
      _snapshot = initialSnap;
      _selectedPaneId =
          initialSnap.panes.isNotEmpty ? initialSnap.panes.first.id : null;

      await _storage.writeToken(hostId, result.deviceToken);
      await _storage.saveHosts(_hosts);
      await _storage.saveActiveHostId(hostId);

      _triggerHaptic(strong: true);
      _tabIndex = 0;
      showToast('Paired with $hostName · Keystore saved');
      await _connectActiveHost();
      return null;
    } on CompanionApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Pairing failed: $e';
    }
  }

  Future<void> switchHost(String hostId) async {
    if (activeHost?.id == hostId && _phase == ConnectionPhase.connected) {
      return;
    }
    final idx = _hosts.indexWhere((h) => h.id == hostId);
    if (idx == -1) return;

    _activeHostId = hostId;
    final target = _hosts[idx];
    if (!target.isDemo) {
      await _storage.saveActiveHostId(hostId);
    }

    if (target.isDemo) {
      _cancelStream();
      if (!target.online) {
        _phase = ConnectionPhase.reconnecting;
        _connectionError = '${target.name} is unreachable';
        _retryCountdownSec = 4;
      } else {
        _phase = ConnectionPhase.connected;
        _connectionError = null;
        _snapshot = DemoFixtures.snapshot();
        _selectedPaneId = _snapshot.panes.first.id;
      }
      showToast('Switched to ${target.name}');
      notifyListeners();
      return;
    }

    showToast('Connecting to ${target.name}…');
    await _connectActiveHost();
  }

  Future<void> retryConnection() async {
    final host = activeHost;
    if (host == null) return;
    if (host.isDemo) {
      _hosts = _hosts
          .map((h) => h.id == host.id
              ? h.copyWith(online: true, latencyMs: 18, paneCount: 4)
              : h)
          .toList();
      _phase = ConnectionPhase.connected;
      _connectionError = null;
      _snapshot = DemoFixtures.snapshot();
      _selectedPaneId = _snapshot.panes.first.id;
      showToast('Reconnected to ${host.name}');
      notifyListeners();
      return;
    }
    _backoffAttempt = 0;
    await _connectActiveHost();
  }

  Future<void> unpairActiveHost() async {
    final host = activeHost;
    if (host == null) return;
    _cancelStream();
    if (!host.isDemo) {
      await _storage.deleteToken(host.id);
    }
    _hosts = _hosts.where((h) => h.id != host.id).toList();
    _activeHostId = _hosts.isEmpty ? null : _hosts.first.id;
    _snapshot = const CompanionSnapshot();
    _selectedPaneId = null;
    _phase = ConnectionPhase.disconnected;
    _connectionError = null;

    if (!host.isDemo) {
      await _storage.saveHosts(_hosts);
      await _storage.saveActiveHostId(_activeHostId);
    }
    showToast('Unpaired ${host.name}');
    notifyListeners();

    if (_hosts.isNotEmpty) {
      await _connectActiveHost();
    }
  }

  Future<void> scanLanHosts() async {
    if (_discoveringLan) return;
    _discoveringLan = true;
    notifyListeners();
    try {
      _discoveredHosts = await _api.discoverLanHosts();
    } finally {
      _discoveringLan = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _connectActiveHost() async {
    _cancelStream();
    final host = activeHost;
    if (host == null) return;
    if (host.isDemo) {
      _phase = ConnectionPhase.connected;
      notifyListeners();
      return;
    }

    final token = await _storage.readToken(host.id);
    if (token == null || token.isEmpty) {
      _phase = ConnectionPhase.revoked;
      _connectionError = 'Missing Keystore token. Please pair again.';
      notifyListeners();
      return;
    }

    _phase = ConnectionPhase.connecting;
    _connectionError = null;
    notifyListeners();

    // Fetch immediate snapshot for instant latency & state before SSE stream ticks.
    try {
      final initial = await _api.fetchState(baseUrl: host.baseUrl, token: token);
      if (_disposed || activeHost?.id != host.id) return;
      _applySnapshot(host.id, initial.snapshot, latencyMs: initial.latencyMs);
      _phase = ConnectionPhase.connected;
      _backoffAttempt = 0;
      notifyListeners();
    } on CompanionApiException catch (e) {
      if (_disposed || activeHost?.id != host.id) return;
      if (e.isUnauthorized) {
        _markRevoked(host.id, e.message);
        return;
      }
      _scheduleReconnect(host.id, e.message);
      return;
    }

    _sseSub = _api
        .subscribeEvents(baseUrl: host.baseUrl, token: token)
        .listen(
      (snap) {
        if (_disposed || activeHost?.id != host.id) return;
        _backoffAttempt = 0;
        _phase = ConnectionPhase.connected;
        _connectionError = null;
        _applySnapshot(host.id, snap);
        notifyListeners();
      },
      onError: (Object err) {
        if (_disposed || activeHost?.id != host.id) return;
        if (err is CompanionApiException && err.isUnauthorized) {
          _markRevoked(host.id, err.message);
          return;
        }
        _scheduleReconnect(host.id, err.toString());
      },
      onDone: () {
        if (_disposed || activeHost?.id != host.id) return;
        if (_phase != ConnectionPhase.revoked) {
          _scheduleReconnect(host.id, 'Event stream closed');
        }
      },
    );
  }

  void _applySnapshot(String hostId, CompanionSnapshot snap, {int? latencyMs}) {
    final prev = _snapshot;
    _snapshot = snap;
    if (_selectedPaneId == null ||
        !snap.panes.any((p) => p.id == _selectedPaneId)) {
      _selectedPaneId = snap.panes.isNotEmpty ? snap.panes.first.id : null;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _hosts = _hosts.map((h) {
      if (h.id != hostId) return h;
      return h.copyWith(
        online: true,
        hostOs: snap.hostOs,
        paneCount: snap.panes.length,
        latencyMs: latencyMs ?? h.latencyMs,
        lastSeenUnix: now,
      );
    }).toList();

    _dispatchTransitionNotifications(prev, snap);
  }

  void _dispatchTransitionNotifications(
    CompanionSnapshot prev,
    CompanionSnapshot next,
  ) {
    for (final pane in next.panes) {
      final sig =
          '${pane.status}|${pane.rateLimit?.fromProfile ?? ''}|${pane.message ?? ''}';
      if (_notifiedSignatures[pane.id] == sig) continue;

      final hadPrev = prev.panes.any((p) => p.id == pane.id);
      _notifiedSignatures[pane.id] = sig;
      if (!hadPrev) continue;

      if (pane.status == 'needs_input' && _settings.notifInput) {
        _notifications.showApprovalAlert(
          paneId: pane.id,
          project: pane.projectName,
          agent: pane.label,
          command: pane.message ?? 'Waiting for your input',
        );
      } else if (pane.rateLimit != null && _settings.notifLimit) {
        final healthy = next.healthyProfilesFor(pane);
        _notifications.showRateLimitAlert(
          paneId: pane.id,
          project: pane.projectName,
          fromProfile: pane.rateLimit!.fromProfile,
          resetsIn: pane.rateLimit!.resetsInLabel,
          nextProfileId: healthy.isNotEmpty ? healthy.first.id : null,
        );
      } else if (pane.status == 'failed' && _settings.notifFailed) {
        _notifications.showFailedAlert(
          paneId: pane.id,
          project: pane.projectName,
          title: pane.statusLabel,
          message: pane.message ?? '${pane.label} failed',
        );
      }
    }
  }

  void _markRevoked(String hostId, String message) {
    _cancelStream();
    _phase = ConnectionPhase.revoked;
    _connectionError = message;
    _hosts = _hosts
        .map((h) => h.id == hostId ? h.copyWith(online: false) : h)
        .toList();
    notifyListeners();
  }

  void _scheduleReconnect(String hostId, String reason) {
    _cancelStream();
    _hosts = _hosts
        .map((h) => h.id == hostId ? h.copyWith(online: false) : h)
        .toList();
    _phase = ConnectionPhase.reconnecting;
    _connectionError = reason;

    const delays = [2, 4, 8, 15, 25];
    final sec = delays[_backoffAttempt.clamp(0, delays.length - 1)];
    _backoffAttempt++;
    _retryCountdownSec = sec;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      if (_retryCountdownSec > 1) {
        _retryCountdownSec--;
        notifyListeners();
      } else {
        t.cancel();
      }
    });

    _reconnectTimer = Timer(Duration(seconds: sec), () {
      if (!_disposed && activeHost?.id == hostId) {
        _connectActiveHost();
      }
    });
  }

  void _cancelStream() {
    _sseSub?.cancel();
    _sseSub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // ---------------------------------------------------------------- Actions

  Future<void> sendQuickAction(
    int paneId,
    String action, {
    bool skipBiometric = false,
  }) async {
    if (action == 'approve' && _settings.biometric && !skipBiometric) {
      final ok = await _notifications
          .authenticateBiometric('Confirm approval for agent command');
      if (!ok) {
        showToast('Approval cancelled');
        return;
      }
    }

    _triggerHaptic(strong: action == 'approve' || action == 'interrupt');

    if (isDemoMode) {
      _handleDemoQuickAction(paneId, action);
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      await _api.sendQuickAction(
        baseUrl: host.baseUrl,
        token: token,
        paneId: paneId,
        action: action,
      );
      final verb = action == 'approve'
          ? 'Approved'
          : action == 'reject'
              ? 'Rejected'
              : 'Interrupted (^C)';
      showToast(verb);
    } on CompanionApiException catch (e) {
      showToast(e.message);
    }
  }

  Future<void> sendTerminalInput(
    int paneId,
    String text, {
    bool enter = true,
    String? toastLabel,
  }) async {
    _triggerHaptic();
    if (isDemoMode) {
      _handleDemoInput(paneId, text, enter: enter, toastLabel: toastLabel);
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      await _api.sendInput(
        baseUrl: host.baseUrl,
        token: token,
        paneId: paneId,
        text: text,
        enter: enter,
      );
      showToast(toastLabel ?? 'Sent to pane');
    } on CompanionApiException catch (e) {
      showToast(e.message);
    }
  }

  Future<void> switchProfile(int paneId, String profileId) async {
    _triggerHaptic(strong: true);
    if (isDemoMode) {
      _handleDemoFailover(paneId, profileId);
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      await _api.switchProfile(
        baseUrl: host.baseUrl,
        token: token,
        paneId: paneId,
        profileId: profileId,
      );
      showToast('Switched to $profileId');
    } on CompanionApiException catch (e) {
      showToast(e.message);
    }
  }

  Future<void> resumeSession({
    required CompanionProject project,
    required CompanionSession session,
  }) async {
    _triggerHaptic();
    if (isDemoMode) {
      _tabIndex = 0;
      showToast('Resuming “${session.title}” in ${project.name}');
      notifyListeners();
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      await _api.resumeSession(
        baseUrl: host.baseUrl,
        token: token,
        projectId: project.id,
        agent: session.agent,
        sessionId: session.id,
        profileId: session.profile,
      );
      _tabIndex = 0;
      showToast('Resuming “${session.title}”');
      notifyListeners();
    } on CompanionApiException catch (e) {
      showToast(e.message);
    }
  }

  void toggleDemoFailoverMode() {
    final next = _snapshot.failoverMode == 'auto' ? 'manual' : 'auto';
    _snapshot = _snapshot.copyWith(failoverMode: next);
    showToast(
      'Failover: ${next == 'auto' ? 'Automatic' : 'Ask me'}${isDemoMode ? '' : ' (set on desktop)'}',
    );
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    await _storage.saveSettings(next);
    notifyListeners();
  }

  Future<ApkReleaseInfo> checkForApkUpdates({bool silent = false}) async {
    final info = await updater.checkForUpdate(_appVersion);
    if (!_disposed) {
      _availableUpdate = info;
      if (!silent && info.statusMessage != null) {
        showToast(info.statusMessage!);
      } else {
        notifyListeners();
      }
    }
    return info;
  }

  Future<void> sendTestApprovalNotification() async {
    await _notifications.showApprovalAlert(
      paneId: 1,
      project: 'storefront',
      agent: 'Claude Code',
      command: r'$ npm test -- auth',
    );
    showToast('Sent Android test notification');
  }

  // ---------------------------------------------------------------- Demo simulation helpers

  void _handleDemoQuickAction(int paneId, String action) {
    final panes = List<CompanionPane>.of(_snapshot.panes);
    final idx = panes.indexWhere((p) => p.id == paneId);
    if (idx == -1) return;
    final pane = panes[idx];

    if (action == 'approve') {
      panes[idx] = pane.copyWith(
        status: 'running',
        statusLabel: 'Running',
        output: '${pane.output}\n  ⎿  Approved from Android · running…',
      );
      _snapshot = _snapshot.copyWith(panes: panes);
      _selectedPaneId = pane.id;
      showToast('Approved ${pane.projectName} · ${pane.label}');
      notifyListeners();

      Timer(const Duration(milliseconds: 1200), () {
        if (_disposed || !isDemoMode) return;
        final curPanes = List<CompanionPane>.of(_snapshot.panes);
        final i = curPanes.indexWhere((p) => p.id == paneId);
        if (i == -1 || curPanes[i].status != 'running') return;
        curPanes[i] = curPanes[i].copyWith(
          status: 'done',
          statusLabel: 'Done',
          output:
              '${curPanes[i].output}\n  ⎿  Tests: 9 passed, 9 total\n⏺ Fixed. All 9 auth tests pass.',
        );
        _snapshot = _snapshot.copyWith(panes: curPanes);
        showToast('${pane.projectName} finished · 9 tests passed');
        notifyListeners();
      });
    } else if (action == 'reject') {
      panes[idx] = pane.copyWith(
        status: 'idle',
        statusLabel: 'Idle',
        output: '${pane.output}\n  ⎿  Rejected (Esc sent from phone)',
      );
      _snapshot = _snapshot.copyWith(panes: panes);
      showToast('Rejected command in ${pane.projectName}');
      notifyListeners();
    } else if (action == 'interrupt') {
      panes[idx] = pane.copyWith(
        status: 'idle',
        statusLabel: 'Idle',
        output: '${pane.output}\n^C Interrupted',
      );
      _snapshot = _snapshot.copyWith(panes: panes);
      showToast('Sent Ctrl+C to ${pane.projectName}');
      notifyListeners();
    }
  }

  void _handleDemoFailover(int paneId, String profileId) {
    final panes = List<CompanionPane>.of(_snapshot.panes);
    final idx = panes.indexWhere((p) => p.id == paneId);
    if (idx == -1) return;
    final pane = panes[idx];
    panes[idx] = pane.copyWith(
      profile: profileId,
      status: 'running',
      statusLabel: 'Running',
      clearRateLimit: true,
      output: '${pane.output}\n⇄ Switched to $profileId · resuming session…',
    );
    _snapshot = _snapshot.copyWith(panes: panes);
    _selectedPaneId = pane.id;
    _tabIndex = 0;
    showToast('Resuming ${pane.projectName} on $profileId');
    notifyListeners();
  }

  void _handleDemoInput(
    int paneId,
    String text, {
    required bool enter,
    String? toastLabel,
  }) {
    final panes = List<CompanionPane>.of(_snapshot.panes);
    final idx = panes.indexWhere((p) => p.id == paneId);
    if (idx == -1) return;
    final pane = panes[idx];
    if (text.trim().isNotEmpty && !text.startsWith('\x1B') && text != '\t') {
      panes[idx] = pane.copyWith(
        status: 'running',
        statusLabel: 'Running',
        output: '${pane.output}\n❯ $text\n◦ Processing…',
      );
      _snapshot = _snapshot.copyWith(panes: panes);
    }
    showToast(toastLabel ?? 'Instruction sent');
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelStream();
    _toastTimer?.cancel();
    _api.dispose();
    updater.dispose();
    super.dispose();
  }
}
