import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camera/camera.dart';
import 'package:photo_booth/core/media/photo_source.dart';
import 'package:photo_booth/core/media/preview_decode.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Roughly an iPhone capture. Encoding a flat rectangle is cheap, so this
/// does not slow the suite down the way real camera noise would.
const int _kCaptureWidth = 3024;
const int _kCaptureHeight = 4032;

Future<Uint8List> _encodeCapture({int width = _kCaptureWidth, int height = _kCaptureHeight}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFF204080),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Decodes [bytes] honouring [targetWidth], the way an image provider does.
Future<ui.Image> _decode(Uint8List bytes, {int? targetWidth}) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(
    buffer,
    targetWidth: targetWidth,
  );
  final ui.FrameInfo frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Approximate RGBA footprint of a decoded bitmap, which is what actually
/// matters for mobile Safari memory pressure.
int _bytesFor(ui.Image image) => image.width * image.height * 4;

void main() {
  group('the preview decode is capped, and measurably smaller', () {
    test('a full decode costs tens of megabytes that the preview avoids', () async {
      final Uint8List capture = await _encodeCapture();

      final int previewWidth =
          PreviewDecode.forWidth(340, 3)!; // a ~340 px cell on a 3x phone

      final ui.Image full = await _decode(capture);
      final Stopwatch fullWatch = Stopwatch()..start();
      final ui.Image fullAgain = await _decode(capture);
      fullWatch.stop();
      full.dispose();

      final Stopwatch previewWatch = Stopwatch()..start();
      final ui.Image preview = await _decode(capture, targetWidth: previewWidth);
      previewWatch.stop();

      // ignore: avoid_print
      print(
        'decode of ${_kCaptureWidth}x$_kCaptureHeight: '
        'full ${fullAgain.width}x${fullAgain.height} '
        '${_bytesFor(fullAgain) ~/ (1024 * 1024)} MB in '
        '${fullWatch.elapsedMilliseconds} ms | '
        'preview ${preview.width}x${preview.height} '
        '${_bytesFor(preview) ~/ (1024 * 1024)} MB in '
        '${previewWatch.elapsedMilliseconds} ms',
      );

      expect(
        fullAgain.width,
        _kCaptureWidth,
        reason: 'an uncapped decode keeps the stored resolution',
      );
      expect(preview.width, lessThanOrEqualTo(previewWidth));
      expect(
        _bytesFor(preview),
        lessThan(_bytesFor(fullAgain) ~/ 5),
        reason:
            'the preview bitmap must be a small fraction of the full one, '
            'otherwise mobile Safari still holds the whole capture',
      );

      fullAgain.dispose();
      preview.dispose();
    });

    test('a four-shot strip stays within a mobile-sane budget', () async {
      final Uint8List capture = await _encodeCapture();
      final int previewWidth = PreviewDecode.forWidth(340, 3)!;
      final ui.Image full = await _decode(capture);
      final ui.Image preview = await _decode(capture, targetWidth: previewWidth);

      final int fullStrip = _bytesFor(full) * 4; // grid4 = 4 photos
      final int previewStrip = _bytesFor(preview) * 4;

      // ignore: avoid_print
      print(
        'four-shot strip bitmaps: full ${fullStrip ~/ (1024 * 1024)} MB vs '
        'preview ${previewStrip ~/ (1024 * 1024)} MB',
      );

      expect(previewStrip, lessThan(24 * 1024 * 1024));
      expect(previewStrip, lessThan(fullStrip ~/ 5));

      full.dispose();
      preview.dispose();
    });
  });

  group('cache behaviour', () {
    test('identical decode requests share one cache entry', () {
      final FileImage base = FileImage(File('shot.png'));
      expect(
        ResizeImage.resizeIfNeeded(300, null, base),
        ResizeImage.resizeIfNeeded(300, null, FileImage(File('shot.png'))),
        reason:
            'the same photo at the same size must hit the image cache',
      );
    });

    test('a different decode width is a different cache entry', () {
      final FileImage base = FileImage(File('shot.png'));
      expect(
        ResizeImage.resizeIfNeeded(300, null, base),
        isNot(
          ResizeImage.resizeIfNeeded(600, null, FileImage(File('shot.png'))),
        ),
        reason:
            'a larger cell must not silently reuse the smaller bitmap, or the '
            'preview looks soft on a big tablet',
      );
    });

    test('omitting the width keeps the full-resolution provider', () {
      final PhotoImage preview = PhotoImage(
        photo: XFile('shot.png'),
        decodeWidth: 512,
      );
      final PhotoImage full = PhotoImage(photo: XFile('shot.png'));
      expect(preview.decodeWidth, 512);
      expect(full.decodeWidth, isNull);
    });
  });

  group('export quality is untouched by the preview work', () {
    for (final PhotoLayout layout in PhotoLayout.values) {
      test('${layout.label} still exports at full canvas width', () async {
        final Uint8List png = await PhotoStripRenderer().render(
          layout: layout,
          photos: const <XFile>[],
          decorationState: DecorationState(
            layout: layout,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
          ),
        );

        final ByteData header = ByteData.sublistView(png);
        expect(
          header.getUint32(16),
          PhotoStripGeometry.exportWidth.toInt(),
          reason:
              'the export must not inherit the preview downscale',
        );
        expect(
          header.getUint32(20),
          PhotoStripGeometry.totalHeight(layout).toInt(),
        );
      });
    }

    test('the exporter never goes through the preview downscale', () {
      final File source = File('lib/features/export/photo_strip_renderer.dart');
      final String text = source.readAsStringSync();
      expect(text, isNot(contains('ResizeImage')));
      expect(text, isNot(contains('decodeWidth')));
      expect(text, contains('targetWidth'));
    });
  });

  group('undo history stays bounded', () {
    test('many edits do not grow the undo stack without limit', () {
      final undo = UndoRedoDecoration(capacity: 30);
      final state = DecorationState(
        layout: PhotoLayout.grid4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );

      for (int i = 0; i < 500; i++) {
        undo.record(state);
      }

      // Recording is O(1) per edit and the history is capped, so a long editing
      // session cannot balloon memory the way an uncapped stack would.
      int undos = 0;
      DecorationState? current = state;
      while (undos < 1000) {
        final DecorationState? previous = undo.undo(current!);
        if (previous == null) break;
        current = previous;
        undos++;
      }
      expect(undos, lessThanOrEqualTo(30));
      expect(undos, greaterThan(0));
    });
  });
}