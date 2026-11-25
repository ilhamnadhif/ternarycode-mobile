import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/host_switcher_sheet.dart';
import '../widgets/slate_reader_view.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/spawn_agent_sheet.dart';
import '../widgets/terminal_view.dart';

/// Screens 05, 06, 07 · Live Terminal & Agent Reader.
///
/// Unified slim 1-row header + edge-to-edge `SlateReaderView` (default for AI
/// agents, reflowing desktop output cleanly with zero double-wrap) + 1-tap
/// `Raw` PTY toggle (horizontal scroll, no double-wrap) + collapsible `⌘` quick
/// keys dock.
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
  final Map<int, bool> _rawModeByPane = {};
  bool _showQuickKeys = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  bool _isRawMode(CompanionPane pane) {
    final override = _rawModeByPane[pane.id];
    if (override != null) return override;
    return pane.agentKey == 'shell';
  }

  void _setRawMode(CompanionPane pane, bool raw) {
    setState(() {
      _rawModeByPane[pane.id] = raw;
      if (raw) {
        _showQuickKeys = true;
      } else {
        _showQuickKeys = false;
      }
    });
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

    final showOfflineWall = ctrl.showOfflineWall;
    final softReconnecting = ctrl.isSoftReconnecting;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 100;
    final hostOnline = ctrl.phase == ConnectionPhase.connected;
    final hostReconnecting = ctrl.phase == ConnectionPhase.connecting ||
        ctrl.phase == ConnectionPhase.reconnecting;
    final hasUpdateBadge = ctrl.availableUpdate?.hasUpdate ?? false;

    // Offline wall or empty state keeps classic SlateTopHeader cleanly padded
    if ((showOfflineWall && host != null) || pane == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SlateTopHeader(
              title: 'Live',
              hostName: host?.name ?? 'No host',
              hostOnline: hostOnline,
              hostReconnecting: hostReconnecting,
              hasUpdateBadge: hasUpdateBadge,
              onTapHost: widget.onOpenHosts,
              onTapSettings: widget.onOpenSettings,
            ),
            const SizedBox(height: 10),
            if (showOfflineWall && host != null)
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
            else
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
              ),
          ],
        ),
      );
    }

    final isRaw = _isRawMode(pane);
    final keysVisible = isRaw || _showQuickKeys;
    final dotColor = hostOnline
        ? c.done
        : (hostReconnecting ? c.input : c.failed);
    final subBarBottomColor = pane.status == 'needs_input'
        ? c.input.withValues(alpha: 0.34)
        : pane.rateLimit != null
            ? c.limited.withValues(alpha: 0.34)
            : c.lineSubtle;
    final metaParts = <String>[
      if (pane.profile != null && pane.profile!.isNotEmpty)
        pane.profile!
      else
        pane.label,
      if (pane.branch != null && pane.branch!.isNotEmpty) pane.branch!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Unified 1-Row Top Bar (reclaims +46px of vertical reading room) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.fromLTRB(9, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.lineSubtle),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onOpenProjects,
                        behavior: HitTestBehavior.opaque,
                        child: ProjectAvatar(name: pane.projectName, size: 22),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: widget.onOpenProjects,
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                pane.projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SlateTypography.body(
                                  c,
                                  weight: FontWeight.w600,
                                ).copyWith(fontSize: 13.5, height: 1.15),
                              ),
                            ),
                            GestureDetector(
                              onTap: widget.onOpenHosts,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      host?.name ?? 'No host',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SlateTypography.data(
                                        c,
                                        size: 10,
                                        color: c.text3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    PhosphorIconsRegular.caretDown,
                                    size: 9,
                                    color: c.text3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onOpenProjects,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.hover,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${snap.panes.length} active',
                                style: SlateTypography.data(
                                  c,
                                  size: 10.5,
                                  color: c.text2,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                PhosphorIconsRegular.caretRight,
                                size: 10,
                                color: c.text3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_projectForPane(snap, pane) != null) ...[
                const SizedBox(width: 7),
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
              const SizedBox(width: 7),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SlateIconButton(
                    icon: PhosphorIconsRegular.gearSix,
                    tooltip: 'Settings',
                    onPressed: widget.onOpenSettings,
                  ),
                  if (hasUpdateBadge)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: IgnorePointer(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.window, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Soft Reconnecting Banner (never wipes terminal during brief drops) ──
        if (softReconnecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.inputTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.input.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: c.input,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctrl.retryCountdownSec > 0
                          ? 'Reconnecting in ${ctrl.retryCountdownSec}s…'
                          : 'Reconnecting to ${host?.name ?? 'host'}…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.data(c, color: c.text2),
                    ),
                  ),
                  GestureDetector(
                    onTap: ctrl.retryConnection,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Retry',
                        style: SlateTypography.data(
                          c,
                          color: c.input,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Edge-to-Edge Pane Control Bar with Reader | Raw Toggle ──
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.sheet,
            border: Border(
              top: BorderSide(color: c.lineSubtle),
              bottom: BorderSide(color: subBarBottomColor),
            ),
          ),
          child: Row(
            children: [
              AgentTile(agent: pane.agentKey, size: 20),
              const SizedBox(width: 6),
              StatusPill(
                status: pane.effectiveStatus,
                label: pane.effectiveStatusLabel,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metaParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SlateTypography.data(c, size: 10.5, color: c.text3),
                ),
              ),
              const SizedBox(width: 5),
              _ReaderRawToggle(
                isRaw: isRaw,
                onChanged: (raw) => _setRawMode(pane, raw),
              ),
              const SizedBox(width: 4),
              SlateIconButton(
                icon: PhosphorIconsRegular.arrowsOutSimple,
                tooltip: 'Fullscreen terminal',
                small: true,
                onPressed: () => widget.onOpenFullscreen(pane),
              ),
            ],
          ),
        ),

        // ── Edge-to-Edge Reading Canvas (Slate Reader OR Raw PTY) ──
        Expanded(
          child: ColoredBox(
            color: isRaw ? c.inset : c.sheet,
            child: isRaw
                ? TerminalOutputView(
                    paneId: pane.id,
                    output: pane.output,
                    fontSize: ctrl.settings.termFontSize,
                    wrap: false,
                  )
                : SlateReaderView(
                    pane: pane,
                    onToast: ctrl.showToast,
                    fontScale: (ctrl.settings.termFontSize / 11.5).clamp(0.85, 1.35),
                  ),
          ),
        ),

        // ── Adaptive Bottom Dock (contextual actions + collapsible quick keys + composer) ──
        Container(
          decoration: BoxDecoration(
            color: c.window,
            border: Border(top: BorderSide(color: c.lineSubtle)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildActionBlock(context, ctrl, snap, pane),

              // Compact Switch account chips when running with profile support
              if (!keyboardOpen &&
                  pane.supportsProfiles &&
                  pane.rateLimit == null &&
                  pane.status == 'running')
                Builder(builder: (context) {
                  final healthy = snap.healthyProfilesFor(pane);
                  if (healthy.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SlateSectionLabel('Switch account'),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: healthy.length.clamp(0, 4),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, idx) {
                              final pr = healthy[idx];
                              final pct = pr.window5h?.usedPct?.round();
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      ctrl.switchProfile(pane.id, pr.id),
                                  borderRadius: BorderRadius.circular(7),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9),
                                    decoration: BoxDecoration(
                                      color: c.raised,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: c.lineSubtle),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsRegular.arrowsLeftRight,
                                          size: 11,
                                          color: c.text2,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          pr.id,
                                          style: SlateTypography.data(
                                            c,
                                            size: 11,
                                            color: c.text,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                        if (pct != null) ...[
                                          const SizedBox(width: 5),
                                          Text('$pct%',
                                              style: SlateTypography.data(c,
                                                  size: 10.5)),
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

              // Collapsible quick terminal keys strip (auto-shown in Raw or on ⌘ tap)
              if (pane.rateLimit == null && keysVisible) ...[
                QuickKeysStrip(
                  onEnter: () => ctrl.sendTerminalInput(pane.id, '',
                      enter: true, toastLabel: 'Sent Enter'),
                  onEsc: () => ctrl.sendTerminalInput(pane.id, '\x1B',
                      enter: false, toastLabel: 'Sent Esc'),
                  onInterrupt: () => ctrl.sendQuickAction(pane.id, 'interrupt'),
                  onTab: () => ctrl.sendTerminalInput(pane.id, '\t',
                      enter: false, toastLabel: 'Sent Tab'),
                  onUp: () => ctrl.sendTerminalInput(pane.id, '\x1B[A',
                      enter: false, toastLabel: 'Sent Up'),
                  onDown: () => ctrl.sendTerminalInput(pane.id, '\x1B[B',
                      enter: false, toastLabel: 'Sent Down'),
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: pane.output));
                    ctrl.showToast('Copied output');
                  },
                ),
                const SizedBox(height: 8),
              ],

              // Composer row with ⌘ key-tray toggle + contextual ^C Stop when running
              Row(
                children: [
                  if (pane.rateLimit == null) ...[
                    Tooltip(
                      message: 'Terminal keys',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() {
                            _showQuickKeys = !_showQuickKeys;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            width: 36,
                            height: 38,
                            decoration: BoxDecoration(
                              color: keysVisible ? c.accentTint : c.raised,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: keysVisible
                                    ? c.accent.withValues(alpha: 0.35)
                                    : c.lineSubtle,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIconsRegular.keyboard,
                                size: 16,
                                color: keysVisible ? c.accentText : c.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  if (pane.status == 'running' &&
                      pane.rateLimit == null &&
                      !keysVisible) ...[
                    Tooltip(
                      message: 'Stop (^C)',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              ctrl.sendQuickAction(pane.id, 'interrupt'),
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            decoration: BoxDecoration(
                              color: c.failedTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: c.failed.withValues(alpha: 0.28)),
                            ),
                            child: Center(
                              child: Text(
                                '^C',
                                style: SlateTypography.data(
                                  c,
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: c.failed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: PromptComposer(
                      controller: _promptCtrl,
                      hint: pane.status == 'running'
                          ? 'Queue instruction…'
                          : 'Reply to ${pane.label}…',
                      primarySend: pane.status != 'running' &&
                          pane.status != 'needs_input' &&
                          pane.rateLimit == null,
                      onSend: () => _sendPrompt(pane),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
        SlateNotice(
          status: 'rate_limited',
          leading: const StatusGlyph(
              status: 'rate_limited', size: 16, animate: false),
          title:
              '${rl.fromProfile} hit its 5h limit · resets in ${rl.resetsInLabel}',
          body: rl.reason,
        ),
        if (healthy.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < healthy.length.clamp(0, 2); i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SlateButton(
                    label: 'Resume ${healthy[i].id}',
                    icon: PhosphorIconsRegular.arrowsLeftRight,
                    height: 38,
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
        const SizedBox(height: 8),
      ];
    }

    if (pane.status == 'needs_input') {
      return [
        SlateNotice(
          status: 'needs_input',
          leading: const StatusGlyph(
              status: 'needs_input', size: 16, animate: false),
          title: '${pane.label} wants your input',
          body: pane.message ?? 'Waiting for approval',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SlateButton(
                label: 'Approve',
                height: 38,
                variant: SlateButtonVariant.primary,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'approve'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SlateButton(
                label: 'Reject',
                height: 38,
                variant: SlateButtonVariant.raised,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'reject'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SlateButton(
                label: 'Stop',
                height: 38,
                variant: SlateButtonVariant.danger,
                expanded: true,
                onPressed: () => ctrl.sendQuickAction(pane.id, 'interrupt'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ];
    }

    if (pane.status == 'failed') {
      return [
        SlateNotice(
          status: 'failed',
          leading:
              const StatusGlyph(status: 'failed', size: 16, animate: false),
          title: pane.statusLabel,
          body: pane.message ?? 'Command exited with a non-zero status',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SlateButton(
                label: 'Run again',
                height: 36,
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
                height: 36,
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
        const SizedBox(height: 8),
      ];
    }

    return const [];
  }
}

class _ReaderRawToggle extends StatelessWidget {
  const _ReaderRawToggle({
    required this.isRaw,
    required this.onChanged,
  });

  final bool isRaw;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.lineSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            label: 'Reader',
            active: !isRaw,
            onTap: () => onChanged(false),
          ),
          _SegBtn(
            label: 'Raw',
            active: isRaw,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? c.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: active ? c.text : c.text3,
          ),
        ),
      ),
    );
  }
}
