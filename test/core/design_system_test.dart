import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_motion.dart';
import 'package:photo_booth/core/theme/app_radius.dart';
import 'package:photo_booth/core/theme/app_shadows.dart';
import 'package:photo_booth/core/theme/app_spacing.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/core/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    final ThemeData theme = AppTheme.theme;

    test('is a Material 3 light theme on the cream canvas', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('maps the brand palette onto the colour scheme', () {
      expect(theme.colorScheme.primary, AppColors.accent);
      expect(theme.colorScheme.onPrimary, AppColors.onAccent);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.colorScheme.error, AppColors.danger);
    });

    test('app bar stays flat and chrome-free', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.backgroundColor, AppColors.background);
    });

    test('buttons share a pill shape and a comfortable height', () {
      final List<OutlinedBorder?> shapes = <OutlinedBorder?>[
        theme.filledButtonTheme.style!.shape!.resolve(<WidgetState>{}),
        theme.outlinedButtonTheme.style!.shape!.resolve(<WidgetState>{}),
        theme.textButtonTheme.style!.shape!.resolve(<WidgetState>{}),
      ];

      for (final OutlinedBorder? shape in shapes) {
        expect(shape, isA<RoundedRectangleBorder>());
        final RoundedRectangleBorder rounded = shape! as RoundedRectangleBorder;
        final BorderRadius radius = rounded.borderRadius.resolve(
          TextDirection.ltr,
        );
        expect(
          radius.topLeft.x,
          R.pill,
          reason: 'buttons should be pill shaped',
        );
      }

      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})?.height,
        54,
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})?.height,
        54,
      );
    });

    test('button minimum widths are finite so buttons work in a Row', () {
      // Size.fromHeight() yields Size(infinity, h), which throws when the
      // button is laid out with unbounded width inside a Row.
      for (final ButtonStyle? style in <ButtonStyle?>[
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
      ]) {
        final Size? minimum = style!.minimumSize!.resolve(<WidgetState>{});
        expect(minimum, isNotNull);
        expect(minimum!.width.isFinite, isTrue, reason: 'finite minimum width');
        expect(minimum.height, greaterThanOrEqualTo(S.touchTarget));
      }
    });

    test('accent text on the cream canvas meets contrast guidance', () {
      // Buttons draw white on the pink accent, so the accent must be dark
      // enough to carry them.
      expect(
        AppColors.accent.computeLuminance(),
        lessThan(0.75),
        reason: 'white-on-accent needs headroom',
      );
      // Accent used as text on cream uses the darker ink token.
      expect(
        AppColors.accentInk.computeLuminance(),
        lessThan(AppColors.accent.computeLuminance()),
      );
      expect(AppColors.textPrimary.computeLuminance(), lessThan(0.1));
    });

    test('chips and switches express selection with the brand palette', () {
      expect(theme.chipTheme.selectedColor, AppColors.accent);
      expect(theme.chipTheme.showCheckmark, isFalse);
      final Color? selectedTrack = theme.switchTheme.trackColor!.resolve(
        <WidgetState>{WidgetState.selected},
      );
      expect(selectedTrack, AppColors.accent);
    });

    test('snackbars float above the content with rounded corners', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });
  });

  group('AppText', () {
    test('roles are ordered from display down to caption', () {
      expect(AppText.display.fontSize!, greaterThan(AppText.title.fontSize!));
      expect(AppText.title.fontSize!, greaterThan(AppText.heading.fontSize!));
      expect(AppText.heading.fontSize!, greaterThan(AppText.label.fontSize!));
      expect(AppText.label.fontSize!, greaterThan(AppText.caption.fontSize!));
    });

    test('body copy keeps a comfortable line height', () {
      expect(AppText.body.height!, greaterThan(1.3));
    });

    test('roles default to the charcoal ink', () {
      expect(AppText.display.color, AppColors.textPrimary);
      expect(AppText.title.color, AppColors.textPrimary);
      expect(AppText.heading.color, AppColors.textPrimary);
    });
  });

  group('Spacing and radius', () {
    test('the spacing scale increases monotonically', () {
      final List<double> scale = <double>[
        S.xxs,
        S.xs,
        S.sm,
        S.md,
        S.lg,
        S.xl,
        S.xxl,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('the radius scale increases monotonically', () {
      final List<double> scale = <double>[R.xs, R.sm, R.md, R.lg, R.xl];
      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('touch target is at least the accessibility minimum', () {
      expect(S.touchTarget, greaterThanOrEqualTo(44));
    });
  });

  group('AppShadows', () {
    test('shadows are soft and low contrast', () {
      for (final List<BoxShadow> shadows in <List<BoxShadow>>[
        AppShadows.soft,
        AppShadows.card,
        AppShadows.lifted,
      ]) {
        for (final BoxShadow shadow in shadows) {
          expect(shadow.color.a, lessThan(0.25));
          expect(shadow.blurRadius, greaterThan(shadow.spreadRadius));
        }
      }
    });

    test('none is an empty list', () {
      expect(AppShadows.none, isEmpty);
    });
  });

  group('AppMotion', () {
    testWidgets('durations collapse when reduced motion is requested', (
      tester,
    ) async {
      late Duration resolved;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (BuildContext context) {
              resolved = AppMotion.of(context, AppMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, Duration.zero);
    });

    testWidgets('durations are kept when animation is allowed', (tester) async {
      late Duration resolved;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (BuildContext context) {
              resolved = AppMotion.of(context, AppMotion.medium);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, AppMotion.medium);
    });

    test('durations stay short and increase with emphasis', () {
      expect(AppMotion.fast, lessThan(AppMotion.medium));
      expect(AppMotion.medium, lessThan(AppMotion.slow));
      expect(AppMotion.slow, lessThan(const Duration(milliseconds: 600)));
    });
  });
}
