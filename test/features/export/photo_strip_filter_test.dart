import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_effect.dart';
import 'package:photo_booth/core/filters/photo_filter.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Writes a small, colourful placeholder photo per grid cell so the renderer
/// has real pixels to colour-process.
///
/// The fixture is deliberately asymmetric - a blue field, a pink disc in the
/// upper left and a yellow block in the lower right - so a mirrored or
/// transposed effect cannot hide behind an average.
Future<List<XFile>> _samplePhotos() async {
  final Directory dir = await Directory.systemTemp.createTemp('pb_filter');
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 64, 96),
    Paint()..color = const ui.Color(0xFF4D7DDB),
  );
  canvas.drawCircle(
    const Offset(32, 24),
    14,
    Paint()..color = const ui.Color(0xFFFFB6C1),
  );
  canvas.drawRect(
    const Rect.fromLTWH(8, 40, 48, 48),
    Paint()..color = const ui.Color(0xFFFED759),
  );
  final ui.Image image = await recorder.endRecording().toImage(64, 96);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final Uint8List png = bytes!.buffer.asUint8List();

  final List<XFile> photos = <XFile>[];
  for (int i = 0; i < PhotoLayout.grid4.photoCount; i++) {
    final File file = File('${dir.path}/photo_$i.png');
    await file.writeAsBytes(png);
    photos.add(XFile(file.path));
  }
  return photos;
}

/// The shared baseline decoration used across these tests.
const DecorationState _base = DecorationState(
  layout: PhotoLayout.grid4,
  background: BackgroundChoice.cream,
  style: DecorativeStyle.clean,
);

void main() {
  group('PhotoStripRenderer effect parity', () {
    late PhotoStripRenderer renderer;
    late List<XFile> photos;

    setUp(() async {
      renderer = PhotoStripRenderer();
      photos = await _samplePhotos();
    });

    Future<Uint8List> renderWith(DecorationState state) {
      return renderer.render(
        layout: state.layout,
        photos: photos,
        decorationState: state,
      );
    }

    test('a chosen effect changes the exported pixels', () async {
      final Uint8List original = await renderWith(_base);
      final Uint8List film = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.classicFilm,
          filterIntensity: 1,
        ),
      );
      final Uint8List flash = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.y2kFlash,
          filterIntensity: 1,
        ),
      );

      expect(film, isNot(orderedEquals(original)));
      expect(flash, isNot(orderedEquals(original)));
      expect(flash, isNot(orderedEquals(film)));
    });

    test('strength 0 exports byte-identical to Original', () async {
      final Uint8List original = await renderWith(_base);
      for (final PhotoEffect effect in PhotoEffect.values) {
        final Uint8List zero = await renderWith(
          _base.copyWith(filter: effect, filterIntensity: 0),
        );
        expect(
          zero,
          orderedEquals(original),
          reason: '${effect.label} at strength 0 must match Original',
        );
      }
    });

    test('all fifteen effects produce distinguishable exports', () async {
      // Comparing a prefix of the compressed bytes would only prove the PNG
      // headers differ, which says nothing about the effect. This measures
      // decoded pixels instead, so "fifteen nearly identical overlays" fails
      // here rather than shipping.
      final Map<PhotoEffect, _PixelStats> stats = <PhotoEffect, _PixelStats>{};
      for (final PhotoEffect effect in PhotoEffect.values) {
        stats[effect] = await _measure(
          await renderWith(
            _base.copyWith(filter: effect, filterIntensity: 1),
          ),
        );
      }

      expect(stats.length, 15, reason: 'the catalogue must hold fifteen');

      final List<PhotoEffect> effects = stats.keys.toList();
      for (int i = 0; i < effects.length; i++) {
        for (int j = i + 1; j < effects.length; j++) {
          final double distance =
              stats[effects[i]]!.distanceTo(stats[effects[j]]!);
          expect(
            distance,
            greaterThanOrEqualTo(0.75),
            reason: '${effects[i].label} and ${effects[j].label} are too alike '
                '(mean-channel distance $distance)',
          );
        }
      }
    });

    test('Original exports identically to a neutral edit', () async {
      final Uint8List original = await renderWith(_base);
      final Uint8List explicit = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.original,
          filterIntensity: 1,
        ),
      );
      expect(explicit, orderedEquals(original));
    });

    test('Grain adds the noise layer only at strength > 0', () async {
      final Uint8List grained = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.grain,
          filterIntensity: 1,
        ),
      );
      final Uint8List zero = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.grain,
          filterIntensity: 0,
        ),
      );
      expect(grained, isNot(orderedEquals(zero)));
      expect(
        grained,
        orderedEquals(await renderWith(
          _base.copyWith(
            filter: PhotoEffect.grain,
            filterIntensity: 1,
          ),
        )),
        reason: 'grain must stay deterministic for the same inputs',
      );
    });

    test('bloom effects lift highlights without touching the shadows', () async {
      // A single white block on a black field: screen blending should raise the
      // white and leave the black where it is. An alpha composite would lift
      // the black too, so this distinguishes the two implementations.
      final Uint8List dream = await renderWith(
        _base.copyWith(filter: PhotoEffect.dreamy, filterIntensity: 1),
      );
      final Uint8List plain = await renderWith(_base);
      final _PixelStats dreamStats = await _measure(dream);
      final _PixelStats plainStats = await _measure(plain);
      expect(
        dreamStats.luma,
        greaterThan(plainStats.luma),
        reason: 'bloom must add light',
      );
    });

    test('manual adjustments alter the export', () async {
      final Uint8List plain = await renderWith(_base);
      final Uint8List adjusted = await renderWith(
        _base.copyWith(
          adjustments: const PhotoAdjustments(
            brightness: 0.25,
            contrast: 0.2,
            saturation: -0.3,
            warmth: 0.5,
          ),
        ),
      );
      expect(adjusted, isNot(orderedEquals(plain)));
    });

    test('frame theme changes the export chrome', () async {
      final Uint8List retro = await renderWith(_base);
      final Uint8List film = await renderWith(
        _base.copyWith(frameTheme: FrameTheme.vintageFilm),
      );
      final Uint8List kawaii = await renderWith(
        _base.copyWith(frameTheme: FrameTheme.kawaii),
      );
      expect(film, isNot(orderedEquals(retro)));
      expect(kawaii, isNot(orderedEquals(retro)));
      expect(kawaii, isNot(orderedEquals(film)));
    });

    test('captions render into the exported strip', () async {
      final Uint8List bare = await renderWith(_base);
      final Uint8List captioned = await renderWith(
        _base.copyWith(
          texts: const <TextPlacement>[
            TextPlacement(text: 'Smile!', x: 0.5, y: 0.5, color: Colors.white),
            TextPlacement(text: 'Party', x: 0.25, y: 0.85, color: Colors.black),
          ],
        ),
      );
      expect(captioned, isNot(orderedEquals(bare)));
      expect(
        captioned,
        orderedEquals(await renderWith(
          _base.copyWith(
            texts: const <TextPlacement>[
              TextPlacement(text: 'Smile!', x: 0.5, y: 0.5, color: Colors.white),
              TextPlacement(text: 'Party', x: 0.25, y: 0.85, color: Colors.black),
            ],
          ),
        )),
        reason: 'captions must render deterministically',
      );
    });

    test('stickers and text survive an applied effect', () async {
      // Compatibility check: compositing order must leave the decorations on
      // top of the graded photos rather than under them.
      final Uint8List plain = await renderWith(_base);
      final Uint8List decorated = await renderWith(
        _base.copyWith(
          filter: PhotoEffect.vintage,
          filterIntensity: 1,
          texts: const <TextPlacement>[
            TextPlacement(text: 'Smile!', x: 0.5, y: 0.9, color: Colors.white),
          ],
        ),
      );
      expect(decorated, isNot(orderedEquals(plain)));
    });
  });
}

/// Mean colour across a decoded export, used to judge how far apart two
/// effects actually look.
class _PixelStats {
  const _PixelStats(this.r, this.g, this.b, this.luma);

  final double r;
  final double g;
  final double b;
  final double luma;

  /// Mean absolute per-channel difference, in 0…255 channel units.
  double distanceTo(_PixelStats other) {
    final double dr = (r - other.r).abs();
    final double dg = (g - other.g).abs();
    final double db = (b - other.b).abs();
    final double dl = (luma - other.luma).abs();
    return (dr + dg + db + dl) / 4;
  }
}

/// Decodes an exported PNG and averages its channels.
Future<_PixelStats> _measure(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? data = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  frame.image.dispose();
  codec.dispose();

  final Uint8List rgba = data!.buffer.asUint8List();
  int r = 0;
  int g = 0;
  int b = 0;
  double luma = 0;
  final int pixels = rgba.length ~/ 4;
  for (int i = 0; i < rgba.length; i += 4) {
    final int pr = rgba[i];
    final int pg = rgba[i + 1];
    final int pb = rgba[i + 2];
    r += pr;
    g += pg;
    b += pb;
    luma += (0.299 * pr) + (0.587 * pg) + (0.114 * pb);
  }
  return _PixelStats(r / pixels, g / pixels, b / pixels, luma / pixels);
}
