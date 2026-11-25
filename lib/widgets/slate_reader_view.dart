import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/companion_models.dart';
import '../services/terminal_reader_parser.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';

/// Clean, typography-first mobile reader for AI agent outputs (Antigravity,
/// Codex, Claude Code, OpenCode, Gemini CLI). Reflows desktop hard-wraps into
/// crisp Inter prose, groups tool calls into collapsible cards, renders diffs
/// with horizontal scroll, and turns long URLs/paths into compact tappable pills.
class SlateReaderView extends StatefulWidget {
  const SlateReaderView({
    super.key,
    required this.pane,
    required this.onToast,
    this.controller,
    this.fontScale = 1.0,
  });

  final CompanionPane pane;
  final ValueChanged<String> onToast;
  final ScrollController? controller;
  final double fontScale;

  @override
  State<SlateReaderView> createState() => _SlateReaderViewState();
}

class _SlateReaderViewState extends State<SlateReaderView> {
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
  void didUpdateWidget(covariant SlateReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleScroll);
      _scrollCtrl.addListener(_handleScroll);
    }
    if (oldWidget.pane.id != widget.pane.id) {
      _stickToBottom = true;
      _scheduleScrollToBottom(force: true);
    } else if (oldWidget.pane.output != widget.pane.output && _stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    _stickToBottom = (pos.maxScrollExtent - pos.pixels) <= 84;
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
    final pane = widget.pane;
    final doc = TerminalReaderParser.parse(pane.output);
    final proseSize = (13.5 * widget.fontScale).clamp(11.0, 17.5);

    if (doc.blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsRegular.terminalWindow,
                size: 22,
                color: c.text3,
              ),
              const SizedBox(height: 8),
              Text(
                pane.status == 'running'
                    ? '${pane.label} is starting…'
                    : 'Waiting for output from ${pane.label}…',
                textAlign: TextAlign.center,
                style: SlateTypography.body2(c),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        // Subtle turn header with extracted model pill (no TUI footer clutter)
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: pane.provider ?? pane.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                    if (pane.profile != null && pane.profile!.isNotEmpty)
                      TextSpan(
                        text: ' · ${pane.profile}',
                        style: SlateTypography.data(c, size: 10.5),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (doc.modelTag != null && doc.modelTag!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.hover,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    doc.modelTag!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlateTypography.data(c, size: 10, color: c.text3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        for (var i = 0; i < doc.blocks.length; i++) ...[
          _buildBlock(context, doc.blocks[i], proseSize),
          if (i < doc.blocks.length - 1) const SizedBox(height: 11),
        ],

        if (pane.status == 'running' && pane.rateLimit == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: c.runningTint,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.running.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: c.running,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    pane.message != null && pane.message!.isNotEmpty
                        ? pane.message!
                        : '${pane.label} is working…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    ReaderBlock block,
    double proseSize,
  ) {
    final c = context.slate;
    switch (block) {
      case ReaderUserPromptBlock(:final text):
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.84,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  c.accent.withValues(alpha: 0.08),
                  c.raised,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: c.accent.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOU',
                    style: SlateTypography.data(
                      c,
                      size: 9.5,
                      weight: FontWeight.w600,
                      color: c.accentText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: (proseSize - 0.3).clamp(11.0, 16.5),
                      height: 1.48,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case ReaderHeadingBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: proseSize + 0.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: -0.15,
              color: c.text,
            ),
          ),
        );

      case ReaderParagraphBlock(:final text):
        return _RichInlineText(
          text: text,
          fontSize: proseSize,
          onToast: widget.onToast,
        );

      case ReaderListBlock(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: proseSize * 0.54, right: 9),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.text3,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _RichInlineText(
                      text: items[i],
                      fontSize: proseSize - 0.2,
                      onToast: widget.onToast,
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1) const SizedBox(height: 8),
            ],
          ],
        );

      case ReaderToolGroupBlock(:final items):
        return _CollapsibleToolGroupCard(items: items);

      case ReaderDiffBlock(:final fileName, :final lines, :final added, :final removed):
        return _HorizontalDiffCard(
          fileName: fileName,
          lines: lines,
          added: added,
          removed: removed,
        );

      case ReaderCodeBlock(:final language, :final lines):
        return _CodeBlockCard(
          language: language,
          lines: lines,
          onCopy: () {
            Clipboard.setData(ClipboardData(text: lines.join('\n')));
            widget.onToast('Copied code snippet');
          },
        );

      case ReaderStatusBlock(:final text, :final tone):
        final Color fg;
        final Color bg;
        switch (tone) {
          case 'error':
            fg = c.failed;
            bg = c.failedTint;
          case 'warn':
            fg = c.input;
            bg = c.inputTint;
          case 'success':
            fg = c.done;
            bg = c.doneTint;
          default:
            fg = c.accentText;
            bg = c.raised;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: tone == 'info' ? c.lineSubtle : fg.withValues(alpha: 0.26),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              height: 1.45,
              color: tone == 'info' ? c.text2 : fg,
            ),
          ),
        );
    }
  }
}

/// Renders natural Inter prose with inline `**bold**`, `` `code` ``, tappable
/// shortened URL pills, and compact file-path chips.
class _RichInlineText extends StatelessWidget {
  const _RichInlineText({
    required this.text,
    required this.fontSize,
    required this.onToast,
  });

  final String text;
  final double fontSize;
  final ValueChanged<String> onToast;

  static final RegExp _tokenRegex = RegExp(
    r'(\*\*[^*]+\*\*|`[^`]+`|https?://[^\s)\]>]+|(?:~/|(?:\.?/)?(?:[A-Za-z0-9_.-]+/)+)[A-Za-z0-9_.-]+\.[a-zA-Z0-9]{1,8})',
  );

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final baseStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      height: 1.56,
      letterSpacing: -0.05,
      color: c.text.withValues(alpha: 0.92),
    );

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in _tokenRegex.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, m.start),
          style: baseStyle,
        ));
      }
      final raw = m.group(0)!;
      if (raw.startsWith('**') && raw.endsWith('**') && raw.length > 4) {
        spans.add(TextSpan(
          text: raw.substring(2, raw.length - 2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ));
      } else if (raw.startsWith('`') && raw.endsWith('`') && raw.length > 2) {
        final code = raw.substring(1, raw.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: c.lineSubtle),
            ),
            child: Text(
              code,
              style: SlateTypography.data(
                c,
                size: (fontSize - 2.0).clamp(10.0, 14.0),
                color: c.text,
              ),
            ),
          ),
        ));
      } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
        // Trim trailing sentence punctuation (e.g. `.` or `,`)
        var url = raw;
        var trailing = '';
        while (url.isNotEmpty && '.,;:!?'.contains(url[url.length - 1])) {
          trailing = url[url.length - 1] + trailing;
          url = url.substring(0, url.length - 1);
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: url));
              onToast('Copied URL');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: c.accent.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.arrowUpRight,
                    size: 11,
                    color: c.accentText,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      _shortUrlLabel(url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlateTypography.data(
                        c,
                        size: 11,
                        weight: FontWeight.w500,
                        color: c.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: baseStyle));
        }
      } else {
        // File path pill (shows clean basename or last 2 segments; tap copies full path)
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: raw));
              onToast('Copied path: ${_shortPathLabel(raw)}');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: c.termCyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: c.termCyan.withValues(alpha: 0.22)),
              ),
              child: Text(
                _shortPathLabel(raw),
                style: SlateTypography.data(
                  c,
                  size: (fontSize - 2.2).clamp(10.0, 13.5),
                  color: c.termCyan,
                ),
              ),
            ),
          ),
        ));
      }
      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  static String _shortUrlLabel(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.host == 'github.com' && segs.length >= 2) {
      final repo = segs[1];
      if (segs.length >= 5 && segs[2] == 'releases' && segs[3] == 'tag') {
        return '$repo · ${segs[4]}';
      }
      return '$repo/${segs.last}';
    }
    if (segs.isEmpty) return uri.host;
    return '${uri.host}/…/${segs.last}';
  }

  static String _shortPathLabel(String path) {
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.length <= 2) return path;
    return segs.last;
  }
}

class _CollapsibleToolGroupCard extends StatefulWidget {
  const _CollapsibleToolGroupCard({required this.items});
  final List<ReaderToolItem> items;

  @override
  State<_CollapsibleToolGroupCard> createState() =>
      _CollapsibleToolGroupCardState();
}

class _CollapsibleToolGroupCardState extends State<_CollapsibleToolGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final items = widget.items;
    final anyRunning = items.any((e) => e.isRunning);
    final anyError = items.any((e) => e.isError);
    final hasDetails = items.length > 1 || items.any((e) => e.detailLines.isNotEmpty);

    final summary = items.length == 1
        ? items.first.title
        : '${items.length} tool actions · ${items.last.title}';

    final Color badgeFg = anyError
        ? c.failed
        : (anyRunning ? c.running : c.done);
    final Color badgeBg = anyError
        ? c.failedTint
        : (anyRunning ? c.runningTint : c.doneTint);

    return Container(
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.lineSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasDetails
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: anyRunning
                          ? SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: badgeFg,
                              ),
                            )
                          : Icon(
                              anyError
                                  ? PhosphorIconsBold.x
                                  : PhosphorIconsBold.check,
                              size: 11,
                              color: badgeFg,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (hasDetails) ...[
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 140),
                        child: Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 12,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_expanded && hasDetails)
            Container(
              decoration: BoxDecoration(
                color: c.inset,
                border: Border(top: BorderSide(color: c.lineSubtle)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var idx = 0; idx < items.length; idx++) ...[
                      Text(
                        items[idx].title,
                        style: SlateTypography.data(
                          c,
                          size: 11,
                          color: c.text,
                          weight: FontWeight.w500,
                        ),
                      ),
                      for (final detail in items[idx].detailLines)
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 2),
                          child: Text(
                            detail,
                            style: SlateTypography.data(
                              c,
                              size: 10.5,
                              color: c.text2,
                            ),
                          ),
                        ),
                      if (idx < items.length - 1) const SizedBox(height: 6),
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

class _HorizontalDiffCard extends StatelessWidget {
  const _HorizontalDiffCard({
    this.fileName,
    required this.lines,
    required this.added,
    required this.removed,
  });

  final String? fileName;
  final List<ReaderDiffLine> lines;
  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: c.raised,
              border: Border(bottom: BorderSide(color: c.lineSubtle)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.gitDiff, size: 13, color: c.text2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fileName ?? 'Changes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlateTypography.data(c, size: 11, color: c.text),
                  ),
                ),
                if (added > 0)
                  Text(
                    '+$added',
                    style: SlateTypography.data(c, size: 10.5, color: c.done),
                  ),
                if (added > 0 && removed > 0) const SizedBox(width: 5),
                if (removed > 0)
                  Text(
                    '-$removed',
                    style: SlateTypography.data(c, size: 10.5, color: c.failed),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final ln in lines)
                    Container(
                      color: ln.kind == 'add'
                          ? c.diffAdd
                          : (ln.kind == 'del' ? c.diffDel : null),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 1),
                      child: Row(
                        children: [
                          if (ln.lineNum != null)
                            SizedBox(
                              width: 30,
                              child: Text(
                                ln.lineNum!,
                                style: SlateTypography.data(
                                  c,
                                  size: 10.5,
                                  color: c.text4,
                                ),
                              ),
                            ),
                          Text(
                            ln.text,
                            style: SlateTypography.data(
                              c,
                              size: 11,
                              color: ln.kind == 'add'
                                  ? c.termGreen
                                  : (ln.kind == 'del'
                                      ? c.termRed
                                      : c.text2),
                            ),
                          ),
                        ],
                      ),
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

class _CodeBlockCard extends StatelessWidget {
  const _CodeBlockCard({
    this.language,
    required this.lines,
    required this.onCopy,
  });

  final String? language;
  final List<String> lines;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Container(
      decoration: BoxDecoration(
        color: c.inset,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.raised,
              border: Border(bottom: BorderSide(color: c.lineSubtle)),
            ),
            child: Row(
              children: [
                Text(
                  language ?? 'code',
                  style: SlateTypography.data(c, size: 10.5, color: c.text3),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCopy,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.copy, size: 12, color: c.text2),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: SlateTypography.data(
                          c,
                          size: 10.5,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              lines.join('\n'),
              style: SlateTypography.data(c, size: 11, color: c.termFg),
            ),
          ),
        ],
      ),
    );
  }
}
