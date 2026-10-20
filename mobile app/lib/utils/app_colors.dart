/// Purpose:
/// - Centralizes application color tokens for consistent theming.
///
/// Responsibilities:
/// - Define semantic colors (primary, success, warning) for light/dark themes.
/// - Expose theme-aware colors via:
///   * `AppColors.of(BuildContext)` — resolves from the Theme's [AppPalette]
///     extension. Always preferred when a BuildContext is available.
///   * `AppColors.background`, `AppColors.cardBackground`, … — static getters
///     that read the current platform brightness at call-time via the nearest
///     Flutter binding dispatcher. These keep the existing call sites working
///     across light/dark modes without requiring a context.
///
/// Used by:
/// - lib/utils/app_theme.dart
/// - lib/screens/*/widgets/*
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "app_palette.dart";

class AppColors {
  AppColors._();

  static AppPalette get _lightPalette => AppPalette.light();
  static AppPalette get _darkPalette => AppPalette.dark();

  static Brightness get _currentBrightness {
    final PlatformDispatcher dispatcher =
        SchedulerBinding.instance.platformDispatcher;
    return dispatcher.platformBrightness;
  }

  static AppPalette get _currentPalette =>
      _currentBrightness == Brightness.dark ? _darkPalette : _lightPalette;

  static AppPalette of(BuildContext context) {
    final AppPalette? palette = Theme.of(context).extension<AppPalette>();
    return palette ?? _currentPalette;
  }

  static Brightness brightnessOf(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context);

  /// Brand colors — these are fixed and identical in both light and dark
  /// (or shared reference points for accent-like semantics).
  static Color get primary => _lightPalette.primary;
  static Color get primaryDark => _lightPalette.primaryDark;
  static Color get primaryLight => _lightPalette.primaryLight;
  static Color get accent => _currentPalette.accent;

  /// Surface / background tokens: adapt based on the current platform theme.
  static Color get background => _currentPalette.background;
  static Color get secondaryBackground => _currentPalette.secondaryBackground;
  static Color get cardBackground => _currentPalette.cardBackground;

  /// Text / content tokens: adapt to current theme.
  static Color get textPrimary => _currentPalette.textPrimary;
  static Color get textSecondary => _currentPalette.textSecondary;
  static Color get hintText => _currentPalette.hintText;

  /// Strokes / dividers.
  static Color get border => _currentPalette.border;
  static Color get divider => _currentPalette.divider;

  /// Semantic status colors (fine to stay fixed, but use theme-aware versions
  /// when we want a slightly lighter shade for dark surfaces).
  static Color get success => _currentPalette.success;
  static Color get warning => _currentPalette.warning;
  static Color get error => _currentPalette.error;
  static Color get info => _currentPalette.info;

  /// Icon tokens.
  static Color get icon => _currentPalette.icon;
  static Color get iconPrimary => _currentPalette.iconPrimary;

  /// Shadow tokens: darker shadow alpha used for dark mode for contrast.
  static Color get shadowSoft => _currentPalette.shadowSoft;
}
