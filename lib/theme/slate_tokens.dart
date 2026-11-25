import 'package:flutter/material.dart';

/// Exact Slate design tokens matching TernaryCode desktop (`src/ui/style.rs`)
/// and the mobile design specification (`design/slate.css`).
@immutable
class SlateColors extends ThemeExtension<SlateColors> {
  const SlateColors({
    required this.isDark,
    required this.window,
    required this.sheet,
    required this.raised,
    required this.overlay,
    required this.menu,
    required this.inset,
    required this.scrim,
    required this.hover,
    required this.active,
    required this.selected,
    required this.lineSubtle,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.accent,
    required this.accentHover,
    required this.accentText,
    required this.accentTint,
    required this.onAccent,
    required this.focusGlow,
    required this.running,
    required this.input,
    required this.done,
    required this.failed,
    required this.idle,
    required this.limited,
    required this.cooldown,
    required this.runningTint,
    required this.inputTint,
    required this.doneTint,
    required this.failedTint,
    required this.limitedTint,
    required this.cooldownTint,
    required this.idleTint,
    required this.diffAdd,
    required this.diffDel,
    required this.termFg,
    required this.termDim,
    required this.termBlue,
    required this.termGreen,
    required this.termYellow,
    required this.termRed,
    required this.termMag,
    required this.termCyan,
    required this.claude,
    required this.hBlue,
    required this.hBlueTint,
    required this.hViolet,
    required this.hVioletTint,
    required this.hGreen,
    required this.hGreenTint,
    required this.hAmber,
    required this.hAmberTint,
    required this.hRose,
    required this.hRoseTint,
    required this.hCyan,
    required this.hCyanTint,
  });

  final bool isDark;

  // Surfaces
  final Color window;
  final Color sheet;
  final Color raised;
  final Color overlay;
  final Color menu;
  final Color inset;
  final Color scrim;

  // Interaction states
  final Color hover;
  final Color active;
  final Color selected;

  // Hairlines
  final Color lineSubtle;
  final Color line;
  final Color lineStrong;

  // Text
  final Color text;
  final Color text2;
  final Color text3;
  final Color text4;

  // Accent
  final Color accent;
  final Color accentHover;
  final Color accentText;
  final Color accentTint;
  final Color onAccent;
  final Color focusGlow;

  // Semantic statuses
  final Color running;
  final Color input;
  final Color done;
  final Color failed;
  final Color idle;
  final Color limited;
  final Color cooldown;

  // Status tints
  final Color runningTint;
  final Color inputTint;
  final Color doneTint;
  final Color failedTint;
  final Color limitedTint;
  final Color cooldownTint;
  final Color idleTint;

  // Diff & terminal ANSI
  final Color diffAdd;
  final Color diffDel;
  final Color termFg;
  final Color termDim;
  final Color termBlue;
  final Color termGreen;
  final Color termYellow;
  final Color termRed;
  final Color termMag;
  final Color termCyan;
  final Color claude;

  // Project avatar hues
  final Color hBlue;
  final Color hBlueTint;
  final Color hViolet;
  final Color hVioletTint;
  final Color hGreen;
  final Color hGreenTint;
  final Color hAmber;
  final Color hAmberTint;
  final Color hRose;
  final Color hRoseTint;
  final Color hCyan;
  final Color hCyanTint;

  static const SlateColors dark = SlateColors(
    isDark: true,
    window: Color(0xFF09090B),
    sheet: Color(0xFF111113),
    raised: Color(0xFF1A1A1D),
    overlay: Color(0xFF18181B),
    menu: Color(0xFF202024),
    inset: Color(0xFF0C0C0E),
    scrim: Color(0x9E000000),
    hover: Color(0x0DFFFFFF),
    active: Color(0x14FFFFFF),
    selected: Color(0x12FFFFFF),
    lineSubtle: Color(0x0FFFFFFF),
    line: Color(0x1AFFFFFF),
    lineStrong: Color(0x2EFFFFFF),
    text: Color(0xFFEDEDF0),
    text2: Color(0xFFA0A0A9),
    text3: Color(0xFF6C6C75),
    text4: Color(0xFF4A4A52),
    accent: Color(0xFF2E6BE6),
    accentHover: Color(0xFF3A76F0),
    accentText: Color(0xFF8BB2FF),
    accentTint: Color(0x242E6BE6),
    onAccent: Color(0xFFFFFFFF),
    focusGlow: Color(0x472E6BE6),
    running: Color(0xFF6AA5FF),
    input: Color(0xFFF2B14B),
    done: Color(0xFF4DC48C),
    failed: Color(0xFFF06A64),
    idle: Color(0xFF6C6C75),
    limited: Color(0xFFF29441),
    cooldown: Color(0xFF5DB6DC),
    runningTint: Color(0x246AA5FF),
    inputTint: Color(0x26F2B14B),
    doneTint: Color(0x244DC48C),
    failedTint: Color(0x26F06A64),
    limitedTint: Color(0x26F29441),
    cooldownTint: Color(0x245DB6DC),
    idleTint: Color(0x0FFFFFFF),
    diffAdd: Color(0x214DC48C),
    diffDel: Color(0x24F06A64),
    termFg: Color(0xFFD6D6DC),
    termDim: Color(0xFF64646E),
    termBlue: Color(0xFF7CB2FF),
    termGreen: Color(0xFF5DD196),
    termYellow: Color(0xFFF2C15A),
    termRed: Color(0xFFF0716A),
    termMag: Color(0xFFC09CFF),
    termCyan: Color(0xFF68D2E8),
    claude: Color(0xFFD97757),
    hBlue: Color(0xFF7AAEFF),
    hBlueTint: Color(0x247AAEFF),
    hViolet: Color(0xFFB392FF),
    hVioletTint: Color(0x24B392FF),
    hGreen: Color(0xFF6FD3A0),
    hGreenTint: Color(0x246FD3A0),
    hAmber: Color(0xFFEFC15E),
    hAmberTint: Color(0x24EFC15E),
    hRose: Color(0xFFF58BA6),
    hRoseTint: Color(0x24F58BA6),
    hCyan: Color(0xFF63CFE3),
    hCyanTint: Color(0x2463CFE3),
  );

  static const SlateColors light = SlateColors(
    isDark: false,
    window: Color(0xFFEDEDEF),
    sheet: Color(0xFFFBFBFC),
    raised: Color(0xFFFFFFFF),
    overlay: Color(0xFFFFFFFF),
    menu: Color(0xFFFFFFFF),
    inset: Color(0xFFE9E9EC),
    scrim: Color(0x57000000),
    hover: Color(0x0A000000),
    active: Color(0x12000000),
    selected: Color(0x0D000000),
    lineSubtle: Color(0x0F000000),
    line: Color(0x1A000000),
    lineStrong: Color(0x2B000000),
    text: Color(0xFF17171A),
    text2: Color(0xFF565660),
    text3: Color(0xFF80808A),
    text4: Color(0xFFABABB3),
    accent: Color(0xFF1F5FBF),
    accentHover: Color(0xFF1A52A8),
    accentText: Color(0xFF1A56B3),
    accentTint: Color(0x1A1F5FBF),
    onAccent: Color(0xFFFFFFFF),
    focusGlow: Color(0x381F5FBF),
    running: Color(0xFF2563C9),
    input: Color(0xFFB26A00),
    done: Color(0xFF15804E),
    failed: Color(0xFFC7352D),
    idle: Color(0xFF8E8E98),
    limited: Color(0xFFC2560A),
    cooldown: Color(0xFF2D6C9E),
    runningTint: Color(0x142563C9),
    inputTint: Color(0x17B26A00),
    doneTint: Color(0x1415804E),
    failedTint: Color(0x14C7352D),
    limitedTint: Color(0x17C2560A),
    cooldownTint: Color(0x172D6C9E),
    idleTint: Color(0x0D000000),
    diffAdd: Color(0x1415804E),
    diffDel: Color(0x14C7352D),
    termFg: Color(0xFF2A2A30),
    termDim: Color(0xFF8A8A94),
    termBlue: Color(0xFF1F5FBF),
    termGreen: Color(0xFF1C7A4A),
    termYellow: Color(0xFF946200),
    termRed: Color(0xFFC0392B),
    termMag: Color(0xFF7C3AED),
    termCyan: Color(0xFF0E7490),
    claude: Color(0xFFC65D3B),
    hBlue: Color(0xFF1F5FBF),
    hBlueTint: Color(0x1A1F5FBF),
    hViolet: Color(0xFF6D3FD6),
    hVioletTint: Color(0x1A6D3FD6),
    hGreen: Color(0xFF16794B),
    hGreenTint: Color(0x1A16794B),
    hAmber: Color(0xFF9A6400),
    hAmberTint: Color(0x1A9A6400),
    hRose: Color(0xFFC02B5A),
    hRoseTint: Color(0x1AC02B5A),
    hCyan: Color(0xFF0E7490),
    hCyanTint: Color(0x1A0E7490),
  );

  (Color fg, Color bg) projectHue(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('store') || lower.contains('web') || lower.contains('front')) {
      return (hBlue, hBlueTint);
    }
    if (lower.contains('ternary') || lower.contains('core')) {
      return (hViolet, hVioletTint);
    }
    if (lower.contains('api') || lower.contains('server') || lower.contains('backend')) {
      return (hGreen, hGreenTint);
    }
    if (lower.contains('doc') || lower.contains('site')) {
      return (hAmber, hAmberTint);
    }
    if (lower.contains('mobile') || lower.contains('app') || lower.contains('ios')) {
      return (hRose, hRoseTint);
    }
    final palette = <(Color, Color)>[
      (hBlue, hBlueTint),
      (hViolet, hVioletTint),
      (hGreen, hGreenTint),
      (hAmber, hAmberTint),
      (hRose, hRoseTint),
      (hCyan, hCyanTint),
    ];
    final hash = name.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    return palette[hash % palette.length];
  }

  (Color fg, Color tint) statusTone(String status) {
    switch (status) {
      case 'running':
        return (running, runningTint);
      case 'needs_input':
        return (input, inputTint);
      case 'done':
        return (done, doneTint);
      case 'failed':
      case 'error':
        return (failed, failedTint);
      case 'rate_limited':
        return (limited, limitedTint);
      case 'cooldown':
        return (cooldown, cooldownTint);
      default:
        return (idle, idleTint);
    }
  }

  @override
  SlateColors copyWith({bool? isDark}) => isDark == false ? light : dark;

  @override
  SlateColors lerp(ThemeExtension<SlateColors>? other, double t) {
    if (other is! SlateColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension SlateBuildContext on BuildContext {
  SlateColors get slate =>
      Theme.of(this).extension<SlateColors>() ?? SlateColors.dark;
}
