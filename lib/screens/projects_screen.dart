import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 11 · Projects, Worktrees & Sessions (searchable with 1-tap Resume).
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

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final ctrl = widget.controller;
    final host = ctrl.activeHost;
    final query = ctrl.projectQuery.trim().toLowerCase();

    final projects = ctrl.snapshot.projects.where((pr) {
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
            hint: 'Filter projects & sessions…',
            prefixIcon: PhosphorIconsRegular.magnifyingGlass,
            compact: true,
            onChanged: ctrl.setProjectQuery,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: projects.isEmpty
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
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, idx) {
                      final pr = projects[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              children: [
                                ProjectAvatar(name: pr.name, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    pr.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SlateTypography.body(c,
                                            weight: FontWeight.w600)
                                        .copyWith(fontSize: 13.5),
                                  ),
                                ),
                                if (pr.branch != null &&
                                    pr.branch!.isNotEmpty) ...[
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
                                              pr.branch!,
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
                          const SizedBox(height: 7),
                          SlateCard(
                            child: Column(
                              children: [
                                for (var i = 0; i < pr.sessions.length; i++)
                                  Builder(builder: (_) {
                                    final s = pr.sessions[i];
                                    return SlateRow(
                                      showTopDivider: i > 0,
                                      leading: AgentTile(agent: s.agent),
                                      title: Text(
                                        s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SlateTypography.body(c,
                                            weight: FontWeight.w500),
                                      ),
                                      monoSubtitle:
                                          '${s.profile ?? s.agent} · ${s.age}',
                                      trailing: s.livePane != null
                                          ? const SlateTag(label: 'Live')
                                          : s.canResume
                                              ? SlateGoButton(
                                                  label: 'Resume',
                                                  icon: PhosphorIconsRegular
                                                      .arrowClockwise,
                                                  onTap: () =>
                                                      ctrl.resumeSession(
                                                    project: pr,
                                                    session: s,
                                                  ),
                                                )
                                              : StatusGlyph(
                                                  status: s.status,
                                                  size: 12,
                                                  animate: false,
                                                ),
                                      onTap: () {
                                        if (s.livePane != null) {
                                          ctrl.focusPane(s.livePane!);
                                        } else if (s.canResume) {
                                          ctrl.resumeSession(
                                              project: pr, session: s);
                                        }
                                      },
                                    );
                                  }),
                                for (var wIdx = 0;
                                    wIdx < pr.worktrees.length;
                                    wIdx++)
                                  Builder(builder: (_) {
                                    final w = pr.worktrees[wIdx];
                                    return SlateRow(
                                      showTopDivider:
                                          pr.sessions.isNotEmpty || wIdx > 0,
                                      backgroundColor: c.hover,
                                      minHeight: 46,
                                      leading: Icon(
                                        PhosphorIconsRegular.gitFork,
                                        size: 15,
                                        color: c.text2,
                                      ),
                                      title: Text(
                                        w.name,
                                        style: SlateTypography.body(c,
                                                weight: FontWeight.w500)
                                            .copyWith(fontSize: 12),
                                      ),
                                      monoSubtitle: 'worktree · ${w.branch}',
                                      trailing: StatusGlyph(
                                          status: w.status, size: 12),
                                      onTap: () => ctrl.showToast(
                                        'Worktree ${w.name} (${w.branch})',
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
