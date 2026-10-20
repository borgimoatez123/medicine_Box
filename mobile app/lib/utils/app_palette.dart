import "package:flutter/material.dart";

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.secondaryBackground,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.hintText,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.icon,
    required this.iconPrimary,
    required this.shadowSoft,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color secondaryBackground;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color hintText;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color icon;
  final Color iconPrimary;
  final Color shadowSoft;

  factory AppPalette.light() {
    return const AppPalette(
      brightness: Brightness.light,
      primary: Color(0xFF216DB4),
      primaryDark: Color(0xFF165A96),
      primaryLight: Color(0xFF5D9DE2),
      accent: Color(0xFFFF6A4D),
      background: Color(0xFFFFFFFF),
      secondaryBackground: Color(0xFFF8FAFC),
      cardBackground: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF1F2937),
      textSecondary: Color(0xFF6B7280),
      hintText: Color(0xFF9CA3AF),
      border: Color(0xFFE5E7EB),
      divider: Color(0xFFEDF2F7),
      success: Color(0xFF22C55E),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      info: Color(0xFF3B82F6),
      icon: Color(0xFF6B7280),
      iconPrimary: Color(0xFF216DB4),
      shadowSoft: Color(0x14000000),
    );
  }

  factory AppPalette.dark() {
    return const AppPalette(
      brightness: Brightness.dark,
      primary: Color(0xFF6AA8E0),
      primaryDark: Color(0xFF165A96),
      primaryLight: Color(0xFF8BC0F0),
      accent: Color(0xFFFF8B72),
      background: Color(0xFF0F172A),
      secondaryBackground: Color(0xFF1E293B),
      cardBackground: Color(0xFF162033),
      textPrimary: Color(0xFFF1F5F9),
      textSecondary: Color(0xFF94A3B8),
      hintText: Color(0xFF64748B),
      border: Color(0xFF334155),
      divider: Color(0xFF273449),
      success: Color(0xFF4ADE80),
      warning: Color(0xFFFBBF24),
      error: Color(0xFFF87171),
      info: Color(0xFF60A5FA),
      icon: Color(0xFF94A3B8),
      iconPrimary: Color(0xFF6AA8E0),
      shadowSoft: Color(0x52000000),
    );
  }

  bool get isDark => brightness == Brightness.dark;

  @override
  ThemeExtension<AppPalette> copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? background,
    Color? secondaryBackground,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? hintText,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? icon,
    Color? iconPrimary,
    Color? shadowSoft,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      hintText: hintText ?? this.hintText,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      icon: icon ?? this.icon,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      shadowSoft: shadowSoft ?? this.shadowSoft,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      primaryLight:
          Color.lerp(primaryLight, other.primaryLight, t) ?? primaryLight,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      background: Color.lerp(background, other.background, t) ?? background,
      secondaryBackground:
          Color.lerp(secondaryBackground, other.secondaryBackground, t) ??
              secondaryBackground,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ??
              cardBackground,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ??
          textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ??
              textSecondary,
      hintText: Color.lerp(hintText, other.hintText, t) ?? hintText,
      border: Color.lerp(border, other.border, t) ?? border,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      info: Color.lerp(info, other.info, t) ?? info,
      icon: Color.lerp(icon, other.icon, t) ?? icon,
      iconPrimary:
          Color.lerp(iconPrimary, other.iconPrimary, t) ?? iconPrimary,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t) ?? shadowSoft,
    );
  }
}
