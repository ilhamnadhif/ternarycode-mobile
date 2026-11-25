import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/host_switcher_sheet.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/spawn_agent_sheet.dart';
import '../widgets/terminal_view.dart';

/// Screens 05, 06, 07 · Live Terminal & Agent Control.
/// Switching active agents/projects happens cleanly via the `Projects` tab
/// (no cramped horizontal top chip strip), giving the terminal maximum room.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.controller,
    required this.onOpenHosts,
    required this.onOpenSettings,
    required this.onOpenFullscreen,
    required this.onOpenProjects,
    required this.onPairAgain,
  });

  final AppController controller;
  final VoidCallback onOpenHosts;
  final VoidCallback onOpenSettings;
  final ValueChanged<CompanionPane> onOpenFullscreen;
  final VoidCallback onOpenProjects;
  final VoidCallback onPairAgain;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final TextEditingController _promptCtrl = TextEditingController();

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _sendPrompt(CompanionPane pane) {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _promptCtrl.clear();
    widget.controller.sendTerminalInput(
      pane.id,
      text,
      enter: true,
      toastLabel: 'Instruction sent',
    );
  }

  CompanionProject? _projectForPane(CompanionSnapshot snap, CompanionPane pane) {
    for (final pr in snap.projects) {
      if (pr.id == pane.projectId) return pr;
    }
    return snap.projects.isNotEmpty ? snap.projects.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final ctrl = widget.controller;
    final host = ctrl.activeHost;
    final snap = ctrl.snapshot;
    final pane = ctrl.selectedPane;

    final isUnreachable = ctrl.phase == ConnectionPhase.reconnecting ||
        ctrl.phase == ConnectionPhase.revoked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlateTopHeader(
            title: 'Live',
            hostName: host?.name ?? 'No host',
            hostOnline: ctrl.phase == ConnectionPhase.connected,
            hostReconnecting: ctrl.phase == ConnectionPhase.connecting ||
                ctrl.phase == ConnectionPhase.reconnecting,
            hasUpdateBadge: ctrl.availableUpdate?.hasUpdate ?? false,
            onTapHost: widget.onOpenHosts,
            onTapSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 10),

          if (isUnreachable && host != null)
            Expanded(
              child: OfflineHostView(
                hostName: host.name,
                baseUrl: host.baseUrl,
                isRevoked: ctrl.phase == ConnectionPhase.revoked,
                retrySeconds: ctrl.retryCountdownSec,
                onRetry: ctrl.retryConnection,
                onSwitchHost: widget.onOpenHosts,
                onPairAgain: widget.onPairAgain,
              ),
            )
          else if (pane == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.hover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.lineSubtle),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.terminalWindow,
                        size: 22,
                        color: c.text2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ctrl.phase == ConnectionPhase.connecting
                          ? 'Connecting to ${host?.name ?? 'host'}…'
                          : 'No active agents running',
                      style: SlateTypography.body(c, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a project or spawn a new agent in Projects.',
                      textAlign: TextAlign.center,
                      style: SlateTypography.body2(c),
                    ),
                    const SizedBox(height: 14),
                    SlateButton(
                      label: 'Open Projects',
                      icon: PhosphorIconsRegular.squaresFour,
                      variant: SlateButtonVariant.secondary,
                      height: 38,
                      onPressed: widget.onOpenProjects,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Clean single-line active context bar (tap to open Projects → Active list)
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onOpenProjects,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.lineSubtle),
                        ),
                        child: Row(
                          children: [
                            ProjectAvatar(name: pane.projectName, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pane.projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SlateTypography.body(c,
                                    weight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${snap.panes.length} active',
                              style: SlateTypography.data(c),
                            ),
                            const SizedBox(width: 4),
                            Icon(PhosphorIconsRegular.caretRight,
                                size: 12, color: c.text3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_projectForPane(snap, pane) != null) ...[
                  const SizedBox(width: 8),
                  SlateIconButton(
                    icon: PhosphorIconsRegular.plus,
                    tooltip: 'New agent',
                    onPressed: () {
                      final proj = _projectForPane(snap, pane);
                      if (proj != null) {
                        showSpawnAgentSheet(
                          context: context,
                          controller: ctrl,
                          project: proj,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Live terminal sheet (fills available space cleanly)
            Expanded(
              child: TerminalSheet(
                pane: pane,
                fontSize: ctrl.settings.termFontSize,
                wrap: ctrl.settings.termWrap,
                onExpand: () => widget.onOpenFullscreen(pane),
              ),
            ),

            // Adaptive status action block (Needs input / Rate limited / Failed)
            ..._buildActionBlock(context, ctrl, snap, pane),

            // Compact Switch account chips when running with profile support
            if (pane.supportsProfiles &&
                pane.rateLimit == null &&
                pane.status == 'running') ...[
              Builder(builder: (context) {
                final healthy = snap.healthyProfilesFor(pane);
                if (healthy.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SlateSectionLabel('Switch account'),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: healthy.length.clamp(0, 4),
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, idx) {
                            final pr = healthy[idx];
                            final pct = pr.window5h?.usedPct?.round();
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => ctrl.switchProfile(pane.id, pr.id),
                                borderRadius: BorderRadius.circular(8),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: c.raised,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: c.lineSubtle),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(PhosphorIconsRegular.arrowsLeftRight,
                                          size: 12, color: c.text2),
                                      const SizedBox(width: 6),
                                      Text(
                                        pr.id,
                                        style: SlateTypography.data(
                                          c,
                                          color: c.text,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                      if (pct != null) ...[
                                        const SizedBox(width: 5),
                                        Text('$pct%',
                                            style: SlateTypography.data(c)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Quick terminal keys strip
            if (pane.rateLimit == null) ...[
              const SizedBox(height: 10),
              QuickKeysStrip(
                onEnter: () => ctrl.sendTerminalInput(pane.id, '',
                    enter: true, toastLabel: 'Sent Enter'),
                onEsc: () => ctrl.sendTerminalInput(pane.id, '\x1B',
                    enter: false, toastLabel: 'Sent Esc'),
                onInterrupt: () => ctrl.sendQuickAction(pane.id, 'interrupt'),
                onTab: () => ctrl.sendTerminalInput(pane.id, '\t',
                    enter: false, toastLabel: 'Sent Tab'),
                onUp: () => ctrl.sendTerminalInput(pane.id, '\x1B[A',
                    enter: false, toastLabel: 'Sent ↑'),
                onDown: () => ctrl.sendTerminalInput(pane.id, '\x1B[B',
                    enter: false, toastLabel: 'Sent ↓'),
              ),
            ],

            const SizedBox(height: 9),
            PromptComposer(
              controller: _promptCtrl,
              hint: 'Send an instruction to ${pane.label}…',
              onSend: () => _sendPrompt(pane),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActionBlock(
    BuildContext context,
    AppController ctrl,
    CompanionSnapshot snap,
    CompanionPane pane,
  ) {
    if (pane.rateLimit != null) {
      final rl = pane.rateLimit!;
      final healthy = snap.healthyProfilesFor(pane);
      return [
        const SizedBox(height: 10),
        SlateNotice(
          status: 'rate_limited',
          leading: const StatusGlyph(
              status: 'rate_limited', size: 16, animate: false),
          title:
              '${rl.fromProfile} hit its 5h limit · resets in ${rl.resetsInLabel}',
          body: rl.reason,
        ),
        if (healthy.isNotEmpty) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              for (var i = 0; i < healthy.length.clamp(0, 2); i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SlateButton(
                    label: 'Resume ${healthy[i].id}',
                    icon: PhosphorIconsRegular.arrowsLeftRight,
                    variant: i == 0
                        ? SlateButtonVariant.primary
                        : SlateButtonVariant.raised,
                    expanded: true,
                    onPressed: () =>
                        ctrl.switchProfile(pane.id, healthy[i].id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ];
    }

    if (pane.status == 'needs_input') {
      return [
        const SizedBox(height: 10),
        SlateNotice(
          status: 'needs_input',
          leading: const StatusGlyph(
              status: 'needs_input', size: 16, animate: false),
          title: '${pane.label} wants your input',
          body: pane.message ?? 'Waiting for approval',
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: SlateButton(
                label: 'Approve',
                variant: SlateButtonVariant.primary,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'approve'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SlateButton(
                label: 'Reject',
                variant: SlateButtonVariant.raised,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SlateButton(
                label: 'Stop',
                variant: SlateButtonVariant.danger,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'interrupt'),
              ),
            ),
          ],
        ),
      ];
    }

    if (pane.status == 'failed') {
      return [
        const SizedBox(height: 10),
        SlateNotice(
          status: 'failed',
          leading:
              const StatusGlyph(status: 'failed', size: 16, animate: false),
          title: pane.statusLabel,
          body: pane.message ?? 'Command exited with a non-zero status',
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: SlateButton(
                label: 'Run again',
                height: 38,
                variant: SlateButtonVariant.primary,
                expanded: true,
                onPressed: () => ctrl.sendTerminalInput(
                  pane.id,
                  pane.label,
                  enter: true,
                  toastLabel: 'Re-running ${pane.label}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SlateButton(
                label: 'Copy output',
                height: 38,
                variant: SlateButtonVariant.raised,
                expanded: true,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pane.output));
                  ctrl.showToast('Copied output to clipboard');
                },
              ),
            ),
          ],
        ),
      ];
    }

    return const [];
  }
}
