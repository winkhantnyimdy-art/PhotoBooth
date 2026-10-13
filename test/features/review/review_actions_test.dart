import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

/// Logical sizes worth defending: an iPhone 16e, a small older phone, and a
/// deliberately cramped viewport.
const Size kIphone16e = Size(393, 852);
const Size kSmallPhone = Size(320, 568);
const Size kCramped = Size(280, 700);

/// WCAG relative luminance.
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// WCAG contrast ratio between two colours.
double contrastRatio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(PhotoLayout layout) {
  return MaterialApp(
    theme: AppTheme.theme,
    home: ReviewScreen(
      layout: layout,
      photos: const <XFile>[],
      retakeCameraBuilder: (BuildContext context, int index) =>
          const SizedBox.shrink(),
    ),
  );
}

Finder _ancestorButton<T extends Widget>(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(T));

/// The button carrying [label], resolved through both the app theme and the
/// widget's own style - which is where the contrast bug lived.
({ButtonStyle theme, ButtonStyle widget}) _stylesFor<T extends ButtonStyleButton>(
  WidgetTester tester,
  String label,
) {
  final Finder button = _ancestorButton<T>(label);
  final Element element = tester.element(button);
  final T widget = tester.widget<T>(button);
  final ButtonStyle themeStyle = T == OutlinedButton
      ? Theme.of(element).outlinedButtonTheme.style!
      : Theme.of(element).filledButtonTheme.style!;
  return (theme: themeStyle, widget: widget.style!);
}

/// Resolves the colours a user actually sees.
///
/// `ButtonStyle.merge` gives the **receiver** priority and only fills gaps from
/// its argument, so the widget's style must be the receiver and the theme the
/// argument - the same order Flutter uses internally. Merging the other way
/// silently returns the theme's colours, which is exactly how the original
/// near-white fill hid behind a passing-looking assertion.
Color _resolvedBackground<T extends ButtonStyleButton>(
  WidgetTester tester,
  String label,
) {
  final ({ButtonStyle theme, ButtonStyle widget}) styles =
      _stylesFor<T>(tester, label);
  return styles.widget
      .merge(styles.theme)
      .backgroundColor!
      .resolve(const <WidgetState>{})!;
}

void main() {
  group('problem 1 - Retake must be readable', () {
    testWidgets('the Retake label reaches WCAG AA contrast on its own fill', (
      tester,
    ) async {
      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      final Color background = _resolvedBackground<OutlinedButton>(
        tester,
        'Retake',
      );

      // The bug: the app theme paints every OutlinedButton with a near-white
      // surface while the Review screen asked for `onDark` text, so the label
      // rendered white-on-white and was effectively invisible on the iPhone.
      final double ratio = contrastRatio(background, AppColors.onDark);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'Retake text on its background must reach WCAG AA. Background was '
            '${background.toARGB32()}, giving a ratio of $ratio.',
      );
    });

    testWidgets('the Retake button does not inherit the light theme fill', (
      tester,
    ) async {
      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      final Color background = _resolvedBackground<OutlinedButton>(
        tester,
        'Retake',
      );
      expect(
        background.computeLuminance(),
        lessThan(0.5),
        reason:
            'the dark review stage needs a dark button fill; got '
            '${background.toARGB32()}',
      );
    });

    testWidgets('the disabled Retake state stays readable too', (tester) async {
      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      // Resolve the disabled state, which is what shows while a retake runs.
      final ({ButtonStyle theme, ButtonStyle widget}) styles =
          _stylesFor<OutlinedButton>(tester, 'Retake');
      final ButtonStyle effective = styles.widget.merge(styles.theme);
      final Color bg = effective.backgroundColor!
          .resolve(const <WidgetState>{WidgetState.disabled})!;
      final Color fg = effective.foregroundColor!
          .resolve(const <WidgetState>{WidgetState.disabled})!;

      expect(
        contrastRatio(bg, fg),
        greaterThanOrEqualTo(3.0),
        reason: 'the busy/disabled label must still be legible',
      );
    });

    testWidgets('Retake and Next are visually distinct', (tester) async {
      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      final Color retake = _resolvedBackground<OutlinedButton>(tester, 'Retake');
      final Color next = _resolvedBackground<FilledButton>(tester, 'Next');

      expect(
        retake,
        isNot(next),
        reason: 'the two actions must not look like the same button',
      );
      expect(
        contrastRatio(retake, next),
        greaterThan(1.5),
        reason: 'they should be clearly distinguishable at a glance',
      );
    });

    testWidgets('both actions are present with readable labels', (tester) async {
      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });

  group('problem 1 - the actions survive narrow viewports', () {
    for (final (String name, Size size) in <(String, Size)>[
      ('iPhone 16e', kIphone16e),
      ('small phone', kSmallPhone),
      ('cramped viewport', kCramped),
    ]) {
      testWidgets('$name keeps both actions large enough to tap', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(PhotoLayout.grid4));
        await tester.pumpAndSettle();

        final Finder retake = _ancestorButton<OutlinedButton>('Retake');
        final Finder next = _ancestorButton<FilledButton>('Next');

        expect(retake, findsOneWidget, reason: 'Retake must survive $name');
        expect(next, findsOneWidget, reason: 'Next must survive $name');

        // Comfortably above the 44pt minimum touch target.
        expect(tester.getSize(retake).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(next).height, greaterThanOrEqualTo(48));

        // And both must still be on screen, not pushed out of the viewport.
        expect(
          tester.getRect(retake).bottom,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.getRect(next).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(retake).width, greaterThan(60));
        expect(tester.getRect(next).width, greaterThan(60));
      });
    }

    testWidgets('no overflow on a narrow viewport', (tester) async {
      tester.view.physicalSize = kSmallPhone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      // A RenderFlex overflow is reported through FlutterError, which fails the
      // test automatically; reaching this point means the layout held.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bottom safe-area inset is respected', (tester) async {
      // iPhone Safari shows browser chrome and iOS shows a home indicator; the
      // action bar has to clear both.
      tester.view.physicalSize = kIphone16e;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(PhotoLayout.grid4));
      await tester.pumpAndSettle();

      final Rect next = tester.getRect(_ancestorButton<FilledButton>('Next'));
      expect(
        next.bottom,
        lessThanOrEqualTo(kIphone16e.height - 34),
        reason: 'the primary action must clear the bottom safe area',
      );
    });
  });
}