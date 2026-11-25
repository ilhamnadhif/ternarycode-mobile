import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/spawn_agent_sheet.dart';

/// Screen 11 · Desktop-matched Projects & Worktrees tree.
///
/// Mirrors TernaryCode desktop's left sidebar:
/// 1. `ACTIVE` section — projects with live agents (grouped by project → nested
///    worktrees → live agent panes with task title, status pill, and close `×`).
/// 2. `IDLE` section — compact 1-line project rows (+ nested worktrees if any)
///    with zero inline session clutter; tapping any project or `+` opens the
///    New / Resume Agent popup with per-agent session history.
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
  bool _activeCollapsed = false;
  bool _idleCollapsed = false;

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

  void _openSpawn(
    BuildContext context,
    CompanionProject project, {
    CompanionWorktree? worktree,
  }) {
    showSpawnAgentSheet(
      context: context,
      controller: widget.controller,
      project: project,
      initialWorktree: worktree,
    );
  }

  Future<void> _confirmClosePane(
    BuildContext context,
    CompanionPane pane,
  ) async {
    final busy = pane.status == 'running' || pane.status == 'needs_input';
    if (!busy) {
      await widget.controller.closePane(pane);
      return;
    }
    final c = context.slate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: c.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.lineStrong),
        ),
        title: Text(
          'Close ${pane.label}?',
          style: SlateTypography.title(c, size: 16),
        ),
        content: Text(
          'This stops the active session in ${pane.projectName}.',
          style: SlateTypography.body2(c),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: Text(
              'Cancel',
              style: SlateTypography.body(c).copyWith(color: c.text2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: Text(
              'Close',
              style: SlateTypography.body(c, weight: FontWeight.w600)
                  .copyWith(color: c.failed),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.closePane(pane);
    }
  }

  _ProjectTree _buildTree(CompanionSnapshot snap, String query) {
    final byId = <int, CompanionProject>{
      for (final p in snap.projects) p.id: p,
    };
    final byNameLower = <String, CompanionProject>{
      for (final p in snap.projects) p.name.toLowerCase(): p,
    };
    final worktreeParentById = <int, (CompanionProject, CompanionWorktree)>{};
    for (final p in snap.projects) {
      for (final w in p.worktrees) {
        if (w.id > 0) {
          worktreeParentById[w.id] = (p, w);
        }
      }
    }

    final directPanes = <int, List<CompanionPane>>{};
    final worktreePanes = <int, Map<String, List<CompanionPane>>>{};
    final orphanNodes = <int, _ActiveProjectNode>{};

    for (final pane in snap.panes) {
      CompanionProject? parent;
      CompanionWorktree? wt;

      // 1. Exact Desktop v0.3.20+ worktree linkage (`parent_project_id` + `worktree.id`).
      if (pane.parentProjectId != null) {
        parent = byId[pane.parentProjectId!];
        if (parent != null) {
          for (final w in parent.worktrees) {
            if (w.id == pane.projectId) {
              wt = w;
              break;
            }
          }
          if (wt == null && pane.projectName.contains(' › ')) {
            final suffix = pane.projectName.split(' › ').last.trim();
            for (final w in parent.worktrees) {
              if (w.name == suffix) {
                wt = w;
                break;
              }
            }
          }
        }
      }

      // 2. Fallback: match by worktree id directly.
      if (parent == null && worktreeParentById.containsKey(pane.projectId)) {
        final pair = worktreeParentById[pane.projectId]!;
        parent = pair.$1;
        wt = pair.$2;
      }

      // 3. Match root project id.
      parent ??= byId[pane.projectId];

      // 4. Fallback for older desktops (<v0.3.20): `"Parent › worktree-name"`.
      if (parent == null && pane.projectName.contains(' › ')) {
        final parts = pane.projectName.split(' › ');
        final pName = parts.first.trim().toLowerCase();
        final wName = parts.last.trim();
        final found = byNameLower[pName];
        if (found != null) {
          parent = found;
          for (final w in found.worktrees) {
            if (w.name == wName) {
              wt = w;
              break;
            }
          }
          wt ??= CompanionWorktree(
            id: pane.projectId,
            name: wName,
            branch: pane.branch ?? '',
            status: pane.effectiveStatus,
          );
        }
      }

      if (parent != null) {
        if (wt != null) {
          worktreePanes
              .putIfAbsent(parent.id, () => {})
              .putIfAbsent(wt.name, () => [])
              .add(pane);
        } else {
          directPanes.putIfAbsent(parent.id, () => []).add(pane);
        }
      } else {
        final synthetic = orphanNodes.putIfAbsent(
          pane.projectId,
          () => _ActiveProjectNode(
            project: CompanionProject(
              id: pane.projectId,
              name: pane.projectName,
              branch: pane.branch,
            ),
            directPanes: [],
            worktrees: [],
          ),
        );
        synthetic.directPanes.add(pane);
      }
    }

    bool paneMatches(CompanionPane p) {
      if (query.isEmpty) return true;
      return p.projectName.toLowerCase().contains(query) ||
          p.label.toLowerCase().contains(query) ||
          (p.task?.toLowerCase().contains(query) ?? false) ||
          (p.profile?.toLowerCase().contains(query) ?? false) ||
          (p.branch?.toLowerCase().contains(query) ?? false);
    }

    bool worktreeMatches(CompanionWorktree w, List<CompanionPane> panes) {
      if (query.isEmpty) return true;
      return w.name.toLowerCase().contains(query) ||
          w.branch.toLowerCase().contains(query) ||
          panes.any(paneMatches) ||
          w.sessions.any((s) => s.title.toLowerCase().contains(query));
    }

    bool projectMatches(CompanionProject pr) {
      if (query.isEmpty) return true;
      return pr.name.toLowerCase().contains(query) ||
          (pr.branch?.toLowerCase().contains(query) ?? false) ||
          pr.sessions.any((s) => s.title.toLowerCase().contains(query)) ||
          pr.worktrees.any((w) =>
              w.name.toLowerCase().contains(query) ||
              w.branch.toLowerCase().contains(query) ||
              w.sessions.any((s) => s.title.toLowerCase().contains(query)));
    }

    final activeNodes = <_ActiveProjectNode>[];
    final idleProjects = <CompanionProject>[];

    for (final pr in snap.projects) {
      final rootPanes = directPanes[pr.id] ?? const <CompanionPane>[];
      final wtPaneMap = worktreePanes[pr.id] ?? const <String, List<CompanionPane>>{};
      final hasAnyLive =
          rootPanes.isNotEmpty || wtPaneMap.values.any((l) => l.isNotEmpty);

      if (hasAnyLive) {
        final selfMatch = projectMatches(pr);
        final filteredDirect =
            selfMatch ? rootPanes : rootPanes.where(paneMatches).toList();

        // Build worktree entries: known project worktrees + any fallback synthetic ones.
        final seenWtNames = <String>{};
        final wtNodes = <_WorktreeNode>[];
        for (final wt in pr.worktrees) {
          seenWtNames.add(wt.name);
          final panes = wtPaneMap[wt.name] ?? const <CompanionPane>[];
          if (query.isEmpty || selfMatch || worktreeMatches(wt, panes)) {
            wtNodes.add(_WorktreeNode(
              worktree: wt,
              panes: selfMatch ? panes : panes.where(paneMatches).toList(),
            ));
          }
        }
        for (final entry in wtPaneMap.entries) {
          if (seenWtNames.contains(entry.key)) continue;
          final panes = entry.value;
          final wt = CompanionWorktree(
            id: panes.first.projectId,
            name: entry.key,
            branch: panes.first.branch ?? '',
            status: panes.first.effectiveStatus,
          );
          if (query.isEmpty || selfMatch || worktreeMatches(wt, panes)) {
            wtNodes.add(_WorktreeNode(
              worktree: wt,
              panes: selfMatch ? panes : panes.where(paneMatches).toList(),
            ));
          }
        }
        // Active worktrees (with running/open panes) appear first.
        wtNodes.sort((a, b) => (b.panes.isNotEmpty ? 1 : 0)
            .compareTo(a.panes.isNotEmpty ? 1 : 0));

        if (selfMatch ||
            filteredDirect.isNotEmpty ||
            wtNodes.any((w) => w.panes.isNotEmpty)) {
          activeNodes.add(_ActiveProjectNode(
            project: pr,
            directPanes: filteredDirect,
            worktrees: wtNodes,
          ));
        }
      } else if (projectMatches(pr)) {
        idleProjects.add(pr);
      }
    }

    for (final orphan in orphanNodes.values) {
      final matches = query.isEmpty ||
          orphan.project.name.toLowerCase().contains(query) ||
          orphan.directPanes.any(paneMatches);
      if (matches) {
        activeNodes.add(orphan);
      }
    }

    // Sort active projects by highest urgency (Needs input / Rate limit / Running / Done / Idle).
    int paneRank(CompanionPane p) {
      if (p.rateLimit != null) return 0;
      switch (p.status) {
        case 'needs_input':
          return 1;
        case 'failed':
          return 2;
        case 'running':
          return 3;
        case 'done':
          return 4;
        case 'active':
          return 5;
        default:
          return 6;
      }
    }

    activeNodes.sort((a, b) {
      final aRank = a.allPanes.map(paneRank).fold<int>(9, (m, r) => r < m ? r : m);
      final bRank = b.allPanes.map(paneRank).fold<int>(9, (m, r) => r < m ? r : m);
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.project.name.toLowerCase().compareTo(b.project.name.toLowerCase());
    });

    final totalLivePanes =
        activeNodes.fold<int>(0, (sum, n) => sum + n.allPanes.length);
    final finishedPanes = activeNodes.fold<int>(
      0,
      (sum, n) =>
          sum + n.allPanes.where((p) => p.status == 'done').length,
    );

    return _ProjectTree(
      activeNodes: activeNodes,
      idleProjects: idleProjects,
      totalLivePanes: totalLivePanes,
      finishedPanes: finishedPanes,
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

    final tree = _buildTree(snap, query);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlateTopHeader(
            title: 'Projects',
            hostName: host?.name ?? 'No host',
            hostOnline: ctrl.phase == ConnectionPhase.connected,
            hostReconnecting: ctrl.phase == ConnectionPhase.connecting ||
                ctrl.phase == ConnectionPhase.reconnecting,
            hasUpdateBadge: ctrl.availableUpdate?.hasUpdate ?? false,
            onTapHost: widget.onOpenHosts,
            onTapSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 12),
          SlateTextField(
            controller: _searchCtrl,
            hint: 'Filter projects, worktrees & agents…',
            prefixIcon: PhosphorIconsRegular.magnifyingGlass,
            compact: true,
            onChanged: ctrl.setProjectQuery,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: tree.activeNodes.isEmpty && tree.idleProjects.isEmpty
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
                      // ── Section 1: ACTIVE (projects → worktrees → live agents) ──
                      if (tree.activeNodes.isNotEmpty) ...[
                        _CollapsibleGroupHeader(
                          label: 'Active · ${tree.activeNodes.length}',
                          collapsed: _activeCollapsed,
                          onToggle: () => setState(
                            () => _activeCollapsed = !_activeCollapsed,
                          ),
                          badge: tree.finishedPanes > 0
                              ? _FinishedPill(count: tree.finishedPanes)
                              : null,
                          trailingText: '${tree.totalLivePanes} live',
                        ),
                        if (!_activeCollapsed) ...[
                          const SizedBox(height: 8),
                          SlateCard(
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < tree.activeNodes.length;
                                    i++)
                                  _ActiveProjectTreeBlock(
                                    node: tree.activeNodes[i],
                                    selectedPaneId: selectedPaneId,
                                    showTopDivider: i > 0,
                                    onTapPane: ctrl.focusPane,
                                    onClosePane: (p) =>
                                        _confirmClosePane(context, p),
                                    onSpawnProject: () => _openSpawn(
                                      context,
                                      tree.activeNodes[i].project,
                                    ),
                                    onSpawnWorktree: (wt) => _openSpawn(
                                      context,
                                      tree.activeNodes[i].project,
                                      worktree: wt,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],

                      // ── Section 2: IDLE (compact project rows + worktrees, NO expanded history) ──
                      if (tree.idleProjects.isNotEmpty) ...[
                        _CollapsibleGroupHeader(
                          label: 'Idle · ${tree.idleProjects.length}',
                          collapsed: _idleCollapsed,
                          onToggle: () => setState(
                            () => _idleCollapsed = !_idleCollapsed,
                          ),
                          trailingText: 'Tap to run or resume',
                        ),
                        if (!_idleCollapsed) ...[
                          const SizedBox(height: 8),
                          SlateCard(
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < tree.idleProjects.length;
                                    i++)
                                  _IdleProjectTreeRow(
                                    project: tree.idleProjects[i],
                                    showTopDivider: i > 0,
                                    onTapProject: () => _openSpawn(
                                      context,
                                      tree.idleProjects[i],
                                    ),
                                    onTapWorktree: (wt) => _openSpawn(
                                      context,
                                      tree.idleProjects[i],
                                      worktree: wt,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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

class _ProjectTree {
  const _ProjectTree({
    required this.activeNodes,
    required this.idleProjects,
    required this.totalLivePanes,
    required this.finishedPanes,
  });

  final List<_ActiveProjectNode> activeNodes;
  final List<CompanionProject> idleProjects;
  final int totalLivePanes;
  final int finishedPanes;
}

class _ActiveProjectNode {
  _ActiveProjectNode({
    required this.project,
    required this.directPanes,
    required this.worktrees,
  });

  final CompanionProject project;
  final List<CompanionPane> directPanes;
  final List<_WorktreeNode> worktrees;

  Iterable<CompanionPane> get allPanes sync* {
    yield* directPanes;
    for (final w in worktrees) {
      yield* w.panes;
    }
  }
}

class _WorktreeNode {
  const _WorktreeNode({
    required this.worktree,
    required this.panes,
  });

  final CompanionWorktree worktree;
  final List<CompanionPane> panes;
}

class _CollapsibleGroupHeader extends StatelessWidget {
  const _CollapsibleGroupHeader({
    required this.label,
    required this.collapsed,
    required this.onToggle,
    this.badge,
    this.trailingText,
  });

  final String label;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? badge;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              collapsed
                  ? PhosphorIconsRegular.caretRight
                  : PhosphorIconsRegular.caretDown,
              size: 12,
              color: c.text3,
            ),
            const SizedBox(width: 5),
            SlateSectionLabel(label),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge!,
            ],
            const Spacer(),
            if (trailingText != null)
              Text(
                trailingText!,
                style: SlateTypography.data(c, size: 10.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishedPill extends StatelessWidget {
  const _FinishedPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.doneTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.done,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count finished',
            style: SlateTypography.data(
              c,
              size: 10.5,
              weight: FontWeight.w500,
              color: c.done,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProjectTreeBlock extends StatelessWidget {
  const _ActiveProjectTreeBlock({
    required this.node,
    required this.selectedPaneId,
    required this.showTopDivider,
    required this.onTapPane,
    required this.onClosePane,
    required this.onSpawnProject,
    required this.onSpawnWorktree,
  });

  final _ActiveProjectNode node;
  final int? selectedPaneId;
  final bool showTopDivider;
  final ValueChanged<int> onTapPane;
  final ValueChanged<CompanionPane> onClosePane;
  final VoidCallback onSpawnProject;
  final ValueChanged<CompanionWorktree> onSpawnWorktree;

  Color _folderDotColor(SlateColors c) {
    final panes = node.allPanes.toList();
    if (panes.any((p) => p.rateLimit != null)) return c.limited;
    if (panes.any((p) => p.status == 'needs_input')) return c.input;
    if (panes.any((p) => p.status == 'failed')) return c.failed;
    if (panes.any((p) => p.status == 'running')) return c.running;
    if (panes.any((p) => p.status == 'done')) return c.done;
    return c.text3;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final pr = node.project;
    final dotColor = _folderDotColor(c);

    return Container(
      decoration: BoxDecoration(
        border: showTopDivider
            ? Border(top: BorderSide(color: c.lineSubtle))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Project Header Row ──
          Row(
            children: [
              _FolderGlyph(dotColor: dotColor, active: true),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  onTap: onSpawnProject,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    pr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlateTypography.body(c, weight: FontWeight.w600)
                        .copyWith(fontSize: 13.5),
                  ),
                ),
              ),
              if (pr.worktrees.isNotEmpty) ...[
                const SizedBox(width: 6),
                _MetaChip(
                  icon: PhosphorIconsRegular.gitFork,
                  label: '${pr.worktrees.length}',
                ),
              ] else if (pr.branch != null && pr.branch!.isNotEmpty) ...[
                const SizedBox(width: 6),
                _MetaChip(label: pr.branch!),
              ],
              const SizedBox(width: 4),
              _InlinePlusButton(
                tooltip: 'New or resume agent in ${pr.name}',
                onTap: onSpawnProject,
              ),
            ],
          ),

          // ── Direct Live Agents under this project ──
          if (node.directPanes.isNotEmpty)
            _TreeBranch(
              indent: 9,
              child: Column(
                children: [
                  for (final pane in node.directPanes)
                    _LiveAgentLeafRow(
                      pane: pane,
                      selected: pane.id == selectedPaneId,
                      onTap: () => onTapPane(pane.id),
                      onClose: () => onClosePane(pane),
                    ),
                ],
              ),
            ),

          // ── Worktree Sub-Groups (with their own live agents) ──
          if (node.worktrees.isNotEmpty)
            _TreeBranch(
              indent: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final wtNode in node.worktrees) ...[
                    _WorktreeHeaderRow(
                      worktree: wtNode.worktree,
                      hasLivePanes: wtNode.panes.isNotEmpty,
                      onTap: () => onSpawnWorktree(wtNode.worktree),
                    ),
                    if (wtNode.panes.isNotEmpty)
                      _TreeBranch(
                        indent: 11,
                        child: Column(
                          children: [
                            for (final pane in wtNode.panes)
                              _LiveAgentLeafRow(
                                pane: pane,
                                selected: pane.id == selectedPaneId,
                                onTap: () => onTapPane(pane.id),
                                onClose: () => onClosePane(pane),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IdleProjectTreeRow extends StatelessWidget {
  const _IdleProjectTreeRow({
    required this.project,
    required this.showTopDivider,
    required this.onTapProject,
    required this.onTapWorktree,
  });

  final CompanionProject project;
  final bool showTopDivider;
  final VoidCallback onTapProject;
  final ValueChanged<CompanionWorktree> onTapWorktree;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      decoration: BoxDecoration(
        border: showTopDivider
            ? Border(top: BorderSide(color: c.lineSubtle))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapProject,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    const _FolderGlyph(active: false),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.body(c, weight: FontWeight.w500)
                            .copyWith(fontSize: 13.5),
                      ),
                    ),
                    if (project.worktrees.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _MetaChip(
                        icon: PhosphorIconsRegular.gitFork,
                        label: '${project.worktrees.length}',
                      ),
                    ],
                    if (project.branch != null &&
                        project.branch!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _MetaChip(label: project.branch!),
                    ],
                    const SizedBox(width: 4),
                    _InlinePlusButton(
                      tooltip: 'New or resume agent in ${project.name}',
                      onTap: onTapProject,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (project.worktrees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
              child: _TreeBranch(
                indent: 9,
                child: Column(
                  children: [
                    for (final wt in project.worktrees)
                      _WorktreeHeaderRow(
                        worktree: wt,
                        hasLivePanes: false,
                        onTap: () => onTapWorktree(wt),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorktreeHeaderRow extends StatelessWidget {
  const _WorktreeHeaderRow({
    required this.worktree,
    required this.hasLivePanes,
    required this.onTap,
  });

  final CompanionWorktree worktree;
  final bool hasLivePanes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.gitFork,
                size: 14,
                color: worktree.merged
                    ? c.done
                    : (hasLivePanes ? c.accentText : c.text2),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  worktree.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SlateTypography.body(c, weight: FontWeight.w500)
                      .copyWith(fontSize: 12.5),
                ),
              ),
              if (worktree.merged) ...[
                const SizedBox(width: 6),
                SlateTag(
                  label: 'merged',
                  fg: c.done,
                  bg: c.doneTint,
                ),
              ],
              const Spacer(),
              _InlinePlusButton(
                tooltip: 'New or resume in ${worktree.name}',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveAgentLeafRow extends StatelessWidget {
  const _LiveAgentLeafRow({
    required this.pane,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final CompanionPane pane;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final hasTask = pane.task != null && pane.task!.trim().isNotEmpty;
    final subParts = <String>[
      if (hasTask) pane.label,
      if (pane.profile != null && pane.profile!.isNotEmpty) pane.profile!,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(7, 6, 4, 6),
            decoration: BoxDecoration(
              color: selected ? c.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                AgentTile(agent: pane.agentKey, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pane.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.body(
                          c,
                          weight: selected ? FontWeight.w600 : FontWeight.w500,
                        ).copyWith(fontSize: 12.5),
                      ),
                      if (subParts.isNotEmpty)
                        Text(
                          subParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SlateTypography.data(c, size: 10.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                StatusPill(
                  status: pane.effectiveStatus,
                  label: pane.effectiveStatusLabel,
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Close pane',
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        PhosphorIconsRegular.x,
                        size: 13,
                        color: c.text3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeBranch extends StatelessWidget {
  const _TreeBranch({
    required this.indent,
    required this.child,
  });

  final double indent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      margin: EdgeInsets.only(left: indent, top: 4),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: c.lineSubtle, width: 1.1),
        ),
      ),
      child: child,
    );
  }
}

class _FolderGlyph extends StatelessWidget {
  const _FolderGlyph({
    this.dotColor,
    required this.active,
  });

  final Color? dotColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              PhosphorIconsFill.folderSimple,
              size: 18,
              color: active ? c.text2 : c.text3,
            ),
          ),
          if (dotColor != null)
            Positioned(
              right: -1,
              bottom: 0,
              child: Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.raised, width: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    this.icon,
    required this.label,
  });

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.hover,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: c.text3),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SlateTypography.data(c, size: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlinePlusButton extends StatelessWidget {
  const _InlinePlusButton({
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              PhosphorIconsRegular.plus,
              size: 14,
              color: c.text2,
            ),
          ),
        ),
      ),
    );
  }
}
