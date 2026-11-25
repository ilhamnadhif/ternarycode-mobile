import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/companion_models.dart';
import '../services/ansi_parser.dart';
import '../theme/agent_icons.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Renders parsed ANSI & diff terminal output cleanly with optional line wrap
/// and smart auto-scroll to bottom (tracks new output without fighting manual scroll-up).
class TerminalOutputView extends StatefulWidget {
  const TerminalOutputView({
    super.key,
    required this.output,
    this.paneId,
    this.fontSize = 11.5,
    this.wrap = true,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
  });

  final String output;
  final int? paneId;
  final double fontSize;
  final bool wrap;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  @override
  State<TerminalOutputView> createState() => _TerminalOutputViewState();
}

class _TerminalOutputViewState extends State<TerminalOutputView> {
  ScrollController? _ownedController;
  bool _stickToBottom = true;

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
      _scheduleScrollToBottom(force: true);
    } else if (oldWidget.output != widget.output && _stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    _stickToBottom = (pos.maxScrollExtent - pos.pixels) <= 72;
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

  @override
  void dispose() {
    _scrollCtrl.removeListener(_handleScroll);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final lines = AnsiTerminalParser.parse(
      widget.output.isEmpty ? 'Waiting for terminal output…' : widget.output,
      c,
      fontSize: widget.fontSize,
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Container(
            color: line.background,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text.rich(
              TextSpan(children: line.spans),
              softWrap: widget.wrap,
              overflow:
                  widget.wrap ? TextOverflow.visible : TextOverflow.clip,
            ),
          ),
      ],
    );

    final verticalPad = widget.padding.resolve(TextDirection.ltr);

    if (!widget.wrap) {
      return SingleChildScrollView(
        controller: _scrollCtrl,
        padding:
            EdgeInsets.only(top: verticalPad.top, bottom: verticalPad.bottom),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(child: column),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding:
          EdgeInsets.only(top: verticalPad.top, bottom: verticalPad.bottom),
      child: column,
    );
  }
}

/// Framed Slate terminal sheet with semantic attention ring & crisp pane header.
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
        color: c.sheet,
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
              output: pane.output,
              fontSize: fontSize,
              wrap: wrap,
            ),
          ),
        ],
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

/// Prompt / command composer row.
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
      children: [
        Expanded(
          child: SlateTextField(
            controller: controller,
            hint: hint,
            compact: true,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
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
