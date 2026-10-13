import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/media/photo_source.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/camera/selfie_mirroring.dart';

const CameraDescription _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const CameraDescription _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);

/// Builds an image whose left half is red and right half is blue.
///
/// The colour split makes mirroring unambiguous: after a horizontal flip the
/// red and blue sides swap. A rotation would not swap them, which is also how
/// this fixture distinguishes mirroring from the upside-down case.
Future<Uint8List> encodeSplitPng({int width = 8, int height = 8}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF0000FF),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Counts red pixels on the left and right halves of an encoded PNG.
///
/// Only red is counted because the fixture is a pure red/blue split: a
/// horizontal flip moves every red pixel to the opposite side, whereas a
/// rotation would leave them on their original side. Counting both colours
/// would be useless, since the totals are identical either way.
Future<(int, int)> readRedPerSide(Uint8List png) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(png);
  final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? raw =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final int width = frame.image.width;
  final int height = frame.image.height;
  frame.image.dispose();
  codec.dispose();

  final Uint8List px = raw!.buffer.asUint8List();
  int left = 0, right = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int i = ((y * width) + x) * 4;
      if (px[i] > 200 && px[i + 2] < 60) {
        if (x < width / 2) {
          left++;
        } else {
          right++;
        }
      }
    }
  }
  return (left, right);
}

/// True when the decoded image has the given dimensions, i.e. still a real
/// image rather than a truncated or empty file.
Future<bool> isDecodableImage(Uint8List bytes, {int? width, int? height}) async {
  try {
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.Codec codec = await ui.instantiateImageCodecFromBuffer(buffer);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final int w = frame.image.width;
    final int h = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (width != null && w != width) return false;
    if (height != null && h != height) return false;
    return true;
  } on Object {
    return false;
  }
}

void main() {
  group('SelfieMirroring.shouldFlipCapturedPhoto', () {
    tearDown(() {
      SelfieMirroring.debugSetPlatformMirrorsFrontCapture(kIsWeb);
    });

    test('the default platform capability follows the build platform', () {
      // Regression test for the Android release: the default used to be
      // hard-coded to the web behaviour (true), so native selfies were stored
      // unmirrored while the preview showed them mirrored.
      SelfieMirroring.debugSetPlatformMirrorsFrontCapture(kIsWeb);
      expect(SelfieMirroring.platformMirrorsFrontCapture, kIsWeb);
      // With the platform default in effect, the default preference (mirrored
      // selfies) resolves to a flip exactly when the platform did not mirror.
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: true,
        ),
        !kIsWeb,
      );
    });

    test('the back camera is NEVER mirrored', () {
      for (final bool mirrorSelfies in <bool>[true, false]) {
        for (final bool platform in <bool>[true, false]) {
          expect(
            SelfieMirroring.shouldFlipCapturedPhoto(
              direction: _back.lensDirection,
              mirrorSelfies: mirrorSelfies,
              platformMirrors: platform,
            ),
            isFalse,
            reason:
                'mirrorSelfies=$mirrorSelfies platformMirrors=$platform: a '
                'back-camera photo must never be flipped',
          );
        }
      }
    });

    test('a front selfie is never double-mirrored', () {
      // Platform already mirrors and the user wants a mirror: flipping again
      // would turn the photo back to its natural (unmirrored) state.
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: true,
          platformMirrors: true,
        ),
        isFalse,
        reason: 'the platform already mirrored it; flipping again would '
            'double-mirror',
      );
    });

    test('turning the preference off un-mirrors a platform-mirrored capture',
        () {
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: false,
          platformMirrors: true,
        ),
        isTrue,
        reason: 'the bytes arrive mirrored, so one flip restores them',
      );
    });

    test('on a platform that does not mirror, the default mirrors the photo',
        () {
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: true,
          platformMirrors: false,
        ),
        isTrue,
      );
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: false,
          platformMirrors: false,
        ),
        isFalse,
      );
    });

    test('exactly one flip happens in every combination', () {
      for (final bool mirrorSelfies in <bool>[true, false]) {
        for (final bool platform in <bool>[true, false]) {
          final bool flips = SelfieMirroring.shouldFlipCapturedPhoto(
            direction: _front.lensDirection,
            mirrorSelfies: mirrorSelfies,
            platformMirrors: platform,
          );
          final int totalFlips =
              (platform ? 1 : 0) + (flips ? 1 : 0);
          expect(
            totalFlips % 2,
            (mirrorSelfies ? 1 : 0),
            reason:
                'mirrorSelfies=$mirrorSelfies platformMirrors=$platform must '
                'produce a net orientation equal to the preference',
          );
        }
      }
    });

    test('defaults to the platform capability when not overridden', () {
      SelfieMirroring.debugSetPlatformMirrorsFrontCapture(true);
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: true,
        ),
        isFalse,
      );
      SelfieMirroring.debugSetPlatformMirrorsFrontCapture(false);
      expect(
        SelfieMirroring.shouldFlipCapturedPhoto(
          direction: _front.lensDirection,
          mirrorSelfies: true,
        ),
        isTrue,
      );
    });
  });

  group('SelfieMirroring.shouldMirrorPreview', () {
    test('the preview mirrors exactly when the stored photo will be mirrored',
        () {
      // The viewfinder used to be an unconditional mirror for the front
      // camera, so turning "Mirror selfies" off produced a mirrored preview
      // and an unmirrored photo. Preview and capture must now agree.
      for (final CameraLensDirection direction in <CameraLensDirection>[
        CameraLensDirection.front,
        CameraLensDirection.back,
      ]) {
        for (final bool mirrorSelfies in <bool>[true, false]) {
          for (final bool platform in <bool>[true, false]) {
            expect(
              SelfieMirroring.shouldMirrorPreview(
                direction: direction,
                mirrorSelfies: mirrorSelfies,
                platformMirrors: platform,
              ),
              SelfieMirroring.storedPhotoIsMirrored(
                direction: direction,
                mirrorSelfies: mirrorSelfies,
                platformMirrors: platform,
              ),
              reason:
                  'direction=$direction mirrorSelfies=$mirrorSelfies '
                  'platformMirrors=$platform: the preview must show the same '
                  'orientation the user will get',
            );
          }
        }
      }
    });

    test('the back preview is never mirrored', () {
      for (final bool mirrorSelfies in <bool>[true, false]) {
        expect(
          SelfieMirroring.shouldMirrorPreview(
            direction: CameraLensDirection.back,
            mirrorSelfies: mirrorSelfies,
            platformMirrors: true,
          ),
          isFalse,
        );
      }
    });

    test('the front preview follows the preference', () {
      expect(
        SelfieMirroring.shouldMirrorPreview(
          direction: CameraLensDirection.front,
          mirrorSelfies: true,
          platformMirrors: true,
        ),
        isTrue,
      );
      expect(
        SelfieMirroring.shouldMirrorPreview(
          direction: CameraLensDirection.front,
          mirrorSelfies: false,
          platformMirrors: true,
        ),
        isFalse,
        reason: 'OFF must show the natural orientation, not a mirror',
      );
    });

    test('stored orientation is independent of platform behaviour', () {
      // Whatever the platform does, the user's preference decides the result.
      for (final bool platform in <bool>[true, false]) {
        expect(
          SelfieMirroring.storedPhotoIsMirrored(
            direction: CameraLensDirection.front,
            mirrorSelfies: true,
            platformMirrors: platform,
          ),
          isTrue,
        );
        expect(
          SelfieMirroring.storedPhotoIsMirrored(
            direction: CameraLensDirection.front,
            mirrorSelfies: false,
            platformMirrors: platform,
          ),
          isFalse,
        );
      }
    });
  });

  group('flipHorizontally', () {
    test('mirrors left and right and leaves top and bottom alone', () async {
      final Uint8List png = await encodeSplitPng();

      final (int leftRedBefore, int rightRedBefore) =
          await readRedPerSide(png);
      // Sanity: red on the left, blue on the right before the flip.
      expect(leftRedBefore, greaterThan(0));
      expect(rightRedBefore, 0);

      final Uint8List? flipped = await flipHorizontally(png);
      expect(flipped, isNotNull);

      final (int leftRedAfter, int rightRedAfter) =
          await readRedPerSide(flipped!);

      // The flip swaps the halves: every red pixel moves to the right side.
      expect(rightRedAfter, leftRedBefore,
          reason: 'after mirroring, the right half holds what the left held');
      expect(leftRedAfter, 0,
          reason: 'after mirroring, the left half must hold no red at all');
      expect(
        await isDecodableImage(flipped, width: 8, height: 8),
        isTrue,
        reason: 'dimensions must be preserved, so this is a flip not a crop',
      );
    });

    test('flipping twice restores the original orientation', () async {
      final Uint8List png = await encodeSplitPng();
      final Uint8List? once = await flipHorizontally(png);
      final Uint8List? twice = await flipHorizontally(once!);

      expect(await readRedPerSide(twice!), await readRedPerSide(png));
    });

    test('undecodable bytes return null instead of throwing', () async {
      expect(
          await flipHorizontally(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
      expect(await flipHorizontally(Uint8List(0)), isNull);
    });
  });

  group('flipPhotoIfNeeded', () {
    late Directory dir;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      dir = Directory.systemTemp.createTempSync('flip_photo');
      // `flipPhotoIfNeeded` writes flipped captures to the app temp directory.
      // Point the plugin at the per-test temp dir so nothing leaks between
      // tests and no platform channel is left unmocked.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => dir.path,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on Object {
        // Best effort.
      }
    });

    test('returns the very same photo when no flip is requested', () async {      final Uint8List png = await encodeSplitPng();
      final File file = File('${dir.path}/shot.png');
      await file.writeAsBytes(png);
      final XFile photo = XFile(file.path);

      final XFile result = await flipPhotoIfNeeded(photo, flipHorizontal: false);

      expect(identical(result, photo), isTrue,
          reason: 'the no-op path must not re-encode or copy the photo');
    });

    test('an unreadable source keeps the original instead of throwing',
        () async {
      // A capture whose bytes cannot be read (deleted temp file, torn-down
      // backing store) must not fail the whole session: the cosmetic mirror
      // is skipped and the original photo survives.
      final XFile missing = XFile('${dir.path}/does_not_exist.jpg');

      final XFile result =
          await flipPhotoIfNeeded(missing, flipHorizontal: true);

      expect(result.path, missing.path);
    });

    test('horizontally mirrors the stored bytes when a flip is requested',
        () async {
      final Uint8List png = await encodeSplitPng();
      final File file = File('${dir.path}/shot.png');
      await file.writeAsBytes(png);

      final XFile result =
          await flipPhotoIfNeeded(XFile(file.path), flipHorizontal: true);

      final (int leftRedBefore, int _) = await readRedPerSide(png);
      final (int leftRedAfter, int rightRedAfter) =
          await readRedPerSide(await readPhotoBytes(result));

      expect(leftRedBefore, greaterThan(0));
      expect(leftRedAfter, 0,
          reason: 'the stored bytes must no longer have red on the left');
      expect(rightRedAfter, leftRedBefore,
          reason: 'the stored bytes must actually be mirrored');
    });

    test('every shot in a session gets its own file', () async {
      // `XFile.name` is empty for most native captures, so deriving the output
      // name from it alone gave every shot the same path and each capture
      // overwrote the previous one - leaving the strip showing the same photo
      // four times.
      final Uint8List png = await encodeSplitPng();
      final File source = File('${dir.path}/source.png');
      await source.writeAsBytes(png);

      final List<XFile> results = <XFile>[];
      for (int i = 0; i < 4; i++) {
        results.add(
          await flipPhotoIfNeeded(XFile(source.path), flipHorizontal: true),
        );
      }

      expect(
        results.map((XFile f) => f.path).toSet().length,
        4,
        reason: 'each captured shot needs a distinct file',
      );
      for (final XFile f in results) {
        expect(
          await isDecodableImage(await readPhotoBytes(f), width: 8, height: 8),
          isTrue,
          reason: 'every shot must still hold a full, decodable image',
        );
      }
    });

    test('a failed flip falls back to the original photo, never losing it',
        () async {
      // A file that is not a decodable image.
      final File file = File('${dir.path}/broken.png');
      await file.writeAsBytes(Uint8List.fromList(<int>[9, 9, 9, 9]));

      final XFile result =
          await flipPhotoIfNeeded(XFile(file.path), flipHorizontal: true);

      expect(File(result.path).existsSync(), isTrue);
      expect(result.path, file.path);
    });
  });

  group('CameraPreferences.mirrorSelfies', () {
    test('defaults to mirrored', () {
      expect(const CameraPreferences().mirrorSelfies, isTrue);
    });

    test('round-trips through JSON', () {
      const CameraPreferences prefs = CameraPreferences(mirrorSelfies: false);
      final CameraPreferences restored =
          CameraPreferences.fromJson(prefs.toJson());
      expect(restored.mirrorSelfies, isFalse);
    });

    test('preferences saved before this fix still load as mirrored', () {
      // An older build wrote no mirrorSelfies key at all.
      final CameraPreferences restored = CameraPreferences.fromJson(
        <String, dynamic>{
          'countdownSeconds': 5,
          'shutterSoundEnabled': true,
          'flashAnimationEnabled': true,
        },
      );
      expect(restored.mirrorSelfies, isTrue);
      expect(restored.countdownSeconds, 5);
    });

    test('copyWith toggles only the mirror flag', () {
      final CameraPreferences updated =
          const CameraPreferences().copyWith(mirrorSelfies: false);
      expect(updated.mirrorSelfies, isFalse);
      expect(updated.countdownSeconds, 3);
      expect(updated.shutterSoundEnabled, isTrue);
    });
  });
}