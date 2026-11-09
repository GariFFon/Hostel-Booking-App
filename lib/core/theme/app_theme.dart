import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 theme derived from the shared design tokens (light + dark).
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.accent,
      onPrimaryContainer: c.accentForeground,
      secondary: c.mutedForeground,
      onSecondary: c.background,
      secondaryContainer: c.muted,
      onSecondaryContainer: c.foreground,
      tertiary: c.info,
      onTertiary: Colors.white,
      error: c.destructive,
      onError: b == Brightness.light ? Colors.white : const Color(0xFF2A0A09),
      errorContainer: Color.alphaBlend(c.destructive.withValues(alpha: 0.12), c.card),
      onErrorContainer: c.destructive,
      surface: c.background,
      onSurface: c.foreground,
      onSurfaceVariant: c.mutedForeground,
      surfaceContainerLowest: c.card,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.popover,
      surfaceContainerHighest: c.muted,
      outline: c.input,
      outlineVariant: c.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.foreground,
      onInverseSurface: c.background,
      inversePrimary: c.primary,
      surfaceTint: Colors.transparent, // no M3 elevation tint: hairline border first, shadow second
    );

    final text = _textTheme(c);
    final hairline = BorderSide(color: c.border);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c],
      splashFactory: NoSplash.splashFactory, // press feedback is a scale on every pressable (see Pressable), not a ripple
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR, side: hairline),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR, side: hairline),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.popover,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetR),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.foreground,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: Radii.baseR),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.accent,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? c.accentForeground : c.mutedForeground,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? c.accentForeground : c.mutedForeground),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: text.bodyLarge?.copyWith(color: c.mutedForeground.withValues(alpha: 0.8)),
        errorStyle: text.bodySmall?.copyWith(color: c.destructive),
        border: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.destructive, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: Radii.controlR,
          borderSide: BorderSide(color: c.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.card),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.input),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.input, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.muted),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.foreground, borderRadius: BorderRadius.circular(8)),
        textStyle: text.bodySmall?.copyWith(color: c.background),
      ),
      listTileTheme: ListTileThemeData(iconColor: c.mutedForeground, textColor: c.foreground),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        rangeSelectionBackgroundColor: c.accent,
        rangeSelectionOverlayColor: const WidgetStatePropertyAll(Colors.transparent),
        headerBackgroundColor: c.popover,
        headerForegroundColor: c.foreground,
      ),
    );
  }

  static TextTheme _textTheme(AppColors c) {
    TextStyle s(double size, double height, FontWeight w, double trackingEm, {Color? color}) =>
        TextStyle(fontSize: size, height: height, fontWeight: w, letterSpacing: size * trackingEm, color: color ?? c.foreground);
    const w4 = FontWeight.w400;
    const w5 = FontWeight.w500;
    const w6 = FontWeight.w600;
    return TextTheme(
      displayLarge: s(42, 1.02, w6, -0.035),
      displayMedium: s(34, 1.05, w6, -0.03),
      displaySmall: s(28, 1.1, w6, -0.025),
      headlineLarge: s(30, 1.15, w6, -0.025),
      headlineMedium: s(24, 1.2, w6, -0.02),
      headlineSmall: s(20, 1.25, w6, -0.02),
      titleLarge: s(18, 1.25, w6, -0.015),
      titleMedium: s(16, 1.3, w6, -0.01),
      titleSmall: s(14, 1.3, w6, 0),
      bodyLarge: s(16, 1.5, w4, 0),
      bodyMedium: s(15, 1.5, w4, 0),
      bodySmall: s(13, 1.4, w4, 0, color: c.mutedForeground),
      labelLarge: s(15, 1.2, w6, 0),
      labelMedium: s(13, 1.3, w5, 0),
      labelSmall: s(11, 1.3, w5, 0.04, color: c.mutedForeground),
    );
  }
}

extension TextStyleX on TextStyle {
  /// Money, counts, dates and countdowns line up: tabular figures.
  TextStyle get tabular => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  TextStyle withColor(Color c) => copyWith(color: c);
}
