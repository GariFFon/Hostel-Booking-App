import 'package:flutter/material.dart';

/// Design tokens shared with the website (`Hostel-Booking/docs/design-tokens.md`). Change the doc first, then here and in `globals.css`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.popover,
    required this.primary,
    required this.onPrimary,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.border,
    required this.input,
    required this.destructive,
    required this.success,
    required this.warning,
    required this.info,
    required this.star,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color popover;
  final Color primary;
  final Color onPrimary;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color border;
  final Color input;
  final Color destructive;
  final Color success;
  final Color warning;
  final Color info;
  final Color star;

  static const light = AppColors(
    background: Color(0xFFFAF9F6),
    foreground: Color(0xFF14171C),
    card: Color(0xFFFFFFFF),
    popover: Color(0xFFFFFFFF),
    primary: Color(0xFF0B7A66),
    onPrimary: Color(0xFFFFFFFF),
    muted: Color(0xFFF1EFE9),
    mutedForeground: Color(0xFF5B616D),
    accent: Color(0xFFE2F3EE),
    accentForeground: Color(0xFF08594A),
    border: Color(0xFFE6E3DC),
    input: Color(0xFFD8D4CB),
    destructive: Color(0xFFC4302B),
    success: Color(0xFF11693A),
    warning: Color(0xFF8A4B00),
    info: Color(0xFF1D4ED8),
    star: Color(0xFFF59E0B),
  );

  static const dark = AppColors(
    background: Color(0xFF0E1012),
    foreground: Color(0xFFECEEF1),
    card: Color(0xFF15181C),
    popover: Color(0xFF1A1D22),
    primary: Color(0xFF3FCFAE),
    onPrimary: Color(0xFF04211A),
    muted: Color(0xFF1E2227),
    mutedForeground: Color(0xFF9AA1AD),
    accent: Color(0xFF12332C),
    accentForeground: Color(0xFF7AE3C9),
    border: Color(0xFF272B31),
    input: Color(0xFF343A42),
    destructive: Color(0xFFF0605B),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF7AA2FF),
    star: Color(0xFFFBBF24),
  );

  /// Tinted chip background: the token at 8-14% opacity, per the design doc.
  Color tint(Color c, [double alpha = 0.12]) => c.withValues(alpha: alpha);

  @override
  AppColors copyWith({Color? background}) => AppColors(
    background: background ?? this.background,
    foreground: foreground,
    card: card,
    popover: popover,
    primary: primary,
    onPrimary: onPrimary,
    muted: muted,
    mutedForeground: mutedForeground,
    accent: accent,
    accentForeground: accentForeground,
    border: border,
    input: input,
    destructive: destructive,
    success: success,
    warning: warning,
    info: info,
    star: star,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      foreground: l(foreground, other.foreground),
      card: l(card, other.card),
      popover: l(popover, other.popover),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      muted: l(muted, other.muted),
      mutedForeground: l(mutedForeground, other.mutedForeground),
      accent: l(accent, other.accent),
      accentForeground: l(accentForeground, other.accentForeground),
      border: l(border, other.border),
      input: l(input, other.input),
      destructive: l(destructive, other.destructive),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      info: l(info, other.info),
      star: l(star, other.star),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40, 56. Page gutter 16 on phones, 24 from tablet width.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
  static const double x5 = 56;
  static const double gutter = 16;
  static const double tabletGutter = 24;

  static double gutterFor(double width) => width >= 600 ? tabletGutter : gutter;
}

/// Radius: base 12, controls 8-10, cards 16, sheets 24 (top corners), pills fully rounded.
abstract final class Radii {
  static const double control = 10;
  static const double base = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;

  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get baseR => BorderRadius.circular(base);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get pillR => BorderRadius.circular(pill);
  static const BorderRadius sheetR = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Minimum touch target (dp): 48 satisfies Android's guideline and exceeds iOS's 44. Visual size may be smaller, the hit area is not.
const double kMinTap = 48;
