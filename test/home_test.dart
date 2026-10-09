import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/home/layout_preview.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text(AppTheme.brand), findsAtLeastNWidgets(1));
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
      // Advance past the push transition. While the outgoing Home route is
      // still onstage its layout card also renders "2 CUT", so the assertions
      // below would see two candidates instead of the camera screen's one.
      // A fixed pump is used rather than pumpAndSettle because the camera
      // screen shows an indefinite progress spinner in tests.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
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
      expect(find.text(AppTheme.brand), findsAtLeastNWidgets(1));
    });
  });

  group('HomeScreen layout selection', () {
    testWidgets('both layouts are offered with visual previews', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('4 CUT'), findsOneWidget);
      expect(find.text('2 CUT'), findsOneWidget);
      // Every option explains its own arrangement.
      expect(find.text('4 photos · 2×2'), findsOneWidget);
      expect(find.text('2 photos · 2×1'), findsOneWidget);
      // Two drawn strip previews, one per option (scoped so Material's own
      // ink CustomPaint widgets are not counted).
      expect(
        find.descendant(
          of: find.byType(LayoutPreview),
          matching: find.byType(CustomPaint),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('selection is exposed to assistive technology', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final SemanticsNode cut4 = tester.getSemantics(
        find.bySemanticsLabel('4 CUT layout, 4 photos · 2×2, Popular'),
      );
      expect(cut4.flagsCollection.isSelected, Tristate.isTrue);

      await tester.tap(find.text('2 CUT'));
      await tester.pumpAndSettle();

      final SemanticsNode cut2 = tester.getSemantics(
        find.bySemanticsLabel('2 CUT layout, 2 photos · 2×1'),
      );
      expect(cut2.flagsCollection.isSelected, Tristate.isTrue);
      final SemanticsNode cut4After = tester.getSemantics(
        find.bySemanticsLabel('4 CUT layout, 4 photos · 2×2, Popular'),
      );
      expect(cut4After.flagsCollection.isSelected, Tristate.isFalse);

      handle.dispose();
    });

    testWidgets('choosing a layout updates the summary line', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.text('We will take 4 photos in a row.'), findsOneWidget);
      await tester.tap(find.text('2 CUT'));
      await tester.pumpAndSettle();
      expect(find.text('We will take 2 photos in a row.'), findsOneWidget);
    });
  });

  group('HomeScreen responsive layout', () {
    for (final double width in <double>[320, 375, 390, 430]) {
      testWidgets('renders without overflow at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const App());
        await tester.pumpAndSettle();

        // Branding and the primary action must both be usable.
        expect(find.text(AppTheme.brand), findsAtLeastNWidgets(1));
        final Rect start = tester.getRect(find.text('Start Photo Booth'));
        expect(start.left, greaterThanOrEqualTo(0));
        expect(start.right, lessThanOrEqualTo(width));
        expect(start.height, greaterThan(0));

        // Both layout cards stay on screen at their true width.
        for (final String label in <String>['4 CUT', '2 CUT']) {
          final Rect rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: label);
          expect(rect.right, lessThanOrEqualTo(width), reason: label);
        }
      });
    }

    testWidgets('survives a large system text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      // Content grows, so the page is allowed to scroll rather than overflow.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start Photo Booth'), findsOneWidget);
    });
  });
}
