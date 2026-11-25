import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/companion_models.dart';
import '../models/demo_fixtures.dart';
import '../models/host_models.dart';
import '../services/apk_updater.dart';
import '../services/companion_api.dart';
import '../services/interactive_prompt_parser.dart';
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
    this.enterDelay = const Duration(milliseconds: 220),
    this.menuKeyDelay = const Duration(milliseconds: 75),
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

  /// Pause between writing prompt text and sending standalone `\r` so TUI
  /// paste-burst detectors (Codex CLI, Claude Code, OpenCode, Antigravity)
  /// submit the prompt instead of inserting a newline.
  final Duration enterDelay;

  /// Pause between consecutive arrow keypresses when selecting an item in an
  /// interactive TUI menu (Claude Code trust/permission, Codex, Gemini, etc.).
  final Duration menuKeyDelay;

  ApkReleaseInfo? _availableUpdate;
  ApkReleaseInfo? get availableUpdate => _availableUpdate;

  String _appVersion = '0.3.6';
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
  int _consecutiveFailures = 0;
  bool _hasSnapshotForHost = false;
  bool _appInBackground = false;
  DateTime? _pausedAt;
  DateTime? _lastStreamActivityAt;
  bool _connecting = false;
  bool _disposed = false;
  Future<void> _sendQueue = Future<void>.value();

  /// Only hijack `LiveScreen` with the full-screen `OfflineHostView` if the
  /// device was revoked or the host stayed unreachable for multiple retries
  /// (or has never loaded a snapshot yet). Brief Wi-Fi/background drops keep
  /// the terminal visible with a compact reconnecting banner instead.
  bool get showOfflineWall {
    if (_phase == ConnectionPhase.revoked) return true;
    if (_phase != ConnectionPhase.reconnecting) return false;
    return !_hasSnapshotForHost || _consecutiveFailures >= 3;
  }

  /// True while recovering a live connection in the background without hiding
  /// the terminal canvas.
  bool get isSoftReconnecting =>
      !showOfflineWall &&
      (_phase == ConnectionPhase.reconnecting ||
          (_phase == ConnectionPhase.connecting && _hasSnapshotForHost));

  // Deduplication map: paneId -> last notified status signature
  final Map<int, String> _notifiedSignatures = {};

  // Auto-focus newly spawned/resumed pane when SSE delivers it
  int? _pendingSpawnProjectId;
  bool _pendingSpawnIsShell = false;
  Set<int> _paneIdsBeforeSpawn = const {};

  // Shells explicitly opened from mobile (fallback for older desktop <v0.3.16
  // that does not yet emit `remote_opened: true`)
  final Set<int> _locallyOpenedShellIds = {};

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

  /// Reacts to Android/iOS foreground/background transitions so returning from
  /// WhatsApp or a locked screen immediately heals the SSE stream without
  /// leaving the user staring at a stale "Retry now" countdown.
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (_disposed || !isPaired || isDemoMode) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appInBackground = true;
      _pausedAt = DateTime.now();
      if (!_settings.keepAlive) {
        // User disabled background keep-alive: release SSE socket immediately
        // to save battery/radio, and reconnect seamlessly on resume.
        _cancelStream();
        return;
      }
      // Pause retry timers while backgrounded so OS background network blocks
      // do not inflate backoff to 10-25s before the user returns.
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final wasPaused = _pausedAt;
      _appInBackground = false;
      _pausedAt = null;
      if (_phase == ConnectionPhase.revoked) return;

      final pausedLong = wasPaused != null &&
          DateTime.now().difference(wasPaused) >= const Duration(seconds: 4);
      final staleStream = _lastStreamActivityAt == null ||
          DateTime.now().difference(_lastStreamActivityAt!) >=
              const Duration(seconds: 12);

      if (_phase != ConnectionPhase.connected ||
          _sseSub == null ||
          pausedLong ||
          staleStream) {
        _backoffAttempt = 0;
        _consecutiveFailures = 0;
        unawaited(_connectActiveHost(silent: _hasSnapshotForHost));
      }
    }
  }

  void openAlertProject(String projectName) {
    final lower = projectName.trim().toLowerCase();
    for (final p in _snapshot.panes) {
      if (p.projectName.toLowerCase() == lower) {
        focusPane(p.id);
        return;
      }
    }
    _projectQuery = projectName;
    _tabIndex = 2;
    notifyListeners();
  }

  /// Launches the interactive Slate demo workspace so users can preview every screen immediately.
  Future<void> enterDemoMode() async {
    _cancelStream();
    _hosts = DemoFixtures.hosts();
    _activeHostId = _hosts.first.id;
    _snapshot = DemoFixtures.snapshot();
    _selectedPaneId = _snapshot.panes.first.id;
    _hasSnapshotForHost = true;
    _consecutiveFailures = 0;
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
      _locallyOpenedShellIds.clear();
      final filteredInitial = initialSnap.copyWith(
        panes: initialSnap.panes.where((p) => !p.isBareIdleShell).toList(),
      );
      _snapshot = filteredInitial;
      _hasSnapshotForHost = true;
      _consecutiveFailures = 0;
      _selectedPaneId = filteredInitial.panes.isNotEmpty
          ? filteredInitial.panes.first.id
          : null;

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
    _hasSnapshotForHost = false;
    _consecutiveFailures = 0;
    _backoffAttempt = 0;
    _locallyOpenedShellIds.clear();
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
        _hasSnapshotForHost = true;
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
      _hasSnapshotForHost = true;
      _consecutiveFailures = 0;
      _connectionError = null;
      _snapshot = DemoFixtures.snapshot();
      _selectedPaneId = _snapshot.panes.first.id;
      showToast('Reconnected to ${host.name}');
      notifyListeners();
      return;
    }
    _backoffAttempt = 0;
    _consecutiveFailures = 0;
    await _connectActiveHost(silent: _hasSnapshotForHost);
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
    _hasSnapshotForHost = false;
    _consecutiveFailures = 0;
    _locallyOpenedShellIds.clear();
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

  Future<void> _connectActiveHost({bool silent = false}) async {
    if (_connecting) return;
    _connecting = true;
    try {
      _cancelStream();
      final host = activeHost;
      if (host == null) return;
      if (host.isDemo) {
        _phase = ConnectionPhase.connected;
        _hasSnapshotForHost = true;
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

      if (!silent) {
        _phase = ConnectionPhase.connecting;
        _connectionError = null;
        notifyListeners();
      }

      // Fetch immediate snapshot for instant latency & state before SSE stream ticks.
      try {
        final initial =
            await _api.fetchState(baseUrl: host.baseUrl, token: token);
        if (_disposed || activeHost?.id != host.id) return;
        _applySnapshot(host.id, initial.snapshot, latencyMs: initial.latencyMs);
        _phase = ConnectionPhase.connected;
        _hasSnapshotForHost = true;
        _backoffAttempt = 0;
        _consecutiveFailures = 0;
        _lastStreamActivityAt = DateTime.now();
        _connectionError = null;
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
          .subscribeEvents(
        baseUrl: host.baseUrl,
        token: token,
        onKeepAlive: () {
          if (_disposed || activeHost?.id != host.id) return;
          _lastStreamActivityAt = DateTime.now();
          _backoffAttempt = 0;
          _consecutiveFailures = 0;
          if (_phase != ConnectionPhase.connected) {
            _phase = ConnectionPhase.connected;
            _connectionError = null;
            notifyListeners();
          }
        },
      )
          .listen(
        (snap) {
          if (_disposed || activeHost?.id != host.id) return;
          _lastStreamActivityAt = DateTime.now();
          _backoffAttempt = 0;
          _consecutiveFailures = 0;
          _hasSnapshotForHost = true;
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
    } finally {
      _connecting = false;
    }
  }

  void _applySnapshot(String hostId, CompanionSnapshot rawSnap, {int? latencyMs}) {
    final prev = _snapshot;

    // Prune locally tracked shells that desktop has since closed.
    final rawIds = rawSnap.panes.map((p) => p.id).toSet();
    _locallyOpenedShellIds.removeWhere((id) => !rawIds.contains(id));

    // If user just spawned/resumed on a project, catch the newly created (or
    // woken) pane before filtering so explicitly spawned shells stay visible
    // even on older desktops (<v0.3.16) that omit `remote_opened`.
    int? autoFocusId;
    if (_pendingSpawnProjectId != null) {
      final targetProj = _pendingSpawnProjectId!;
      final spawned = rawSnap.panes.where(
        (p) =>
            p.projectId == targetProj &&
            !_paneIdsBeforeSpawn.contains(p.id) &&
            (_pendingSpawnIsShell || !p.isBareIdleShell),
      );
      if (spawned.isNotEmpty) {
        autoFocusId = spawned.last.id;
        if (_pendingSpawnIsShell) {
          _locallyOpenedShellIds.add(autoFocusId);
        }
        _pendingSpawnProjectId = null;
        _pendingSpawnIsShell = false;
        _paneIdsBeforeSpawn = const {};
      }
    }

    // Never let untouched idle default shells (`zsh · Idle`) pollute ACTIVE/Live.
    final visiblePanes = rawSnap.panes
        .where(
          (p) => !p.isBareIdleShell || _locallyOpenedShellIds.contains(p.id),
        )
        .toList();
    final snap = rawSnap.copyWith(panes: visiblePanes);
    _snapshot = snap;

    if (autoFocusId != null && snap.panes.any((p) => p.id == autoFocusId)) {
      _selectedPaneId = autoFocusId;
    }

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
    final activeIds = next.panes.map((p) => p.id).toSet();
    _notifiedSignatures.removeWhere((id, _) => !activeIds.contains(id));

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
    _connectionError = reason;

    // While app is backgrounded on Android, pause retries instead of climbing
    // backoff to 10s+; `onAppLifecycleChanged(resumed)` will heal instantly.
    if (_appInBackground) {
      _phase = ConnectionPhase.reconnecting;
      notifyListeners();
      return;
    }

    _consecutiveFailures++;
    _hosts = _hosts
        .map((h) => h.id == hostId ? h.copyWith(online: false) : h)
        .toList();
    _phase = ConnectionPhase.reconnecting;

    // First retry fires almost immediately (350ms) so momentary Wi-Fi roams or
    // desktop ticks recover invisibly without ever flashing "Retry now".
    const delaysMs = [350, 1000, 2000, 4000, 8000, 10000];
    final delayMs = delaysMs[_backoffAttempt.clamp(0, delaysMs.length - 1)];
    _backoffAttempt++;
    final sec = (delayMs / 1000).ceil();
    _retryCountdownSec = delayMs >= 1000 ? sec : 0;
    notifyListeners();

    if (delayMs >= 1000) {
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
    }

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_disposed && !_appInBackground && activeHost?.id == hostId) {
        _connectActiveHost(silent: _hasSnapshotForHost);
      }
    });
  }

  void _handleActionError(String hostId, CompanionApiException e) {
    if (e.isUnauthorized) {
      _markRevoked(hostId, e.message);
    } else if (e.isNetwork && _phase == ConnectionPhase.connected) {
      _scheduleReconnect(hostId, e.message);
    }
    showToast(e.message);
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
      if (action == 'dismiss_limit') {
        _optimisticallyDismissRateLimit(paneId);
      }
      final verb = action == 'approve'
          ? 'Approved'
          : action == 'reject'
              ? 'Rejected'
              : action == 'dismiss_limit'
                  ? 'Dismissed rate-limit notice'
                  : 'Interrupted (^C)';
      showToast(verb);
    } on CompanionApiException catch (e) {
      _handleActionError(host.id, e);
    }
  }

  /// Dismisses a stale rate-limit banner on `paneId` and clears profile cooldown
  /// on desktop when no other pane is still blocked on that profile.
  Future<void> dismissRateLimit(int paneId) {
    return sendQuickAction(paneId, 'dismiss_limit', skipBiometric: true);
  }

  /// Asks desktop (`v0.3.20+`) to refresh recent session history for `projectId`
  /// and its worktrees so the Run / Resume Agent popup shows up-to-date items.
  Future<void> refreshProjectSessions(int projectId) async {
    if (isDemoMode) return;
    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;
    try {
      await _api.refreshProjectSessions(
        baseUrl: host.baseUrl,
        token: token,
        projectId: projectId,
      );
    } catch (_) {
      // Best-effort background refresh; older desktops safely ignore it.
    }
  }

  void _optimisticallyDismissRateLimit(int paneId) {
    final panes = List<CompanionPane>.of(_snapshot.panes);
    final idx = panes.indexWhere((p) => p.id == paneId);
    if (idx == -1) return;
    final pane = panes[idx];
    final profId = pane.rateLimit?.fromProfile ?? pane.profile;
    panes[idx] = pane.copyWith(
      clearRateLimit: true,
      status: pane.status == 'rate_limited' ? 'idle' : pane.status,
      statusLabel: pane.status == 'rate_limited' ? 'Idle' : pane.statusLabel,
    );
    var profiles = _snapshot.profiles;
    if (profId != null && profId.isNotEmpty) {
      final stillLimited = panes.any(
        (p) => p.id != paneId && p.rateLimit?.fromProfile == profId,
      );
      if (!stillLimited) {
        profiles = profiles
            .map((pr) => pr.id == profId &&
                    (pr.state == 'rate_limited' || pr.state == 'cooldown')
                ? pr.copyWith(state: 'idle', clearResetsAt: true)
                : pr)
            .toList();
      }
    }
    _snapshot = _snapshot.copyWith(panes: panes, profiles: profiles);
    notifyListeners();
  }

  Future<void> sendTerminalInput(
    int paneId,
    String text, {
    bool enter = true,
    String? toastLabel,
    bool silent = false,
  }) {
    if (!silent) {
      _triggerHaptic();
    }
    if (isDemoMode) {
      _handleDemoInput(
        paneId,
        text,
        enter: enter,
        toastLabel: silent ? null : toastLabel,
      );
      return Future<void>.value();
    }

    // Serialize writes in FIFO order so rapid sends never interleave text & Enter.
    final next = _sendQueue.then((_) => _performSendTerminalInput(
          paneId,
          text,
          enter: enter,
          toastLabel: toastLabel,
          silent: silent,
        ));
    _sendQueue = next.catchError((_) {});
    return next;
  }

  /// Answers a detected interactive TUI prompt (e.g. Claude Code workspace trust
  /// dialog, permission menu, Codex/Gemini confirmation, or `[Y/n]` prompt) by
  /// sending the exact arrow delta + Enter or confirmation key sequence.
  Future<void> selectInteractiveOption(
    int paneId,
    InteractivePrompt prompt,
    InteractivePromptOption option,
  ) async {
    switch (prompt.kind) {
      case PromptInputKind.tuiMenu:
        final delta = option.index - prompt.selectedIndex;
        if (delta != 0) {
          final seq = delta > 0 ? '\x1B[B' : '\x1B[A';
          final steps = delta.abs();
          for (var s = 0; s < steps; s++) {
            await sendTerminalInput(
              paneId,
              seq,
              enter: false,
              silent: true,
            );
            if (menuKeyDelay > Duration.zero) {
              await Future<void>.delayed(menuKeyDelay);
            }
          }
        }
        await sendTerminalInput(
          paneId,
          '',
          enter: true,
          toastLabel: 'Selected: ${option.label}',
        );
      case PromptInputKind.yesNo:
        final key = option.shortcutKey ?? (option.index == 0 ? 'y' : 'n');
        await sendTerminalInput(
          paneId,
          key,
          enter: true,
          toastLabel: 'Sent ${option.label}',
        );
      case PromptInputKind.confirmCancel:
        if (option.shortcutKey == 'esc') {
          await sendTerminalInput(
            paneId,
            '\x1B',
            enter: false,
            toastLabel: 'Sent Esc',
          );
        } else {
          await sendTerminalInput(
            paneId,
            '',
            enter: true,
            toastLabel: 'Confirmed',
          );
        }
    }
  }

  Future<void> _performSendTerminalInput(
    int paneId,
    String text, {
    required bool enter,
    String? toastLabel,
    bool silent = false,
  }) async {
    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      final normalized = text.replaceAll('\r\n', '\n');
      final clean = enter && normalized.isNotEmpty
          ? normalized.replaceFirst(RegExp(r'[\r\n]+$'), '')
          : normalized;

      if (enter && clean.isNotEmpty) {
        // Wrap multi-line prompts in ANSI bracketed paste so inner newlines do
        // not submit early, then send standalone Enter after `enterDelay` so TUI
        // paste-burst detectors submit instead of inserting a trailing newline.
        final payload =
            clean.contains('\n') ? '\x1B[200~$clean\x1B[201~' : clean;
        await _api.sendInput(
          baseUrl: host.baseUrl,
          token: token,
          paneId: paneId,
          text: payload,
          enter: false,
        );
        if (enterDelay > Duration.zero) {
          await Future<void>.delayed(enterDelay);
        }
        if (_disposed || activeHost?.id != host.id) return;
        await _api.sendInput(
          baseUrl: host.baseUrl,
          token: token,
          paneId: paneId,
          text: '',
          enter: true,
        );
      } else {
        await _api.sendInput(
          baseUrl: host.baseUrl,
          token: token,
          paneId: paneId,
          text: clean,
          enter: enter,
        );
      }
      if (!silent) {
        showToast(toastLabel ?? 'Sent to pane');
      }
    } on CompanionApiException catch (e) {
      _handleActionError(host.id, e);
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
      _handleActionError(host.id, e);
    }
  }

  Future<void> resumeSession({
    required CompanionProject project,
    required CompanionSession session,
    CompanionWorktree? worktree,
    String? profileId,
  }) async {
    _triggerHaptic();
    final targetId =
        (worktree != null && worktree.id > 0) ? worktree.id : project.id;
    final targetName =
        worktree != null ? '${project.name} › ${worktree.name}' : project.name;
    final targetBranch = worktree?.branch ?? project.branch;
    final chosenProfile = (profileId != null && profileId.isNotEmpty)
        ? profileId
        : session.profile;

    if (isDemoMode) {
      if (session.livePane != null &&
          _snapshot.panes.any((p) => p.id == session.livePane)) {
        focusPane(session.livePane!);
        return;
      }
      final nextId =
          _snapshot.panes.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;
      final label = _agentDisplayLabel(session.agent);
      final newPane = CompanionPane(
        id: nextId,
        projectId: targetId,
        parentProjectId: worktree != null ? project.id : null,
        projectName: targetName,
        label: label,
        task: session.title,
        branch: targetBranch,
        provider: label,
        profile: chosenProfile ?? _defaultProfileFor(session.agent),
        supportsProfiles: session.agent == 'claude' ||
            session.agent == 'codex' ||
            session.agent == 'antigravity',
        status: 'running',
        statusLabel: 'Running',
        message: 'Resumed ${session.title}',
        age: 'now',
        output: '● Resumed $label session “${session.title}” in $targetName…',
      );
      _snapshot = _snapshot.copyWith(panes: [newPane, ..._snapshot.panes]);
      _selectedPaneId = nextId;
      _tabIndex = 0;
      showToast('Resuming “${session.title}” in $targetName');
      notifyListeners();
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    _pendingSpawnProjectId = targetId;
    _pendingSpawnIsShell = false;
    _paneIdsBeforeSpawn = _snapshot.panes
        .where((p) => p.projectId == targetId)
        .map((p) => p.id)
        .toSet();

    try {
      await _api.resumeSession(
        baseUrl: host.baseUrl,
        token: token,
        projectId: targetId,
        agent: session.agent,
        sessionId: session.id,
        profileId: chosenProfile,
      );
      _tabIndex = 0;
      showToast('Resuming “${session.title}”');
      notifyListeners();
    } on CompanionApiException catch (e) {
      _pendingSpawnProjectId = null;
      _paneIdsBeforeSpawn = const {};
      _handleActionError(host.id, e);
    }
  }

  /// Spawns a new agent (or plain terminal `'shell'`) inside `project` (or `worktree`).
  Future<void> spawnAgent({
    required CompanionProject project,
    required String agent,
    String? profileId,
    CompanionWorktree? worktree,
  }) async {
    _triggerHaptic(strong: true);
    final label = _agentDisplayLabel(agent);
    final targetId =
        (worktree != null && worktree.id > 0) ? worktree.id : project.id;
    final targetName =
        worktree != null ? '${project.name} › ${worktree.name}' : project.name;
    final targetBranch = worktree?.branch ?? project.branch;

    if (isDemoMode) {
      final nextId =
          _snapshot.panes.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;
      final isShell = agent == 'shell';
      final chosenProfile =
          isShell ? null : (profileId ?? _defaultProfileFor(agent));
      final newPane = CompanionPane(
        id: nextId,
        projectId: targetId,
        parentProjectId: worktree != null ? project.id : null,
        projectName: targetName,
        label: label,
        branch: targetBranch,
        provider: isShell ? null : label,
        profile: chosenProfile,
        supportsProfiles: !isShell &&
            (agent == 'claude' ||
                agent == 'codex' ||
                agent == 'antigravity'),
        status: 'running',
        statusLabel: 'Running',
        message: 'Started $label',
        age: 'now',
        output: isShell
            ? '~/code/$targetName ${targetBranch ?? 'main'} ❯ '
            : '● Starting $label in $targetName…\n◦ Ready for your instruction',
      );
      _snapshot = _snapshot.copyWith(panes: [newPane, ..._snapshot.panes]);
      _selectedPaneId = nextId;
      _tabIndex = 0;
      showToast('Started $label in $targetName');
      notifyListeners();
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    _pendingSpawnProjectId = targetId;
    _pendingSpawnIsShell = agent == 'shell';
    _paneIdsBeforeSpawn = _snapshot.panes
        .where((p) => p.projectId == targetId)
        .map((p) => p.id)
        .toSet();

    try {
      await _api.spawnAgent(
        baseUrl: host.baseUrl,
        token: token,
        projectId: targetId,
        agent: agent,
        profileId: profileId,
      );
      _tabIndex = 0;
      showToast('Starting $label in $targetName…');
      notifyListeners();
    } on CompanionApiException catch (e) {
      _pendingSpawnProjectId = null;
      _pendingSpawnIsShell = false;
      _paneIdsBeforeSpawn = const {};
      _handleActionError(host.id, e);
    }
  }

  /// Closes an active agent or terminal pane on desktop (removing it from Active).
  Future<void> closePane(CompanionPane pane) async {
    _triggerHaptic(strong: true);
    if (isDemoMode) {
      final remaining = _snapshot.panes.where((p) => p.id != pane.id).toList();
      _snapshot = _snapshot.copyWith(panes: remaining);
      if (_selectedPaneId == pane.id) {
        _selectedPaneId = remaining.isNotEmpty ? remaining.first.id : null;
      }
      showToast('Closed ${pane.label} in ${pane.projectName}');
      notifyListeners();
      return;
    }

    final host = activeHost;
    if (host == null) return;
    final token = await _storage.readToken(host.id);
    if (token == null) return;

    try {
      await _api.closePane(
        baseUrl: host.baseUrl,
        token: token,
        paneId: pane.id,
      );
      _locallyOpenedShellIds.remove(pane.id);
      final remaining = _snapshot.panes.where((p) => p.id != pane.id).toList();
      _snapshot = _snapshot.copyWith(panes: remaining);
      if (_selectedPaneId == pane.id) {
        _selectedPaneId = remaining.isNotEmpty ? remaining.first.id : null;
      }
      showToast('Closed ${pane.label} in ${pane.projectName}');
      notifyListeners();
    } on CompanionApiException catch (e) {
      _handleActionError(host.id, e);
    }
  }

  String? _defaultProfileFor(String agentSlug) {
    for (final p in _snapshot.profiles) {
      if (p.enabled && p.agentKey == agentSlug && p.state != 'rate_limited') {
        return p.id;
      }
    }
    return null;
  }

  static String _agentDisplayLabel(String slug) {
    switch (slug) {
      case 'claude':
        return 'Claude Code';
      case 'codex':
        return 'Codex';
      case 'antigravity':
        return 'Antigravity';
      case 'opencode':
        return 'OpenCode';
      case 'gemini':
        return 'Gemini CLI';
      default:
        return 'Terminal';
    }
  }

  void toggleDemoFailoverMode() {
    if (!isDemoMode) {
      showToast('Configure failover mode in Desktop Settings → Accounts');
      return;
    }
    final next = _snapshot.failoverMode == 'auto' ? 'manual' : 'auto';
    _snapshot = _snapshot.copyWith(failoverMode: next);
    showToast('Failover: ${next == 'auto' ? 'Automatic' : 'Ask me'}');
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
    } else if (action == 'dismiss_limit') {
      _optimisticallyDismissRateLimit(paneId);
      showToast('Dismissed rate-limit notice');
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
