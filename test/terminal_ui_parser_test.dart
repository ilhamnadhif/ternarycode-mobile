import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/services/ansi_parser.dart';
import 'package:ternarycode_mobile/services/interactive_prompt_parser.dart';
import 'package:ternarycode_mobile/theme/slate_theme.dart';
import 'package:ternarycode_mobile/theme/slate_tokens.dart';
import 'package:ternarycode_mobile/widgets/terminal_view.dart';

void main() {
  group('InteractivePromptParser', () {
    test('detects Claude Code boxed and unboxed workspace trust dialogs cleanly', () {
      const boxed = '''
╭──────────────────────────────────────────────────────────────╮
│ Do you trust the files in this folder?                       │
│                                                              │
│ /Users/ilham/Developments/my-project                         │
│                                                              │
│ ❯ 1. Yes, proceed                                            │
│   2. No, exit                                                │
│                                                              │
│ Enter to confirm · Esc to cancel                             │
╰──────────────────────────────────────────────────────────────╯
''';

      final prompt = InteractivePromptParser.parse(boxed);
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
      final p2 = InteractivePromptParser.parse(unboxedV2);
      expect(p2, isNotNull);
      expect(p2!.options.first.label, '1. Yes, I trust this folder');
      expect(p2.options.last.label, '2. No, exit');
    });

    test('detects unnumbered Claude trust dialog with second option highlighted', () {
      const sample = '''
Do you trust the files in this folder?

  Yes, I trust this folder
❯ No, exit

Enter to confirm · Esc to cancel
''';
      final prompt = InteractivePromptParser.parse(sample);
      expect(prompt, isNotNull);
      expect(prompt!.kind, PromptInputKind.tuiMenu);
      expect(prompt.selectedIndex, 1);
      expect(prompt.options.length, 2);
      expect(prompt.options[0].label, 'Yes, I trust this folder');
      expect(prompt.options[1].label, 'No, exit');
    });

    test('detects multi-option permission menus with wrapped text and [Y/n] prompts', () {
      const claudePerm = '''
Bash command
  npm test

Do you want to proceed?
❯ 1. Yes
  2. Yes, and don't ask again for Bash commands in
     /Users/ilham/Developments/app
  3. No, and tell Claude what to do differently (esc)
''';
      final prompt = InteractivePromptParser.parse(claudePerm);
      expect(prompt, isNotNull);
      expect(prompt!.title, 'Do you want to proceed?');
      expect(prompt.options.length, 3);
      expect(prompt.options[1].label, contains('/Users/ilham/Developments/app'));
      expect(prompt.options[2].isDanger, isTrue);
      expect(prompt.allowsEsc, isTrue);

      final yn = InteractivePromptParser.parse(
        'Proceed with database migration? [y/N]',
      );
      expect(yn, isNotNull);
      expect(yn!.kind, PromptInputKind.yesNo);
      expect(yn.selectedIndex, 1);
      expect(yn.options.map((o) => o.label), ['Yes', 'No']);
    });

    test('never falsely flags normal numbered lists or finished prose as interactive prompts', () {
      const normalList = '''
Done! Summary of updates:
1. Updated API handler
2. Added unit tests
3. Deployed release
''';
      expect(InteractivePromptParser.parse(normalList), isNull);
    });
  });

  group('AnsiTerminalParser raw styling', () {
    test('preserves verbatim text while semantically styling prompts, diffs, tools, URLs & rules', () {
      const sample = '''
❯ perbaiki timezone cron ke WIB
● Read(src/config.yaml)
  └ 42 lines read
  19 - timezone: "UTC"
  19 + timezone: "Asia/Jakarta"
See https://github.com/ilhamnadhif/ternarycode and `cargo test`
────────────────────────────────────────
❯ 1. Yes, I trust this folder
? for shortcuts
GPT-6-Luna low · ~/Developments/app
''';
      final c = SlateColors.dark;
      final lines = AnsiTerminalParser.parse(sample, c);

      // Verbatim text preserved line-for-line
      String joinLine(TerminalLineData l) =>
          l.spans.map((s) => s.text ?? '').join();

      expect(joinLine(lines[0]), '❯ perbaiki timezone cron ke WIB');
      expect(lines[0].isPromptBand, isTrue);
      expect(lines[0].background, isNotNull);

      expect(joinLine(lines[1]), '● Read(src/config.yaml)');
      expect(lines[1].spans.first.style?.color, c.claude);

      expect(lines[3].background, c.diffDel);
      expect(lines[4].background, c.diffAdd);

      // Inline URL + code highlighted while keeping exact text
      expect(joinLine(lines[5]),
          'See https://github.com/ilhamnadhif/ternarycode and `cargo test`');
      expect(lines[5].spans.any((s) => s.style?.color == c.accentText), isTrue);
      expect(lines[5].spans.any((s) => s.style?.color == c.termCyan), isTrue);

      // Horizontal rules softened, selected option accented, shortcut dimmed
      expect(lines[6].spans.single.style?.color?.a, lessThan(0.6));
      expect(lines[7].background, c.accentTint);
      expect(lines[8].spans.single.style?.color, c.termDim);
      expect(joinLine(lines[9]), 'GPT-6-Luna low · ~/Developments/app');
    });

    test('renders ANSI SGR 16-color, 256-color, and truecolor escapes cleanly', () {
      final c = SlateColors.dark;
      final lines = AnsiTerminalParser.parse(
        '\x1B[1;32mOK\x1B[0m \x1B[38;5;196mERR\x1B[0m \x1B[38;2;10;20;30mRGB\x1B[0m',
        c,
      );
      expect(lines.length, 1);
      final text = lines.first.spans.map((s) => s.text ?? '').join();
      expect(text, 'OK ERR RGB');
      expect(lines.first.spans.first.style?.fontWeight, FontWeight.w600);
      expect(lines.first.spans.first.style?.color, c.termGreen);
      expect(
        lines.first.spans.last.style?.color,
        const Color.fromARGB(255, 10, 20, 30),
      );
    });

    test('tags wide desktop horizontal rules and multi-column CLI tables accurately', () {
      const sample = '''
────────────────────────────────────────────────────────────────────────────────
❯ hi
────────────────────────────────────────────────────────────────────────────────
┌──────────┬─────────────────────────┬─────────┬───────┐
│ Service  │ Operator yang dikirim   │ Request │ Gagal │
├──────────┼─────────────────────────┼─────────┼───────┤
│ gemezz   │ AE - Etisalat           │ 400     │ 0     │
└──────────┴─────────────────────────┴─────────┴───────┘
Normal prose paragraph stays wrapped.
''';
      final lines = AnsiTerminalParser.parse(sample, SlateColors.dark);
      expect(lines[0].isHorizontalRule, isTrue);
      expect(lines[0].isTableLine, isFalse);
      expect(lines[1].isHorizontalRule, isFalse);
      expect(lines[2].isHorizontalRule, isTrue);
      expect(lines[3].isTableLine, isTrue);
      expect(lines[4].isTableLine, isTrue);
      expect(lines[5].isTableLine, isTrue);
      expect(lines[6].isTableLine, isTrue);
      expect(lines[7].isTableLine, isTrue);
      expect(lines[8].isHorizontalRule, isFalse);
      expect(lines[8].isTableLine, isFalse);
    });
  });

  group('TerminalOutputView scroll stability & responsive rules/tables', () {
    testWidgets('scrolling to bottom and tapping Latest NEVER bounces back to top',
        (tester) async {
      final ctrl = ScrollController();
      addTearDown(ctrl.dispose);

      final longOutput = [
        for (var i = 1; i <= 60; i++)
          '● Step $i: Processing operator report line with details for mobile scroll test',
        '─' * 140,
        '❯ ',
        '─' * 140,
        '┌──────────┬─────────────────────────┬─────────┬───────┐',
        '│ Service  │ Operator yang dikirim   │ Request │ Gagal │',
        '├──────────┼─────────────────────────┼─────────┼───────┤',
        '│ gemezz   │ AE - Etisalat           │ 400     │ 0     │',
        '└──────────┴─────────────────────────┴─────────┴───────┘',
        'FINAL_BOTTOM_LINE_MARKER',
      ].join('\n');

      await tester.pumpWidget(
        MaterialApp(
          theme: SlateTheme.build(Brightness.dark),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: TerminalOutputView(
                paneId: 1,
                output: longOutput,
                controller: ctrl,
                wrap: true,
                showLatestPill: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially stuck at bottom, Latest pill hidden, wide table gets an inline horizontal scroller
      expect(ctrl.position.maxScrollExtent, greaterThan(400));
      expect(ctrl.offset, closeTo(ctrl.position.maxScrollExtent, 2.0));
      expect(find.text('Latest'), findsNothing);
      final horizontalScrollers = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((w) => w.scrollDirection == Axis.horizontal)
          .toList();
      expect(horizontalScrollers.length, 1);

      // Scroll up near top -> Latest pill appears
      ctrl.jumpTo(40);
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);

      // Scroll back down into bottom zone -> pill hides WITHOUT resetting offset back to 0!
      final bottom = ctrl.position.maxScrollExtent;
      ctrl.jumpTo(bottom - 20);
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsNothing);
      expect(ctrl.offset, greaterThan(bottom - 40));

      // Scroll up again and tap Latest pill -> smoothly reaches bottom and STAYS there!
      ctrl.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsNothing);
      expect(ctrl.offset, closeTo(ctrl.position.maxScrollExtent, 2.0));
    });
  });
}
