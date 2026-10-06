import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

/// Centralized app theme for PhotoBooth.
///
/// Builds the Material light theme from the shared token files so a single
/// edit to [AppColors], [R], or [S] propagates across the whole app.
abstract final class AppTheme {
  static const String brand = 'PhotoBooth';

  /// The brand font stack. Kept system-native for an offline-first app.
  static const List<String> fontFamilies = <String>['System'];

  static ThemeData light() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: AppColors.onAccent,
          secondary: AppColors.accentDeep,
          onSecondary: AppColors.onAccent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.accentDeep,
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'System',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: R.all(R.md)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentDeep,
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: S.md,
          vertical: S.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: R.all(R.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: R.all(R.sm),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      dividerColor: AppColors.line,
    );
  }

  /// Single light theme; PhotoBooth is a bright cream aesthetic and does not
  /// currently ship a dark variant.
  static ThemeData get theme => light();
}
