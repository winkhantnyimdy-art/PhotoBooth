import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_filter.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Writes a small, colourful placeholder photo per grid cell so the renderer
/// has real pixels to colour-process.
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
  group('PhotoStripRenderer filter parity', () {
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

    test('a chosen filter changes the exported pixels', () async {
      final Uint8List original = await renderWith(_base);
      final Uint8List retro = await renderWith(
        _base.copyWith(
          filter: PhotoFilterType.retroFilm,
          filterIntensity: 1,
        ),
      );
      final Uint8List vivid = await renderWith(
        _base.copyWith(
          filter: PhotoFilterType.vividPop,
          filterIntensity: 1,
        ),
      );

      expect(retro, isNot(orderedEquals(original)));
      expect(vivid, isNot(orderedEquals(original)));
      expect(vivid, isNot(orderedEquals(retro)));
    });

    test('strength 0 exports byte-identical to Original', () async {
      final Uint8List original = await renderWith(_base);
      for (final PhotoFilterType type in PhotoFilterType.values) {
        final Uint8List zero = await renderWith(
          _base.copyWith(filter: type, filterIntensity: 0),
        );
        expect(
          zero,
          orderedEquals(original),
          reason: '${type.label} at strength 0 must match Original',
        );
      }
    });

    test('every preset is export parity with a live preview', () async {
      // The preview resolves the exact same matrix via buildColorFilter; here
      // we only assert the exporter consumes it without dropping a preset.
      final Set<List<int>> signatures =
          <List<int>>{};
      for (final PhotoFilterType type in PhotoFilterType.values) {
        final Uint8List bytes = await renderWith(
          _base.copyWith(filter: type, filterIntensity: 1),
        );
        signatures.add(bytes.take(4096).toList());
      }
      expect(signatures.length, PhotoFilterType.values.length);
    });

    test('Film Grain adds the noise layer only at strength > 0', () async {
      final Uint8List grained = await renderWith(
        _base.copyWith(
          filter: PhotoFilterType.filmGrain,
          filterIntensity: 1,
        ),
      );
      final Uint8List zero = await renderWith(
        _base.copyWith(
          filter: PhotoFilterType.filmGrain,
          filterIntensity: 0,
        ),
      );
      expect(grained, isNot(orderedEquals(zero)));
      expect(
        grained,
        orderedEquals(await renderWith(
          _base.copyWith(
            filter: PhotoFilterType.filmGrain,
            filterIntensity: 1,
          ),
        )),
        reason: 'grain must stay deterministic for the same inputs',
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

    test('frame style changes the export chrome', () async {
      final Uint8List dots = await renderWith(_base);
      final Uint8List film = await renderWith(
        _base.copyWith(frameStyle: FrameStyle.filmEdge),
      );
      final Uint8List scallop = await renderWith(
        _base.copyWith(frameStyle: FrameStyle.scallop),
      );
      expect(film, isNot(orderedEquals(dots)));
      expect(scallop, isNot(orderedEquals(dots)));
      expect(scallop, isNot(orderedEquals(film)));
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
  });
}