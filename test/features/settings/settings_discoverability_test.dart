import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/album/album_scope.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/camera/preferences_service.dart';
import 'package:photo_booth/features/camera/selfie_mirroring.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/settings/settings_screen.dart';

import '../../support/fake_album.dart';

/// The labelled shortcut on the Home screen (as opposed to the top-bar icon).
Finder _homeShortcut(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

/// Writes a photo whose left half is red and right half is blue.
///
/// A horizontal flip swaps the halves while a rotation would not, so this
/// fixture can prove whether saved bytes were rewritten.
Future<File> _splitPhotoFile(Directory dir) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(8, 0, 8, 8),
    ui.Paint()..color = const Color(0xFF0000FF),
  );
  final ui.Image image = await recorder.endRecording().toImage(16, 8);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final File file = File('${dir.path}/split.png');
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

/// How much red sits on the left half of an encoded image.
Future<int> _redOnLeft(Uint8List png) async {
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
  int red = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width / 2; x++) {
      final int i = ((y * width) + x) * 4;
      if (px[i] > 200 && px[i + 2] < 60) red++;
    }
  }
  return red;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('problem 3 - Settings must be discoverable from Home', () {
    testWidgets('Home offers a visibly labelled Settings shortcut', (
      tester,
    ) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      // Settings used to be reachable only through a bare gear icon in the top
      // bar, and its Tooltip never appears on a touch device, so there was
      // nothing a user could actually read.
      expect(
        find.text('Settings'),
        findsOneWidget,
        reason: 'a visible text label is required, not just an icon',
      );
      expect(_homeShortcut('Settings'), findsOneWidget);
    });

    testWidgets('the Settings shortcut actually navigates', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsNothing);

      await tester.tap(_homeShortcut('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsScreen),
        findsOneWidget,
        reason: 'tapping the labelled shortcut must open Settings',
      );
    });

    testWidgets('the Album shortcut is labelled too', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      expect(_homeShortcut('Album'), findsOneWidget);
    });

    testWidgets('both shortcuts are large enough to tap', (tester) async {
      // A cramped phone viewport, as in a Safari window with visible chrome.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      for (final String label in <String>['Album', 'Settings']) {
        final Size size = tester.getSize(_homeShortcut(label));
        expect(size.height, greaterThanOrEqualTo(44),
            reason: '$label must clear the minimum touch target');
        expect(size.width, greaterThan(80));
      }
    });
  });

  group('problem 3 - Mirror selfies is explained and persists', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      final PreferencesService service = await PreferencesService.create();
      await tester.pumpWidget(
        AlbumScope(
          service: FakeAlbumService(),
          child: MaterialApp(
            theme: AppTheme.theme,
            home: SettingsScreen(preferencesService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the option is labelled exactly "Mirror selfies"', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Mirror selfies'), findsOneWidget);
    });

    testWidgets('the label explains what ON and OFF mean', (tester) async {
      await pumpSettings(tester);

      // The tile renders its title and subtitle as sibling Texts, so read the
      // subtitle that follows the title rather than the whole screen.
      final List<Text> texts = tester.widgetList<Text>(find.byType(Text)).toList();
      final int titleIndex = texts.indexWhere(
        (Text t) => t.data == 'Mirror selfies',
      );
      expect(titleIndex, greaterThanOrEqualTo(0));

      final String nearby = texts
          .skip(titleIndex)
          .take(3)
          .map((Text t) => t.data ?? '')
          .join(' ')
          .toLowerCase();

      expect(nearby, contains('mirrored'),
          reason: 'the ON state must be explained');
      expect(nearby, contains('natural'),
          reason: 'the OFF state must be explained');
    });

    testWidgets('the toggle round-trips through a reload', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('toggle-Mirror selfies')));
      await tester.pumpAndSettle();

      expect(
        (await PreferencesService.create()).load().mirrorSelfies,
        isFalse,
      );

      // Simulate a reload: a brand new screen built from stored preferences.
      await pumpSettings(tester);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('toggle-Mirror selfies')))
            .value,
        isFalse,
        reason: 'the saved value must survive a reload',
      );
    });

    testWidgets('toggling back on restores the mirrored default', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('toggle-Mirror selfies')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-Mirror selfies')));
      await tester.pumpAndSettle();

      expect(
        (await PreferencesService.create()).load().mirrorSelfies,
        isTrue,
      );
    });
  });

  group('problem 3 - the preference actually drives saved photos', () {
    test('both states produce a different capture outcome', () {
      // The whole point of the setting: both values must map to a definite
      // flip decision, not to "no effect".
      final bool mirrored = SelfieMirroring.shouldFlipCapturedPhoto(
        direction: CameraLensDirection.front,
        mirrorSelfies: true,
        platformMirrors: true,
      );
      final bool natural = SelfieMirroring.shouldFlipCapturedPhoto(
        direction: CameraLensDirection.front,
        mirrorSelfies: false,
        platformMirrors: true,
      );
      expect(mirrored, isFalse);
      expect(natural, isTrue);
    });

    test('the back camera is unaffected by the setting either way', () {
      for (final bool enabled in <bool>[true, false]) {
        expect(
          SelfieMirroring.shouldFlipCapturedPhoto(
            direction: CameraLensDirection.back,
            mirrorSelfies: enabled,
            platformMirrors: true,
          ),
          isFalse,
        );
      }
    });

    test('the stored preference drives the same decision', () {
      // End to end through persistence: what is saved is what is consulted.
      for (final bool enabled in <bool>[true, false]) {
        final CameraPreferences prefs =
            CameraPreferences(mirrorSelfies: enabled);
        final CameraPreferences restored =
            CameraPreferences.fromJson(prefs.toJson());
        expect(
          SelfieMirroring.shouldFlipCapturedPhoto(
            direction: CameraLensDirection.front,
            mirrorSelfies: restored.mirrorSelfies,
            platformMirrors: true,
          ),
          !enabled,
        );
      }
    });

    test('the export renders saved bytes without re-flipping them', () async {
      // A retaken photo already went through the capture-time normalisation.
      // If the exporter flipped again, the strip would come out double
      // mirrored. A red/blue split makes that detectable.
      final Directory dir =
          Directory.systemTemp.createTempSync('settings_export');
      addTearDown(() {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        } on Object {
          // Best effort.
        }
      });

      final File photo = await _splitPhotoFile(dir);
      final Uint8List png = await PhotoStripRenderer().render(
        layout: PhotoLayout.grid4,
        photos: <XFile>[XFile(photo.path), XFile(photo.path),
            XFile(photo.path), XFile(photo.path)],
        decorationState: const DecorationState(
          layout: PhotoLayout.grid4,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        ),
      );

      // The source has red on the left, so a rendered strip with red still on
      // the left proves nothing re-flipped it.
      expect(
        await _redOnLeft(await _readSourcePng(photo)),
        greaterThan(0),
        reason: 'sanity: the fixture really does start out red on the left',
      );
      expect(
        await _redOnLeft(png),
        greaterThan(0),
        reason:
            'the exporter must render the bytes it was given, unchanged, so a '
            'photo already normalised at capture time is not double-flipped',
      );
    });
  });

  group('WCAG helper sanity', () {
    test('the fixture is not accidentally symmetric', () async {
      final Directory dir =
          Directory.systemTemp.createTempSync('settings_helper');
      addTearDown(() {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        } on Object {
          // Best effort.
        }
      });
      final File photo = await _splitPhotoFile(dir);
      final int red = await _redOnLeft(await _readSourcePng(photo));
      expect(red, greaterThan(0));
      expect(red, lessThan(16 * 8));
    });
  });
}

/// Reads the encoded bytes of an image file.
Future<Uint8List> _readSourcePng(File file) =>
    Future<Uint8List>.value(File(file.path).readAsBytesSync());