import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_effect.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// WCAG relative-luminance contrast ratio, used to keep the dark selectors
/// readable rather than relying on a screenshot looking acceptable.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Widget editor() => MaterialApp(
  theme: AppTheme.theme,
  home: const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[]),
);

Future<void> pumpEditor(
  WidgetTester tester, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(editor());
  await tester.pumpAndSettle();
}

Finder labelFor(PhotoEffect effect) =>
    find.byKey(ValueKey<String>('filter-label-${effect.name}'));

Finder thumbFor(PhotoEffect effect) =>
    find.byKey(ValueKey<String>('filter-thumb-${effect.name}'));

void expectFilterShelfClearsActionBar(WidgetTester tester) {
  final Rect scroll = tester.getRect(
    find.byKey(const ValueKey<String>('decorate-tool-scroll')),
  );
  final Rect done = tester.getRect(
    find.byKey(const ValueKey<String>('decorate-done-bar')),
  );
  final Rect shelf = tester.getRect(
    find.byKey(const ValueKey<String>('filter-shelf')),
  );

  expect(
    shelf.bottom,
    lessThanOrEqualTo(scroll.bottom + 0.01),
    reason: 'the effect shelf must be inside the tool viewport',
  );
  expect(
    shelf.bottom,
    lessThanOrEqualTo(done.top + 0.01),
    reason: 'Finish & Save must not cover the effect shelf',
  );

  for (final PhotoEffect effect in PhotoEffect.values) {
    final Finder label = labelFor(effect);
    final Finder thumb = thumbFor(effect);
    expect(label, findsOneWidget, reason: effect.label);
    expect(thumb, findsOneWidget, reason: effect.label);

    final Rect labelRect = tester.getRect(label);
    final Rect thumbRect = tester.getRect(thumb);
    expect(
      labelRect.top,
      greaterThanOrEqualTo(thumbRect.bottom + 3),
      reason: '${effect.label}: the thumbnail must not cover its label',
    );
    expect(
      labelRect.bottom,
      lessThanOrEqualTo(shelf.bottom - 0.01),
      reason: '${effect.label}: the label must fit inside the shelf',
    );
    expect(
      labelRect.bottom,
      lessThanOrEqualTo(scroll.bottom - 0.01),
      reason: '${effect.label}: the tool viewport must not clip the label',
    );
    expect(
      labelRect.bottom,
      lessThanOrEqualTo(done.top - 0.01),
      reason: '${effect.label}: the action bar must not cover the label',
    );
  }
}

void main() {
  group('Filter tray layout', () {
    testWidgets('every effect label is fully visible above Finish & Save', (
      tester,
    ) async {
      await pumpEditor(tester);
      expectFilterShelfClearsActionBar(tester);
    });

    testWidgets('the effect shelf scrolls horizontally', (tester) async {
      await pumpEditor(tester);

      final Finder classicFilm = labelFor(PhotoEffect.classicFilm);
      final double before = tester.getTopLeft(classicFilm).dx;
      expect(
        before,
        greaterThan(360),
        reason: 'Classic Film starts off-screen',
      );

      await tester.drag(thumbFor(PhotoEffect.original), const Offset(-500, 0));
      await tester.pumpAndSettle();

      final double after = tester.getTopLeft(classicFilm).dx;
      expect(
        after,
        lessThan(before - 300),
        reason: 'dragging left must move later effects towards the viewport',
      );
      expect(after, lessThan(360));

      await tester.tap(classicFilm);
      await tester.pumpAndSettle();
      final Semantics selected = tester.widget<Semantics>(
        find.bySemanticsLabel('Classic Film effect'),
      );
      expect(selected.properties.selected, isTrue);
    });

    testWidgets('the bottom action bar does not overlap the filter shelf', (
      tester,
    ) async {
      await pumpEditor(tester);

      final Rect shelf = tester.getRect(
        find.byKey(const ValueKey<String>('filter-shelf')),
      );
      final Rect done = tester.getRect(
        find.byKey(const ValueKey<String>('decorate-done-bar')),
      );
      expect(shelf.bottom, lessThanOrEqualTo(done.top));
    });

    testWidgets('the editor keeps the shelf visible on a 320 x 640 viewport', (
      tester,
    ) async {
      await pumpEditor(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Finish & Save'), findsOneWidget);
      expectFilterShelfClearsActionBar(tester);

      // The Reset action shares the header with the strength readout. At
      // 320 dp its full label must still fit without an overflow stripe.
      await tester.tap(find.bySemanticsLabel('Warm effect'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('reset-effect')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expectFilterShelfClearsActionBar(tester);

      final Rect done = tester.getRect(
        find.byKey(const ValueKey<String>('decorate-done-bar')),
      );
      expect(done.bottom, lessThanOrEqualTo(640));
    });
  });

  group('Selected frame and pattern chips', () {
    testWidgets(
      'selected frame and pattern labels meet contrast requirements',
      (tester) async {
        await pumpEditor(tester);
        await tester.tap(find.text('Frames'));
        await tester.pumpAndSettle();

        final Finder vintageFilm = find.byKey(
          const ValueKey<String>('frame-theme-vintageFilm'),
        );
        await tester.ensureVisible(vintageFilm);
        await tester.pumpAndSettle();
        await tester.tap(vintageFilm);
        await tester.pumpAndSettle();

        Color chipSurface(Finder pill) {
          final AnimatedContainer container = tester.widget<AnimatedContainer>(
            find
                .descendant(of: pill, matching: find.byType(AnimatedContainer))
                .first,
          );
          return (container.decoration! as BoxDecoration).color!;
        }

        Color chipInk(Finder pill) {
          final Text text = tester.widget<Text>(
            find.descendant(of: pill, matching: find.byType(Text)).first,
          );
          return text.style!.color!;
        }

        final Color selectedFrameSurface = chipSurface(vintageFilm);
        final Color selectedFrameInk = chipInk(vintageFilm);
        expect(selectedFrameSurface, AppColors.darkChipSelectedSurface);
        expect(selectedFrameInk, AppColors.darkChipSelectedInk);
        expect(
          contrastRatio(selectedFrameSurface, selectedFrameInk),
          greaterThanOrEqualTo(4.5),
          reason: 'the selected Frame Theme label must remain readable',
        );

        final Finder minimalWhite = find.byKey(
          const ValueKey<String>('frame-theme-minimalWhite'),
        );
        final Color unselectedFrameSurface = chipSurface(minimalWhite);
        final Color unselectedFrameInk = chipInk(minimalWhite);
        expect(
          selectedFrameSurface,
          isNot(unselectedFrameSurface),
          reason: 'selected and unselected frame chips must be distinguishable',
        );
        expect(
          contrastRatio(unselectedFrameSurface, unselectedFrameInk),
          greaterThanOrEqualTo(4.5),
        );

        final Finder hearts = find.byKey(
          const ValueKey<String>('frame-pattern-hearts'),
        );
        await tester.ensureVisible(hearts);
        await tester.pumpAndSettle();
        await tester.tap(hearts);
        await tester.pumpAndSettle();

        final Color selectedPatternSurface = chipSurface(hearts);
        final Color selectedPatternInk = chipInk(hearts);
        expect(
          contrastRatio(selectedPatternSurface, selectedPatternInk),
          greaterThanOrEqualTo(4.5),
          reason: 'the selected Pattern label must remain readable',
        );

        final Finder clean = find.byKey(
          const ValueKey<String>('frame-pattern-clean'),
        );
        final Color unselectedPatternSurface = chipSurface(clean);
        expect(
          selectedPatternSurface,
          isNot(unselectedPatternSurface),
          reason:
              'selected and unselected pattern chips must be distinguishable',
        );
      },
    );

    testWidgets('the disabled strength control is visually muted', (
      tester,
    ) async {
      await pumpEditor(tester);

      Text strengthLabel() => tester.widget<Text>(find.text('Strength'));

      expect(strengthLabel().style!.color, AppColors.darkMuted);

      final SliderTheme disabledTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byType(Slider),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        disabledTheme.data.activeTrackColor,
        AppColors.darkChipDisabledInk,
      );

      await tester.tap(find.bySemanticsLabel('Warm effect'));
      await tester.pumpAndSettle();

      expect(strengthLabel().style!.color, AppColors.onDark);
      final SliderTheme enabledTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byType(Slider),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(enabledTheme.data.activeTrackColor, AppColors.onDark);
    });
  });
}
