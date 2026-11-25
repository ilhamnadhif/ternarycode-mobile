/// Smart parser transforming desktop-wrapped PTY screen tails (Claude Code,
/// Codex CLI, Antigravity CLI, OpenCode, Gemini CLI) into clean, reflowed
/// structured blocks for mobile reading — eliminating double-wrap, stripping
/// bottom TUI chrome (`────`, empty `>`, `? for shortcuts`), and extracting
/// collapsible tool calls, horizontal-scroll diffs, and model metadata.
library;

sealed class ReaderBlock {
  const ReaderBlock();
}

class ReaderUserPromptBlock extends ReaderBlock {
  const ReaderUserPromptBlock(this.text);
  final String text;
}

class ReaderHeadingBlock extends ReaderBlock {
  const ReaderHeadingBlock(this.text);
  final String text;
}

class ReaderParagraphBlock extends ReaderBlock {
  const ReaderParagraphBlock(this.text);
  final String text;
}

class ReaderListBlock extends ReaderBlock {
  const ReaderListBlock(this.items);
  final List<String> items;
}

class ReaderToolItem {
  const ReaderToolItem({
    required this.title,
    this.detailLines = const [],
    this.isRunning = false,
    this.isError = false,
  });

  final String title;
  final List<String> detailLines;
  final bool isRunning;
  final bool isError;
}

class ReaderToolGroupBlock extends ReaderBlock {
  const ReaderToolGroupBlock(this.items);
  final List<ReaderToolItem> items;
}

class ReaderDiffLine {
  const ReaderDiffLine({
    this.lineNum,
    required this.kind, // 'add' | 'del' | 'ctx'
    required this.text,
  });

  final String? lineNum;
  final String kind;
  final String text;
}

class ReaderDiffBlock extends ReaderBlock {
  const ReaderDiffBlock({
    this.fileName,
    required this.lines,
    required this.added,
    required this.removed,
  });

  final String? fileName;
  final List<ReaderDiffLine> lines;
  final int added;
  final int removed;
}

class ReaderCodeBlock extends ReaderBlock {
  const ReaderCodeBlock({this.language, required this.lines});
  final String? language;
  final List<String> lines;
}

class ReaderStatusBlock extends ReaderBlock {
  const ReaderStatusBlock(this.text, {required this.tone});
  final String text;
  final String tone; // 'info' | 'warn' | 'error' | 'success'
}

class ReaderDocument {
  const ReaderDocument({
    required this.blocks,
    this.modelTag,
  });

  final List<ReaderBlock> blocks;
  final String? modelTag;
}

class TerminalReaderParser {
  static final RegExp _ansiRegex = RegExp(
    r'\x1B(?:\][^\x07\x1B]*(?:\x07|\x1B\\)|\[[0-9;?]*[ -/]*[@-~]|\([A-Za-z0-9])',
  );
  static final RegExp _ruleLineRegex = RegExp(r'^[\s─━═\-_╭╮╰╯┌┐└┘┬┴┼│┃]+$');
  static final RegExp _emptyPromptRegex = RegExp(
    r'^[│┃\s]*[>›❯]\s*(?:(?:Ask|Send|Type|Message|Write|Enter|Follow-up|Reply)[^\n]{0,40}?)?[│┃\s]*$',
    caseSensitive: false,
  );
  static final RegExp _shortcutHintRegex = RegExp(
    r'(?:\?\s*for\s+shortcuts|esc\s+to\s+interrupt|ctrl\+c\s+to|shift\+tab|alt\+enter|tab\s+to\s+(?:autocomplete|complete)|bypass\s+permissions|accept\s+edits|enter\s+to\s+send)',
    caseSensitive: false,
  );
  static final RegExp _modelFooterRegex = RegExp(
    r'(?:gemini|claude|opus|sonnet|haiku|gpt-|o[134]-|codex|antigravity|deepseek|qwen|llama|auto\s*[·•]\s*\w|context\s+left|\bxh?igh\b|\bmedium\b|\blow\b)',
    caseSensitive: false,
  );
  static final RegExp _bulletRegex = RegExp(r'^\s*(?:[•●◦▪▫▸▹\*]|-)\s+(.+)$');
  static final RegExp _numberedRegex = RegExp(r'^\s*(\d{1,2})[.)]\s+(.+)$');
  static final RegExp _headingRegex = RegExp(r'^\s*#{1,3}\s+(.+)$');
  static final RegExp _numberedDiffRegex =
      RegExp(r'^\s*(\d+)\s+([+-])\s?(.*)$');
  static final RegExp _numberedCtxRegex = RegExp(r'^\s*(\d+)\s{2,}(.*)$');
  static final RegExp _toolCallRegex = RegExp(
    r'^\s*(?:[●•◦✓✔✗✘▸▹]\s*)?(?:'
    r'(?:Ran|Running|Executed|Explored|Read|Reading|Edited|Editing|Updated|Updating|Created|Wrote|Deleted|Searched|Searching|Checked|Applied|Patched|Built|Tested|Fetched)\s+\S.{0,120}'
    r'|(?:Bash|Read|Edit|Write|Update|MultiEdit|Grep|Glob|Search|Task|WebFetch|WebSearch|NotebookEdit|Tool)\s*\(.+\)'
    r')$',
    caseSensitive: false,
  );
  static final RegExp _toolDetailRegex = RegExp(r'^\s*[└├⎿]\s*(.*)$');
  static final RegExp _userPromptLineRegex = RegExp(r'^\s*[❯›>]\s+(\S.*)$');

  static ReaderDocument parse(String raw) {
    if (raw.trim().isEmpty) {
      return const ReaderDocument(blocks: []);
    }

    // 1. Strip ANSI escapes & normalize line endings / agent glyphs
    final cleanedText = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_ansiRegex, '')
        .replaceAll('⏺', '●')
        .replaceAll('⎿', '└');

    final rawLines = cleanedText.split('\n').map((l) => l.trimRight()).toList();

    // 2. Strip bottom TUI chrome (rules, empty prompt box, shortcut hints, model bar)
    String? modelTag;
    var end = rawLines.length;
    var scannedBottom = 0;
    while (end > 0 && scannedBottom < 14) {
      final line = rawLines[end - 1].trim();
      scannedBottom++;
      if (line.isEmpty) {
        end--;
        continue;
      }
      if (_isRuleLine(line) ||
          _emptyPromptRegex.hasMatch(line) ||
          _shortcutHintRegex.hasMatch(line)) {
        end--;
        continue;
      }
      if (_looksLikeModelFooter(line)) {
        modelTag ??= _cleanModelTag(line);
        end--;
        continue;
      }
      break;
    }

    final bodyLines = <String>[];
    for (var i = 0; i < end; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();
      // Drop standalone horizontal rule boxes & shortcut lines anywhere
      if (trimmed.isNotEmpty &&
          (_isRuleLine(trimmed) || _shortcutHintRegex.hasMatch(trimmed))) {
        if (bodyLines.isNotEmpty && bodyLines.last.isNotEmpty) {
          bodyLines.add('');
        }
        continue;
      }
      bodyLines.add(line);
    }

    // 3. Parse into structured blocks with intelligent desktop-unwrap reflow
    final blocks = <ReaderBlock>[];
    var i = 0;
    while (i < bodyLines.length) {
      final line = bodyLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 3a. Fenced code block
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        i++;
        final codeLines = <String>[];
        while (i < bodyLines.length && !bodyLines[i].trim().startsWith('```')) {
          codeLines.add(bodyLines[i]);
          i++;
        }
        if (i < bodyLines.length) i++;
        if (codeLines.isNotEmpty) {
          blocks.add(ReaderCodeBlock(
            language: lang.isEmpty ? null : lang,
            lines: codeLines,
          ));
        }
        continue;
      }

      // 3b. Diff block (numbered `19 - foo` / `19 + bar` or unified `-foo` / `+bar`)
      if (_isDiffStart(bodyLines, i)) {
        String? fileName;
        if (trimmed.startsWith('diff --git') ||
            trimmed.startsWith('--- ') ||
            trimmed.startsWith('+++ ')) {
          fileName = _extractDiffFileName(trimmed);
          i++;
          while (i < bodyLines.length &&
              (bodyLines[i].trim().startsWith('--- ') ||
                  bodyLines[i].trim().startsWith('+++ ') ||
                  bodyLines[i].trim().startsWith('@@'))) {
            fileName ??= _extractDiffFileName(bodyLines[i].trim());
            i++;
          }
        }
        final diffLines = <ReaderDiffLine>[];
        var added = 0;
        var removed = 0;
        while (i < bodyLines.length) {
          final cur = bodyLines[i];
          final ct = cur.trim();
          if (ct.isEmpty) break;
          final numM = _numberedDiffRegex.firstMatch(cur);
          if (numM != null) {
            final kind = numM.group(2) == '+' ? 'add' : 'del';
            if (kind == 'add') {
              added++;
            } else {
              removed++;
            }
            diffLines.add(ReaderDiffLine(
              lineNum: numM.group(1),
              kind: kind,
              text: '${numM.group(2)} ${numM.group(3) ?? ''}',
            ));
            i++;
            continue;
          }
          final ctxM = _numberedCtxRegex.firstMatch(cur);
          if (ctxM != null && diffLines.isNotEmpty) {
            diffLines.add(ReaderDiffLine(
              lineNum: ctxM.group(1),
              kind: 'ctx',
              text: '  ${ctxM.group(2) ?? ''}',
            ));
            i++;
            continue;
          }
          if ((ct.startsWith('+') && !ct.startsWith('+++')) ||
              (ct.startsWith('-') && !ct.startsWith('---'))) {
            final kind = ct.startsWith('+') ? 'add' : 'del';
            if (kind == 'add') {
              added++;
            } else {
              removed++;
            }
            diffLines.add(ReaderDiffLine(kind: kind, text: ct));
            i++;
            continue;
          }
          break;
        }
        if (diffLines.isNotEmpty) {
          blocks.add(ReaderDiffBlock(
            fileName: fileName,
            lines: diffLines,
            added: added,
            removed: removed,
          ));
          continue;
        }
      }

      // 3c. Tool execution group (consecutive tool calls + `└` outputs)
      if (_isToolCallLine(trimmed)) {
        final tools = <ReaderToolItem>[];
        while (i < bodyLines.length) {
          final t = bodyLines[i].trim();
          if (t.isEmpty) {
            // Peek past a single blank line if another tool call follows immediately
            if (i + 1 < bodyLines.length &&
                _isToolCallLine(bodyLines[i + 1].trim())) {
              i++;
              continue;
            }
            break;
          }
          if (!_isToolCallLine(t)) break;
          final cleanTitle =
              t.replaceFirst(RegExp(r'^[●•◦✓✔✗✘▸▹]\s*'), '').trim();
          final isRun = t.startsWith('◦') ||
              cleanTitle.toLowerCase().startsWith('running') ||
              cleanTitle.toLowerCase().startsWith('reading') ||
              cleanTitle.toLowerCase().startsWith('editing') ||
              cleanTitle.toLowerCase().startsWith('searching');
          final isErr = t.startsWith('✗') ||
              t.startsWith('✘') ||
              cleanTitle.toLowerCase().contains('failed');
          i++;
          final details = <String>[];
          while (i < bodyLines.length) {
            final dl = bodyLines[i];
            final dm = _toolDetailRegex.firstMatch(dl);
            if (dm != null) {
              final dText = (dm.group(1) ?? '').trim();
              if (dText.isNotEmpty) details.add(dText);
              i++;
            } else if (details.isNotEmpty &&
                dl.startsWith('    ') &&
                dl.trim().isNotEmpty &&
                !_isToolCallLine(dl.trim())) {
              details.add(dl.trim());
              i++;
            } else {
              break;
            }
          }
          tools.add(ReaderToolItem(
            title: cleanTitle,
            detailLines: details,
            isRunning: isRun,
            isError: isErr,
          ));
        }
        blocks.add(ReaderToolGroupBlock(tools));
        continue;
      }

      // 3d. Standalone status / error / warning lines
      if (trimmed.startsWith('⚠') ||
          trimmed.startsWith('⇄ ') ||
          trimmed.startsWith('^C') ||
          trimmed.startsWith('✗ ') ||
          trimmed.contains('Waiting for your approval')) {
        final tone = (trimmed.startsWith('^C') || trimmed.startsWith('✗ '))
            ? 'error'
            : (trimmed.startsWith('⚠') ||
                    trimmed.contains('Waiting for your approval'))
                ? 'warn'
                : 'info';
        blocks.add(ReaderStatusBlock(trimmed, tone: tone));
        i++;
        continue;
      }

      // 3e. User prompt line (`❯ ...` or `> ...` with actual user prompt text)
      final upMatch = _userPromptLineRegex.firstMatch(line);
      if (upMatch != null && !trimmed.startsWith('>>')) {
        final buf = StringBuffer(upMatch.group(1)!.trim());
        i++;
        while (i < bodyLines.length &&
            _isSoftContinuation(bodyLines[i], prevLine: buf.toString())) {
          _appendReflowed(buf, bodyLines[i].trim());
          i++;
        }
        blocks.add(ReaderUserPromptBlock(buf.toString()));
        continue;
      }

      // 3f. Markdown heading (`# ...`, `## ...`, `### ...`)
      final hMatch = _headingRegex.firstMatch(line);
      if (hMatch != null) {
        blocks.add(ReaderHeadingBlock(hMatch.group(1)!.trim()));
        i++;
        continue;
      }

      // 3g. Bullet or numbered list (with smart multi-line desktop unwrap!)
      if (_isBulletStart(line)) {
        final items = <String>[];
        while (i < bodyLines.length) {
          final cur = bodyLines[i];
          final ct = cur.trim();
          if (ct.isEmpty) {
            if (i + 1 < bodyLines.length && _isBulletStart(bodyLines[i + 1])) {
              i++;
              continue;
            }
            break;
          }
          final bm = _bulletRegex.firstMatch(cur);
          final nm = _numberedRegex.firstMatch(cur);
          if (bm != null && !_isToolCallLine(ct) && !_isDiffStart(bodyLines, i)) {
            final buf = StringBuffer(bm.group(1)!.trim());
            var lastRaw = cur;
            i++;
            while (i < bodyLines.length &&
                _isSoftContinuation(bodyLines[i], prevLine: lastRaw)) {
              lastRaw = bodyLines[i];
              _appendReflowed(buf, bodyLines[i].trim());
              i++;
            }
            items.add(buf.toString());
            continue;
          }
          if (nm != null) {
            final buf = StringBuffer('${nm.group(1)}. ${nm.group(2)!.trim()}');
            var lastRaw = cur;
            i++;
            while (i < bodyLines.length &&
                _isSoftContinuation(bodyLines[i], prevLine: lastRaw)) {
              lastRaw = bodyLines[i];
              _appendReflowed(buf, bodyLines[i].trim());
              i++;
            }
            items.add(buf.toString());
            continue;
          }
          break;
        }
        if (items.isNotEmpty) {
          blocks.add(ReaderListBlock(items));
          continue;
        }
      }

      // 3h. Standard prose paragraph (smart desktop-unwrap reflow!)
      final buf = StringBuffer(trimmed);
      var lastRaw = line;
      i++;
      while (i < bodyLines.length &&
          _isSoftContinuation(bodyLines[i], prevLine: lastRaw)) {
        lastRaw = bodyLines[i];
        _appendReflowed(buf, bodyLines[i].trim());
        i++;
      }
      blocks.add(ReaderParagraphBlock(buf.toString()));
    }

    return ReaderDocument(blocks: blocks, modelTag: modelTag);
  }

  static bool _isRuleLine(String trimmed) =>
      trimmed.length >= 4 && _ruleLineRegex.hasMatch(trimmed);

  static bool _looksLikeModelFooter(String trimmed) {
    if (trimmed.length > 72 ||
        trimmed.startsWith('●') ||
        trimmed.startsWith('•') ||
        trimmed.startsWith('◦') ||
        trimmed.startsWith('⚠') ||
        trimmed.startsWith('⇄') ||
        trimmed.startsWith('└') ||
        trimmed.contains(',') ||
        trimmed.contains('!')) {
      return false;
    }
    if (trimmed.contains('·') && _modelFooterRegex.hasMatch(trimmed)) {
      return true;
    }
    return RegExp(
      r'^(?:auto|manual)\s*[·•]|^\d+%\s+context\s+left|^[A-Za-z0-9._-]+\s+(?:low|medium|high|xhigh)\s*[·•]',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  static String _cleanModelTag(String line) {
    // Strip leading `auto · ` or path tails after `~/...` so the pill stays crisp.
    final parts = line
        .split(RegExp(r'\s*[·•]\s*'))
        .map((s) => s.trim())
        .where((s) =>
            s.isNotEmpty &&
            !s.startsWith('~/') &&
            !s.startsWith('/') &&
            s.toLowerCase() != 'auto')
        .toList();
    if (parts.isEmpty) return line.trim();
    return parts.take(2).join(' · ');
  }

  static bool _isToolCallLine(String trimmed) {
    if (trimmed.length > 140) return false;
    return _toolCallRegex.hasMatch(trimmed);
  }

  static bool _isBulletStart(String rawLine) {
    final trimmed = rawLine.trim();
    if (_isToolCallLine(trimmed)) return false;
    if (_bulletRegex.hasMatch(rawLine)) {
      // A line like `- timezone: "UTC"` followed by `+ timezone:` is a diff, not a bullet.
      return true;
    }
    return _numberedRegex.hasMatch(rawLine);
  }

  static bool _isDiffStart(List<String> lines, int idx) {
    final cur = lines[idx];
    final t = cur.trim();
    if (t.startsWith('diff --git') || t.startsWith('@@ ')) return true;
    if (_numberedDiffRegex.hasMatch(cur)) return true;
    if ((t.startsWith('+') && !t.startsWith('+++')) ||
        (t.startsWith('-') && !t.startsWith('---'))) {
      // Require adjacent diff line so normal `- bullet` prose isn't treated as a diff
      if (idx + 1 < lines.length) {
        final next = lines[idx + 1].trim();
        if ((next.startsWith('+') && !next.startsWith('+++')) ||
            (next.startsWith('-') && !next.startsWith('---')) ||
            _numberedDiffRegex.hasMatch(lines[idx + 1])) {
          return true;
        }
      }
    }
    return false;
  }

  static String? _extractDiffFileName(String line) {
    final m = RegExp(r'(?:b/|\+\+\+\s+(?:b/)?)([^\s]+)$').firstMatch(line);
    return m?.group(1);
  }

  static bool _isSoftContinuation(String nextRaw, {required String prevLine}) {
    final nextTrim = nextRaw.trim();
    if (nextTrim.isEmpty) return false;
    if (nextTrim.startsWith('```')) return false;
    if (_isRuleLine(nextTrim) || _shortcutHintRegex.hasMatch(nextTrim)) {
      return false;
    }
    if (_headingRegex.hasMatch(nextRaw)) return false;
    if (_isToolCallLine(nextTrim)) return false;
    if (_toolDetailRegex.hasMatch(nextRaw)) return false;
    if (_userPromptLineRegex.hasMatch(nextRaw)) return false;
    if (_numberedDiffRegex.hasMatch(nextRaw)) return false;
    if (_bulletRegex.hasMatch(nextRaw) || _numberedRegex.hasMatch(nextRaw)) {
      return false;
    }
    if (nextTrim.startsWith('⚠') ||
        nextTrim.startsWith('⇄ ') ||
        nextTrim.startsWith('^C') ||
        nextTrim.startsWith('✗ ')) {
      return false;
    }
    return true;
  }

  /// Appends a soft-wrapped continuation line back onto `buf`, intelligently
  /// joining mid-URL / mid-path / mid-word desktop PTY breaks WITHOUT stray spaces.
  static void _appendReflowed(StringBuffer buf, String nextTrim) {
    final prev = buf.toString();
    if (prev.isEmpty) {
      buf.write(nextTrim);
      return;
    }

    // Grab the trailing non-whitespace token of `prev`
    final lastSpace = prev.lastIndexOf(' ');
    final lastToken = lastSpace == -1 ? prev : prev.substring(lastSpace + 1);

    // 1. Mid-URL break (`https://github.` + `com/ilham/...`, or `.../tag/` + `v0.3.16`)
    final isUrlBreak = (lastToken.contains('://') ||
            lastToken.startsWith('http') ||
            lastToken.contains('.com/') ||
            lastToken.contains('.org/')) &&
        (lastToken.endsWith('.') ||
            lastToken.endsWith('/') ||
            lastToken.endsWith('-') ||
            lastToken.endsWith('_') ||
            nextTrim.startsWith('/') ||
            nextTrim.startsWith('.') ||
            RegExp(r'^[a-z0-9._~:/?#\[\]@!$&()*+,;=%-]+(?:\s|$)')
                .hasMatch(nextTrim));

    // 2. Mid-file-path break (`~/Developments/.../test/live_companion_server_tes` + `t.dart`)
    final isPathBreak = (lastToken.contains('/') || lastToken.contains('_')) &&
        !lastToken.endsWith('.') &&
        !lastToken.endsWith(',') &&
        !lastToken.endsWith(')') &&
        !lastToken.endsWith(':') &&
        (lastToken.endsWith('/') ||
            lastToken.endsWith('_') ||
            lastToken.endsWith('-') ||
            nextTrim.startsWith('/') ||
            RegExp(r'^[a-z0-9_-]*\.[a-z]{1,6}(?:[\s),.:]|$)')
                .hasMatch(nextTrim));

    // 3. Hyphenated word wrap (`in-` + `app updater`)
    final isHyphenBreak =
        lastToken.endsWith('-') && lastToken.length > 1 && RegExp(r'^[a-z]').hasMatch(nextTrim);

    if (isUrlBreak || isPathBreak || isHyphenBreak) {
      buf.write(nextTrim);
    } else {
      buf.write(' ');
      buf.write(nextTrim);
    }
  }
}
