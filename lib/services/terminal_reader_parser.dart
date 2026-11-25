/// Smart parser transforming desktop-wrapped PTY screen tails (Claude Code,
/// Codex CLI, Antigravity CLI, OpenCode, Gemini CLI) into clean, reflowed
/// structured blocks for mobile reading — eliminating double-wrap, stripping
/// bottom TUI chrome (`────`, empty `>`, `? for shortcuts`), detecting
/// interactive TUI prompts (trust dialogs, permission menus, `[Y/n]` confirms),
/// and extracting collapsible tool calls, horizontal-scroll diffs, and model metadata.
library;

enum PromptInputKind {
  /// Arrow-navigated TUI selection menu (`❯ 1. Yes` / `  2. No` or `❯ Yes` / `  No`).
  tuiMenu,

  /// Classic `[Y/n]` / `(y/N)` confirmation prompt.
  yesNo,

  /// Single-action `Enter to confirm · Esc to cancel` prompt.
  confirmCancel,
}

class ReaderPromptOption {
  const ReaderPromptOption({
    required this.index,
    required this.label,
    required this.isSelected,
    this.shortcutKey,
    this.isDanger = false,
  });

  final int index;
  final String label;
  final bool isSelected;
  final String? shortcutKey;
  final bool isDanger;
}

class ReaderInteractivePrompt {
  const ReaderInteractivePrompt({
    required this.kind,
    required this.title,
    required this.options,
    required this.selectedIndex,
    this.allowsEsc = false,
    this.hint,
  });

  final PromptInputKind kind;
  final String title;
  final List<ReaderPromptOption> options;
  final int selectedIndex;
  final bool allowsEsc;
  final String? hint;
}

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

class ReaderInteractivePromptBlock extends ReaderBlock {
  const ReaderInteractivePromptBlock(this.prompt);
  final ReaderInteractivePrompt prompt;
}

class ReaderDocument {
  const ReaderDocument({
    required this.blocks,
    this.modelTag,
    this.interactivePrompt,
  });

  final List<ReaderBlock> blocks;
  final String? modelTag;
  final ReaderInteractivePrompt? interactivePrompt;
}

class _ExtractedPrompt {
  const _ExtractedPrompt({
    required this.prompt,
    required this.startIndex,
  });

  final ReaderInteractivePrompt prompt;
  final int startIndex;
}

class _RawMenuItem {
  _RawMenuItem({
    required this.number,
    required this.hasCursor,
    required this.label,
    required this.startLine,
  });

  final int? number;
  final bool hasCursor;
  String label;
  final int startLine;
}

class TerminalReaderParser {
  static final RegExp _ansiRegex = RegExp(
    r'\x1B(?:\][^\x07\x1B]*(?:\x07|\x1B\\)|\[[0-9;?]*[ -/]*[@-~]|\([A-Za-z0-9])',
  );
  static final RegExp _ruleLineRegex = RegExp(r'^[\s─━═\-_╭╮╰╯┌┐└┘┬┴┼│┃]+$');
  static final RegExp _outerBoxLineRegex =
      RegExp(r'^\s*[│┃]\s?(.*?)\s*[│┃]?\s*$');
  static final RegExp _emptyPromptRegex = RegExp(
    r'^[│┃\s]*[>›❯]\s*(?:(?:Ask|Send|Type|Message|Write|Enter|Follow-up|Reply)[^\n]{0,40}?)?[│┃\s]*$',
    caseSensitive: false,
  );
  static final RegExp _shortcutHintRegex = RegExp(
    r'(?:\?\s*for\s+shortcuts|esc\s+to\s+interrupt|ctrl\+c\s+to|shift\+tab|alt\+enter|tab\s+to\s+(?:autocomplete|complete)|bypass\s+permissions|accept\s+edits|enter\s+to\s+send)',
    caseSensitive: false,
  );
  static final RegExp _menuFooterHintRegex = RegExp(
    r'(?:enter\s+to\s+(?:confirm|select|continue|submit)|esc\s+to\s+(?:cancel|exit|dismiss)|arrow\s+keys|↑\s*/?\s*↓|to\s+navigate|press\s+enter\s+to\s+continue)',
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
  static final RegExp _tuiNumberedOptionRegex = RegExp(
    r'^\s*([❯›>▸→●◉*])?\s*(?:(\d)[.)]|\[(\d)\])\s+(.+)$',
  );
  static final RegExp _tuiCursorOptionRegex =
      RegExp(r'^\s*([❯›▸→◉●○])\s+(\S.*)$');
  static final RegExp _yesNoPromptRegex = RegExp(
    r'(?:\[(y)/(n)\]|\[(n)/(y)\]|\((y)/(n)\)|\((n)/(y)\))\s*:?\s*$',
    caseSensitive: false,
  );
  static final RegExp _choiceWordRegex = RegExp(
    r'^(?:yes\b|no\b|allow\b|deny\b|approve\b|reject\b|trust\b|don.?t\s+trust|cancel\b|exit\b|skip\b|always\b|once\b|continue\b|accept\b|decline\b)',
    caseSensitive: false,
  );

  static ReaderDocument parse(String raw) {
    if (raw.trim().isEmpty) {
      return const ReaderDocument(blocks: []);
    }

    // 1. Strip ANSI escapes, normalize line endings / agent glyphs, and unwrap
    //    outer single-column Unicode dialog borders (`│ ... │`).
    final cleanedText = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_ansiRegex, '')
        .replaceAll('⏺', '●')
        .replaceAll('⎿', '└');

    final rawLines = cleanedText
        .split('\n')
        .map((l) => _unwrapBoxFrame(l).trimRight())
        .toList();

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

    // 2b. Detect active interactive TUI prompt at the bottom of the screen
    //     (e.g. Claude workspace trust dialog, permission menus, Codex/Gemini
    //     confirmations, `[Y/n]` prompts) BEFORE normal prose/user-prompt parsing
    //     so `❯ 1. Yes, I trust this folder` is never mistaken for a YOU bubble.
    final extractedPrompt = _extractInteractivePrompt(bodyLines);
    final parseEnd = extractedPrompt?.startIndex ?? bodyLines.length;

    // 3. Parse remaining body lines into structured blocks with desktop-unwrap reflow
    final blocks = <ReaderBlock>[];
    var i = 0;
    while (i < parseEnd) {
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
        while (i < parseEnd && !bodyLines[i].trim().startsWith('```')) {
          codeLines.add(bodyLines[i]);
          i++;
        }
        if (i < parseEnd) i++;
        if (codeLines.isNotEmpty) {
          blocks.add(ReaderCodeBlock(
            language: lang.isEmpty ? null : lang,
            lines: codeLines,
          ));
        }
        continue;
      }

      // 3b. Diff block (numbered `19 - foo` / `19 + bar` or unified `-foo` / `+bar`)
      if (_isDiffStart(bodyLines, i, parseEnd)) {
        String? fileName;
        if (trimmed.startsWith('diff --git') ||
            trimmed.startsWith('--- ') ||
            trimmed.startsWith('+++ ')) {
          fileName = _extractDiffFileName(trimmed);
          i++;
          while (i < parseEnd &&
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
        while (i < parseEnd) {
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
        while (i < parseEnd) {
          final t = bodyLines[i].trim();
          if (t.isEmpty) {
            if (i + 1 < parseEnd &&
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
          while (i < parseEnd) {
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
        while (i < parseEnd &&
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
        while (i < parseEnd) {
          final cur = bodyLines[i];
          final ct = cur.trim();
          if (ct.isEmpty) {
            if (i + 1 < parseEnd && _isBulletStart(bodyLines[i + 1])) {
              i++;
              continue;
            }
            break;
          }
          final bm = _bulletRegex.firstMatch(cur);
          final nm = _numberedRegex.firstMatch(cur);
          if (bm != null &&
              !_isToolCallLine(ct) &&
              !_isDiffStart(bodyLines, i, parseEnd)) {
            final buf = StringBuffer(bm.group(1)!.trim());
            var lastRaw = cur;
            i++;
            while (i < parseEnd &&
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
            while (i < parseEnd &&
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
      while (i < parseEnd &&
          _isSoftContinuation(bodyLines[i], prevLine: lastRaw)) {
        lastRaw = bodyLines[i];
        _appendReflowed(buf, bodyLines[i].trim());
        i++;
      }
      blocks.add(ReaderParagraphBlock(buf.toString()));
    }

    if (extractedPrompt != null) {
      blocks.add(ReaderInteractivePromptBlock(extractedPrompt.prompt));
    }

    return ReaderDocument(
      blocks: blocks,
      modelTag: modelTag,
      interactivePrompt: extractedPrompt?.prompt,
    );
  }

  /// Unwraps a single outer Unicode dialog frame (`│ ... │` or `┃ ... ┃`) while
  /// preserving multi-column Unicode tables (lines containing inner `│`).
  static String _unwrapBoxFrame(String line) {
    final m = _outerBoxLineRegex.firstMatch(line);
    if (m == null) return line;
    final inner = m.group(1) ?? '';
    if (inner.contains('│') || inner.contains('┃')) return line;
    return inner;
  }

  /// Detects an active interactive TUI prompt at the bottom of `lines`:
  /// 1. Numbered cursor menu (`❯ 1. Yes, I trust this folder` / `  2. No, exit`)
  /// 2. Unnumbered cursor/radio menu (`❯ Yes, I trust this folder` / `  No, exit`)
  /// 3. Classic `[Y/n]` / `(y/N)` confirmation prompt
  static _ExtractedPrompt? _extractInteractivePrompt(List<String> lines) {
    var end = lines.length;
    while (end > 0 && lines[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == 0) return null;

    // Consume an optional menu footer hint (`Enter to confirm · Esc to cancel`).
    String? menuHint;
    var allowsEsc = false;
    var scanEnd = end;
    for (var tries = 0; tries < 2 && scanEnd > 0; tries++) {
      final t = lines[scanEnd - 1].trim();
      if (t.isEmpty) {
        scanEnd--;
        continue;
      }
      if (_menuFooterHintRegex.hasMatch(t)) {
        menuHint = menuHint == null ? t : '$t · $menuHint';
        if (t.toLowerCase().contains('esc') ||
            t.toLowerCase().contains('cancel')) {
          allowsEsc = true;
        }
        scanEnd--;
      } else {
        break;
      }
    }
    while (scanEnd > 0 && lines[scanEnd - 1].trim().isEmpty) {
      scanEnd--;
    }
    if (scanEnd == 0) return null;

    // ── Detector 1: Numbered TUI selection menu (`❯ 1. ...` / `  2. ...`) ──
    final numbered = _tryExtractNumberedMenu(
      lines,
      scanEnd: scanEnd,
      menuHint: menuHint,
      allowsEsc: allowsEsc,
    );
    if (numbered != null) return numbered;

    // ── Detector 2: Unnumbered TUI cursor/radio menu (`❯ Yes` / `  No`) ──
    final unnumbered = _tryExtractUnnumberedMenu(
      lines,
      scanEnd: scanEnd,
      menuHint: menuHint,
      allowsEsc: allowsEsc,
    );
    if (unnumbered != null) return unnumbered;

    // ── Detector 3: Classic `[Y/n]` or `(y/N)` confirmation at bottom ──
    final lastLine = lines[scanEnd - 1].trim();
    final ynMatch = _yesNoPromptRegex.firstMatch(lastLine);
    if (ynMatch != null) {
      final rawToken = ynMatch.group(0) ?? '';
      final defaultNo =
          rawToken.contains('N') && !rawToken.contains('Y');
      final cleanTitle =
          lastLine.substring(0, ynMatch.start).trim();
      final title = cleanTitle.isNotEmpty ? cleanTitle : 'Confirm action';
      final options = [
        ReaderPromptOption(
          index: 0,
          label: 'Yes',
          isSelected: !defaultNo,
          shortcutKey: 'y',
        ),
        ReaderPromptOption(
          index: 1,
          label: 'No',
          isSelected: defaultNo,
          shortcutKey: 'n',
          isDanger: true,
        ),
      ];
      return _ExtractedPrompt(
        startIndex: scanEnd - 1,
        prompt: ReaderInteractivePrompt(
          kind: PromptInputKind.yesNo,
          title: title,
          options: options,
          selectedIndex: defaultNo ? 1 : 0,
          allowsEsc: allowsEsc,
          hint: menuHint,
        ),
      );
    }

    // ── Detector 4: Standalone `Press Enter to continue` / `Enter to confirm` ──
    if (menuHint != null &&
        RegExp(r'(?:press\s+enter\s+to\s+continue|enter\s+to\s+confirm)',
                caseSensitive: false)
            .hasMatch(menuHint)) {
      final title = _findPromptTitle(lines, scanEnd) ?? 'Confirmation needed';
      final options = <ReaderPromptOption>[
        const ReaderPromptOption(
          index: 0,
          label: 'Continue (Enter)',
          isSelected: true,
        ),
        if (allowsEsc)
          const ReaderPromptOption(
            index: 1,
            label: 'Cancel (Esc)',
            isSelected: false,
            shortcutKey: 'esc',
            isDanger: true,
          ),
      ];
      return _ExtractedPrompt(
        startIndex: scanEnd,
        prompt: ReaderInteractivePrompt(
          kind: PromptInputKind.confirmCancel,
          title: title,
          options: options,
          selectedIndex: 0,
          allowsEsc: allowsEsc,
          hint: menuHint,
        ),
      );
    }

    return null;
  }

  static _ExtractedPrompt? _tryExtractNumberedMenu(
    List<String> lines, {
    required int scanEnd,
    required String? menuHint,
    required bool allowsEsc,
  }) {
    final parsed = <_RawMenuItem>[];
    final trailingContinuation = <String>[];
    var idx = scanEnd - 1;
    var blanks = 0;

    while (idx >= 0 && parsed.length < 6) {
      final raw = lines[idx];
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        blanks++;
        if (blanks > 1 || parsed.isEmpty) break;
        idx--;
        continue;
      }
      blanks = 0;
      final m = _tuiNumberedOptionRegex.firstMatch(raw);
      if (m != null) {
        final cursor = m.group(1);
        final numStr = m.group(2) ?? m.group(3);
        final number = int.tryParse(numStr ?? '');
        var label = (m.group(4) ?? '').trim();
        if (trailingContinuation.isNotEmpty) {
          label = '$label ${trailingContinuation.reversed.join(' ')}';
          trailingContinuation.clear();
        }
        parsed.add(_RawMenuItem(
          number: number,
          hasCursor: cursor != null,
          label: label,
          startLine: idx,
        ));
        idx--;
        continue;
      }
      // Allow 1-2 indented soft-wrapped continuation lines under an option
      // (e.g. Claude's long "2. Yes, and don't ask again for Bash commands in /Users/...").
      if (raw.startsWith('  ') &&
          trailingContinuation.length < 2 &&
          !_isToolCallLine(trimmed) &&
          !trimmed.endsWith('?')) {
        trailingContinuation.add(trimmed);
        idx--;
        continue;
      }
      break;
    }

    if (parsed.length < 2) return null;
    final ordered = parsed.reversed.toList();

    // Must be strictly sequential starting at 1 (1, 2, ...).
    for (var k = 0; k < ordered.length; k++) {
      if (ordered[k].number != k + 1) return null;
    }

    final cursorIndexes = <int>[];
    for (var k = 0; k < ordered.length; k++) {
      if (ordered[k].hasCursor) cursorIndexes.add(k);
    }
    // Require exactly 1 cursor marker, OR 0 markers ONLY when an explicit TUI
    // menu footer (`Enter to confirm · Esc to cancel`) is present (reverse-video highlight).
    if (cursorIndexes.length > 1) return null;
    if (cursorIndexes.isEmpty && menuHint == null) return null;

    final selectedIndex = cursorIndexes.isEmpty ? 0 : cursorIndexes.first;
    final anyEsc = allowsEsc ||
        ordered.any((o) => o.label.toLowerCase().contains('(esc)'));
    final startLine = ordered.first.startLine;
    final title = _findPromptTitle(lines, startLine) ?? 'Choose an option';

    final options = <ReaderPromptOption>[
      for (var k = 0; k < ordered.length; k++)
        ReaderPromptOption(
          index: k,
          label: '${k + 1}. ${ordered[k].label}',
          isSelected: k == selectedIndex,
          shortcutKey: '${k + 1}',
          isDanger: _looksLikeDangerOption(ordered[k].label),
        ),
    ];

    return _ExtractedPrompt(
      startIndex: startLine,
      prompt: ReaderInteractivePrompt(
        kind: PromptInputKind.tuiMenu,
        title: title,
        options: options,
        selectedIndex: selectedIndex,
        allowsEsc: anyEsc,
        hint: menuHint,
      ),
    );
  }

  static _ExtractedPrompt? _tryExtractUnnumberedMenu(
    List<String> lines, {
    required int scanEnd,
    required String? menuHint,
    required bool allowsEsc,
  }) {
    final collected = <_RawMenuItem>[];
    var idx = scanEnd - 1;
    while (idx >= 0 && collected.length < 5) {
      final raw = lines[idx];
      final trimmed = raw.trim();
      if (trimmed.isEmpty) break;
      if (trimmed.length > 96 || _isToolCallLine(trimmed)) break;
      if (trimmed.endsWith('?') || trimmed.endsWith(':')) break;

      final cm = _tuiCursorOptionRegex.firstMatch(raw);
      if (cm != null) {
        final marker = cm.group(1)!;
        final label = cm.group(2)!.trim();
        collected.add(_RawMenuItem(
          number: null,
          hasCursor: marker != '○',
          label: label,
          startLine: idx,
        ));
        idx--;
        continue;
      }
      // Sibling unselected line (must not be a prose bullet `-` / `*` / `•`)
      if (!trimmed.startsWith('-') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('•') &&
          (raw.startsWith(' ') || _choiceWordRegex.hasMatch(trimmed))) {
        collected.add(_RawMenuItem(
          number: null,
          hasCursor: false,
          label: trimmed,
          startLine: idx,
        ));
        idx--;
        continue;
      }
      break;
    }

    if (collected.length < 2) return null;
    final ordered = collected.reversed.toList();
    final cursorIndexes = <int>[];
    for (var k = 0; k < ordered.length; k++) {
      if (ordered[k].hasCursor) cursorIndexes.add(k);
    }
    if (cursorIndexes.length != 1) return null;

    final startLine = ordered.first.startLine;
    final title = _findPromptTitle(lines, startLine);
    final hasChoiceKeywords =
        ordered.any((o) => _choiceWordRegex.hasMatch(o.label));
    if (menuHint == null && title == null && !hasChoiceKeywords) {
      return null;
    }
    // Guard against misclassifying a random `❯ prompt` + plain line beneath it.
    if (menuHint == null && !hasChoiceKeywords) {
      return null;
    }

    final selectedIndex = cursorIndexes.first;
    final anyEsc = allowsEsc ||
        ordered.any((o) => o.label.toLowerCase().contains('(esc)'));
    final options = <ReaderPromptOption>[
      for (var k = 0; k < ordered.length; k++)
        ReaderPromptOption(
          index: k,
          label: ordered[k].label,
          isSelected: k == selectedIndex,
          isDanger: _looksLikeDangerOption(ordered[k].label),
        ),
    ];

    return _ExtractedPrompt(
      startIndex: startLine,
      prompt: ReaderInteractivePrompt(
        kind: PromptInputKind.tuiMenu,
        title: title ?? 'Choose an option',
        options: options,
        selectedIndex: selectedIndex,
        allowsEsc: anyEsc,
        hint: menuHint,
      ),
    );
  }

  /// Scans slightly above a detected menu block to pick a crisp 1-line title
  /// (e.g. `"Do you trust the files in this folder?"` or `"Do you want to proceed?"`).
  static String? _findPromptTitle(List<String> lines, int menuStart) {
    final lowerBound = (menuStart - 12).clamp(0, menuStart);
    String? fallbackQuestion;
    for (var i = menuStart - 1; i >= lowerBound; i--) {
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (lower.contains('trust the files in this folder') ||
          lower.contains('trust this folder') ||
          lower.contains('quick safety check') ||
          lower.contains('do you trust')) {
        return t.length > 90 ? 'Do you trust this folder?' : t;
      }
      if (fallbackQuestion == null &&
          t.length <= 100 &&
          (t.endsWith('?') ||
              lower.startsWith('do you want') ||
              lower.startsWith('would you like') ||
              lower.startsWith('allow ') ||
              lower.startsWith('? allow'))) {
        fallbackQuestion = t.replaceFirst(RegExp(r'^\?\s+'), '');
      }
    }
    return fallbackQuestion;
  }

  static bool _looksLikeDangerOption(String label) {
    final lower = label.trim().toLowerCase();
    return lower == 'no' ||
        lower.startsWith('no,') ||
        lower.startsWith('no ') ||
        lower.startsWith('deny') ||
        lower.startsWith('reject') ||
        lower.startsWith('cancel') ||
        lower.startsWith('exit') ||
        lower.startsWith('abort') ||
        lower.contains('(esc)');
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
      return true;
    }
    return _numberedRegex.hasMatch(rawLine);
  }

  static bool _isDiffStart(List<String> lines, int idx, int parseEnd) {
    final cur = lines[idx];
    final t = cur.trim();
    if (t.startsWith('diff --git') || t.startsWith('@@ ')) return true;
    if (_numberedDiffRegex.hasMatch(cur)) return true;
    if ((t.startsWith('+') && !t.startsWith('+++')) ||
        (t.startsWith('-') && !t.startsWith('---'))) {
      if (idx + 1 < parseEnd) {
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

    final lastSpace = prev.lastIndexOf(' ');
    final lastToken = lastSpace == -1 ? prev : prev.substring(lastSpace + 1);

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

    final isHyphenBreak = lastToken.endsWith('-') &&
        lastToken.length > 1 &&
        RegExp(r'^[a-z]').hasMatch(nextTrim);

    if (isUrlBreak || isPathBreak || isHyphenBreak) {
      buf.write(nextTrim);
    } else {
      buf.write(' ');
      buf.write(nextTrim);
    }
  }
}
