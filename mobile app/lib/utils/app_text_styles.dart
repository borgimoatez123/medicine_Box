import "package:flutter/material.dart";

import "app_dimensions.dart";

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge ?? const TextStyle();

  static TextStyle headlineLarge(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge ?? const TextStyle();

  static TextStyle headlineMedium(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium ?? const TextStyle();

  static TextStyle titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge ?? const TextStyle();

  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium ?? const TextStyle();

  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall ?? const TextStyle();

  static TextStyle labelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge ?? const TextStyle();

  static TextStyle labelMedium(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium ?? const TextStyle();

  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge ?? const TextStyle();

  static TextStyle button(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: AppDimensions.buttonTextSize,
          ) ??
      const TextStyle();
}
