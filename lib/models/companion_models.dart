import '../theme/agent_icons.dart';

/// Exact Dart mirror of `CompanionSnapshot` in desktop `src/companion.rs`.
class CompanionSnapshot {
  const CompanionSnapshot({
    this.hostOs = 'computer',
    this.failoverMode = 'auto',
    this.projects = const [],
    this.panes = const [],
    this.profiles = const [],
    this.alerts = const [],
  });

  final String hostOs;
  final String failoverMode;
  final List<CompanionProject> projects;
  final List<CompanionPane> panes;
  final List<CompanionProfile> profiles;
  final List<CompanionAlert> alerts;

  factory CompanionSnapshot.fromJson(Map<String, dynamic> json) {
    return CompanionSnapshot(
      hostOs: (json['host_os'] as String?) ?? 'computer',
      failoverMode: (json['failover_mode'] as String?) ?? 'auto',
      projects: ((json['projects'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionProject.fromJson)
          .toList(),
      panes: ((json['panes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionPane.fromJson)
          .toList(),
      profiles: ((json['profiles'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionProfile.fromJson)
          .toList(),
      alerts: ((json['alerts'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionAlert.fromJson)
          .toList(),
    );
  }

  CompanionSnapshot copyWith({
    String? hostOs,
    String? failoverMode,
    List<CompanionProject>? projects,
    List<CompanionPane>? panes,
    List<CompanionProfile>? profiles,
    List<CompanionAlert>? alerts,
  }) {
    return CompanionSnapshot(
      hostOs: hostOs ?? this.hostOs,
      failoverMode: failoverMode ?? this.failoverMode,
      projects: projects ?? this.projects,
      panes: panes ?? this.panes,
      profiles: profiles ?? this.profiles,
      alerts: alerts ?? this.alerts,
    );
  }

  int get waitingCount =>
      panes.where((p) => p.status == 'needs_input' || p.rateLimit != null).length;

  int get urgentInboxCount => panes
      .where((p) =>
          p.status == 'needs_input' ||
          p.status == 'failed' ||
          p.rateLimit != null)
      .length;

  int get runningCount =>
      panes.where((p) => p.status == 'running' || p.status == 'needs_input').length;

  int get healthyProfileCount => profiles
      .where((p) =>
          p.enabled &&
          p.state != 'rate_limited' &&
          p.state != 'cooldown' &&
          p.state != 'error')
      .length;

  int get total5hTokens => profiles.fold<int>(
        0,
        (sum, p) => sum + (p.window5h?.tokens ?? (p.tokensIn + p.tokensOut)),
      );

  /// Healthy replacement profiles for a pane, prioritizing same provider first.
  List<CompanionProfile> healthyProfilesFor(CompanionPane pane) {
    final list = profiles
        .where((p) =>
            p.enabled &&
            p.state != 'rate_limited' &&
            p.state != 'cooldown' &&
            p.state != 'error' &&
            p.id != pane.profile)
        .toList();
    list.sort((a, b) {
      final aSame = pane.provider != null && a.provider == pane.provider ? 0 : 1;
      final bSame = pane.provider != null && b.provider == pane.provider ? 0 : 1;
      return aSame.compareTo(bSame);
    });
    return list;
  }
}

class CompanionProject {
  const CompanionProject({
    required this.id,
    required this.name,
    this.branch,
    this.sessions = const [],
    this.worktrees = const [],
  });

  final int id;
  final String name;
  final String? branch;
  final List<CompanionSession> sessions;
  final List<CompanionWorktree> worktrees;

  factory CompanionProject.fromJson(Map<String, dynamic> json) {
    return CompanionProject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'project',
      branch: json['branch'] as String?,
      sessions: ((json['sessions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionSession.fromJson)
          .toList(),
      worktrees: ((json['worktrees'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionWorktree.fromJson)
          .toList(),
    );
  }
}

class CompanionWorktree {
  const CompanionWorktree({
    this.id = 0,
    required this.name,
    required this.branch,
    this.merged = false,
    this.status = 'idle',
    this.sessions = const [],
  });

  final int id;
  final String name;
  final String branch;
  final bool merged;
  final String status;
  final List<CompanionSession> sessions;

  factory CompanionWorktree.fromJson(Map<String, dynamic> json) {
    return CompanionWorktree(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      branch: (json['branch'] as String?) ?? '',
      merged: (json['merged'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'idle',
      sessions: ((json['sessions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompanionSession.fromJson)
          .toList(),
    );
  }
}

class CompanionSession {
  const CompanionSession({
    required this.id,
    required this.title,
    required this.agent,
    this.profile,
    this.status = 'idle',
    this.age = '',
    this.livePane,
  });

  final String id;
  final String title;
  final String agent;
  final String? profile;
  final String status;
  final String age;
  final int? livePane;

  factory CompanionSession.fromJson(Map<String, dynamic> json) {
    return CompanionSession(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled session',
      agent: (json['agent'] as String?) ?? 'claude',
      profile: json['profile'] as String?,
      status: (json['status'] as String?) ?? 'idle',
      age: (json['age'] as String?) ?? '',
      livePane: (json['live_pane'] as num?)?.toInt(),
    );
  }

  bool get canResume =>
      livePane == null && id.isNotEmpty && !id.startsWith('pane-');
}

class CompanionPane {
  const CompanionPane({
    required this.id,
    required this.projectId,
    this.parentProjectId,
    required this.projectName,
    required this.label,
    this.task,
    this.branch,
    this.provider,
    this.profile,
    this.supportsProfiles = false,
    this.status = 'idle',
    this.statusLabel = 'Idle',
    this.message,
    this.output = '',
    this.rateLimit,
    this.age = 'now',
    this.remoteOpened = false,
  });

  final int id;
  final int projectId;
  final int? parentProjectId;
  final String projectName;
  final String label;
  final String? task;
  final String? branch;
  final String? provider;
  final String? profile;
  final bool supportsProfiles;
  final String status;
  final String statusLabel;
  final String? message;
  final String output;
  final CompanionRateLimit? rateLimit;
  final String age;
  final bool remoteOpened;

  factory CompanionPane.fromJson(Map<String, dynamic> json) {
    return CompanionPane(
      id: (json['id'] as num?)?.toInt() ?? 0,
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      parentProjectId: (json['parent_project_id'] as num?)?.toInt(),
      projectName: (json['project_name'] as String?) ?? 'workspace',
      label: (json['label'] as String?) ?? 'shell',
      task: json['task'] as String?,
      branch: json['branch'] as String?,
      provider: json['provider'] as String?,
      profile: json['profile'] as String?,
      supportsProfiles: (json['supports_profiles'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'idle',
      statusLabel: (json['status_label'] as String?) ?? 'Idle',
      message: json['message'] as String?,
      output: (json['output'] as String?) ?? '',
      rateLimit: json['rate_limit'] is Map<String, dynamic>
          ? CompanionRateLimit.fromJson(
              json['rate_limit'] as Map<String, dynamic>)
          : null,
      age: (json['age'] as String?) ?? 'live',
      remoteOpened: (json['remote_opened'] as bool?) ?? false,
    );
  }

  CompanionPane copyWith({
    String? profile,
    String? status,
    String? statusLabel,
    String? message,
    String? output,
    CompanionRateLimit? rateLimit,
    bool clearRateLimit = false,
    bool? remoteOpened,
  }) {
    return CompanionPane(
      id: id,
      projectId: projectId,
      parentProjectId: parentProjectId,
      projectName: projectName,
      label: label,
      task: task,
      branch: branch,
      provider: provider,
      profile: profile ?? this.profile,
      supportsProfiles: supportsProfiles,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      message: message ?? this.message,
      output: output ?? this.output,
      rateLimit: clearRateLimit ? null : (rateLimit ?? this.rateLimit),
      age: age,
      remoteOpened: remoteOpened ?? this.remoteOpened,
    );
  }

  /// Root project id (parent repo id when running inside a git worktree).
  int get rootProjectId => parentProjectId ?? projectId;

  /// Sidebar display title matching Desktop (`task` prompt/rename when available, else agent label).
  String get displayTitle {
    final t = task?.trim();
    return (t != null && t.isNotEmpty) ? t : label;
  }

  String get effectiveStatus => rateLimit != null ? 'rate_limited' : status;

  String get effectiveStatusLabel =>
      rateLimit != null ? 'Rate limited' : statusLabel;

  String get agentKey =>
      AgentTile.normalizeAgent(provider ?? label);

  bool get isUrgent =>
      status == 'needs_input' || status == 'failed' || rateLimit != null;

  /// True when this pane is just an untouched/idle default shell (no AI agent,
  /// no active/running/failed process, not explicitly opened from mobile).
  bool get isBareIdleShell {
    final isShell =
        (provider == null || provider!.isEmpty) && agentKey == 'shell';
    return isShell &&
        rateLimit == null &&
        status == 'idle' &&
        !remoteOpened;
  }
}

class CompanionRateLimit {
  const CompanionRateLimit({
    required this.fromProfile,
    required this.reason,
    required this.resetsAtUnix,
  });

  final String fromProfile;
  final String reason;
  final int resetsAtUnix;

  factory CompanionRateLimit.fromJson(Map<String, dynamic> json) {
    return CompanionRateLimit(
      fromProfile: (json['from_profile'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? 'Rate limit reached',
      resetsAtUnix: (json['resets_at_unix'] as num?)?.toInt() ?? 0,
    );
  }

  String get resetsInLabel => formatResetCountdown(resetsAtUnix) ?? 'soon';
}

class CompanionWindowQuota {
  const CompanionWindowQuota({
    required this.label,
    this.usedPct,
    this.tokens = 0,
    this.resetsAtUnix,
  });

  final String label;
  final double? usedPct;
  final int tokens;
  final int? resetsAtUnix;

  factory CompanionWindowQuota.fromJson(Map<String, dynamic> json) {
    return CompanionWindowQuota(
      label: (json['label'] as String?) ?? 'Window',
      usedPct: (json['used_pct'] as num?)?.toDouble(),
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      resetsAtUnix: (json['resets_at_unix'] as num?)?.toInt(),
    );
  }
}

class CompanionProfile {
  const CompanionProfile({
    required this.id,
    required this.name,
    required this.provider,
    this.accountHint,
    this.planType,
    this.signedIn,
    this.state = 'idle',
    this.enabled = true,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.quotaPct,
    this.resetsAtUnix,
    this.window5h,
    this.windowWeekly,
    this.activeSession,
  });

  final String id;
  final String name;
  final String provider;
  final String? accountHint;
  final String? planType;
  final bool? signedIn;
  final String state;
  final bool enabled;
  final int tokensIn;
  final int tokensOut;
  final double? quotaPct;
  final int? resetsAtUnix;
  final CompanionWindowQuota? window5h;
  final CompanionWindowQuota? windowWeekly;
  final String? activeSession;

  factory CompanionProfile.fromJson(Map<String, dynamic> json) {
    return CompanionProfile(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? 'Agent',
      accountHint: json['account_hint'] as String?,
      planType: json['plan_type'] as String?,
      signedIn: json['signed_in'] as bool?,
      state: (json['state'] as String?) ?? 'idle',
      enabled: (json['enabled'] as bool?) ?? true,
      tokensIn: (json['tokens_in'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokens_out'] as num?)?.toInt() ?? 0,
      quotaPct: (json['quota_pct'] as num?)?.toDouble(),
      resetsAtUnix: (json['resets_at_unix'] as num?)?.toInt(),
      window5h: json['window_5h'] is Map<String, dynamic>
          ? CompanionWindowQuota.fromJson(
              json['window_5h'] as Map<String, dynamic>)
          : null,
      windowWeekly: json['window_weekly'] is Map<String, dynamic>
          ? CompanionWindowQuota.fromJson(
              json['window_weekly'] as Map<String, dynamic>)
          : null,
      activeSession: json['active_session'] as String?,
    );
  }

  CompanionProfile copyWith({
    String? state,
    bool? enabled,
    int? resetsAtUnix,
    bool clearResetsAt = false,
  }) {
    return CompanionProfile(
      id: id,
      name: name,
      provider: provider,
      accountHint: accountHint,
      planType: planType,
      signedIn: signedIn,
      state: state ?? this.state,
      enabled: enabled ?? this.enabled,
      tokensIn: tokensIn,
      tokensOut: tokensOut,
      quotaPct: quotaPct,
      resetsAtUnix: clearResetsAt ? null : (resetsAtUnix ?? this.resetsAtUnix),
      window5h: window5h,
      windowWeekly: windowWeekly,
      activeSession: activeSession,
    );
  }

  String get agentKey => AgentTile.normalizeAgent(provider);

  String get statusPillKey {
    switch (state) {
      case 'rate_limited':
        return 'rate_limited';
      case 'cooldown':
        return 'cooldown';
      case 'error':
        return 'failed';
      case 'running':
        return 'running';
      default:
        return enabled ? 'done' : 'idle';
    }
  }

  String get statusPillLabel {
    switch (state) {
      case 'rate_limited':
        return 'Limited';
      case 'cooldown':
        return 'Cooldown';
      case 'error':
        return 'Error';
      case 'running':
        return 'In use';
      default:
        return enabled ? 'Ready' : 'Disabled';
    }
  }
}

class CompanionAlert {
  const CompanionAlert({
    required this.time,
    required this.level,
    this.profile,
    required this.message,
  });

  final String time;
  final String level;
  final String? profile;
  final String message;

  factory CompanionAlert.fromJson(Map<String, dynamic> json) {
    return CompanionAlert(
      time: (json['time'] as String?) ?? '',
      level: (json['level'] as String?) ?? 'info',
      profile: json['profile'] as String?,
      message: (json['message'] as String?) ?? '',
    );
  }
}

String formatTokens(int n) {
  if (n >= 1000000) {
    final v = n / 1000000.0;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
  }
  if (n >= 1000) {
    final v = n / 1000.0;
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}k';
  }
  return '$n';
}

String? formatResetCountdown(int? resetsAtUnix, {int? nowUnix}) {
  if (resetsAtUnix == null || resetsAtUnix <= 0) return null;
  final now = nowUnix ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final diff = resetsAtUnix - now;
  if (diff <= 0) return 'now';
  final days = diff ~/ 86400;
  final hours = (diff % 86400) ~/ 3600;
  final mins = (diff % 3600) ~/ 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  return '${mins < 1 ? 1 : mins}m';
}
