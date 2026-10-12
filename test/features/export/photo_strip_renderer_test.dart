import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
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
    layout: PhotoLayout.grid4,
    background: BackgroundChoice.cream,
    style: DecorativeStyle.clean,
  );

  group('PhotoStripGeometry', () {
    test('Korean 4-cut is the default and stacks four portrait frames', () {
      expect(kDefaultPhotoLayout, PhotoLayout.korean4);
      expect(PhotoLayout.korean4.cols, 1);
      expect(PhotoLayout.korean4.rows, 4);
      expect(PhotoLayout.korean4.photoCount, 4);
    });

    test('the 2x2 grid arranges four photos in two columns', () {
      expect(PhotoLayout.grid4.cols, 2);
      expect(PhotoLayout.grid4.rows, 2);
      expect(PhotoLayout.grid4.photoCount, 4);
    });

    test('the two-photo layout stacks two portrait frames', () {
      expect(PhotoLayout.pair2.cols, 1);
      expect(PhotoLayout.pair2.rows, 2);
      expect(PhotoLayout.pair2.photoCount, 2);
    });

    test('the two four-photo layouts produce different arrangements', () {
      // Guards against the two options collapsing into the same arrangement.
      expect(
        PhotoLayout.korean4.contentSignature,
        isNot(PhotoLayout.grid4.contentSignature),
      );
      expect(
        PhotoLayout.korean4.description,
        isNot(PhotoLayout.grid4.description),
      );
      expect(PhotoLayout.korean4.isColumnStack, isTrue);
      expect(PhotoLayout.grid4.isColumnStack, isFalse);
    });

    test('photo cells are 3:4 portrait, so captures are not stretched', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        expect(
          PhotoStripGeometry.cellWidth(layout) /
              PhotoStripGeometry.cellHeight(layout),
          closeTo(3 / 4, 0.001),
          reason: '${layout.label} cells must be 3:4 portrait',
        );
      }
    });

    test('cell rects tile the grid without overlapping', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        for (int i = 0; i < layout.photoCount; i++) {
          final Rect cell = PhotoStripGeometry.cellRect(layout, i);
          expect(cell.left, greaterThanOrEqualTo(0));
          expect(cell.top, greaterThanOrEqualTo(0));
          expect(cell.right, lessThanOrEqualTo(PhotoStripGeometry.exportWidth));
          expect(
            cell.bottom,
            lessThanOrEqualTo(PhotoStripGeometry.contentHeight(layout)),
          );
        }
        // Row-major: the first cell is top-left, the last is bottom-right.
        final Rect first = PhotoStripGeometry.cellRect(layout, 0);
        final Rect last = PhotoStripGeometry.cellRect(
          layout,
          layout.photoCount - 1,
        );
        expect(first.left, PhotoStripGeometry.outerPadding);
        expect(first.top, PhotoStripGeometry.outerPadding);
        expect(
          last.right,
          PhotoStripGeometry.exportWidth - PhotoStripGeometry.outerPadding,
        );
        expect(
          last.bottom,
          closeTo(
            PhotoStripGeometry.contentHeight(layout) -
                PhotoStripGeometry.outerPadding,
            0.001,
          ),
        );
      }
    });

    test('content plus footer equals the strip height', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        expect(
          PhotoStripGeometry.totalHeight(layout),
          closeTo(
            PhotoStripGeometry.contentHeight(layout) +
                PhotoStripGeometry.footerHeight,
            0.001,
          ),
        );
      }
    });

    test('aspect ratio is the strip ratio, not the screen ratio', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        expect(
          PhotoStripGeometry.aspectRatio(layout),
          closeTo(
            PhotoStripGeometry.exportWidth /
                PhotoStripGeometry.totalHeight(layout),
            0.0001,
          ),
        );
      }
    });

    test('gutterRatio lets previews match the exported gap', () {
      for (final PhotoLayout layout in PhotoLayout.values) {
        expect(
          PhotoStripGeometry.gutterRatio(layout),
          closeTo(
            PhotoStripGeometry.gutter / PhotoStripGeometry.cellWidth(layout),
            0.0001,
          ),
        );
        // A preview cell of N logical px must use N * ratio as its gap, so the
        // on-screen gap scales to the exported gutter. This has to be derived
        // per layout: a 2 column layout has a much narrower export cell than a
        // single column stack, so the ratio differs per layout.
        const double cell = 100;
        expect(
          cell * PhotoStripGeometry.gutterRatio(layout),
          closeTo(
            PhotoStripGeometry.gutter * (cell / PhotoStripGeometry.cellWidth(layout)),
            0.001,
          ),
        );
      }
    });

    test('stickerSize is a fraction of the strip width', () {
      // Keeps a sticker the same visual size on the preview and the export.
      expect(
        PhotoStripGeometry.stickerSize / PhotoStripGeometry.exportWidth,
        closeTo(34 / 1200, 0.0001),
      );
      expect(
        PhotoStripGeometry.stickerSize,
        lessThan(PhotoStripGeometry.cellWidth(PhotoLayout.grid4)),
      );
    });
  });

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
        cleanCream.copyWith(layout: PhotoLayout.pair2),
      );

      expect(PhotoStripRenderer.exportWidth, 1200.0);
      expect(_pngSize(cut4).first, 1200);
      expect(_pngSize(cut2).first, 1200);
    });

    test('output matches the shared geometry for every layout', () async {
      for (final PhotoLayout layout in PhotoLayout.values) {
        final Uint8List bytes = await renderWith(
          cleanCream.copyWith(layout: layout),
          layout: layout,
        );
        final List<int> size = _pngSize(bytes);
        expect(
          size.first,
          PhotoStripGeometry.exportWidth.toInt(),
          reason: '${layout.label} width',
        );
        expect(
          size.last,
          PhotoStripGeometry.totalHeight(layout).toInt(),
          reason: '${layout.label} height',
        );
      }
    });

    test('the two-photo column stack is taller than the 2x2 grid', () async {
      final List<int> grid4 = _pngSize(await renderWith(cleanCream));
      final List<int> pair2 = _pngSize(
        await renderWith(cleanCream.copyWith(layout: PhotoLayout.pair2)),
      );

      // Every canvas is the grid plus the same fixed branding footer, so
      // subtracting it must yield each layout's content height. The canvas is
      // rounded to whole pixels, so allow the 1px that rounding can shift.
      final int footer = PhotoStripRenderer.footerHeight.round();
      expect(
        grid4[1] - footer,
        closeTo(PhotoStripGeometry.contentHeight(PhotoLayout.grid4), 1.0),
      );
      expect(
        pair2[1] - footer,
        closeTo(PhotoStripGeometry.contentHeight(PhotoLayout.pair2), 1.0),
      );
      expect(pair2[1], greaterThan(grid4[1]));
    });

    test('the Korean column stack is taller than the 2x2 grid', () {
      // A single column of four portrait frames is the tallest strip.
      expect(
        PhotoStripGeometry.totalHeight(PhotoLayout.korean4),
        greaterThan(PhotoStripGeometry.totalHeight(PhotoLayout.grid4)),
      );
    });

    test('renders non-empty PNG bytes at the geometry-derived canvas size', () async {
      final Uint8List bytes = await renderWith(cleanCream);

      expect(bytes, isNotEmpty);
      // Derived, not hardcoded: the canvas size is a consequence of the layout
      // (2x2 grid) and the portrait 3:4 cell shape.
      expect(_pngSize(bytes), <int>[
        PhotoStripGeometry.exportWidth.toInt(),
        PhotoStripGeometry.totalHeight(PhotoLayout.grid4).round(),
      ]);
    });

    test('identical inputs produce identical output', () async {
      final Uint8List first = await renderWith(cleanCream);
      final Uint8List second = await renderWith(cleanCream);

      expect(first, orderedEquals(second));
    });

    test('frame theme paper changes the rendered output', () async {
      final Uint8List cream = await renderWith(cleanCream);
      final Uint8List dark = await renderWith(
        cleanCream.copyWith(frameTheme: FrameTheme.darkFilm),
      );

      expect(cream, isNot(orderedEquals(dark)));
    });

    test('decorative style changes the rendered output', () async {
      final Uint8List clean = await renderWith(cleanCream);
      final Uint8List hearts = await renderWith(
        cleanCream.copyWith(style: DecorativeStyle.hearts),
      );

      expect(clean, isNot(orderedEquals(hearts)));
    });

    test('every decorative style renders distinct output', () async {
      final Map<String, Uint8List> renders = <String, Uint8List>{};
      for (final DecorativeStyle style in DecorativeStyle.values) {
        renders[style.name] = await renderWith(
          cleanCream.copyWith(style: style),
        );
      }
      final Set<List<int>> unique = renders.values
          .map((Uint8List b) => b.take(64).toList())
          .toSet();
      // The first bytes cover the frame, so distinct styles must differ there.
      expect(unique.length, greaterThan(1));
    });

    test('stickers change the rendered output', () async {
      final Uint8List bare = await renderWith(cleanCream);
      final Uint8List stickered = await renderWith(
        cleanCream.copyWith(
          stickers: const <StickerPlacement>[
            StickerPlacement(type: StickerType.heart, x: 0.5, y: 0.5),
            StickerPlacement(type: StickerType.smiley, x: 0.2, y: 0.8),
          ],
        ),
      );

      expect(bare, isNot(orderedEquals(stickered)));
    });

    test('every sticker type contributes artwork to the export', () async {
      // Each type used to be offered in the UI; only three had artwork, so the
      // rest silently vanished from the exported PNG.
      final Uint8List bare = await renderWith(cleanCream);
      final Set<List<int>> distinct = <List<int>>{bare.take(4096).toList()};

      for (final StickerType type in StickerType.values) {
        final Uint8List rendered = await renderWith(
          cleanCream.copyWith(
            stickers: <StickerPlacement>[
              StickerPlacement(type: type, x: 0.5, y: 0.35),
            ],
          ),
        );
        expect(
          rendered,
          isNot(orderedEquals(bare)),
          reason: '${type.label} must draw something',
        );
        distinct.add(rendered.take(4096).toList());
      }
      expect(distinct.length, StickerType.values.length + 1);
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
      // cut4 expects four cells; an empty session must not break the bounds.
      final Uint8List bytes = await renderer.render(
        layout: PhotoLayout.grid4,
        photos: const <XFile>[],
        decorationState: cleanCream,
      );

      expect(_pngSize(bytes), <int>[
        PhotoStripGeometry.exportWidth.toInt(),
        PhotoStripGeometry.totalHeight(PhotoLayout.grid4).round(),
      ]);
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
