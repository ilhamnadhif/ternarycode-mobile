import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../services/ansi_parser.dart';
import '../services/interactive_prompt_parser.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Polished mobile raw terminal canvas:
/// - Crisp JetBrainsMono rendering with rich ANSI & plain-text semantic coloring
/// - Native text selection (`SelectionArea`) for easy long-press copying
/// - Smart stick-to-bottom streaming + floating "Latest" jump-to-bottom pill
/// - Smooth horizontal scrolling when line-wrap is off (tables, wide diffs)
/// - Styled empty state & subtle live running indicator strip
class TerminalOutputView extends StatefulWidget {
  const TerminalOutputView({
    super.key,
    required this.output,
    this.paneId,
    this.agentLabel,
    this.isRunning = false,
    this.runningMessage,
    this.fontSize = 11.5,
    this.wrap = true,
    this.showLatestPill = true,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 14),
  });

  final String output;
  final int? paneId;
  final String? agentLabel;
  final bool isRunning;
  final String? runningMessage;
  final double fontSize;
  final bool wrap;
  final bool showLatestPill;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  @override
  State<TerminalOutputView> createState() => _TerminalOutputViewState();
}

class _TerminalOutputViewState extends State<TerminalOutputView> {
  ScrollController? _ownedController;
  bool _stickToBottom = true;
  bool _scrolledUp = false;

  ScrollController get _scrollCtrl =>
      widget.controller ?? (_ownedController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_handleScroll);
    _scheduleScrollToBottom(force: true);
  }

  @override
  void didUpdateWidget(covariant TerminalOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleScroll);
      _scrollCtrl.addListener(_handleScroll);
    }
    if (oldWidget.paneId != widget.paneId) {
      _stickToBottom = true;
      _scrolledUp = false;
      _scheduleScrollToBottom(force: true);
    } else if (oldWidget.output != widget.output && _stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final dist = pos.maxScrollExtent - pos.pixels;
    _stickToBottom = dist <= 72;
    final up = dist > 84;
    if (up != _scrolledUp && mounted) {
      setState(() => _scrolledUp = up);
    }
  }

  void _scheduleScrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (!force && !_stickToBottom) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (max > 0) {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  void _jumpToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _stickToBottom = true;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_handleScroll);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final trimmed = widget.output.trim();
    if (trimmed.isEmpty) {
      final label = widget.agentLabel ?? 'terminal';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.lineSubtle),
                ),
                child: Icon(
                  PhosphorIconsRegular.terminalWindow,
                  size: 19,
                  color: c.text3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isRunning
                    ? '$label is starting…'
                    : 'Waiting for output from $label…',
                textAlign: TextAlign.center,
                style: SlateTypography.body2(c),
              ),
            ],
          ),
        ),
      );
    }

    final lines = AnsiTerminalParser.parse(
      widget.output,
      c,
      fontSize: widget.fontSize,
    );

    final verticalPad = widget.padding.resolve(TextDirection.ltr);
    final hPad = verticalPad.left;

    final column = SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Container(
              color: line.background,
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: line.isPromptBand ? 2.5 : 0.5,
              ),
              child: Text.rich(
                TextSpan(children: line.spans),
                softWrap: widget.wrap,
                overflow:
                    widget.wrap ? TextOverflow.visible : TextOverflow.clip,
              ),
            ),
          if (widget.isRunning)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: c.running,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.runningMessage != null &&
                              widget.runningMessage!.isNotEmpty
                          ? widget.runningMessage!
                          : '${widget.agentLabel ?? 'Agent'} is working…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.data(
                        c,
                        size: 11,
                        color: c.text2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final Widget scrollBody = !widget.wrap
        ? SingleChildScrollView(
            controller: _scrollCtrl,
            padding: EdgeInsets.only(
                top: verticalPad.top, bottom: verticalPad.bottom),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(child: column),
            ),
          )
        : SingleChildScrollView(
            controller: _scrollCtrl,
            padding: EdgeInsets.only(
                top: verticalPad.top, bottom: verticalPad.bottom),
            child: column,
          );

    if (!widget.showLatestPill || !_scrolledUp) {
      return scrollBody;
    }

    return Stack(
      children: [
        Positioned.fill(child: scrollBody),
        Positioned(
          right: 12,
          bottom: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _jumpToLatest,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.lineStrong),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 10,
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
                      'Latest',
                      style: SlateTypography.data(c,
                          size: 11, color: c.text, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Framed Slate terminal sheet with semantic attention ring & crisp pane header
/// (used in Inbox Detail preview).
class TerminalSheet extends StatelessWidget {
  const TerminalSheet({
    super.key,
    required this.pane,
    required this.fontSize,
    required this.wrap,
    this.onExpand,
    this.showHeader = true,
  });

  final CompanionPane pane;
  final double fontSize;
  final bool wrap;
  final VoidCallback? onExpand;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final isWaiting = pane.status == 'needs_input';
    final isLimited = pane.rateLimit != null;

    final borderColor = isWaiting
        ? c.input.withValues(alpha: 0.58)
        : isLimited
            ? c.limited.withValues(alpha: 0.58)
            : c.line;

    final whereParts = <String>[
      if (pane.profile != null && pane.profile!.isNotEmpty)
        pane.profile!
      else
        pane.label,
      if (pane.branch != null && pane.branch!.isNotEmpty) pane.branch!,
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isWaiting
            ? [
                BoxShadow(
                  color: c.input.withValues(alpha: 0.14),
                  blurRadius: 0,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.sheet,
                border: Border(bottom: BorderSide(color: c.lineSubtle)),
              ),
              child: Row(
                children: [
                  AgentTile(agent: pane.agentKey),
                  const SizedBox(width: 7),
                  StatusPill(
                    status: pane.effectiveStatus,
                    label: pane.effectiveStatusLabel,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      whereParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: SlateTypography.data(c),
                    ),
                  ),
                  if (onExpand != null) ...[
                    const SizedBox(width: 7),
                    SlateIconButton(
                      icon: PhosphorIconsRegular.arrowsOutSimple,
                      tooltip: 'Fullscreen terminal',
                      small: true,
                      onPressed: onExpand,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: TerminalOutputView(
              paneId: pane.id,
              agentLabel: pane.label,
              isRunning: pane.status == 'running' && pane.rateLimit == null,
              runningMessage: pane.message,
              output: pane.output,
              fontSize: fontSize,
              wrap: wrap,
              showLatestPill: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, thumb-friendly 1-tap choice dock shown right above the composer
/// whenever an active TUI prompt (Claude workspace trust dialog, permission
/// menu, Codex/Gemini approval, or `[Y/n]`) is detected in raw terminal output.
class InteractivePromptDock extends StatelessWidget {
  const InteractivePromptDock({
    super.key,
    required this.prompt,
    required this.onSelect,
    this.onCancel,
    this.compact = false,
  });

  final InteractivePrompt prompt;
  final ValueChanged<InteractivePromptOption> onSelect;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final twoShort = prompt.options.length == 2 &&
        prompt.options.every((o) => o.label.length <= 20);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: c.inputTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.input.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.input,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  prompt.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              if (prompt.allowsEsc && onCancel != null) ...[
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(6),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.raised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.lineSubtle),
                      ),
                      child: Text(
                        'Esc',
                        style: SlateTypography.data(
                          c,
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          if (twoShort)
            Row(
              children: [
                for (var i = 0; i < prompt.options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _DockOptionButton(
                      option: prompt.options[i],
                      isPrimary: !prompt.options[i].isDanger &&
                          (prompt.options[i].isSelected || i == 0),
                      onTap: () => onSelect(prompt.options[i]),
                    ),
                  ),
                ],
              ],
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: compact ? 84 : 156),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < prompt.options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 5),
                      _DockOptionButton(
                        option: prompt.options[i],
                        isPrimary: !prompt.options[i].isDanger &&
                            (prompt.options[i].isSelected || i == 0),
                        alignLeft: true,
                        onTap: () => onSelect(prompt.options[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DockOptionButton extends StatelessWidget {
  const _DockOptionButton({
    required this.option,
    required this.isPrimary,
    required this.onTap,
    this.alignLeft = false,
  });

  final InteractivePromptOption option;
  final bool isPrimary;
  final VoidCallback onTap;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final bg = isPrimary ? c.accent : c.raised;
    final border = isPrimary ? c.accent : c.line;
    final fg = isPrimary
        ? Colors.white
        : option.isDanger
            ? c.text2
            : c.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment:
                alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android quick terminal accessory keys (`↵ Enter`, `Esc`, `^C Stop`, `Tab`, `↑`, `↓`).
class QuickKeysStrip extends StatelessWidget {
  const QuickKeysStrip({
    super.key,
    required this.onEnter,
    required this.onEsc,
    required this.onInterrupt,
    required this.onTab,
    required this.onUp,
    required this.onDown,
    this.onCopy,
  });

  final VoidCallback onEnter;
  final VoidCallback onEsc;
  final VoidCallback onInterrupt;
  final VoidCallback onTab;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _KeyChip(
            icon: PhosphorIconsRegular.keyReturn,
            label: 'Enter',
            onTap: onEnter,
          ),
          const SizedBox(width: 5),
          _KeyChip(label: 'Esc', onTap: onEsc),
          const SizedBox(width: 5),
          _KeyChip(label: '^C Stop', warn: true, onTap: onInterrupt),
          const SizedBox(width: 5),
          _KeyChip(label: 'Tab', onTap: onTab),
          const SizedBox(width: 5),
          _KeyChip(
            icon: PhosphorIconsRegular.arrowUp,
            label: '',
            tooltip: 'Arrow Up',
            onTap: onUp,
          ),
          const SizedBox(width: 5),
          _KeyChip(
            icon: PhosphorIconsRegular.arrowDown,
            label: '',
            tooltip: 'Arrow Down',
            onTap: onDown,
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 5),
            _KeyChip(label: 'Copy', onTap: onCopy!),
          ],
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.tooltip,
    this.warn = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final fg = warn ? c.failed : c.text2;
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: warn ? c.failedTint : c.raised,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: warn ? c.failed.withValues(alpha: 0.24) : c.lineSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: fg),
                if (label.isNotEmpty) const SizedBox(width: 4),
              ],
              if (label.isNotEmpty)
                Text(
                  label,
                  style: SlateTypography.data(
                    c,
                    size: 11,
                    color: fg,
                    weight: warn ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Multiline prompt / command composer row (keyboard Enter = newline, Send button submits).
class PromptComposer extends StatelessWidget {
  const PromptComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.primarySend = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final bool primarySend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SlateTextField(
            controller: controller,
            hint: hint,
            compact: true,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
        ),
        const SizedBox(width: 8),
        SlateButton(
          label: 'Send',
          height: 38,
          variant: primarySend
              ? SlateButtonVariant.primary
              : SlateButtonVariant.secondary,
          onPressed: onSend,
        ),
      ],
    );
  }
}
