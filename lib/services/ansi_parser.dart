import 'package:flutter/material.dart';
import '../theme/slate_tokens.dart';

/// Parsed terminal line with optional full-bleed background wash, subtle edge
/// inset, and syntax-highlighted monospace spans preserving exact column fidelity.
class TerminalLineData {
  const TerminalLineData({
    required this.spans,
    this.background,
    this.isPromptBand = false,
  });

  final List<TextSpan> spans;
  final Color? background;
  final bool isPromptBand;
}

/// Renders authentic raw PTY output (both ANSI SGR streams and plain-text
/// desktop `screen_tail` snapshots from Claude Code, Codex CLI, Antigravity CLI,
/// OpenCode, Gemini CLI, and zsh) with refined, eye-friendly Slate syntax
/// highlighting while preserving 100% verbatim text & column alignment.
class AnsiTerminalParser {
  static final RegExp _sgrRegex = RegExp(r'\x1B\[([0-9;]*)m');
  static final RegExp _otherEscRegex =
      RegExp(r'\x1B(?:\][^\x07\x1B]*(?:\x07|\x1B\\)|\[[0-9;?]*[A-LN-Za-ln-z]|\([A-Za-z0-9])');
  static final RegExp _diffAddRegex = RegExp(r'^(\s*\d+)(\s+)(\+\s?.*)$');
  static final RegExp _diffDelRegex = RegExp(r'^(\s*\d+)(\s+)(-\s?.*)$');
  static final RegExp _ruleLineRegex = RegExp(r'^[\s─━═╭╮╰╯┌┐└┘┬┴┼]+$');
  static final RegExp _tuiChromeHintRegex = RegExp(
    r'(?:\?\s*for\s+shortcuts|esc\s+to\s+(?:interrupt|cancel)|ctrl\+c\s+to|shift\+tab|alt\+enter|enter\s+to\s+(?:confirm|select|send)|bypass\s+permissions|accept\s+edits|←\s*for\s+agents)',
    caseSensitive: false,
  );
  static final RegExp _modelBarRegex = RegExp(
    r'^(?:auto|manual)\s*[·•]|^\d+%\s+context\s+left|^[A-Za-z0-9._-]+\s+(?:low|medium|high|xhigh)\s*[·•]',
    caseSensitive: false,
  );
  static final RegExp _selectedOptionRegex =
      RegExp(r'^(\s*[│┃]?\s*)([❯›▸→◉])(\s+(?:\d+[.)]\s+|\S).*)$');
  static final RegExp _toolVerbRegex = RegExp(
    r'^(\s*)([●•◦✓✔✗✘▸▹]\s*)?((?:Ran|Running|Executed|Explored|Read|Reading|Edited|Editing|Updated|Updating|Created|Wrote|Deleted|Searched|Searching|Checked|Applied|Patched|Built|Tested|Fetched)\s+\S.{0,120}|(?:Bash|Read|Edit|Write|Update|MultiEdit|Grep|Glob|Search|Task|WebFetch|WebSearch|NotebookEdit|Tool)\s*\(.+\))$',
    caseSensitive: false,
  );
  static final RegExp _headingRegex = RegExp(r'^(\s*#{1,3}\s+)(.+)$');
  static final RegExp _inlineHighlightRegex = RegExp(
    r'(https?://[^\s)\]>]+|`[^`]+`|\*\*[^*]+\*\*)',
  );

  static List<TerminalLineData> parse(
    String raw,
    SlateColors c, {
    double fontSize = 11.5,
  }) {
    final baseStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['Inter', 'sans-serif'],
      fontSize: fontSize,
      height: 1.52,
      letterSpacing: -0.1,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: c.termFg,
    );
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('⏺', '●')
        .replaceAll('⎿', '└');
    final lines = normalized.split('\n');
    final result = <TerminalLineData>[];

    Color? activeFg;
    Color? activeBg;
    bool bold = false;
    bool dim = false;
    bool italic = false;
    bool underline = false;

    for (final rawLine in lines) {
      final hasAnsi = rawLine.contains('\x1B');
      if (hasAnsi) {
        final cleaned = rawLine.replaceAll(_otherEscRegex, '');
        final spans = <TextSpan>[];
        var cursor = 0;
        for (final m in _sgrRegex.allMatches(cleaned)) {
          if (m.start > cursor) {
            spans.add(TextSpan(
              text: cleaned.substring(cursor, m.start),
              style: baseStyle.copyWith(
                color: dim ? c.termDim : (activeFg ?? c.termFg),
                backgroundColor: activeBg,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                decoration:
                    underline ? TextDecoration.underline : TextDecoration.none,
              ),
            ));
          }
          final codes = (m.group(1) ?? '')
              .split(';')
              .map((s) => int.tryParse(s) ?? 0)
              .toList();
          for (var i = 0; i < codes.length; i++) {
            final code = codes[i];
            if (code == 0) {
              activeFg = null;
              activeBg = null;
              bold = false;
              dim = false;
              italic = false;
              underline = false;
            } else if (code == 1) {
              bold = true;
            } else if (code == 2) {
              dim = true;
            } else if (code == 3) {
              italic = true;
            } else if (code == 4) {
              underline = true;
            } else if (code == 22) {
              bold = false;
              dim = false;
            } else if (code == 23) {
              italic = false;
            } else if (code == 24) {
              underline = false;
            } else if (code == 39) {
              activeFg = null;
            } else if (code == 49) {
              activeBg = null;
            } else if (code == 38 && i + 2 < codes.length && codes[i + 1] == 5) {
              activeFg = _ansi256(codes[i + 2], c);
              i += 2;
            } else if (code == 38 && i + 4 < codes.length && codes[i + 1] == 2) {
              activeFg = Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]);
              i += 4;
            } else if (code == 48 && i + 2 < codes.length && codes[i + 1] == 5) {
              activeBg = _ansi256(codes[i + 2], c)?.withValues(alpha: 0.22);
              i += 2;
            } else if (code == 48 && i + 4 < codes.length && codes[i + 1] == 2) {
              activeBg = Color.fromARGB(56, codes[i + 2], codes[i + 3], codes[i + 4]);
              i += 4;
            } else {
              final mapped = _ansiColor(code, c);
              if (mapped != null) {
                activeFg = mapped;
                dim = false;
              }
            }
          }
          cursor = m.end;
        }
        if (cursor < cleaned.length) {
          spans.add(TextSpan(
            text: cleaned.substring(cursor),
            style: baseStyle.copyWith(
              color: dim ? c.termDim : (activeFg ?? c.termFg),
              backgroundColor: activeBg,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  underline ? TextDecoration.underline : TextDecoration.none,
            ),
          ));
        }
        result.add(TerminalLineData(
          spans: spans.isEmpty ? [TextSpan(text: ' ', style: baseStyle)] : spans,
        ));
        continue;
      }

      // ── Plain-text semantic styling (matches desktop screen_tail snapshots) ──
      if (rawLine.isEmpty) {
        result.add(TerminalLineData(spans: [TextSpan(text: ' ', style: baseStyle)]));
        continue;
      }

      final trimmed = rawLine.trim();

      // 1. Horizontal TUI rules & box borders recede softly instead of glaring
      if (trimmed.length >= 4 && _ruleLineRegex.hasMatch(trimmed)) {
        result.add(TerminalLineData(spans: [
          TextSpan(
            text: rawLine,
            style: baseStyle.copyWith(color: c.text3.withValues(alpha: 0.45)),
          ),
        ]));
        continue;
      }

      // 2. Numbered & unified diff deletions / additions / hunk headers
      final numDel = _diffDelRegex.firstMatch(rawLine);
      if (numDel != null) {
        result.add(TerminalLineData(
          background: c.diffDel,
          spans: [
            TextSpan(
              text: numDel.group(1),
              style: baseStyle.copyWith(color: c.termDim),
            ),
            TextSpan(text: numDel.group(2), style: baseStyle),
            TextSpan(
              text: numDel.group(3),
              style: baseStyle.copyWith(color: c.termRed),
            ),
          ],
        ));
        continue;
      }
      if (rawLine.startsWith('-') &&
          !rawLine.startsWith('---') &&
          !rawLine.startsWith('- ')) {
        result.add(TerminalLineData(
          background: c.diffDel,
          spans: [
            TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termRed)),
          ],
        ));
        continue;
      }

      final numAdd = _diffAddRegex.firstMatch(rawLine);
      if (numAdd != null) {
        result.add(TerminalLineData(
          background: c.diffAdd,
          spans: [
            TextSpan(
              text: numAdd.group(1),
              style: baseStyle.copyWith(color: c.termDim),
            ),
            TextSpan(text: numAdd.group(2), style: baseStyle),
            TextSpan(
              text: numAdd.group(3),
              style: baseStyle.copyWith(color: c.termGreen),
            ),
          ],
        ));
        continue;
      }
      if (rawLine.startsWith('+') && !rawLine.startsWith('+++')) {
        result.add(TerminalLineData(
          background: c.diffAdd,
          spans: [
            TextSpan(
                text: rawLine, style: baseStyle.copyWith(color: c.termGreen)),
          ],
        ));
        continue;
      }

      if (trimmed.startsWith('@@ ') ||
          trimmed.startsWith('diff --git ') ||
          trimmed.startsWith('--- ') ||
          trimmed.startsWith('+++ ')) {
        result.add(TerminalLineData(spans: [
          TextSpan(
            text: rawLine,
            style: baseStyle.copyWith(
              color: c.termCyan,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]));
        continue;
      }

      // 3. Bottom TUI shortcut hints & model status bars (calm muted footer)
      if (_tuiChromeHintRegex.hasMatch(trimmed)) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termDim)),
        ]));
        continue;
      }
      if (trimmed.length <= 84 && _modelBarRegex.hasMatch(trimmed)) {
        result.add(TerminalLineData(
          spans: _styleModelBar(rawLine, baseStyle, c),
        ));
        continue;
      }

      // 4. Highlighted TUI menu choice (`❯ 1. Yes, I trust this folder`)
      final selOpt = _selectedOptionRegex.firstMatch(rawLine);
      if (selOpt != null &&
          (RegExp(r'^\s*\d+[.)]\s+').hasMatch(selOpt.group(3)!) ||
              RegExp(r'^\s*(?:Yes|No|Allow|Deny|Cancel|Trust|Skip|Approve)',
                      caseSensitive: false)
                  .hasMatch(selOpt.group(3)!))) {
        result.add(TerminalLineData(
          background: c.accentTint,
          spans: [
            TextSpan(
                text: selOpt.group(1),
                style: baseStyle.copyWith(color: c.text3)),
            TextSpan(
              text: selOpt.group(2),
              style: baseStyle.copyWith(
                color: c.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: selOpt.group(3),
              style: baseStyle.copyWith(
                color: c.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ));
        continue;
      }

      // 5. User prompt lines (`❯ fix tests`, `> hai`) get a crisp subtle band
      final leadPrompt = RegExp(r'^(\s*)([❯›>])(\s+\S.*)$').firstMatch(rawLine);
      if (leadPrompt != null && !trimmed.startsWith('>>')) {
        result.add(TerminalLineData(
          background: c.raised.withValues(alpha: 0.72),
          isPromptBand: true,
          spans: [
            TextSpan(text: leadPrompt.group(1), style: baseStyle),
            TextSpan(
              text: leadPrompt.group(2),
              style: baseStyle.copyWith(
                color: c.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: leadPrompt.group(3),
              style: baseStyle.copyWith(
                color: c.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ));
        continue;
      }

      // 6. Tool executions (`● Read(src/app.rs)`, `Ran 3 shell commands`, etc.)
      final toolM = _toolVerbRegex.firstMatch(rawLine);
      if (toolM != null) {
        final indent = toolM.group(1) ?? '';
        final bullet = toolM.group(2) ?? '';
        final body = toolM.group(3) ?? '';
        final paren = body.indexOf('(');
        final isErr =
            bullet.contains('✗') || bullet.contains('✘') || body.toLowerCase().contains('failed');
        final bulletColor = isErr
            ? c.termRed
            : bullet.contains('✓') || bullet.contains('✔')
                ? c.termGreen
                : bullet.contains('◦')
                    ? c.termBlue
                    : c.claude;
        result.add(TerminalLineData(spans: [
          if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
          if (bullet.isNotEmpty)
            TextSpan(
                text: bullet, style: baseStyle.copyWith(color: bulletColor)),
          if (paren > 0) ...[
            TextSpan(
              text: body.substring(0, paren),
              style: baseStyle.copyWith(
                color: c.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: body.substring(paren),
              style: baseStyle.copyWith(color: c.termDim),
            ),
          ] else
            TextSpan(
              text: body,
              style: baseStyle.copyWith(
                color: isErr ? c.termRed : c.termCyan,
                fontWeight: FontWeight.w500,
              ),
            ),
        ]));
        continue;
      }

      // 7. Bullet points (`● ...`, `• ...`) with inline URL/code/bold highlights
      final claudeBullet = RegExp(r'^(\s*)(●)(\s+)(.*)$').firstMatch(rawLine);
      if (claudeBullet != null) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: claudeBullet.group(1), style: baseStyle),
          TextSpan(
              text: claudeBullet.group(2),
              style: baseStyle.copyWith(color: c.claude)),
          TextSpan(text: claudeBullet.group(3), style: baseStyle),
          ..._inlineSpans(claudeBullet.group(4)!, baseStyle.copyWith(color: c.text), c),
        ]));
        continue;
      }
      final cyanBullet = RegExp(r'^(\s*)(•)(\s+)(.*)$').firstMatch(rawLine);
      if (cyanBullet != null) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: cyanBullet.group(1), style: baseStyle),
          TextSpan(
              text: cyanBullet.group(2),
              style: baseStyle.copyWith(color: c.termCyan)),
          TextSpan(text: cyanBullet.group(3), style: baseStyle),
          ..._inlineSpans(cyanBullet.group(4)!, baseStyle.copyWith(color: c.text), c),
        ]));
        continue;
      }

      // 8. Progress / failover / warnings / errors / success / tree details
      if (trimmed.startsWith('◦ ') || trimmed.startsWith('⇄ ')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termBlue)),
        ]));
        continue;
      }

      if (trimmed.startsWith('⚠') ||
          trimmed.contains('Waiting for your approval')) {
        result.add(TerminalLineData(spans: [
          TextSpan(
              text: rawLine, style: baseStyle.copyWith(color: c.termYellow)),
        ]));
        continue;
      }

      if (rawLine.contains('[E]') ||
          rawLine.contains('Some tests failed') ||
          rawLine.contains('Expected:') ||
          rawLine.contains('Actual:') ||
          trimmed.startsWith('^C') ||
          trimmed.startsWith('✗ ') ||
          rawLine.contains('Rejected') ||
          rawLine.contains('panicked at')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termRed)),
        ]));
        continue;
      }

      if ((rawLine.contains('passed') && rawLine.contains('└')) ||
          trimmed.startsWith('✓ ') ||
          trimmed.startsWith('✔ ')) {
        result.add(TerminalLineData(spans: [
          TextSpan(
              text: rawLine, style: baseStyle.copyWith(color: c.termGreen)),
        ]));
        continue;
      }

      if (trimmed.startsWith('└') ||
          trimmed.startsWith('├') ||
          trimmed.startsWith('00:')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termDim)),
        ]));
        continue;
      }

      // 9. Markdown headings (`# ...`, `## ...`, `### ...`)
      final hMatch = _headingRegex.firstMatch(rawLine);
      if (hMatch != null) {
        result.add(TerminalLineData(spans: [
          TextSpan(
              text: hMatch.group(1),
              style: baseStyle.copyWith(color: c.termDim)),
          TextSpan(
            text: hMatch.group(2),
            style: baseStyle.copyWith(
              color: c.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]));
        continue;
      }

      // 10. Shell prompt with embedded `❯ ` (e.g. `~/app main ❯ git status`)
      final promptIdx = rawLine.indexOf('❯ ');
      if (promptIdx > 0) {
        result.add(TerminalLineData(spans: [
          TextSpan(
            text: rawLine.substring(0, promptIdx),
            style: baseStyle.copyWith(color: c.termBlue),
          ),
          TextSpan(
              text: '❯ ',
              style: baseStyle.copyWith(
                  color: c.termGreen, fontWeight: FontWeight.w600)),
          TextSpan(
            text: rawLine.substring(promptIdx + 2),
            style: baseStyle.copyWith(color: c.text),
          ),
        ]));
        continue;
      }

      // 11. Regular text with subtle inline URL / backtick / bold highlights
      //     and softly muted outer box-drawing pipes `│`
      result.add(TerminalLineData(
        spans: _styleRegularLine(rawLine, baseStyle, c),
      ));
    }

    return result;
  }

  static List<TextSpan> _styleModelBar(
    String rawLine,
    TextStyle baseStyle,
    SlateColors c,
  ) {
    final segments = rawLine.split('·');
    if (segments.length <= 1) {
      return [TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termDim))];
    }
    final spans = <TextSpan>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: '·', style: baseStyle.copyWith(color: c.text3)));
      }
      final seg = segments[i];
      final st = seg.trim();
      final color = st.startsWith('~/') || st.startsWith('/')
          ? c.termGreen.withValues(alpha: 0.78)
          : i == 0
              ? c.termYellow.withValues(alpha: 0.85)
              : c.termDim;
      spans.add(TextSpan(text: seg, style: baseStyle.copyWith(color: color)));
    }
    return spans;
  }

  static List<TextSpan> _styleRegularLine(
    String rawLine,
    TextStyle baseStyle,
    SlateColors c,
  ) {
    // Softly mute box-drawing vertical bars (`│`, `┃`) while highlighting inner text
    if (rawLine.contains('│') || rawLine.contains('┃')) {
      final spans = <TextSpan>[];
      final buf = StringBuffer();
      for (var i = 0; i < rawLine.length; i++) {
        final ch = rawLine[i];
        if (ch == '│' || ch == '┃') {
          if (buf.isNotEmpty) {
            spans.addAll(_inlineSpans(buf.toString(), baseStyle, c));
            buf.clear();
          }
          spans.add(TextSpan(
            text: ch,
            style: baseStyle.copyWith(color: c.text3.withValues(alpha: 0.45)),
          ));
        } else {
          buf.write(ch);
        }
      }
      if (buf.isNotEmpty) {
        spans.addAll(_inlineSpans(buf.toString(), baseStyle, c));
      }
      return spans;
    }
    return _inlineSpans(rawLine, baseStyle, c);
  }

  static List<TextSpan> _inlineSpans(
    String text,
    TextStyle baseStyle,
    SlateColors c,
  ) {
    if (!text.contains('http') && !text.contains('`') && !text.contains('**')) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in _inlineHighlightRegex.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, m.start),
          style: baseStyle,
        ));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('http://') || tok.startsWith('https://')) {
        spans.add(TextSpan(
          text: tok,
          style: baseStyle.copyWith(
            color: c.accentText,
            decoration: TextDecoration.underline,
            decorationColor: c.accentText.withValues(alpha: 0.45),
          ),
        ));
      } else if (tok.startsWith('`') && tok.endsWith('`')) {
        spans.add(TextSpan(
          text: tok,
          style: baseStyle.copyWith(color: c.termCyan),
        ));
      } else if (tok.startsWith('**') && tok.endsWith('**')) {
        spans.add(TextSpan(
          text: tok,
          style: baseStyle.copyWith(
            color: c.text,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(text: tok, style: baseStyle));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  static Color? _ansiColor(int code, SlateColors c) {
    switch (code) {
      case 30:
      case 90:
        return c.termDim;
      case 31:
      case 91:
        return c.termRed;
      case 32:
      case 92:
        return c.termGreen;
      case 33:
      case 93:
        return c.termYellow;
      case 34:
      case 94:
        return c.termBlue;
      case 35:
      case 95:
        return c.termMag;
      case 36:
      case 96:
        return c.termCyan;
      case 37:
      case 97:
        return c.text;
      default:
        return null;
    }
  }

  static Color? _ansi256(int n, SlateColors c) {
    if (n < 16) return _ansiColor(n < 8 ? 30 + n : 90 + (n - 8), c);
    if (n >= 232) {
      final v = (8 + (n - 232) * 10).clamp(0, 255);
      return Color.fromARGB(255, v, v, v);
    }
    final idx = n - 16;
    final r = ((idx ~/ 36) * 51).clamp(0, 255);
    final g = (((idx % 36) ~/ 6) * 51).clamp(0, 255);
    final b = ((idx % 6) * 51).clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }
}
