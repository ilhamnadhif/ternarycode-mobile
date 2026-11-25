import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/interactive_prompt_parser.dart';
import '../state/app_controller.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';
import '../widgets/terminal_view.dart';

/// Screen 08 · Fullscreen Raw Terminal with A-/A+ text zoom, line-wrap toggle,
/// interactive prompt 1-tap choice dock, scroll-to-latest pill, Copy, and quick keys.
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
  final TextEditingController _promptCtrl = TextEditingController();

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final pane = ctrl.snapshot.panes
                .where((p) => p.id == widget.paneId)
                .firstOrNull ??
            ctrl.selectedPane;
        final settings = ctrl.settings;
        final interactivePrompt = pane != null
            ? InteractivePromptParser.parse(pane.output)
            : null;
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 100;

        return Scaffold(
          backgroundColor: c.window,
          body: SafeArea(
            child: Column(
              children: [
                // Compact top bar with A- / A+ zoom & line wrap toggle
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  decoration: BoxDecoration(
                    color: c.sheet,
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
                  ),
                ),

                // Edge-to-edge polished raw terminal canvas
                Expanded(
                  child: ColoredBox(
                    color: isDark ? c.inset : c.sheet,
                    child: TerminalOutputView(
                      paneId: pane?.id,
                      agentLabel: pane?.label,
                      isRunning: pane != null &&
                          pane.status == 'running' &&
                          pane.rateLimit == null,
                      runningMessage: pane?.message,
                      output: pane?.output ?? '',
                      fontSize: settings.termFontSize,
                      wrap: settings.termWrap,
                      showLatestPill: true,
                    ),
                  ),
                ),

                // Interactive prompt dock + quick keys + multiline composer bar
                if (pane != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: BoxDecoration(
                      color: c.window,
                      border: Border(top: BorderSide(color: c.lineSubtle)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (interactivePrompt != null &&
                            pane.rateLimit == null) ...[
                          InteractivePromptDock(
                            prompt: interactivePrompt,
                            compact: keyboardOpen,
                            onSelect: (opt) => ctrl.selectInteractiveOption(
                                pane.id, interactivePrompt, opt),
                            onCancel: () => ctrl.sendTerminalInput(
                              pane.id,
                              '\x1B',
                              enter: false,
                              toastLabel: 'Sent Esc',
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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
