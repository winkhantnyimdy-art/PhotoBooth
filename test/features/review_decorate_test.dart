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

      expect(find.text('Looking good!'), findsOneWidget);
      expect(find.text('Continue to Decorate'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      // A clear next step toward decoration.
      expect(
        find.text('Next: add a frame, style and stickers'),
        findsOneWidget,
      );
    });

    testWidgets('Continue navigates to the decoration studio', (tester) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue to Decorate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.text('Preview & Export'), findsOneWidget);
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

        for (final String label in <String>['Continue to Decorate', 'Retake']) {
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

      for (final String section in <String>['FRAME', 'STYLE', 'STICKERS']) {
        expect(find.text(section), findsOneWidget, reason: section);
      }

      // All six frames, all four styles and all eight sticker types remain.
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
      for (final String label in <String>[
        'Clean',
        'Hearts',
        'Stars',
        'Sparkle',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final StickerType type in StickerType.values) {
        expect(find.bySemanticsLabel('${type.label} sticker'), findsOneWidget);
      }
    });

    testWidgets('date toggle and sticker add/remove work', (tester) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // Date toggle.
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
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Heart sticker'),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.bySemanticsLabel('Heart sticker'));
      await tester.pumpAndSettle();
      expect(find.text('Add Heart'), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Charcoal frame'),
        60,
        scrollable: panel,
      );
      await tester.tap(find.bySemanticsLabel('Charcoal frame'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Hearts'),
        60,
        scrollable: panel,
      );
      await tester.tap(find.text('Hearts'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Preview & Export'),
        60,
        scrollable: panel,
      );
      await tester.tap(find.text('Preview & Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Export'), findsNothing);
      expect(find.text('Your photos'), findsOneWidget);
    });

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
        final Finder export = find.text('Preview & Export');
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
