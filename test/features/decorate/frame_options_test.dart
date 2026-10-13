import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/art/frame_decorations.dart';
import 'package:photo_booth/core/art/frame_theme_painter.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Encodes a solid-colour PNG.
///
/// Encoding an image needs real async engine work, which deadlocks inside a
/// `testWidgets` fake-async zone. Every test in this file therefore lives in a
/// plain `test()` body, which has a real async zone.
Future<Uint8List> solidPng(Color color, {int size = 16}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = color,
  );
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Writes [count] solid-colour photo files and returns handles to them.
Future<(Directory, List<XFile>)> solidPhotoFiles(int count, Color color) async {
  final Directory dir = Directory.systemTemp.createTempSync('frame_opts');
  final List<XFile> photos = <XFile>[];
  final Uint8List png = await solidPng(color);
  for (int i = 0; i < count; i++) {
    final File file = File('${dir.path}/shot_$i.png');
    await file.writeAsBytes(png, flush: true);
    photos.add(XFile(file.path));
  }
  return (dir, photos);
}

void disposeDir(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } on Object {
    // Best effort.
  }
}

/// Decodes PNG bytes into a mutable RGBA buffer plus its size.
Future<({Uint8List px, int width, int height})> decodeRgba(Uint8List png) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(png);
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? raw =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final int width = frame.image.width;
  final int height = frame.image.height;
  frame.image.dispose();
  codec.dispose();
  return (px: raw!.buffer.asUint8List(), width: width, height: height);
}

/// Rasterises [paint] onto a transparent canvas and returns its pixels.
Future<({Uint8List px, int width, int height})> rasterise(
  void Function(ui.Canvas canvas, ui.Rect rect) paint, {
  int size = 200,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder), ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(size, size);
  picture.dispose();
  final ByteData? raw =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final Uint8List px = raw!.buffer.asUint8List();
  image.dispose();
  return (px: px, width: size, height: size);
}

bool _opaqueWhite(Uint8List px, int width, int x, int y) {
  final int i = ((y * width) + x) * 4;
  return px[i] > 220 && px[i + 1] > 220 && px[i + 2] > 220 && px[i + 3] > 200;
}

/// 8-bit channel of [color], matching what `toByteData` hands back.
int _channel(Color color, int index) {
  final List<double> v = <double>[color.r, color.g, color.b];
  return (v[index] * 255).round();
}

void main() {
  group('problem 2 - polka dots must stay on the rail, not the photos', () {
    test('the rail keeps the middle of the canvas transparent', () async {
      // Before the clip, `paintPolkaDotFrame` looped x/y across the whole
      // inner rectangle, so a dense field of white dots was drawn over
      // everything beneath. In Review it is a foreground painter over the
      // photos, which buried them completely.
      final ({Uint8List px, int width, int height}) frame =
          await rasterise(
        (ui.Canvas canvas, ui.Rect rect) =>
            FrameDecorations.paintPolkaDotFrame(canvas, rect),
      );

      // Scan the interior densely rather than probing two points: the dots sit
      // on a 20px lattice, so single samples can land in the gaps and pass by
      // accident even with the clip removed.
      final List<Offset> leaks = <Offset>[];
      for (int y = 20; y < 180; y++) {
        for (int x = 20; x < 180; x++) {
          if (_opaqueWhite(frame.px, frame.width, x, y)) {
            leaks.add(Offset(x.toDouble(), y.toDouble()));
          }
        }
      }

      expect(
        leaks,
        isEmpty,
        reason:
            'nothing may be painted well inside the border - the photos sit '
            'there. Found ${leaks.length} painted pixels, first at '
            '${leaks.isEmpty ? 'n/a' : leaks.first}',
      );
    });

    test('the dots are still drawn on the border rail', () async {
      // Confines the change: decoration is kept, it is only relocated.
      final ({Uint8List px, int width, int height}) frame =
          await rasterise(
        (ui.Canvas canvas, ui.Rect rect) =>
            FrameDecorations.paintPolkaDotFrame(canvas, rect),
      );

      int dotsOnRail = 0;
      for (int y = 1; y < frame.height; y++) {
        for (int x = 1; x < 8; x++) {
          if (_opaqueWhite(frame.px, frame.width, x, y)) dotsOnRail++;
        }
      }
      expect(
        dotsOnRail,
        greaterThan(0),
        reason: 'the decorative dots must remain visible on the rail',
      );
    });

    test('no dot is drawn beyond the border band', () async {
      // Belt and braces: sample a band just inside the rail and require it to
      // stay clear, so widening the rail cannot silently creep inward.
      final ({Uint8List px, int width, int height}) frame =
          await rasterise(
        (ui.Canvas canvas, ui.Rect rect) => FrameDecorations.paintPolkaDotFrame(
          canvas,
          rect,
          borderWidth: 12,
          dotSpacing: 20,
          dotRadius: 4,
        ),
      );

      // 20px in is well past a 12px rail.
      for (int y = 20; y < 180; y += 7) {
        for (int x = 20; x < 180; x += 7) {
          expect(
            _opaqueWhite(frame.px, frame.width, x, y),
            isFalse,
            reason: 'no white dot may appear at ($x, $y), inside the rail',
          );
        }
      }
    });
  });

  group('problem 4 - the border and paper controls were never drawn', () {
    test('every border style produces different artwork', () async {
      // `FrameDecorations.paintFrame` had no call sites anywhere in lib/, so
      // tapping Polka Dot / Film Edge / Scallop / Minimal changed the state and
      // the selected pill but nothing on screen. Each style must now draw.
      final Set<String> rendered = <String>{};

      for (final FrameStyle style in FrameStyle.values) {
        final ({Uint8List px, int width, int height}) frame =
            await rasterise(
          (ui.Canvas canvas, ui.Rect rect) =>
              FrameDecorations.paintFrame(canvas, rect, style),
        );
        // A crude but effective fingerprint: how many pixels differ from
        // fully transparent.
        int painted = 0;
        for (int i = 3; i < frame.px.length; i += 4) {
          if (frame.px[i] > 0) painted++;
        }
        expect(
          painted,
          greaterThan(0),
          reason: '${style.label} must actually draw something',
        );
        rendered.add('$painted');
      }

      expect(
        rendered.length,
        greaterThan(1),
        reason:
            'the styles must be visually distinct, otherwise picking one looks '
            'like nothing happened',
      );
    });

    test('the chosen paper colour overrides the theme paper', () async {
      const Color chosen = Color(0xFFF2ECFF); // Lavender
      final ({Uint8List px, int width, int height}) frame = await rasterise(
        (ui.Canvas canvas, ui.Rect rect) => FrameThemePainter.paint(
          canvas,
          rect,
          FrameTheme.retroPop,
          paper: chosen,
        ),
      );

      // Sample a point that is pure paper: inside the border, clear of the
      // photo area and away from the wordmark.
      final int i = ((30 * frame.width) + 30) * 4;
      expect(
        frame.px[i],
        _channel(chosen, 0),
        reason: 'the paper swatch must reach the rendered frame',
      );
      expect(frame.px[i + 1], _channel(chosen, 1));
      expect(frame.px[i + 2], _channel(chosen, 2));
    });

    test('a null paper keeps the theme default', () async {
      final ({Uint8List px, int width, int height}) frame = await rasterise(
        (ui.Canvas canvas, ui.Rect rect) =>
            FrameThemePainter.paint(canvas, rect, FrameTheme.retroPop),
      );
      final int i = ((30 * frame.width) + 30) * 4;
      expect(
        frame.px[i],
        _channel(FrameTheme.retroPop.spec.paper, 0),
        reason: 'omitting paper must not change the theme identity',
      );
    });

    test('the border rail never changes a pixel inside the photo area',
        () async {
      // The decisive test, and deliberately theme-agnostic: render the same
      // theme twice, once without a rail and once with one, and require the
      // photo area to be byte-identical. Comparing against a baseline rather
      // than probing for a colour is what makes this independent of what the
      // theme itself draws in its interior - Retro Pop, for instance, also
      // scatters white dots over the paper, which would otherwise mask or
      // imitate a leaked rail.
      const double inset = 40;
      final ({Uint8List px, int width, int height}) withoutRail =
          await rasterise(
        (ui.Canvas canvas, ui.Rect rect) => FrameThemePainter.paint(
          canvas,
          rect,
          FrameTheme.retroPop,
          includeWordmark: false,
        ),
      );

      for (final FrameStyle style in FrameStyle.values) {
        final ({Uint8List px, int width, int height}) withRail =
            await rasterise(
          (ui.Canvas canvas, ui.Rect rect) => FrameThemePainter.paint(
            canvas,
            rect,
            FrameTheme.retroPop,
            includeWordmark: false,
            frameStyle: style,
            contentInset: inset,
          ),
        );

        // Only the content rect itself, inset by 2 so antialiasing at the
        // boundary cannot make a correct clip look like a leak.
        final int from = (inset + 2).toInt();
        final int to = (200 - inset - 2).toInt();
        for (int y = from; y < to; y++) {
          for (int x = from; x < to; x++) {
            final int i = ((y * withRail.width) + x) * 4;
            expect(
              <int>[
                withRail.px[i],
                withRail.px[i + 1],
                withRail.px[i + 2],
                withRail.px[i + 3],
              ],
              <int>[
                withoutRail.px[i],
                withoutRail.px[i + 1],
                withoutRail.px[i + 2],
                withoutRail.px[i + 3],
              ],
              reason:
                  '${style.label}: the rail changed the pixel at ($x, $y), '
                  'which lies inside the photo area',
            );
          }
        }
      }
    });
  });

  group('problem 4 - the export actually reflects the frame options', () {
    DecorationState base(PhotoLayout layout, FrameStyle style, BackgroundChoice bg) {
      return DecorationState(
        layout: layout,
        background: bg,
        style: DecorativeStyle.clean,
        frameStyle: style,
      );
    }

    for (final PhotoLayout layout in <PhotoLayout>[
      PhotoLayout.korean4,
      PhotoLayout.grid4,
    ]) {
      test('${layout.label}: border style changes the exported PNG', () async {
        final renderer = PhotoStripRenderer();
        final Uint8List polka = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState: base(layout, FrameStyle.polkaDot, BackgroundChoice.cream),
        );
        final Uint8List film = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState: base(layout, FrameStyle.filmEdge, BackgroundChoice.cream),
        );
        final Uint8List scallop = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState: base(layout, FrameStyle.scallop, BackgroundChoice.cream),
        );
        final Uint8List minimal = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState: base(layout, FrameStyle.minimal, BackgroundChoice.cream),
        );

        // Identical PNGs would mean the option is inert again.
        expect(polka, isNot(equals(film)),
            reason: '${layout.label}: Film Edge must differ from Polka Dot');
        expect(polka, isNot(equals(scallop)));
        expect(polka, isNot(equals(minimal)));
        expect(film, isNot(equals(minimal)));
      });

      test('${layout.label}: paper colour changes the exported PNG', () async {
        final renderer = PhotoStripRenderer();
        final Uint8List cream = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState:
              base(layout, FrameStyle.minimal, BackgroundChoice.cream),
        );
        final Uint8List lavender = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState:
              base(layout, FrameStyle.minimal, BackgroundChoice.lavender),
        );
        final Uint8List charcoal = await renderer.render(
          layout: layout,
          photos: const <XFile>[],
          decorationState:
              base(layout, FrameStyle.minimal, BackgroundChoice.charcoal),
        );

        expect(cream, isNot(equals(lavender)));
        expect(cream, isNot(equals(charcoal)));
      });
    }

    test('photos stay visible under every border style and paper colour',
        () async {
      // The end-to-end guarantee: whatever frame is chosen, the captured
      // pixels must still be in the export.
      const Color photoColor = Color(0xFF0000FF);
      final (Directory dir, List<XFile> photos) =
          await solidPhotoFiles(PhotoLayout.grid4.photoCount, photoColor);
      addTearDown(() => disposeDir(dir));

      for (final FrameStyle style in FrameStyle.values) {
        for (final BackgroundChoice bg in <BackgroundChoice>[
          BackgroundChoice.cream,
          BackgroundChoice.charcoal,
        ]) {
          final Uint8List png = await PhotoStripRenderer().render(
            layout: PhotoLayout.grid4,
            photos: photos,
            decorationState: base(PhotoLayout.grid4, style, bg),
          );

          final ({Uint8List px, int width, int height}) out = await decodeRgba(png);

          // Look at the centre of the first photo cell, where a covering rail
          // or paper fill would land.
          final double scale = out.width / PhotoStripGeometry.exportWidth;
          final ui.Rect cell = PhotoStripGeometry.cellRect(PhotoLayout.grid4, 0);
          final int cx = (cell.center.dx * scale).round();
          final int cy = (cell.center.dy * scale).round();
          final int i = ((cy * out.width) + cx) * 4;

          expect(
            out.px[i + 2] > 150 && out.px[i] < 110 && out.px[i + 1] < 110,
            isTrue,
            reason:
                '${style.label} / ${bg.label}: the photo at the centre of '
                'cell 0 must still be visible (got '
                'r=${out.px[i]} g=${out.px[i + 1]} b=${out.px[i + 2]})',
          );
        }
      }
    });

    test('the chosen paper shows in the export footer band', () async {
      final renderer = PhotoStripRenderer();
      final Uint8List png = await renderer.render(
        layout: PhotoLayout.grid4,
        photos: const <XFile>[],
        decorationState: base(
          PhotoLayout.grid4,
          FrameStyle.minimal,
          BackgroundChoice.lavender,
        ),
      );
      final ({Uint8List px, int width, int height}) out = await decodeRgba(png);
      final double scale = out.width / PhotoStripGeometry.exportWidth;

      // The side margins are mostly covered by the theme's own border stroke
      // (Retro Pop's rail is ~2.6% of the export width, wider than the 16px
      // margin), so the reliable paper-only region is the footer band, which
      // no border artwork touches.
      final double gridBottom =
          PhotoStripGeometry.contentHeight(PhotoLayout.grid4) * scale;
      final int y = ((out.height + gridBottom) / 2).round();
      // Near the left edge, clear of the centred wordmark.
      final int x = (out.width * 0.04).round();
      final int i = ((y * out.width) + x) * 4;

      expect(
        out.px[i + 2] - out.px[i],
        greaterThan(5),
        reason:
            'lavender paper (blue-dominant) must appear in the footer, or the '
            'paper swatch is still inert (got r=${out.px[i]} '
            'g=${out.px[i + 1]} b=${out.px[i + 2]})',
      );
    });
  });
}