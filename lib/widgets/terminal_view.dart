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
  bool _jumping = false;

  // Memoized parsed terminal lines so scrolling, toasts, and composer typing
  // never re-run regex parsing when output/font/theme haven't changed.
  String? _cachedOutput;
  double? _cachedFontSize;
  bool? _cachedIsDark;
  List<TerminalLineData> _cachedLines = const [];

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
    if (oldWidget.paneId != widget.paneId ||
        (oldWidget.output.trim().isEmpty && widget.output.trim().isNotEmpty)) {
      _stickToBottom = true;
      _scrolledUp = false;
      _scheduleScrollToBottom(force: true);
    } else if ((oldWidget.output != widget.output ||
            oldWidget.wrap != widget.wrap ||
            oldWidget.fontSize != widget.fontSize) &&
        _stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients || _jumping) return;
    final pos = _scrollCtrl.position;
    if (pos.maxScrollExtent <= 0) {
      _stickToBottom = true;
      if (_scrolledUp && mounted) {
        setState(() => _scrolledUp = false);
      }
      return;
    }
    final dist = pos.maxScrollExtent - pos.pixels;
    _stickToBottom = dist <= 64;
    final up = dist > 72;
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
      if (_scrolledUp && mounted) {
        setState(() => _scrolledUp = false);
      }
    });
  }

  Future<void> _jumpToLatest() async {
    if (!_scrollCtrl.hasClients) return;
    _stickToBottom = true;
    _jumping = true;
    if (_scrolledUp && mounted) {
      setState(() => _scrolledUp = false);
    }
    try {
      await _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      if (mounted && _scrollCtrl.hasClients) {
        final max = _scrollCtrl.position.maxScrollExtent;
        if ((_scrollCtrl.position.pixels - max).abs() > 2) {
          _scrollCtrl.jumpTo(max);
        }
      }
    } finally {
      _jumping = false;
    }
  }

  List<TerminalLineData> _parsedLines(SlateColors c) {
    if (_cachedOutput == widget.output &&
        _cachedFontSize == widget.fontSize &&
        _cachedIsDark == c.isDark) {
      return _cachedLines;
    }
    _cachedOutput = widget.output;
    _cachedFontSize = widget.fontSize;
    _cachedIsDark = c.isDark;
    _cachedLines = AnsiTerminalParser.parse(
      widget.output,
      c,
      fontSize: widget.fontSize,
    );
    return _cachedLines;
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_handleScroll);
    _ownedController?.dispose();
    super.dispose();
  }

  List<Widget> _buildWrappedChildren(
    List<TerminalLineData> lines,
    SlateColors c,
    double hPad,
  ) {
    final widgets = <Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 1. Desktop-width horizontal rules (`────…`) become a single crisp
      //    phone-width hairline instead of wrapping into 3–4 stacked lines.
      if (line.isHorizontalRule) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 5),
            child: Container(
              height: 1,
              color: c.line,
            ),
          ),
        );
        i++;
        continue;
      }

      // 2. Contiguous multi-column box/pipe tables stay column-aligned inside
      //    an inline horizontally scrollable strip while prose still wraps.
      if (line.isTableLine) {
        final block = <TerminalLineData>[];
        while (i < lines.length && lines[i].isTableLine) {
          block.add(lines[i]);
          i++;
        }
        if (block.length >= 2) {
          widgets.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: c.hover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.lineSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row in block)
                          Container(
                            color: row.background,
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Text.rich(
                              TextSpan(children: row.spans),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          continue;
        }
        // Single stray box line falls through to regular line rendering.
        for (final row in block) {
          widgets.add(_buildRegularLine(row, hPad, wrap: true));
        }
        continue;
      }

      widgets.add(_buildRegularLine(line, hPad, wrap: true));
      i++;
    }
    return widgets;
  }

  Widget _buildRegularLine(
    TerminalLineData line,
    double hPad, {
    required bool wrap,
  }) {
    return Container(
      color: line.background,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: line.isPromptBand ? 2.5 : 0.5,
      ),
      child: Text.rich(
        TextSpan(children: line.spans),
        softWrap: wrap,
        overflow: wrap ? TextOverflow.visible : TextOverflow.clip,
      ),
    );
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

    final lines = _parsedLines(c);
    final verticalPad = widget.padding.resolve(TextDirection.ltr);
    final hPad = verticalPad.left;

    final runningFooter = widget.isRunning
        ? Padding(
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
          )
        : null;

    final Widget innerContent = widget.wrap
        ? SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildWrappedChildren(lines, c, hPad),
                ?runningFooter,
              ],
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines)
                      _buildRegularLine(line, hPad, wrap: false),
                    ?runningFooter,
                  ],
                ),
              ),
            ),
          );

    // IMPORTANT: Keep a stable Stack -> Positioned.fill -> SingleChildScrollView
    // tree regardless of `_scrolledUp` or `widget.wrap` so Flutter NEVER unmounts
    // the ScrollPosition and resets scroll offset back to 0.0 when reaching bottom.
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              // Ignore metrics bubbling up from nested horizontal table/wrap scrollers!
              if (n.depth != 0 || n.metrics.axis != Axis.vertical) {
                return false;
              }
              if (_stickToBottom && !_jumping && _scrollCtrl.hasClients) {
                final max = n.metrics.maxScrollExtent;
                if (max > 0 && (n.metrics.pixels - max).abs() > 2) {
                  _scheduleScrollToBottom();
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                top: verticalPad.top,
                bottom: verticalPad.bottom,
              ),
              child: innerContent,
            ),
          ),
        ),
        if (widget.showLatestPill && _scrolledUp)
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
