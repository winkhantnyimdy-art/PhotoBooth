import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Reads width/height straight out of the PNG IHDR chunk (bytes 16..24).
/// This asserts real output geometry without pixel/golden comparisons.
List<int> _pngSize(Uint8List bytes) {
  expect(
    bytes.take(8),
    orderedEquals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    reason: 'output must be a PNG',
  );
  final ByteData header = ByteData.sublistView(bytes);
  return <int>[header.getUint32(16), header.getUint32(20)];
}

void main() {
  final DecorationState cleanCream = const DecorationState(
    layout: PhotoLayout.cut4,
    background: BackgroundChoice.cream,
    style: DecorativeStyle.clean,
  );

  group('PhotoStripRenderer', () {
    late PhotoStripRenderer renderer;

    setUp(() {
      renderer = PhotoStripRenderer();
    });

    Future<Uint8List> renderWith(DecorationState state, {PhotoLayout? layout}) {
      return renderer.render(
        layout: layout ?? state.layout,
        photos: const <XFile>[],
        decorationState: state,
      );
    }

    test('export width is fixed regardless of layout', () async {
      final Uint8List cut4 = await renderWith(cleanCream);
      final Uint8List cut2 = await renderWith(
        cleanCream.copyWith(layout: PhotoLayout.cut2),
      );

      expect(PhotoStripRenderer.exportWidth, 1200.0);
      expect(_pngSize(cut4).first, 1200);
      expect(_pngSize(cut2).first, 1200);
    });

    test('4 CUT is taller than 2 CUT by the fixed footer', () async {
      final List<int> cut4 = _pngSize(await renderWith(cleanCream));
      final List<int> cut2 = _pngSize(
        await renderWith(cleanCream.copyWith(layout: PhotoLayout.cut2)),
      );

      final int footer = PhotoStripRenderer.footerHeight.round();
      expect(cut4[1] - footer, 2000);
      expect(cut2[1] - footer, 1200);
      expect(cut4[1], greaterThan(cut2[1]));
    });

    test('renders non-empty PNG bytes', () async {
      final Uint8List bytes = await renderWith(cleanCream);

      expect(bytes, isNotEmpty);
      expect(_pngSize(bytes), <int>[1200, 2150]);
    });

    test('identical inputs produce identical output', () async {
      final Uint8List first = await renderWith(cleanCream);
      final Uint8List second = await renderWith(cleanCream);

      expect(first, orderedEquals(second));
    });

    test('background choice changes the rendered output', () async {
      final Uint8List cream = await renderWith(cleanCream);
      final Uint8List charcoal = await renderWith(
        cleanCream.copyWith(background: BackgroundChoice.charcoal),
      );

      expect(cream, isNot(orderedEquals(charcoal)));
    });

    test('decorative style changes the rendered output', () async {
      final Uint8List clean = await renderWith(cleanCream);
      final Uint8List hearts = await renderWith(
        cleanCream.copyWith(style: DecorativeStyle.hearts),
      );

      expect(clean, isNot(orderedEquals(hearts)));
    });

    test('stickers change the rendered output', () async {
      final Uint8List bare = await renderWith(cleanCream);
      final Uint8List stickered = await renderWith(
        cleanCream.copyWith(
          stickers: const <StickerPlacement>[
            StickerPlacement(type: StickerType.heart, x: 0.5, y: 0.5),
            StickerPlacement(type: StickerType.smile, x: 0.2, y: 0.8),
          ],
        ),
      );

      expect(bare, isNot(orderedEquals(stickered)));
    });

    test('showDate adds branding content', () async {
      final Uint8List withoutDate = await renderWith(cleanCream);
      final Uint8List withDate = await renderWith(
        cleanCream.copyWith(
          showDate: true,
          dateOverride: DateTime(2024, 5, 17),
        ),
      );

      expect(withoutDate, isNot(orderedEquals(withDate)));
    });

    test('renders when fewer photos than grid cells are provided', () async {
      // cut4 expects four cells; two photos must not break the loop bounds.
      final Uint8List bytes = await renderer.render(
        layout: PhotoLayout.cut4,
        photos: const <XFile>[],
        decorationState: cleanCream,
      );

      expect(_pngSize(bytes), <int>[1200, 2150]);
    });

    test('rendered geometry is independent of the decoration style', () async {
      final List<int> clean = _pngSize(await renderWith(cleanCream));
      final List<int> sparkle = _pngSize(
        await renderWith(cleanCream.copyWith(style: DecorativeStyle.sparkle)),
      );

      expect(clean, sparkle);
    });
  });
}
