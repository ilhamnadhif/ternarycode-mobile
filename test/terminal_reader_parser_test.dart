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
              })
          .join('\n');

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
    });
  });
}
