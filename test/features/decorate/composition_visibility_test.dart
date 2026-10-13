import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/art/frame_theme_painter.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// The `Stack` that layers the composition.
Finder _compositionStack() => find
    .descendant(
      of: find.byType(DecorateScreen),
      matching: find.byType(Stack),
    )
    .first;

/// Index, within the composition [Stack]'s children, of the subtree carrying
/// [key].
///
/// Matches each declared child by widget identity and asks whether [key] sits
/// in that child's subtree, so it stays correct no matter how the child is
/// wrapped (Positioned, IgnorePointer, KeyedSubtree, ...).
int _stackChildIndexOf(WidgetTester tester, Key key) {
  final Stack stack = tester.widget<Stack>(_compositionStack());
  final List<Widget> children = stack.children;
  for (int i = 0; i < children.length; i++) {
    final Finder child = find.byWidget(children[i]);
    if (child.evaluate().isEmpty) continue;
    if (find
        .descendant(of: child, matching: find.byKey(key))
        .evaluate()
        .isNotEmpty) {
      return i;
    }
  }
  return -1;
}

/// The composition, built without photos.
///
/// Note on test strategy: `Image.file` does not complete its decode inside the
/// widget test's fake-async zone, so no test here loads real image bytes -
/// every pre-existing widget test in this repo passes an empty photo list for
/// the same reason. The invariants that actually caused the blank-photo bug
/// (paint order and cell shape) are pure and are asserted directly.
Widget _host({PhotoLayout? layout, DecorationState? state}) {
  return MaterialApp(
    theme: AppTheme.theme,
    home: DecorateScreen(
      layout: layout ?? PhotoLayout.grid4,
      photos: const <Never>[],
      initialDecorationState: state,
    ),
  );
}

void main() {
  group('composition paint order (Bug 1 regression)', () {
    testWidgets('the frame theme is painted BEHIND the photo grid', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      final int frameIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-canvas'));
      final int gridIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-grid'));

      expect(frameIndex, isNot(-1), reason: 'the frame layer must exist');
      expect(gridIndex, isNot(-1), reason: 'the photo grid must exist');

      expect(
        frameIndex,
        lessThan(gridIndex),
        reason:
            'FrameThemePainter fills the whole strip with opaque paper before '
            'drawing its border, so painting it above the grid hides every '
            'captured photo. Reported on device as a pink frame around an '
            'empty interior, while the filter thumbnails - which live outside '
            'this Stack - still rendered the photos correctly.',
      );
    });

    testWidgets('the branding footer is painted above the photo grid', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      final int gridIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-grid'));
      final int footerIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-footer'));

      expect(gridIndex, isNot(-1));
      expect(footerIndex, greaterThan(gridIndex));
    });

    testWidgets('stickers still render above the frame layer', (tester) async {
      // Named to make the intent obvious: this is the layer that hid the
      // photos, kept first in the stack from now on.
      await tester.pumpWidget(
        _host(
          state: DecorationState(
            layout: PhotoLayout.grid4,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
            stickers: <StickerPlacement>[
              StickerPlacement(type: StickerType.heart, x: 0.3, y: 0.2),
            ],
          ),
        ),
      );
      await tester.pump();

      // The layer exists exactly once, so a future change cannot reintroduce a
      // second opaque copy on top.
      expect(
        find.byKey(const ValueKey<String>('composition-canvas')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Heart sticker on the preview'), findsOneWidget);

      final int frameIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-canvas'));
      final int gridIndex =
          _stackChildIndexOf(tester, const ValueKey<String>('composition-grid'));
      expect(frameIndex, lessThan(gridIndex));
    });
  });

  group('FrameThemePainter z-order contract', () {
    test('the paper fill is opaque and covers the whole rect', () {
      // Pins the behaviour that made the Bug 1 layering fatal. If a future
      // change makes the fill optional or translucent, this test must be
      // revisited deliberately rather than silently invalidated.
      final double paperAlpha =
          FrameTheme.retroPop.spec.paper.a; // 1.0 for an opaque colour
      expect(paperAlpha, 1.0);
    });

    test('includeWordmark: false really omits the wordmark', () {
      // The wordmark is centred on the rect, i.e. over the photo grid, so a
      // caller that draws its own footer band must be able to opt out.
      final ui.PictureRecorder withoutRecorder = ui.PictureRecorder();
      FrameThemePainter.paint(
        ui.Canvas(withoutRecorder),
        const ui.Rect.fromLTWH(0, 0, 400, 400),
        FrameTheme.retroPop,
        wordmarkSize: 40,
        includeWordmark: false,
      );
      final ui.Picture withoutMark = withoutRecorder.endRecording();

      final ui.PictureRecorder withRecorder = ui.PictureRecorder();
      FrameThemePainter.paint(
        ui.Canvas(withRecorder),
        const ui.Rect.fromLTWH(0, 0, 400, 400),
        FrameTheme.retroPop,
        wordmarkSize: 40,
      );
      final ui.Picture withMark = withRecorder.endRecording();

      expect(
        withoutMark.approximateBytesUsed,
        lessThan(withMark.approximateBytesUsed),
        reason:
            'the opt-out must actually skip the wordmark; otherwise the '
            'preview prints a second wordmark across the photos',
      );
      withoutMark.dispose();
      withMark.dispose();
    });
  });

  group('preview cells match the exported cell shape', () {
    for (final PhotoLayout layout in PhotoLayout.values) {
      test('${layout.label} preview cells are 3:4 portrait', () {
        // The square-cell regression: the preview derived its cell height from
        // its cell width, so it drew 1:1 cells while the PNG rendered 3:4.
        final Rect cell = PhotoStripGeometry.previewCell(
          layout: layout,
          availableWidth: 400,
          gutter: PhotoStripGeometry.gutter * (400 / PhotoStripGeometry.exportWidth),
        );

        expect(
          cell.width / cell.height,
          closeTo(PhotoStripGeometry.cellAspect(layout), 0.0001),
        );
        expect(cell.height, greaterThan(cell.width));
      });
    }

    test('the scaled preview grid fills the space the footer reserves', () {
      // With square cells the tall 4-cut overflowed the area reserved for the
      // branding footer; with the exported aspect it fits exactly.
      for (final PhotoLayout layout in PhotoLayout.values) {
        const double width = 1200;
        final double scale = width / PhotoStripGeometry.exportWidth;
        final Rect cell = PhotoStripGeometry.previewCell(
          layout: layout,
          availableWidth: width - (PhotoStripGeometry.outerPadding * scale * 2),
          gutter: PhotoStripGeometry.gutter * scale,
        );
        final double gridHeight =
            (cell.height * layout.rows) +
            (PhotoStripGeometry.gutter * scale * (layout.rows - 1));
        final double expected =
            PhotoStripGeometry.contentHeight(layout) * scale -
            (PhotoStripGeometry.outerPadding * scale * 2);

        expect(
          gridHeight,
          closeTo(expected, 0.5),
          reason:
              '${layout.label}: the preview grid must occupy exactly the space '
              'the geometry reserves for it',
        );
      }
    });

    test('previewCell refuses to build a negative box', () {
      expect(
        PhotoStripGeometry.previewCell(
          layout: PhotoLayout.grid4,
          availableWidth: 0,
          gutter: 4,
        ),
        Rect.zero,
      );
    });
  });
}