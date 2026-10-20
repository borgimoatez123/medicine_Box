/// Purpose:
/// - Defines the application theming boundary.
///
/// Responsibilities:
/// - Provide Light Theme and Dark Theme configuration.
/// - Centralize typography, component styling, and theme tokens.
/// - Attach an [AppPalette] extension that screens can resolve via
///   `Theme.of(context).extension<AppPalette>()` or `AppColors.of(context)`.
///
/// Used by:
/// - lib/main.dart (theme setup)
/// - lib/screens/*/widgets/* (themed UI)
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_palette.dart";
import "app_dimensions.dart";
import "app_radius.dart";

class AppTheme {
  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();

  static ThemeData light() {
    final AppPalette palette = AppPalette.light();
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: palette.primary,
          onPrimary: Colors.white,
          primaryContainer: palette.primaryLight,
          onPrimaryContainer: palette.primaryDark,
          secondary: palette.accent,
          onSecondary: Colors.white,
          secondaryContainer: palette.accent.withValues(alpha: 0.12),
          onSecondaryContainer: palette.accent,
          error: palette.error,
          onError: Colors.white,
          surface: palette.cardBackground,
          onSurface: palette.textPrimary,
          surfaceContainerHighest: palette.secondaryBackground,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.border,
          outlineVariant: palette.divider,
          shadow: palette.shadowSoft,
        );

    final TextTheme base = GoogleFonts.poppinsTextTheme();
    final TextTheme textTheme = base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        )
        .apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        );

    return _buildTheme(
      scheme: scheme,
      palette: palette,
      textTheme: textTheme,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final AppPalette palette = AppPalette.dark();
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: Brightness.dark,
        ).copyWith(
          brightness: Brightness.dark,
          primary: palette.primary,
          onPrimary: const Color(0xFF0A1930),
          primaryContainer: palette.primaryDark,
          onPrimaryContainer: palette.primaryLight,
          secondary: palette.accent,
          onSecondary: const Color(0xFF2A120A),
          secondaryContainer: palette.accent.withValues(alpha: 0.16),
          onSecondaryContainer: palette.accent,
          error: palette.error,
          onError: const Color(0xFF440A0A),
          surface: palette.cardBackground,
          onSurface: palette.textPrimary,
          surfaceContainerHighest: palette.secondaryBackground,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.border,
          outlineVariant: palette.divider,
          shadow: palette.shadowSoft,
        );

    final TextTheme base = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );
    final TextTheme textTheme = base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: palette.textPrimary,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: palette.textPrimary,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: palette.textPrimary,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: palette.textPrimary,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: palette.textPrimary,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: palette.textPrimary,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
            color: palette.textSecondary,
          ),
        )
        .apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        );

    return _buildTheme(
      scheme: scheme,
      palette: palette,
      textTheme: textTheme,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required AppPalette palette,
    required TextTheme textTheme,
    required Brightness brightness,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final Color onPrimary = scheme.onPrimary;
    final Color primary = scheme.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.icon, size: 22),
      primaryIconTheme: IconThemeData(color: palette.iconPrimary, size: 22),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.icon, size: 22),
        actionsIconTheme: IconThemeData(color: palette.icon, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.cardBackground,
        indicatorColor: primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(color: palette.icon, size: 24),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.cardBackground,
        selectedItemColor: primary,
        unselectedItemColor: palette.icon,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: palette.shadowSoft,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br16,
          side: BorderSide(color: palette.border),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.icon,
        textColor: palette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: isDark
              ? palette.primary.withValues(alpha: 0.35)
              : palette.primaryLight,
          disabledForegroundColor: isDark
              ? onPrimary.withValues(alpha: 0.7)
              : Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br14),
          textStyle: GoogleFonts.poppins(
            fontSize: AppDimensions.buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br14),
          textStyle: GoogleFonts.poppins(
            fontSize: AppDimensions.buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br14),
          side: BorderSide(color: primary, width: 1.5),
          textStyle: GoogleFonts.poppins(
            fontSize: AppDimensions.buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.secondaryBackground,
        labelStyle: GoogleFonts.poppins(
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          color: primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: primary.withValues(alpha: 0.14),
        disabledColor: palette.border,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.br999),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.cardBackground,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.cardBackground,
        modalBarrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br16,
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.br16,
          side: BorderSide(color: palette.border),
        ),
        textStyle: textTheme.bodyLarge?.copyWith(color: palette.textPrimary),
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.secondaryBackground,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: palette.border),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        actionTextColor: primary,
      ),
      dividerColor: palette.divider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.secondaryBackground,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: palette.hintText,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        helperStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: palette.textSecondary,
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.textFieldHorizontalPadding,
          vertical: AppDimensions.textFieldVerticalPadding,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: palette.error, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: palette.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.br12,
          borderSide: BorderSide(color: palette.border),
        ),
        prefixIconColor: palette.icon,
        suffixIconColor: palette.icon,
      ),
    );
  }

  const AppTheme._();
}
