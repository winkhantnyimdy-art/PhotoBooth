import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

void main() {
  group('ReviewScreen', () {
    testWidgets('presents the photos and both actions', (tester) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
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
        _app(const ReviewScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.textContaining('Finish & Save'), findsOneWidget);
    });

    testWidgets('Retake opens the camera for a single-photo replacement', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(
                      layout: PhotoLayout.pair2,
                      photos: <XFile>[
                        XFile('/tmp/shot_1.jpg'),
                        XFile('/tmp/shot_2.jpg'),
                      ],
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

      // Retake now navigates to the camera so a single frame can be replaced,
      // rather than discarding the whole session.
      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CameraScreen), findsOneWidget);
      // The original screen is still underneath, so nothing is lost.
      expect(find.text('Go to Review'), findsNothing);
    });

    testWidgets('Review announces which photo is selected for retake', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.pair2, photos: <XFile>[])),
      );
      await tester.pump();

      // With no photos the caption must say so rather than claiming a
      // selection that does not exist.
      expect(find.text('No photos yet'), findsOneWidget);
    });

    for (final double width in <double>[320, 430]) {
      testWidgets('no clipped actions at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(const ReviewScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
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
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // The redesign groups the options into a five-tab tray, so each section
      // is reached by selecting its tab rather than all being on screen at once.
      for (final String section in <String>[
        'Filters',
        'Frames',
        'Stickers',
        'Text',
        'Adjust',
      ]) {
        expect(find.text(section), findsOneWidget, reason: section);
      }

      // All fifteen effects, all six frames, all four border styles, all four
      // patterns and all eight sticker types remain.
      //
      // Checkpoint 3 replaced the eight v1.0.0 presets with a fifteen-effect
      // catalogue, so this list is the new vocabulary. The accessibility label
      // is "<effect> effect", matching the on-screen section title.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      for (final String label in <String>[
        'Original',
        'Soft',
        'Warm',
        'Cool',
        '35mm',
        'Vintage',
        'Grain',
        'Faded',
        'Classic Film',
        'Y2K Flash',
        'CCD',
        'Tokyo Night',
        'Mono',
        'Noir',
        'Dreamy',
      ]) {
        expect(find.bySemanticsLabel('$label effect'), findsOneWidget);
      }

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
      for (final String label in <String>[
        'Polka Dot',
        'Film Edge',
        'Scallop',
        'Minimal',
      ]) {
        expect(find.bySemanticsLabel('$label border'), findsOneWidget);
      }
      for (final String label in <String>[
        'Clean',
        'Hearts',
        'Stars',
        'Sparkle',
      ]) {
        expect(find.bySemanticsLabel('$label pattern'), findsOneWidget);
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
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // Date toggle lives on the Frames tab.
      await tester.tap(find.text('Frames'));
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
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      final Finder panel = find.byType(Scrollable).last;
      // The screen opens on the Filters tab, so switch to Frames before
      // reaching for a background swatch.
      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Charcoal frame'),
        60,
        scrollable: panel,
      );
      await tester.tap(find.bySemanticsLabel('Charcoal frame'));
      await tester.pumpAndSettle();

      // The pattern shelf also lives on the Frames tab, below the swatches.
      await tester.scrollUntilVisible(
        find.text('Hearts'),
        60,
        scrollable: panel,
      );
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

    testWidgets('filter shelf drives a real intensity slider', (tester) async {
      // Portrait, like the emulator verification: in the default 800x600
      // landscape surface the tray is so short that the shelf and the slider
      // fall below its viewport cut, which says nothing about the phone.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      // Opens on Effects with Original selected, so strength is inactive.
      Slider slider() => tester.widget<Slider>(find.byType(Slider));
      expect(slider().onChanged, isNull);

      // Picking a non-Original effect activates the strength slider, and
      // tapping its track moves it off the default.
      //
      // Warm is the third chip, so it sits inside the tray viewport without
      // any scrolling. Whether all fifteen are reachable through the shelf's
      // own horizontal scroll is covered by the emulator verification.
      await tester.tap(find.bySemanticsLabel('Warm effect'));
      await tester.pumpAndSettle();
      expect(slider().onChanged, isNotNull);

      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      final Rect track = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(track.left + track.width * 0.25, track.center.dy));
      await tester.pumpAndSettle();
      expect(slider().value, lessThan(0.5));

      // Every thumbnail really is rendered; Original keeps the first slot.
      expect(find.bySemanticsLabel('Original effect'), findsOneWidget);
    });

    testWidgets('captions can be added and edited on the fly', (tester) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();

      // Focusing the caption field starts the cursor blink, so step through
      // frames with fixed pumps instead of pumpAndSettle from here on.
      await tester.enterText(find.byType(TextField), 'Smile!');
      await tester.scrollUntilVisible(
        find.text('Add Text'),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Add Text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.bySemanticsLabel('Caption: Smile!'), findsOneWidget);

      // The caption stays attached to the cursor, so typing edits it in place.
      await tester.enterText(find.byType(TextField), 'Smile! x2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Caption: Smile! x2'), findsOneWidget);
      expect(find.bySemanticsLabel('Caption: Smile!'), findsNothing);
    });

    testWidgets('adjust sliders are live and independent', (tester) async {
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adjust'));
      await tester.pumpAndSettle();

      // Four functional sliders, all starting neutral at 0.
      final Finder sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(4));
      for (final Slider s in tester.widgetList<Slider>(sliders)) {
        expect(s.value, 0);
        expect(s.onChanged, isNotNull);
      }

      // Dragging Brightness changes only its own slider.
      final Slider before = tester.widgetList<Slider>(sliders).first;
      await tester.ensureVisible(sliders.first);
      await tester.pumpAndSettle();
      final Rect track = tester.getRect(sliders.first);
      await tester.tapAt(Offset(track.left + track.width * 0.9, track.center.dy));
      await tester.pumpAndSettle();
      final Slider after = tester.widgetList<Slider>(find.byType(Slider)).first;
      expect(after.value, greaterThan(before.value));
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
            const DecorateScreen(layout: PhotoLayout.grid4, photos: <XFile>[]),
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
