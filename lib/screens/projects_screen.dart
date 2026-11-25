import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/spawn_agent_sheet.dart';

/// Screen 11 · Desktop-inspired Projects & Active Agents hub.
///
/// Mirrors TernaryCode desktop's sidebar:
/// 1. `ACTIVE` section pinned at the very top listing every live agent/pane across
///    all projects & worktrees (1-tap jump into `Live`).
/// 2. `PROJECTS` list below where EVERY project — even ones with 0 prior sessions —
///    can spawn a new agent (Claude Code, Codex, Antigravity, OpenCode, Gemini, Terminal).
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.onOpenHosts,
    required this.onOpenSettings,
  });

  final AppController controller;
  final VoidCallback onOpenHosts;
  final VoidCallback onOpenSettings;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.controller.projectQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSpawn(BuildContext context, CompanionProject project) {
    showSpawnAgentSheet(
      context: context,
      controller: widget.controller,
      project: project,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final ctrl = widget.controller;
    final host = ctrl.activeHost;
    final snap = ctrl.snapshot;
    final query = ctrl.projectQuery.trim().toLowerCase();
    final selectedPaneId = ctrl.selectedPane?.id;

    final activePanes = snap.panes.where((p) {
      if (query.isEmpty) return true;
      return p.projectName.toLowerCase().contains(query) ||
          p.label.toLowerCase().contains(query) ||
          (p.profile?.toLowerCase().contains(query) ?? false) ||
          (p.branch?.toLowerCase().contains(query) ?? false);
    }).toList();

    final projects = snap.projects.where((pr) {
      if (query.isEmpty) return true;
      return pr.name.toLowerCase().contains(query) ||
          (pr.branch?.toLowerCase().contains(query) ?? false) ||
          pr.sessions.any((s) => s.title.toLowerCase().contains(query));
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlateTopHeader(
            title: 'Projects',
            hostName: host?.name ?? 'No host',
            hostOnline: ctrl.phase == ConnectionPhase.connected,
            hostReconnecting: ctrl.phase == ConnectionPhase.reconnecting,
            hasUpdateBadge: ctrl.availableUpdate?.hasUpdate ?? false,
            onTapHost: widget.onOpenHosts,
            onTapSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 12),
          SlateTextField(
            controller: _searchCtrl,
            hint: 'Filter active agents & projects…',
            prefixIcon: PhosphorIconsRegular.magnifyingGlass,
            compact: true,
            onChanged: ctrl.setProjectQuery,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: activePanes.isEmpty && projects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsRegular.squaresFour,
                            size: 28, color: c.text3),
                        const SizedBox(height: 10),
                        Text(
                          query.isEmpty
                              ? 'No projects loaded'
                              : 'No matches for “${ctrl.projectQuery}”',
                          style: SlateTypography.body2(c),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // ── Section 1: ACTIVE AGENTS (desktop sidebar style) ──
                      if (activePanes.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SlateSectionLabel(
                                'Active · ${activePanes.length}',
                              ),
                            ),
                            if (snap.projects.isNotEmpty)
                              Text(
                                'Tap to open Live',
                                style: SlateTypography.data(c),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SlateCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < activePanes.length; i++)
                                _ActivePaneRow(
                                  pane: activePanes[i],
                                  selected:
                                      activePanes[i].id == selectedPaneId,
                                  showTopDivider: i > 0,
                                  onTap: () =>
                                      ctrl.focusPane(activePanes[i].id),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Section 2: ALL PROJECTS (every project can spawn a new agent) ──
                      if (projects.isNotEmpty) ...[
                        SlateSectionLabel('Projects · ${projects.length}'),
                        const SizedBox(height: 10),
                        for (var pIdx = 0; pIdx < projects.length; pIdx++) ...[
                          _ProjectGroup(
                            project: projects[pIdx],
                            onSpawn: () => _openSpawn(context, projects[pIdx]),
                            onFocusPane: ctrl.focusPane,
                            onResumeSession: (s) => ctrl.resumeSession(
                              project: projects[pIdx],
                              session: s,
                            ),
                            onTapWorktree: (w) => ctrl.showToast(
                              'Worktree ${w.name} (${w.branch})',
                            ),
                          ),
                          if (pIdx < projects.length - 1)
                            const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivePaneRow extends StatelessWidget {
  const _ActivePaneRow({
    required this.pane,
    required this.selected,
    required this.showTopDivider,
    required this.onTap,
  });

  final CompanionPane pane;
  final bool selected;
  final bool showTopDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final subParts = <String>[
      pane.label,
      if (pane.profile != null && pane.profile!.isNotEmpty) pane.profile!,
      if (pane.branch != null && pane.branch!.isNotEmpty) pane.branch!,
    ];

    return SlateRow(
      showTopDivider: showTopDivider,
      backgroundColor: selected ? c.selected : null,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AgentTile(agent: pane.agentKey, size: 26),
          if (selected)
            Positioned(
              left: -5,
              top: 6,
              bottom: 6,
              child: Container(
                width: 2.5,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        pane.projectName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SlateTypography.body(c, weight: FontWeight.w500),
      ),
      monoSubtitle: subParts.join(' · '),
      trailing: StatusPill(
        status: pane.effectiveStatus,
        label: pane.effectiveStatusLabel,
      ),
      onTap: onTap,
    );
  }
}

class _ProjectGroup extends StatelessWidget {
  const _ProjectGroup({
    required this.project,
    required this.onSpawn,
    required this.onFocusPane,
    required this.onResumeSession,
    required this.onTapWorktree,
  });

  final CompanionProject project;
  final VoidCallback onSpawn;
  final ValueChanged<int> onFocusPane;
  final ValueChanged<CompanionSession> onResumeSession;
  final ValueChanged<CompanionWorktree> onTapWorktree;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final hasItems =
        project.sessions.isNotEmpty || project.worktrees.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ProjectAvatar(name: project.name, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.body(c, weight: FontWeight.w600)
                            .copyWith(fontSize: 13.5),
                      ),
                    ),
                    if (project.branch != null &&
                        project.branch!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.hover,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIconsRegular.gitBranch,
                                  size: 11, color: c.text3),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  project.branch!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SlateTypography.data(c),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SlateGoButton(
                label: 'New',
                icon: PhosphorIconsRegular.plus,
                onTap: onSpawn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        if (hasItems)
          SlateCard(
            child: Column(
              children: [
                for (var i = 0; i < project.sessions.length; i++)
                  Builder(builder: (_) {
                    final s = project.sessions[i];
                    return SlateRow(
                      showTopDivider: i > 0,
                      leading: AgentTile(agent: s.agent),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.body(c, weight: FontWeight.w500),
                      ),
                      monoSubtitle: '${s.profile ?? s.agent} · ${s.age}',
                      trailing: s.livePane != null
                          ? const SlateTag(label: 'Live')
                          : s.canResume
                              ? SlateGoButton(
                                  label: 'Resume',
                                  icon: PhosphorIconsRegular.arrowClockwise,
                                  onTap: () => onResumeSession(s),
                                )
                              : StatusGlyph(
                                  status: s.status,
                                  size: 12,
                                  animate: false,
                                ),
                      onTap: () {
                        if (s.livePane != null) {
                          onFocusPane(s.livePane!);
                        } else if (s.canResume) {
                          onResumeSession(s);
                        }
                      },
                    );
                  }),
                for (var wIdx = 0; wIdx < project.worktrees.length; wIdx++)
                  Builder(builder: (_) {
                    final w = project.worktrees[wIdx];
                    return SlateRow(
                      showTopDivider: project.sessions.isNotEmpty || wIdx > 0,
                      backgroundColor: c.hover,
                      minHeight: 46,
                      leading: Icon(
                        PhosphorIconsRegular.gitFork,
                        size: 15,
                        color: c.text2,
                      ),
                      title: Text(
                        w.name,
                        style: SlateTypography.body(c, weight: FontWeight.w500)
                            .copyWith(fontSize: 12),
                      ),
                      monoSubtitle: 'worktree · ${w.branch}',
                      trailing: StatusGlyph(status: w.status, size: 12),
                      onTap: () => onTapWorktree(w),
                    );
                  }),
              ],
            ),
          )
        else
          SlateCard(
            backgroundColor: c.sheet,
            child: SlateRow(
              minHeight: 44,
              leading: Icon(
                PhosphorIconsRegular.sparkle,
                size: 15,
                color: c.text3,
              ),
              title: Text(
                'No sessions yet',
                style: SlateTypography.body2(c),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start agent',
                    style: SlateTypography.data(c, color: c.accentText),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 12,
                    color: c.accentText,
                  ),
                ],
              ),
              onTap: onSpawn,
            ),
          ),
      ],
    );
  }
}
