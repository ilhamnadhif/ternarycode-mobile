import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Slate bottom sheet matching Desktop's Run Agent dialog:
/// pick target worktree (if any) → pick Agent → pick Account → either start a
/// **New session** or pick any past session from **Resume session** history.
Future<void> showSpawnAgentSheet({
  required BuildContext context,
  required AppController controller,
  required CompanionProject project,
  CompanionWorktree? initialWorktree,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SpawnAgentBody(
      controller: controller,
      project: project,
      initialWorktree: initialWorktree,
    ),
  );
}

class _AgentOption {
  const _AgentOption(this.slug, this.label, this.supportsProfiles);
  final String slug;
  final String label;
  final bool supportsProfiles;
}

class _SpawnAgentBody extends StatefulWidget {
  const _SpawnAgentBody({
    required this.controller,
    required this.project,
    this.initialWorktree,
  });

  final AppController controller;
  final CompanionProject project;
  final CompanionWorktree? initialWorktree;

  @override
  State<_SpawnAgentBody> createState() => _SpawnAgentBodyState();
}

class _SpawnAgentBodyState extends State<_SpawnAgentBody> {
  static const List<_AgentOption> _agents = [
    _AgentOption('claude', 'Claude Code', true),
    _AgentOption('codex', 'Codex', true),
    _AgentOption('antigravity', 'Antigravity', true),
    _AgentOption('opencode', 'OpenCode', false),
    _AgentOption('gemini', 'Gemini CLI', false),
    _AgentOption('shell', 'Terminal', false),
  ];

  String _selectedAgent = 'claude';
  String? _selectedProfileId; // null = Auto (best healthy account)
  int? _selectedWorktreeId; // null = root project folder
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _selectedWorktreeId =
        (widget.initialWorktree != null && widget.initialWorktree!.id > 0)
            ? widget.initialWorktree!.id
            : null;
    // Ask desktop to scan fresh historical sessions for this project + worktrees.
    unawaited(widget.controller.refreshProjectSessions(widget.project.id));
  }

  _AgentOption get _activeOption =>
      _agents.firstWhere((a) => a.slug == _selectedAgent);

  CompanionProject _liveProject() {
    for (final p in widget.controller.snapshot.projects) {
      if (p.id == widget.project.id) return p;
    }
    return widget.project;
  }

  CompanionWorktree? _liveWorktree(CompanionProject project) {
    if (_selectedWorktreeId == null) return null;
    for (final w in project.worktrees) {
      if (w.id == _selectedWorktreeId) return w;
    }
    return null;
  }

  List<CompanionProfile> _matchingProfiles() {
    if (!_activeOption.supportsProfiles) return const [];
    return widget.controller.snapshot.profiles
        .where((p) => p.enabled && p.agentKey == _selectedAgent)
        .toList();
  }

  Future<void> _startNew(
    CompanionProject project,
    CompanionWorktree? worktree,
  ) async {
    if (_starting) return;
    setState(() => _starting = true);
    Navigator.of(context).pop();
    await widget.controller.spawnAgent(
      project: project,
      worktree: worktree,
      agent: _selectedAgent,
      profileId: _selectedProfileId,
    );
  }

  Future<void> _resume(
    CompanionProject project,
    CompanionWorktree? worktree,
    CompanionSession session,
  ) async {
    if (_starting) return;
    setState(() => _starting = true);
    Navigator.of(context).pop();
    if (session.livePane != null &&
        widget.controller.snapshot.panes
            .any((p) => p.id == session.livePane)) {
      widget.controller.focusPane(session.livePane!);
      return;
    }
    await widget.controller.resumeSession(
      project: project,
      worktree: worktree,
      session: session,
      profileId: _selectedProfileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.84;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final project = _liveProject();
        final worktree = _liveWorktree(project);
        final profiles = _matchingProfiles();
        final allTargetSessions =
            worktree != null ? worktree.sessions : project.sessions;
        final agentSessions = _selectedAgent == 'shell'
            ? const <CompanionSession>[]
            : allTargetSessions
                .where((s) => AgentTile.normalizeAgent(s.agent) == _selectedAgent)
                .toList();

        final subtitle = worktree != null
            ? '${project.name} › ${worktree.name}${worktree.branch.isNotEmpty ? ' · ${worktree.branch}' : ''}'
            : (project.branch != null && project.branch!.isNotEmpty
                ? '${project.name} · ${project.branch}'
                : project.name);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: c.overlay,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: c.lineStrong)),
            ),
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Sheet Header ──
                Row(
                  children: [
                    ProjectAvatar(name: project.name, size: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New agent',
                            style: SlateTypography.title(c, size: 16),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SlateTypography.data(c),
                          ),
                        ],
                      ),
                    ),
                    SlateIconButton(
                      icon: PhosphorIconsRegular.x,
                      small: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Optional Worktree Selector ──
                        if (project.worktrees.isNotEmpty) ...[
                          const SlateSectionLabel('Workspace'),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _TargetChip(
                                  icon: PhosphorIconsFill.folderSimple,
                                  label: project.branch ?? project.name,
                                  selected: worktree == null,
                                  onTap: () => setState(
                                      () => _selectedWorktreeId = null),
                                ),
                                for (final wt in project.worktrees) ...[
                                  const SizedBox(width: 6),
                                  _TargetChip(
                                    icon: PhosphorIconsRegular.gitFork,
                                    label: wt.name,
                                    badge: wt.merged ? 'merged' : null,
                                    selected: worktree?.id == wt.id &&
                                        wt.id > 0,
                                    onTap: wt.id > 0
                                        ? () => setState(
                                            () => _selectedWorktreeId = wt.id)
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ── Agent Picker ──
                        const SlateSectionLabel('Agent'),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.35,
                          children: [
                            for (final opt in _agents)
                              Builder(builder: (_) {
                                final on = _selectedAgent == opt.slug;
                                final count = opt.slug == 'shell'
                                    ? 0
                                    : allTargetSessions
                                        .where((s) =>
                                            AgentTile.normalizeAgent(s.agent) ==
                                            opt.slug)
                                        .length;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedAgent = opt.slug;
                                        _selectedProfileId = null;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: on ? c.accentTint : c.raised,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: on ? c.accent : c.lineSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AgentTile(agent: opt.slug, size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              opt.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: SlateTypography.body(
                                                c,
                                                weight: on
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ).copyWith(
                                                fontSize: 12.5,
                                                color: on ? c.text : c.text2,
                                              ),
                                            ),
                                          ),
                                          if (count > 0) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: on
                                                    ? c.accent
                                                        .withValues(alpha: 0.18)
                                                    : c.hover,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: SlateTypography.data(
                                                  c,
                                                  size: 10,
                                                  weight: FontWeight.w600,
                                                  color: on
                                                      ? c.accentText
                                                      : c.text3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),

                        // ── Account Profile Picker ──
                        if (profiles.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const SlateSectionLabel('Account'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _ProfileChip(
                                  label: 'Auto',
                                  detail: 'best healthy',
                                  selected: _selectedProfileId == null,
                                  onTap: () => setState(
                                      () => _selectedProfileId = null),
                                ),
                                for (final pr in profiles) ...[
                                  const SizedBox(width: 6),
                                  _ProfileChip(
                                    label: pr.id,
                                    detail: pr.state == 'rate_limited'
                                        ? 'limited'
                                        : pr.window5h?.usedPct != null
                                            ? '${pr.window5h!.usedPct!.round()}%'
                                            : pr.statusPillLabel.toLowerCase(),
                                    warn: pr.state == 'rate_limited',
                                    selected: _selectedProfileId == pr.id,
                                    onTap: () => setState(
                                        () => _selectedProfileId = pr.id),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // ── Primary Action: New Session ──
                        const SizedBox(height: 16),
                        SlateButton(
                          label: _selectedAgent == 'shell'
                              ? 'New Terminal'
                              : 'New ${_activeOption.label} session',
                          icon: PhosphorIconsRegular.plus,
                          variant: SlateButtonVariant.primary,
                          expanded: true,
                          busy: _starting,
                          onPressed: () => _startNew(project, worktree),
                        ),

                        // ── Resume Session History ──
                        if (_selectedAgent != 'shell') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SlateSectionLabel(
                                  agentSessions.isNotEmpty
                                      ? 'Resume session · ${agentSessions.length}'
                                      : 'Resume session',
                                ),
                              ),
                              if (agentSessions.isNotEmpty)
                                Text(
                                  'Tap to continue',
                                  style: SlateTypography.data(c, size: 10.5),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (agentSessions.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: c.sheet,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.lineSubtle),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    PhosphorIconsRegular.clockCounterClockwise,
                                    size: 15,
                                    color: c.text3,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'No previous ${_activeOption.label} sessions here yet',
                                      style: SlateTypography.body2(c),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SlateCard(
                              child: Column(
                                children: [
                                  for (var i = 0;
                                      i < agentSessions.length;
                                      i++)
                                    _SessionHistoryRow(
                                      session: agentSessions[i],
                                      fallbackAgentLabel: _activeOption.label,
                                      showTopDivider: i > 0,
                                      onTap: () => _resume(
                                        project,
                                        worktree,
                                        agentSessions[i],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SessionHistoryRow extends StatelessWidget {
  const _SessionHistoryRow({
    required this.session,
    required this.fallbackAgentLabel,
    required this.showTopDivider,
    required this.onTap,
  });

  final CompanionSession session;
  final String fallbackAgentLabel;
  final bool showTopDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final subParts = <String>[
      if (session.profile != null && session.profile!.isNotEmpty)
        session.profile!
      else
        fallbackAgentLabel,
      if (session.age.isNotEmpty) session.age,
    ];

    return SlateRow(
      showTopDivider: showTopDivider,
      minHeight: 48,
      leading: AgentTile(agent: session.agent, size: 22),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SlateTypography.body(c, weight: FontWeight.w500)
            .copyWith(fontSize: 12.5),
      ),
      monoSubtitle: subParts.join(' · '),
      trailing: session.livePane != null
          ? const SlateTag(label: 'Live')
          : session.canResume
              ? SlateGoButton(
                  label: 'Resume',
                  icon: PhosphorIconsRegular.arrowClockwise,
                  onTap: onTap,
                )
              : StatusGlyph(
                  status: session.status,
                  size: 12,
                  animate: false,
                ),
      onTap: (session.livePane != null || session.canResume) ? onTap : null,
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : c.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.accent : c.lineSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? c.accentText : c.text2,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: SlateTypography.data(
                  c,
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: selected ? c.accentText : c.text,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Text(
                  badge!,
                  style: SlateTypography.data(
                    c,
                    size: 10,
                    weight: FontWeight.w600,
                    color: c.done,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? c.accentTint : c.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.accent : c.lineSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: SlateTypography.data(
                  c,
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: selected ? c.accentText : c.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                detail,
                style: SlateTypography.data(
                  c,
                  size: 10.5,
                  color: warn ? c.limited : c.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
