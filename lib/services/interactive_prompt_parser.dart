/// Detects active interactive TUI prompts (Claude Code workspace trust dialogs,
/// permission menus, Codex/Gemini confirmations, and `[Y/n]` prompts) directly
/// from raw PTY screen tails so Mobile can offer 1-tap choice buttons right
/// above the terminal composer.
library;

enum PromptInputKind {
  /// Arrow-navigated TUI selection menu (`❯ 1. Yes` / `  2. No` or `❯ Yes` / `  No`).
  tuiMenu,

  /// Classic `[Y/n]` / `(y/N)` confirmation prompt.
  yesNo,

  /// Single-action `Enter to confirm · Esc to cancel` prompt.
  confirmCancel,
}

class InteractivePromptOption {
  const InteractivePromptOption({
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

class InteractivePrompt {
  const InteractivePrompt({
    required this.kind,
    required this.title,
    required this.options,
    required this.selectedIndex,
    this.allowsEsc = false,
    this.hint,
  });

  final PromptInputKind kind;
  final String title;
  final List<InteractivePromptOption> options;
  final int selectedIndex;
  final bool allowsEsc;
  final String? hint;
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

class InteractivePromptParser {
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
  static final RegExp _toolCallRegex = RegExp(
    r'^\s*(?:[●•◦✓✔✗✘▸▹]\s*)?(?:'
    r'(?:Ran|Running|Executed|Explored|Read|Reading|Edited|Editing|Updated|Updating|Created|Wrote|Deleted|Searched|Searching|Checked|Applied|Patched|Built|Tested|Fetched)\s+\S.{0,120}'
    r'|(?:Bash|Read|Edit|Write|Update|MultiEdit|Grep|Glob|Search|Task|WebFetch|WebSearch|NotebookEdit|Tool)\s*\(.+\)'
    r')$',
    caseSensitive: false,
  );
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

  /// Scans the bottom of a raw PTY screen tail for an active interactive prompt
  /// (workspace trust dialog, permission selection menu, or `[Y/n]` prompt).
  static InteractivePrompt? parse(String raw) {
    if (raw.trim().isEmpty) return null;

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

    // Strip bottom TUI chrome (rules, empty prompt box, shortcut hints, model bar)
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
          _shortcutHintRegex.hasMatch(line) ||
          _looksLikeModelFooter(line)) {
        end--;
        continue;
      }
      break;
    }

    final lines = <String>[];
    for (var i = 0; i < end; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          (_isRuleLine(trimmed) || _shortcutHintRegex.hasMatch(trimmed))) {
        if (lines.isNotEmpty && lines.last.isNotEmpty) {
          lines.add('');
        }
        continue;
      }
      lines.add(line);
    }

    return _extractInteractivePrompt(lines);
  }

  static String _unwrapBoxFrame(String line) {
    final m = _outerBoxLineRegex.firstMatch(line);
    if (m == null) return line;
    final inner = m.group(1) ?? '';
    if (inner.contains('│') || inner.contains('┃')) return line;
    return inner;
  }

  static InteractivePrompt? _extractInteractivePrompt(List<String> lines) {
    var end = lines.length;
    while (end > 0 && lines[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == 0) return null;

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

    final numbered = _tryExtractNumberedMenu(
      lines,
      scanEnd: scanEnd,
      menuHint: menuHint,
      allowsEsc: allowsEsc,
    );
    if (numbered != null) return numbered;

    final unnumbered = _tryExtractUnnumberedMenu(
      lines,
      scanEnd: scanEnd,
      menuHint: menuHint,
      allowsEsc: allowsEsc,
    );
    if (unnumbered != null) return unnumbered;

    final lastLine = lines[scanEnd - 1].trim();
    final ynMatch = _yesNoPromptRegex.firstMatch(lastLine);
    if (ynMatch != null) {
      final rawToken = ynMatch.group(0) ?? '';
      final defaultNo = rawToken.contains('N') && !rawToken.contains('Y');
      final cleanTitle = lastLine.substring(0, ynMatch.start).trim();
      final title = cleanTitle.isNotEmpty ? cleanTitle : 'Confirm action';
      return InteractivePrompt(
        kind: PromptInputKind.yesNo,
        title: title,
        options: [
          InteractivePromptOption(
            index: 0,
            label: 'Yes',
            isSelected: !defaultNo,
            shortcutKey: 'y',
          ),
          InteractivePromptOption(
            index: 1,
            label: 'No',
            isSelected: defaultNo,
            shortcutKey: 'n',
            isDanger: true,
          ),
        ],
        selectedIndex: defaultNo ? 1 : 0,
        allowsEsc: allowsEsc,
        hint: menuHint,
      );
    }

    if (menuHint != null &&
        RegExp(r'(?:press\s+enter\s+to\s+continue|enter\s+to\s+confirm)',
                caseSensitive: false)
            .hasMatch(menuHint)) {
      final title = _findPromptTitle(lines, scanEnd) ?? 'Confirmation needed';
      return InteractivePrompt(
        kind: PromptInputKind.confirmCancel,
        title: title,
        options: [
          const InteractivePromptOption(
            index: 0,
            label: 'Continue (Enter)',
            isSelected: true,
          ),
          if (allowsEsc)
            const InteractivePromptOption(
              index: 1,
              label: 'Cancel (Esc)',
              isSelected: false,
              shortcutKey: 'esc',
              isDanger: true,
            ),
        ],
        selectedIndex: 0,
        allowsEsc: allowsEsc,
        hint: menuHint,
      );
    }

    return null;
  }

  static InteractivePrompt? _tryExtractNumberedMenu(
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
    for (var k = 0; k < ordered.length; k++) {
      if (ordered[k].number != k + 1) return null;
    }

    final cursorIndexes = <int>[];
    for (var k = 0; k < ordered.length; k++) {
      if (ordered[k].hasCursor) cursorIndexes.add(k);
    }
    if (cursorIndexes.length > 1) return null;
    if (cursorIndexes.isEmpty && menuHint == null) return null;

    final selectedIndex = cursorIndexes.isEmpty ? 0 : cursorIndexes.first;
    final anyEsc = allowsEsc ||
        ordered.any((o) => o.label.toLowerCase().contains('(esc)'));
    final startLine = ordered.first.startLine;
    final title = _findPromptTitle(lines, startLine) ?? 'Choose an option';

    return InteractivePrompt(
      kind: PromptInputKind.tuiMenu,
      title: title,
      options: [
        for (var k = 0; k < ordered.length; k++)
          InteractivePromptOption(
            index: k,
            label: '${k + 1}. ${ordered[k].label}',
            isSelected: k == selectedIndex,
            shortcutKey: '${k + 1}',
            isDanger: _looksLikeDangerOption(ordered[k].label),
          ),
      ],
      selectedIndex: selectedIndex,
      allowsEsc: anyEsc,
      hint: menuHint,
    );
  }

  static InteractivePrompt? _tryExtractUnnumberedMenu(
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
    if (menuHint == null && (title == null || !hasChoiceKeywords)) {
      return null;
    }
    if (menuHint == null && !hasChoiceKeywords) {
      return null;
    }

    final selectedIndex = cursorIndexes.first;
    final anyEsc = allowsEsc ||
        ordered.any((o) => o.label.toLowerCase().contains('(esc)'));
    return InteractivePrompt(
      kind: PromptInputKind.tuiMenu,
      title: title ?? 'Choose an option',
      options: [
        for (var k = 0; k < ordered.length; k++)
          InteractivePromptOption(
            index: k,
            label: ordered[k].label,
            isSelected: k == selectedIndex,
            isDanger: _looksLikeDangerOption(ordered[k].label),
          ),
      ],
      selectedIndex: selectedIndex,
      allowsEsc: anyEsc,
      hint: menuHint,
    );
  }

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

  static bool _isToolCallLine(String trimmed) =>
      trimmed.length <= 140 && _toolCallRegex.hasMatch(trimmed);

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
}
