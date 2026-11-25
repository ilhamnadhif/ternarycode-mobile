import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/services/terminal_reader_parser.dart';

void main() {
  group('TerminalReaderParser', () {
    test('strips Antigravity TUI chrome, extracts model tag, and unwraps double-wrapped URLs & paths', () {
      const sample = '''
https://github.
      com/ilhamnadhif/ternarycode/releases/tag/
v0.3.16 (12 aset: macOS
      universal .dmg/.zip, Windows, Linux).
  • Mobile: flutter analyze --fatal-infos (0
issue) + 16/16 tes unit,
  widget 14-layar, dan live HTTP+SSE E2E
  (~/Developments/FLUTTER/ternarycode-mobile/
test/live_companion_server_tes
  t.dart) lulus semua.
      • Published: TernaryCode Mobile v0.2.2
https://github.
      com/ilhamnadhif/ternarycode-mobile/
releases/tag/v0.2.2 (5 aset APK
      signed + SHA256SUMS.txt).

  Anda bisa langsung update keduanya lewat in-
app updater masing-masing.
──────────────────────────────────────────────────────────────────────────
>
──────────────────────────────────────────────────────────────────────────
? for shortcuts
auto · Gemini 4 Neon · xhigh
''';

      final doc = TerminalReaderParser.parse(sample);

      // Model tag lifted out of footer cleanly
      expect(doc.modelTag, 'Gemini 4 Neon · xhigh');

      // Zero TUI divider or shortcut chrome left in body blocks
      final allText = doc.blocks
          .map((b) => switch (b) {
                ReaderParagraphBlock(:final text) => text,
                ReaderListBlock(:final items) => items.join('\n'),
                ReaderHeadingBlock(:final text) => text,
                ReaderUserPromptBlock(:final text) => text,
                ReaderStatusBlock(:final text) => text,
                ReaderToolGroupBlock(:final items) =>
                  items.map((e) => e.title).join('\n'),
                ReaderDiffBlock(:final lines) =>
                  lines.map((e) => e.text).join('\n'),
                ReaderCodeBlock(:final lines) => lines.join('\n'),
                ReaderInteractivePromptBlock(:final prompt) => prompt.title,
              })
          .join('\n');

      expect(doc.interactivePrompt, isNull);

      expect(allText, isNot(contains('────')));
      expect(allText, isNot(contains('? for shortcuts')));
      expect(allText, isNot(contains('Gemini 4 Neon')));

      // Double-wrapped URLs, file paths, and hyphenated words reassembled cleanly!
      expect(
        allText,
        contains('https://github.com/ilhamnadhif/ternarycode/releases/tag/v0.3.16'),
      );
      expect(
        allText,
        contains('~/Developments/FLUTTER/ternarycode-mobile/test/live_companion_server_test.dart'),
      );
      expect(
        allText,
        contains('https://github.com/ilhamnadhif/ternarycode-mobile/releases/tag/v0.2.2'),
      );
      expect(allText, contains('in-app updater masing-masing.'));
    });

    test('groups Codex/Claude tool calls and parses horizontal-scroll diffs cleanly', () {
      const sample = '''
❯ perbaiki timezone cron ke WIB
● Read(src/config.yaml)
  └ 42 lines read
Ran 2 shell commands
  └ OK · 148,920 rows matched
  18   schedule: "0 0 * * *"
  19 - timezone: "UTC"
  19 + timezone: "Asia/Jakarta"

Sudah diperbaiki ke Asia/Jakarta.
GPT-6-Luna low · ~/Developments/SaveBite-Web
''';

      final doc = TerminalReaderParser.parse(sample);
      expect(doc.modelTag, 'GPT-6-Luna low');

      expect(doc.blocks.whereType<ReaderUserPromptBlock>().length, 1);
      expect(
        doc.blocks.whereType<ReaderUserPromptBlock>().first.text,
        'perbaiki timezone cron ke WIB',
      );

      final toolGroups = doc.blocks.whereType<ReaderToolGroupBlock>().toList();
      expect(toolGroups.length, 1);
      expect(toolGroups.first.items.length, 2);
      expect(toolGroups.first.items.first.title, 'Read(src/config.yaml)');
      expect(toolGroups.first.items.first.detailLines, ['42 lines read']);
      expect(toolGroups.first.items.last.title, 'Ran 2 shell commands');

      final diffs = doc.blocks.whereType<ReaderDiffBlock>().toList();
      expect(diffs.length, 1);
      expect(diffs.first.added, 1);
      expect(diffs.first.removed, 1);
      expect(diffs.first.lines.first.kind, 'del');
      expect(diffs.first.lines.last.kind, 'add');

      final paras = doc.blocks.whereType<ReaderParagraphBlock>().toList();
      expect(paras.last.text, 'Sudah diperbaiki ke Asia/Jakarta.');
      expect(doc.interactivePrompt, isNull);
    });

    test('detects Claude Code boxed and unboxed workspace trust dialogs cleanly', () {
      const boxed = '''
╭──────────────────────────────────────────────────────────────╮
│ Do you trust the files in this folder?                       │
│                                                              │
│ /Users/ilham/Developments/my-project                         │
│                                                              │
│ Claude Code may read, write, or execute files contained in   │
│ this directory.                                              │
│                                                              │
│ ❯ 1. Yes, proceed                                            │
│   2. No, exit                                                │
│                                                              │
│ Enter to confirm · Esc to cancel                             │
╰──────────────────────────────────────────────────────────────╯
''';

      final doc = TerminalReaderParser.parse(boxed);
      expect(doc.blocks.whereType<ReaderUserPromptBlock>(), isEmpty);
      final prompt = doc.interactivePrompt;
      expect(prompt, isNotNull);
      expect(prompt!.kind, PromptInputKind.tuiMenu);
      expect(prompt.title, 'Do you trust the files in this folder?');
      expect(prompt.selectedIndex, 0);
      expect(prompt.allowsEsc, isTrue);
      expect(prompt.options.length, 2);
      expect(prompt.options[0].label, '1. Yes, proceed');
      expect(prompt.options[0].isSelected, isTrue);
      expect(prompt.options[0].isDanger, isFalse);
      expect(prompt.options[1].label, '2. No, exit');
      expect(prompt.options[1].isSelected, isFalse);
      expect(prompt.options[1].isDanger, isTrue);

      const unboxedV2 = '''
Accessing workspace:

/Users/ilham/Developments/demo

Quick safety check: Is this a project you created or one you trust?

❯ 1. Yes, I trust this folder
  2. No, exit

Enter to confirm · Esc to cancel
''';
      final doc2 = TerminalReaderParser.parse(unboxedV2);
      expect(doc2.interactivePrompt, isNotNull);
      expect(doc2.interactivePrompt!.options.first.label, '1. Yes, I trust this folder');
      expect(doc2.interactivePrompt!.options.last.label, '2. No, exit');
    });

    test('detects unnumbered Claude trust dialog with second option highlighted', () {
      const sample = '''
Do you trust the files in this folder?

  Yes, I trust this folder
❯ No, exit

Enter to confirm · Esc to cancel
''';
      final doc = TerminalReaderParser.parse(sample);
      final prompt = doc.interactivePrompt;
      expect(prompt, isNotNull);
      expect(prompt!.kind, PromptInputKind.tuiMenu);
      expect(prompt.selectedIndex, 1);
      expect(prompt.options.length, 2);
      expect(prompt.options[0].label, 'Yes, I trust this folder');
      expect(prompt.options[0].isSelected, isFalse);
      expect(prompt.options[1].label, 'No, exit');
      expect(prompt.options[1].isSelected, isTrue);
    });

    test('detects multi-option Claude/Codex permission menus with wrapped option text and [Y/n] prompts', () {
      const claudePerm = '''
Bash command
  npm test

Do you want to proceed?
❯ 1. Yes
  2. Yes, and don't ask again for Bash commands in
     /Users/ilham/Developments/app
  3. No, and tell Claude what to do differently (esc)
''';
      final doc = TerminalReaderParser.parse(claudePerm);
      final prompt = doc.interactivePrompt;
      expect(prompt, isNotNull);
      expect(prompt!.title, 'Do you want to proceed?');
      expect(prompt.options.length, 3);
      expect(prompt.options[1].label, contains('/Users/ilham/Developments/app'));
      expect(prompt.options[2].isDanger, isTrue);
      expect(prompt.allowsEsc, isTrue);

      const ynPrompt = 'Proceed with database migration? [y/N]';
      final ynDoc = TerminalReaderParser.parse(ynPrompt);
      expect(ynDoc.interactivePrompt, isNotNull);
      expect(ynDoc.interactivePrompt!.kind, PromptInputKind.yesNo);
      expect(ynDoc.interactivePrompt!.selectedIndex, 1);
      expect(ynDoc.interactivePrompt!.options.map((o) => o.label), ['Yes', 'No']);
    });

    test('never falsely flags normal numbered lists or prose as interactive prompts', () {
      const normalList = '''
Done! Summary of updates:
1. Updated API handler
2. Added unit tests
3. Deployed release
''';
      final doc = TerminalReaderParser.parse(normalList);
      expect(doc.interactivePrompt, isNull);
    });
  });
}
