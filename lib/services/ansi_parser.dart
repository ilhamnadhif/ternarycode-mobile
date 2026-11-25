import 'package:flutter/material.dart';
import '../theme/slate_tokens.dart';

/// Parsed terminal line with optional full-bleed diff background tint and styled spans.
class TerminalLineData {
  const TerminalLineData({
    required this.spans,
    this.background,
  });

  final List<TextSpan> spans;
  final Color? background;
}

/// Renders real PTY output containing ANSI SGR sequences as well as plain-text
/// Claude/Codex/diff output cleanly into Slate-colored lines.
class AnsiTerminalParser {
  static final RegExp _sgrRegex = RegExp(r'\x1B\[([0-9;]*)m');
  static final RegExp _otherEscRegex =
      RegExp(r'\x1B(?:\][^\x07]*\x07|\[[0-9;?]*[A-LN-Za-ln-z])');
  static final RegExp _diffAddRegex = RegExp(r'^\s*\d+\s+\+\s');
  static final RegExp _diffDelRegex = RegExp(r'^\s*\d+\s+-\s');

  static List<TerminalLineData> parse(
    String raw,
    SlateColors c, {
    double fontSize = 11.5,
  }) {
    final baseStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['Inter', 'sans-serif'],
      fontSize: fontSize,
      height: 1.46,
      color: c.termFg,
    );
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('⏺', '●')
        .replaceAll('⎿', '└');
    final lines = normalized.split('\n');
    final result = <TerminalLineData>[];

    Color? activeFg;
    bool bold = false;

    for (final rawLine in lines) {
      final hasAnsi = rawLine.contains('\x1B[');
      if (hasAnsi) {
        final cleaned = rawLine.replaceAll(_otherEscRegex, '');
        final spans = <TextSpan>[];
        var cursor = 0;
        for (final m in _sgrRegex.allMatches(cleaned)) {
          if (m.start > cursor) {
            spans.add(TextSpan(
              text: cleaned.substring(cursor, m.start),
              style: baseStyle.copyWith(
                color: activeFg ?? c.termFg,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ));
          }
          final codes = (m.group(1) ?? '')
              .split(';')
              .map((s) => int.tryParse(s) ?? 0);
          for (final code in codes) {
            if (code == 0) {
              activeFg = null;
              bold = false;
            } else if (code == 1) {
              bold = true;
            } else if (code == 2) {
              activeFg = c.termDim;
            } else if (code == 22) {
              bold = false;
            } else if (code == 39) {
              activeFg = null;
            } else {
              final mapped = _ansiColor(code, c);
              if (mapped != null) activeFg = mapped;
            }
          }
          cursor = m.end;
        }
        if (cursor < cleaned.length) {
          spans.add(TextSpan(
            text: cleaned.substring(cursor),
            style: baseStyle.copyWith(
              color: activeFg ?? c.termFg,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ));
        }
        result.add(TerminalLineData(
          spans: spans.isEmpty ? [TextSpan(text: ' ', style: baseStyle)] : spans,
        ));
        continue;
      }

      // Plain-text semantic styling (matches desktop screen_tail snapshots)
      if (rawLine.isEmpty) {
        result.add(TerminalLineData(spans: [TextSpan(text: ' ', style: baseStyle)]));
        continue;
      }

      if (_diffDelRegex.hasMatch(rawLine) ||
          (rawLine.startsWith('-') && !rawLine.startsWith('---'))) {
        result.add(TerminalLineData(
          background: c.diffDel,
          spans: [TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termRed))],
        ));
        continue;
      }

      if (_diffAddRegex.hasMatch(rawLine) ||
          (rawLine.startsWith('+') && !rawLine.startsWith('+++'))) {
        result.add(TerminalLineData(
          background: c.diffAdd,
          spans: [TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termGreen))],
        ));
        continue;
      }

      if (rawLine.startsWith('● ')) {
        final paren = rawLine.indexOf('(');
        if (paren > 2) {
          result.add(TerminalLineData(spans: [
            TextSpan(text: '● ', style: baseStyle.copyWith(color: c.claude)),
            TextSpan(
              text: rawLine.substring(2, paren),
              style: baseStyle.copyWith(color: c.text, fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: rawLine.substring(paren),
              style: baseStyle.copyWith(color: c.termDim),
            ),
          ]));
        } else {
          result.add(TerminalLineData(spans: [
            TextSpan(text: '● ', style: baseStyle.copyWith(color: c.claude)),
            TextSpan(text: rawLine.substring(2), style: baseStyle),
          ]));
        }
        continue;
      }

      if (rawLine.startsWith('• ')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: '• ', style: baseStyle.copyWith(color: c.termCyan)),
          TextSpan(
            text: rawLine.substring(2),
            style: baseStyle.copyWith(color: c.text),
          ),
        ]));
        continue;
      }

      if (rawLine.startsWith('◦ ') || rawLine.startsWith('⇄ ')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termBlue)),
        ]));
        continue;
      }

      if (rawLine.startsWith('⚠') || rawLine.contains('Waiting for your approval')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termYellow)),
        ]));
        continue;
      }

      if (rawLine.contains('[E]') ||
          rawLine.contains('Some tests failed') ||
          rawLine.contains('Expected:') ||
          rawLine.contains('Actual:') ||
          rawLine.startsWith('^C') ||
          rawLine.contains('Rejected')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termRed)),
        ]));
        continue;
      }

      if (rawLine.contains('passed') && rawLine.contains('└')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termGreen)),
        ]));
        continue;
      }

      if (rawLine.trimLeft().startsWith('└') ||
          rawLine.trimLeft().startsWith('00:')) {
        result.add(TerminalLineData(spans: [
          TextSpan(text: rawLine, style: baseStyle.copyWith(color: c.termDim)),
        ]));
        continue;
      }

      final promptIdx = rawLine.indexOf('❯ ');
      if (promptIdx != -1) {
        result.add(TerminalLineData(spans: [
          TextSpan(
            text: rawLine.substring(0, promptIdx),
            style: baseStyle.copyWith(color: c.termBlue),
          ),
          TextSpan(text: '❯ ', style: baseStyle.copyWith(color: c.termGreen)),
          TextSpan(text: rawLine.substring(promptIdx + 2), style: baseStyle),
        ]));
        continue;
      }

      result.add(TerminalLineData(spans: [TextSpan(text: rawLine, style: baseStyle)]));
    }

    return result;
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
}
