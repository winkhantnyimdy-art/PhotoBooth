import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Centralized app theme for PhotoBooth.
///
/// Builds the Material light theme from the shared token files so a single
/// edit to [AppColors], [R], [S], [AppText] or [AppShadows] propagates across
/// the whole app.
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
          error: AppColors.danger,
          onError: Colors.white,
          outline: AppColors.lineStrong,
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'System',
    );

    final TextTheme textTheme = base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineLarge: AppText.display,
          headlineMedium: AppText.title,
          titleLarge: AppText.heading,
          titleMedium: AppText.label,
          bodyLarge: AppText.body,
          bodyMedium: AppText.body,
          labelLarge: AppText.button,
          labelMedium: AppText.buttonSmall,
          labelSmall: AppText.overline,
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.heading,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: R.all(R.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.onAccent.withValues(alpha: 0.9),
          elevation: 0,
          // A finite width keeps these usable inside a Row; full width comes
          // from a stretched parent, not from an infinite minimum.
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: S.lg),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(0, 54),
          side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: AppText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentInk,
          minimumSize: const Size(0, S.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
          textStyle: AppText.buttonSmall,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        checkmarkColor: AppColors.onAccent,
        showCheckmark: false,
        side: const BorderSide(color: AppColors.line),
        labelStyle: AppText.label,
        secondaryLabelStyle: AppText.label.copyWith(color: AppColors.onAccent),
        padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.onAccent
              : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.lineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceTint,
        circularTrackColor: AppColors.surfaceTint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppText.label.copyWith(color: AppColors.onDark),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: R.all(R.sm)),
        insetPadding: const EdgeInsets.all(S.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: R.all(R.lg)),
        titleTextStyle: AppText.heading,
        contentTextStyle: AppText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
        ),
      ),
    );
  }

  /// Single light theme; PhotoBooth is a bright cream aesthetic and does not
  /// currently ship a dark variant.
  static ThemeData get theme => light();
}
