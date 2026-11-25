import 'package:flutter/material.dart';
import 'slate_tokens.dart';

class SlateTypography {
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  static TextStyle title(SlateColors c, {double size = 22}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.025 * size,
        color: c.text,
      );

  static TextStyle section(SlateColors c) => TextStyle(
        fontFamily: sans,
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.44,
        color: c.text3,
      );

  static TextStyle body(SlateColors c, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: 13,
        height: 18 / 13,
        fontWeight: weight,
        color: c.text,
      );

  static TextStyle body2(SlateColors c) => TextStyle(
        fontFamily: sans,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: c.text2,
      );

  static TextStyle data(SlateColors c,
          {double size = 11, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: 1.32,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? c.text3,
      );
}

class SlateTheme {
  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? SlateColors.dark : SlateColors.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accentText,
      onSecondary: c.onAccent,
      error: c.failed,
      onError: c.onAccent,
      surface: c.window,
      onSurface: c.text,
      outline: c.line,
      outlineVariant: c.lineSubtle,
      surfaceContainerHighest: c.raised,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.window,
      canvasColor: c.window,
      cardColor: c.raised,
      dividerColor: c.lineSubtle,
      splashFactory: InkSparkle.splashFactory,
      splashColor: c.hover,
      highlightColor: c.active,
      fontFamily: SlateTypography.sans,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.window,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.overlay,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.overlay,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.lineStrong),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.menu,
        contentTextStyle: SlateTypography.body(c),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.lineStrong),
        ),
      ),
    );
  }
}
