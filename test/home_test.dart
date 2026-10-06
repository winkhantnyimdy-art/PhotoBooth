import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text(AppTheme.brand), findsOneWidget);
    });

    testWidgets('4 CUT is selected by default', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text('4 CUT'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
    });

    testWidgets('selecting 2 CUT works', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text('2 CUT'), findsOneWidget);
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      expect(find.text('2 CUT'), findsWidgets);
    });

    testWidgets('Start Photo Booth navigates to camera', (tester) async {
      await tester.pumpWidget(const App());
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Camera'), findsOneWidget);
    });

    testWidgets('Start Photo Booth passes selected layout', (tester) async {
      await tester.pumpWidget(const App());
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pump();
      await tester.pump();
      // Camera screen shows the selected layout badge
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('2 CUT'), findsOneWidget);
    });
  });

  group('CameraScreen', () {
    testWidgets('shows loading state initially', (tester) async {
      final Completer<List<CameraDescription>> pending = Completer();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.cut4,
            cameraProvider: () async => pending.future,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error when no cameras available', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.cut4,
            cameraProvider: () async => <CameraDescription>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No cameras detected'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows error when camera provider throws', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.cut4,
            cameraProvider: () async => throw Exception('boom'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Camera unavailable'), findsOneWidget);
    });

    testWidgets('displays selected layout badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.cut2,
            cameraProvider: () async => <CameraDescription>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Even on error path, the layout badge is rendered.
      expect(find.text('2 CUT'), findsOneWidget);
    });

    testWidgets('back navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const HomeScreen()),
      );
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump();
      expect(find.text(AppTheme.brand), findsOneWidget);
    });
  });
}
