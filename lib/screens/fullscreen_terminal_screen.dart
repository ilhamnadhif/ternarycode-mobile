import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_reader_view.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/terminal_view.dart';

/// Screen 08 · Fullscreen Reader / Raw Terminal with A-/A+ text zoom,
/// Reader/Raw switch, wrap toggle (Raw), scroll-to-latest pill, Copy, and quick keys.
class FullscreenTerminalScreen extends StatefulWidget {
  const FullscreenTerminalScreen({
    super.key,
    required this.controller,
    required this.paneId,
  });

  final AppController controller;
  final int paneId;

  @override
  State<FullscreenTerminalScreen> createState() =>
      _FullscreenTerminalScreenState();
}

class _FullscreenTerminalScreenState extends State<FullscreenTerminalScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _promptCtrl = TextEditingController();
  bool _showLatestPill = false;
  bool? _rawOverride;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final distFromBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset;
    final show = distFromBottom > 48;
    if (show != _showLatestPill) {
      setState(() => _showLatestPill = show);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final pane = ctrl.snapshot.panes
                .where((p) => p.id == widget.paneId)
                .firstOrNull ??
            ctrl.selectedPane;
        final settings = ctrl.settings;
        final isRaw = _rawOverride ?? (pane?.agentKey == 'shell');

        return Scaffold(
          backgroundColor: c.window,
          body: SafeArea(
            child: Column(
              children: [
                // Compact top bar
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.lineSubtle)),
                  ),
                  child: Row(
                    children: [
                      SlateIconButton(
                        icon: PhosphorIconsRegular.arrowLeft,
                        tooltip: 'Back',
                        small: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      if (pane != null) AgentTile(agent: pane.agentKey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pane != null
                                  ? '${pane.projectName} · ${pane.label}'
                                  : 'Terminal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SlateTypography.body(c,
                                      weight: FontWeight.w500)
                                  .copyWith(fontSize: 12.5),
                            ),
                            Text(
                              pane != null
                                  ? '${pane.profile ?? 'shell'}${pane.branch != null ? ' · ${pane.branch}' : ''}'
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SlateTypography.data(c),
                            ),
                          ],
                        ),
                      ),
                      SlateIconButton(
                        icon: null,
                        label: isRaw ? 'Raw' : 'Rdr',
                        tooltip: isRaw
                            ? 'Switch to Reader view'
                            : 'Switch to Raw terminal',
                        small: true,
                        active: !isRaw,
                        onPressed: () => setState(() => _rawOverride = !isRaw),
                      ),
                      const SizedBox(width: 5),
                      SlateIconButton(
                        icon: null,
                        label: 'A-',
                        tooltip: 'Smaller text',
                        small: true,
                        onPressed: () => ctrl.updateSettings(
                          settings.copyWith(
                            termFontSize:
                                (settings.termFontSize - 1).clamp(9.0, 16.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SlateIconButton(
                        icon: null,
                        label: 'A+',
                        tooltip: 'Larger text',
                        small: true,
                        onPressed: () => ctrl.updateSettings(
                          settings.copyWith(
                            termFontSize:
                                (settings.termFontSize + 1).clamp(9.0, 16.0),
                          ),
                        ),
                      ),
                      if (isRaw) ...[
                        const SizedBox(width: 5),
                        SlateIconButton(
                          icon: PhosphorIconsRegular.arrowUDownLeft,
                          tooltip: 'Toggle line wrap',
                          small: true,
                          active: settings.termWrap,
                          onPressed: () => ctrl.updateSettings(
                            settings.copyWith(termWrap: !settings.termWrap),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Edge-to-edge Reader or Raw terminal canvas
                Expanded(
                  child: Container(
                    color: isRaw ? c.inset : c.sheet,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: isRaw || pane == null
                              ? TerminalOutputView(
                                  paneId: pane?.id,
                                  controller: _scrollCtrl,
                                  output: pane?.output ?? '',
                                  fontSize: settings.termFontSize,
                                  wrap: settings.termWrap,
                                )
                              : SlateReaderView(
                                  pane: pane,
                                  controller: _scrollCtrl,
                                  onToast: ctrl.showToast,
                                  fontScale: (settings.termFontSize / 11.5)
                                      .clamp(0.85, 1.35),
                                ),
                        ),
                        if (_showLatestPill)
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _scrollToBottom,
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  height: 28,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11),
                                  decoration: BoxDecoration(
                                    color: c.raised,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: c.lineStrong),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(PhosphorIconsRegular.arrowDown,
                                          size: 12, color: c.text),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Latest output',
                                        style: SlateTypography.data(c,
                                            color: c.text),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Quick keys + composer bar
                if (pane != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: BoxDecoration(
                      color: c.window,
                      border: Border(top: BorderSide(color: c.lineSubtle)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuickKeysStrip(
                          onEnter: () => ctrl.sendTerminalInput(pane.id, '',
                              enter: true, toastLabel: 'Sent Enter'),
                          onEsc: () => ctrl.sendTerminalInput(pane.id, '\x1B',
                              enter: false, toastLabel: 'Sent Esc'),
                          onInterrupt: () =>
                              ctrl.sendQuickAction(pane.id, 'interrupt'),
                          onTab: () => ctrl.sendTerminalInput(pane.id, '\t',
                              enter: false, toastLabel: 'Sent Tab'),
                          onUp: () => ctrl.sendTerminalInput(pane.id, '\x1B[A',
                              enter: false, toastLabel: 'Sent Up'),
                          onDown: () => ctrl.sendTerminalInput(
                              pane.id, '\x1B[B',
                              enter: false, toastLabel: 'Sent Down'),
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: pane.output));
                            ctrl.showToast('Copied output to clipboard');
                          },
                        ),
                        const SizedBox(height: 8),
                        PromptComposer(
                          controller: _promptCtrl,
                          hint: 'Type command or instruction…',
                          primarySend: true,
                          onSend: () {
                            final t = _promptCtrl.text.trim();
                            if (t.isEmpty) return;
                            _promptCtrl.clear();
                            ctrl.sendTerminalInput(pane.id, t, enter: true);
                          },
                        ),
                      ],
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
