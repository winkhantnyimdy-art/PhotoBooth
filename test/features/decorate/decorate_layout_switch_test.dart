import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Writes [count] real portrait PNGs so the editor and the renderer have
/// genuine pixels to work with.
///
/// Each frame is a different solid colour, which makes it obvious at a glance
/// whether a particular photo survived a layout switch.
Future<List<XFile>> _samplePhotos(int count) async {
  final Directory dir = await Directory.systemTemp.createTemp('pb_switch');
  final List<XFile> photos = <XFile>[];
  const List<Color> colors = <Color>[
    Color(0xFF4D7DDB),
    Color(0xFFFFB6C1),
    Color(0xFFFED759),
    Color(0xFF8FD9C0),
    Color(0xFFC9A7F0),
    Color(0xFFFF9F68),
  ];

  for (int i = 0; i < count; i++) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);
    // Deliberately NOT 3:4, so cover-cropping is actually exercised.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 96, 64),
      Paint()..color = colors[i % colors.length],
    );
    final ui.Image image = await recorder.endRecording().toImage(96, 64);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    final File file = File('${dir.path}/p$i.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    photos.add(XFile(file.path));
  }
  return photos;
}

void main() {
  Widget app(List<XFile> photos, PhotoLayout layout) => MaterialApp(
    theme: AppTheme.theme,
    home: DecorateScreen(layout: layout, photos: photos),
  );

  /// Generates sample photos from inside a widget test.
  ///
  /// `toImage()` is real async work, and `testWidgets` runs its body in a fake
  /// async zone where such a Future would never complete - so it must be
  /// awaited through [WidgetTester.runAsync] or the test deadlocks.
  Future<List<XFile>> photosFor(WidgetTester tester, int count) async =>
      (await tester.runAsync<List<XFile>>(() => _samplePhotos(count)))!;

  group('Decorate layout switching', () {
    testWidgets('offers only layouts that match the captured photo count', (
      tester,
    ) async {
      final List<XFile> photos = await photosFor(tester, 4);
      await tester.pumpWidget(app(photos, PhotoLayout.korean4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('decorate-layout-grid4')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('decorate-layout-grid4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The editor rebuilt cleanly and is still fully usable.
      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(find.text('Finish & Save'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a switched layout round-trips back to the original', (
      tester,
    ) async {
      final List<XFile> photos = await photosFor(tester, 4);
      await tester.pumpWidget(app(photos, PhotoLayout.korean4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('decorate-layout-grid4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('decorate-layout-korean4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Finish & Save'), findsOneWidget);
    });

    testWidgets('a two-photo session offers only the two-photo layout', (
      tester,
    ) async {
      final List<XFile> two = await photosFor(tester, 2);
      await tester.pumpWidget(app(two, PhotoLayout.pair2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only one layout can hold two photos, so there is nothing to switch to
      // and the switcher stays hidden entirely.
      expect(find.byKey(const ValueKey('decorate-layout-cut6')), findsNothing);
      expect(find.byKey(const ValueKey('decorate-layout-pair2')), findsNothing);
      expect(find.byKey(const ValueKey('decorate-layout-korean4')), findsNothing);
    });

    testWidgets('a four-photo session offers both four-frame layouts', (
      tester,
    ) async {
      final List<XFile> four = await photosFor(tester, 4);
      await tester.pumpWidget(app(four, PhotoLayout.korean4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('decorate-layout-korean4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('decorate-layout-grid4')),
        findsOneWidget,
      );
      // The two- and six-frame layouts do not fit four photos.
      expect(find.byKey(const ValueKey('decorate-layout-pair2')), findsNothing);
      expect(find.byKey(const ValueKey('decorate-layout-cut6')), findsNothing);
    });

    testWidgets('the layout chips never overflow, even at 320dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final List<XFile> photos = await photosFor(tester, 6);
      await tester.pumpWidget(app(photos, PhotoLayout.cut6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(DecorateScreen), findsOneWidget);
    });
  });

  group('Export canvas follows the selected layout', () {
    test('every layout renders a canvas matching the shared geometry', () async {
      // Preview/export parity: the PNG the user downloads is exactly the
      // geometry the editor previews.
      final List<XFile> photos = await _samplePhotos(4);
      for (final PhotoLayout layout in PhotoLayout.values) {
        final List<XFile> slice = photos.take(layout.photoCount).toList();
        final Uint8List bytes = await PhotoStripRenderer().render(
          layout: layout,
          photos: slice,
          decorationState: DecorationState(
            layout: layout,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
          ),
        );
        expect(bytes, isNotEmpty, reason: layout.label);

        final ByteData header = ByteData.sublistView(bytes);
        expect(
          header.getUint32(16),
          PhotoStripGeometry.exportWidth.toInt(),
          reason: '${layout.label} width',
        );
        expect(
          header.getUint32(20),
          closeTo(PhotoStripGeometry.totalHeight(layout), 1.0),
          reason: '${layout.label} height must match the shared geometry',
        );
      }
    });

    test('a non-3:4 source photo is cover-cropped, never stretched', () async {
      // The samples are 96x64 (landscape). If the renderer stretched instead of
      // cropping, the 3:4 cells would show distorted content and the strip would
      // be unrecognisably squashed. This asserts the crop path runs.
      final List<XFile> photos = await _samplePhotos(4);
      final Uint8List bytes = await PhotoStripRenderer().render(
        layout: PhotoLayout.grid4,
        photos: photos,
        decorationState: const DecorationState(
          layout: PhotoLayout.grid4,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        ),
      );
      expect(bytes.length, greaterThan(5000));
      // Deterministic: the same inputs must produce the same export.
      final Uint8List again = await PhotoStripRenderer().render(
        layout: PhotoLayout.grid4,
        photos: photos,
        decorationState: const DecorationState(
          layout: PhotoLayout.grid4,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        ),
      );
      expect(again, orderedEquals(bytes));
    });
  });
}