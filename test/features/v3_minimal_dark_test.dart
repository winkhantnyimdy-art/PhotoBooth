import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/shared/minimal_dark.dart';

import '../support/fake_album.dart';

/// Focuses the Minimal Dark foundation: the approved palette, the reusable
/// primitives, and the Home/Camera composition built on them.
void main() {
  group('Minimal Dark tokens', () {
    test('match the approved palette exactly', () {
      expect(AppColors.darkBackground, const Color(0xFF101012));
      expect(AppColors.darkSurface, const Color(0xFF1C1C20));
      expect(AppColors.darkLine, const Color(0xFF303036));
      expect(AppColors.darkMuted, const Color(0xFFA6A6AD));
      expect(AppColors.onDark, Colors.white);
    });
  });

  group('MinimalWordmark', () {
    testWidgets('is monochrome: no Retro Pop artwork is used', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: MinimalWordmark())),
        ),
      );

      expect(find.byType(MinimalWordmark), findsOneWidget);
      final Text text = tester.widget<Text>(find.text('PhotoBooth'));
      expect(text.style?.color, AppColors.onDark);

      // The old brand was a colourful bubble logo; the Minimal Dark wordmark
      // must not fall back to it.
      expect(find.text('PHOTO'), findsNothing);
      expect(find.text('BOOTH'), findsNothing);
    });

    testWidgets('scales down instead of overflowing a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: MinimalWordmark(fontSize: 40))),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsWidgets);
    });
  });

  group('Home Minimal Dark layout', () {
    testWidgets('uses the dark background and a real primary action', (
      tester,
    ) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      final Scaffold scaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(scaffold.backgroundColor, AppColors.darkBackground);

      expect(find.byType(MinimalWordmark), findsOneWidget);
      expect(find.byType(MinimalPrimaryButton), findsOneWidget);
      expect(find.text('Start Photo Booth'), findsOneWidget);
    });

    testWidgets('presents the layout chooser as one grouped surface', (
      tester,
    ) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      expect(find.text('Choose layout'), findsOneWidget);
      for (final String label in <String>['4 CUT', '6 CUT', '2 CUT', '3 CUT']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Album and Settings both remain reachable', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      expect(find.byType(MinimalSecondaryButton), findsNWidgets(2));
      // The footer shows the labelled Album/Settings actions; the top bar
      // duplicates them as icon-only buttons whose labels are tooltips and
      // semantics (not Text widgets).
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('primary action opens the camera', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Photo Booth'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CameraScreen), findsOneWidget);
    });
  });

  group('Camera Minimal Dark layout', () {
    testWidgets('paints the dark background and shows the layout badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.korean4,
            cameraProvider: () async => <CameraDescription>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final Scaffold scaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(scaffold.backgroundColor, AppColors.darkBackground);
      expect(find.textContaining('4 CUT'), findsOneWidget);
    });

    testWidgets('reports a camera error with actionable copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.korean4,
            cameraProvider: () async => <CameraDescription>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No cameras detected'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('keeps a clear close affordance', (tester) async {
      final Completer<List<CameraDescription>> pending = Completer();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.korean4,
            cameraProvider: () async => pending.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
