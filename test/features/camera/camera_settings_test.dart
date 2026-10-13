import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/album/album_scope.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/camera/preferences_service.dart';
import 'package:photo_booth/features/camera/session_runner.dart';
import 'package:photo_booth/features/camera/session_state.dart';
import 'package:photo_booth/features/camera/shutter_sound.dart';
import 'package:photo_booth/features/camera/timing.dart';
import 'package:photo_booth/features/settings/settings_screen.dart';

import '../../support/fake_album.dart';

/// Counts the sound calls the camera makes, without an audio plugin.
class RecordingShutterSound extends ShutterSoundService {
  RecordingShutterSound() : super.silent();

  int prepareCount = 0;
  int playCount = 0;

  @override
  Future<void> prepare() async {
    prepareCount++;
  }

  @override
  Future<void> play() async {
    playCount++;
  }
}

/// Advances a [TestTiming] by one delay and lets the runner resume.
Future<void> _tick(TestTiming timing) async {
  timing.tick();
  await Future<void>.delayed(const Duration(milliseconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('returns defaults when nothing has been saved', () async {
      final PreferencesService service = await PreferencesService.create();
      final CameraPreferences loaded = service.load();

      expect(loaded.countdownSeconds, 3);
      expect(loaded.shutterSoundEnabled, isTrue);
      expect(loaded.flashAnimationEnabled, isTrue);
    });

    test('saved preferences survive a new service instance', () async {
      // First "launch" writes the preference.
      final PreferencesService first = await PreferencesService.create();
      final bool saved = await first.save(
        const CameraPreferences(
          countdownSeconds: 10,
          shutterSoundEnabled: false,
          flashAnimationEnabled: false,
        ),
      );
      expect(saved, isTrue);

      // Second "launch" is a brand new instance over the same backing store.
      final PreferencesService second = await PreferencesService.create();
      final CameraPreferences reloaded = second.load();

      expect(reloaded.countdownSeconds, 10);
      expect(reloaded.shutterSoundEnabled, isFalse);
      expect(reloaded.flashAnimationEnabled, isFalse);
    });

    test('reset restores the defaults', () async {
      final PreferencesService service = await PreferencesService.create();
      await service.save(
        const CameraPreferences(countdownSeconds: 5, shutterSoundEnabled: false),
      );

      await service.reset();

      final CameraPreferences reloaded = service.load();
      expect(reloaded.countdownSeconds, 3);
      expect(reloaded.shutterSoundEnabled, isTrue);
    });

    test('a corrupt stored value falls back to defaults instead of throwing',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.camera_preferences': 'this is not json',
      });
      final PreferencesService service = await PreferencesService.create();

      expect(service.load().countdownSeconds, 3);
    });
  });

  group('countdown preference drives the session', () {
    for (final int seconds in CameraPreferences.validCountdownOptions) {
      test('a $seconds second countdown emits $seconds down to 1', () async {
        final TestTiming timing = TestTiming();
        final List<int> countdowns = <int>[];

        final SessionRunner runner = SessionRunner(
          timing: timing,
          countdownSeconds: seconds,
          takePicture: () async {
            await timing.delay(const Duration(seconds: 1));
            return XFile('/fake/photo.png');
          },
          onStep: (CameraSessionState state, {int? countdown, int? shot}) {
            if (countdown != null) countdowns.add(countdown);
          },
        );

        final Future<bool> done = runner.run(1).then((_) => true);
        // $seconds countdown delays plus one capture delay.
        for (int i = 0; i < seconds + 1; i++) {
          await _tick(timing);
        }

        expect(await done, isTrue);
        expect(countdowns, List<int>.generate(seconds, (int i) => seconds - i));
      });
    }

    test('the default countdown is three seconds', () async {
      final TestTiming timing = TestTiming();
      final List<int> countdowns = <int>[];

      final SessionRunner runner = SessionRunner(
        timing: timing,
        takePicture: () async {
          await timing.delay(const Duration(seconds: 1));
          return XFile('/fake/photo.png');
        },
        onStep: (CameraSessionState state, {int? countdown, int? shot}) {
          if (countdown != null) countdowns.add(countdown);
        },
      );

      final Future<bool> done = runner.run(1).then((_) => true);
      for (int i = 0; i < 4; i++) {
        await _tick(timing);
      }

      expect(await done, isTrue);
      expect(countdowns, <int>[3, 2, 1]);
    });
  });

  group('ShutterSoundService', () {
    test('a silent service reports itself as usable and does nothing', () async {
      final ShutterSoundService service = ShutterSoundService.silent();
      await service.prepare();
      await service.play();
      await service.dispose();

      // No backend means nothing to report as broken; capture simply stays quiet.
      expect(service.isAvailable, isTrue);
    });

    test('the shutter sound asset is declared and bundled', () async {
      // Resolved through the asset bundle rather than the filesystem, so this
      // checks the asset is actually declared in pubspec.yaml and reachable at
      // runtime - not merely present on disk.
      final ByteData data = await rootBundle.load(
        'assets/${ShutterSoundService.assetPath}',
      );
      final Uint8List bytes = data.buffer.asUint8List();

      expect(bytes.length, greaterThan(44), reason: 'a WAV header plus payload');
      // A RIFF/WAVE container, so the platform players can decode it.
      expect(bytes.sublist(0, 4), 'RIFF'.codeUnits);
      expect(bytes.sublist(8, 12), 'WAVE'.codeUnits);
    });
  });

  group('SettingsScreen', () {
    late FakeAlbumService album;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      album = FakeAlbumService();
      tempDir = Directory.systemTemp.createTempSync('settings_album');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } on Object {
        // Best effort.
      }
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      final PreferencesService service = await PreferencesService.create();
      await tester.pumpWidget(
        AlbumScope(
          service: album,
          child: MaterialApp(
            theme: AppTheme.theme,
            home: SettingsScreen(preferencesService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers exactly the three supported countdown options',
        (tester) async {
      await pumpSettings(tester);

      for (final int seconds in <int>[3, 5, 10]) {
        expect(find.byKey(ValueKey('countdown-$seconds')), findsOneWidget);
        expect(find.text('$seconds sec'), findsOneWidget);
      }
      // No other durations leak into the UI.
      expect(find.text('7 sec'), findsNothing);
    });

    testWidgets('changing the countdown persists it immediately',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('countdown-10')));
      await tester.pumpAndSettle();

      final PreferencesService service = await PreferencesService.create();
      expect(service.load().countdownSeconds, 10);
    });

    testWidgets('toggling shutter sound and flash persists both',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('toggle-Shutter sound')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-Flash animation')));
      await tester.pumpAndSettle();

      final CameraPreferences loaded =
          (await PreferencesService.create()).load();
      expect(loaded.shutterSoundEnabled, isFalse);
      expect(loaded.flashAnimationEnabled, isFalse);

      // A fresh screen reads the saved values back.
      await pumpSettings(tester);
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('toggle-Shutter sound'))).value,
        isFalse,
      );
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('toggle-Flash animation'))).value,
        isFalse,
      );
    });

    testWidgets('reports album storage usage and the backend', (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));
      await pumpSettings(tester);

      expect(find.textContaining('Album size'), findsOneWidget);
      expect(find.textContaining(album.backendName), findsOneWidget);
      expect(
        find.textContaining("Clearing this site's data"),
        findsOneWidget,
        reason: 'browser data loss must be explained',
      );
    });

    testWidgets('clearing the album requires confirmation', (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));
      await pumpSettings(tester);

      // The storage section sits below the fold on a short viewport.
      await tester.ensureVisible(find.text('Clear album'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear album'));
      await tester.pumpAndSettle();
      expect(find.text('Clear the whole album?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(album.memoryStore.recordCount, 1);

      await tester.ensureVisible(find.text('Clear album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();

      expect(album.memoryStore.recordCount, 0);
      expect(album.memoryStore.photoCount, 0);
    });

    testWidgets('the album can be reached from settings', (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));
      await pumpSettings(tester);

      await tester.ensureVisible(find.text('Album'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Album'));
      await tester.pumpAndSettle();

      // The album screen opened with the same backend instance.
      expect(find.byKey(const ValueKey('album-session-s1')), findsOneWidget);
    });
  });
}