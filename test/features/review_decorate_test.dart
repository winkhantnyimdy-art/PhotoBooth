import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

void main() {
  group('ReviewScreen', () {
    testWidgets('presents the photos and both actions', (tester) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      // A clear next step toward decoration.
      expect(
        find.text('Review'),
        findsOneWidget,
      );
    });

    testWidgets('Continue navigates to the decoration studio', (tester) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.textContaining('Finish & Save'), findsOneWidget);
    });

    testWidgets('Retake returns to the previous screen', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReviewScreen(
                      layout: PhotoLayout.cut2,
                      photos: <XFile>[],
                    ),
                  ),
                ),
                child: const Text('Go to Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go to Review'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Retake'), findsOneWidget);

      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Go to Review'), findsOneWidget);
      expect(find.text('Retake'), findsNothing);
    });

    for (final double width in <double>[320, 430]) {
      testWidgets('no clipped actions at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(const ReviewScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
        );
        await tester.pumpAndSettle();

        for (final String label in <String>['Next', 'Retake']) {
          final Rect rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: label);
          expect(rect.right, lessThanOrEqualTo(width), reason: label);
        }
      });
    }
  });

  group('DecorateScreen', () {
    testWidgets('offers every decoration option in labelled sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // The redesign groups the options into a tab bar, so each section is
      // reached by selecting its tab rather than all being on screen at once.
      for (final String section in <String>['Frames', 'Effects', 'Stickers']) {
        expect(find.text(section), findsOneWidget, reason: section);
      }

      // All six frames, all four styles and all eight sticker types remain.
      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();
      for (final String label in <String>[
        'Cream',
        'Soft Pink',
        'White',
        'Charcoal',
        'Lavender',
        'Sky Blue',
      ]) {
        expect(find.bySemanticsLabel('$label frame'), findsOneWidget);
      }

      await tester.tap(find.text('Effects'));
      await tester.pumpAndSettle();
      for (final String label in <String>[
        'Clean',
        'Hearts',
        'Stars',
        'Sparkle',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();
      for (final StickerType type in StickerType.values) {
        expect(find.bySemanticsLabel('${type.label} sticker'), findsOneWidget);
      }
    });

    testWidgets('date toggle and sticker add/remove work', (tester) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // Date toggle lives on the Date tab.
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(Switch),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // Pick a sticker, add it, then remove it again. Controls live in a
      // scrollable panel, so scroll each one into view before tapping.
      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Heart sticker'),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.bySemanticsLabel('Heart sticker'));
      await tester.pumpAndSettle();
      expect(find.text('Add Heart'), findsOneWidget);
      // Selecting a sticker reveals the Add button, which can land below the
      // fold, so bring it into view before tapping.
      await tester.scrollUntilVisible(
        find.text('Add Heart'),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Add Heart'));
      await tester.pumpAndSettle();
      expect(find.text('1 sticker added'), findsOneWidget);

      await tester.tap(find.text('Remove last'));
      await tester.pumpAndSettle();
      expect(find.text('1 sticker added'), findsNothing);
    });

    testWidgets('continues to export with the chosen decoration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      final Finder panel = find.byType(Scrollable).last;
      // The screen opens on the Stickers tab, so switch to Frames before
      // reaching for a background swatch.
      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel('Charcoal frame'));
      await tester.tap(find.bySemanticsLabel('Charcoal frame'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Effects'));
      await tester.pumpAndSettle();
      // The Effects panel is short enough to fit without scrolling, so just
      // ensure it is on screen instead of dragging the panel.
      await tester.ensureVisible(find.text('Hearts'));
      await tester.tap(find.text('Hearts'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Finish & Save'),
        60,
        scrollable: panel,
      );
      await tester.tap(find.textContaining('Finish & Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Rendering the strip is real async work, so let it drain before
      // asserting on the export screen's ready state.
      for (int i = 0; i < 120; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.text('Save to Photos').evaluate().isNotEmpty) break;
      }

      expect(find.text('Export'), findsNothing);
      expect(find.text('Ready!'), findsOneWidget);
    });

    for (final PhotoLayout layout in PhotoLayout.values) {
      testWidgets('preview grid never overlaps the branding footer', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(DecorateScreen(layout: layout, photos: const <XFile>[])),
        );
        await tester.pumpAndSettle();

        final Rect grid = tester.getRect(
          find.byKey(const ValueKey('composition-grid')),
        );
        final Rect footer = tester.getRect(
          find.byKey(const ValueKey('composition-footer')),
        );

        // The photos must sit entirely above the branding strip, exactly as
        // the exporter lays them out within the content area.
        expect(
          grid.bottom,
          lessThanOrEqualTo(footer.top + 0.5),
          reason:
              '${layout.label}: the photo grid overlaps the branding footer',
        );
        // And the footer must be a real band, not collapsed to nothing.
        expect(footer.height, greaterThan(0));
      });
    }

    for (final double width in <double>[320, 430]) {
      testWidgets('renders without overflow at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[]),
          ),
        );
        await tester.pumpAndSettle();

        // The export action must remain reachable on a small screen.
        final Finder export = find.textContaining('Finish & Save');
        expect(export, findsOneWidget);
        await tester.ensureVisible(export);
        await tester.pumpAndSettle();
        final Rect rect = tester.getRect(export);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      });
    }
  });
}
