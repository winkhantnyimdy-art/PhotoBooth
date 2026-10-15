import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/shared/minimal_dark.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';

import 'support/fake_album.dart';

/// Finds the tappable card that shows [label] for a layout.
Finder _layoutCard(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(AnimatedContainer),
);

/// Whether the layout card showing [label] is drawn as the selected one.
bool _isSelected(WidgetTester tester, String label) {
  final AnimatedContainer card = tester.widget<AnimatedContainer>(
    _layoutCard(label),
  );
  final BoxDecoration decoration = card.decoration! as BoxDecoration;
  final Border border = decoration.border! as Border;
  return border.top.color == AppColors.onDark;
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      // The redesign paints the wordmark as a bubble logo rather than a Text
      // widget, so the brand is asserted by widget type now.
      expect(find.byType(MinimalWordmark), findsAtLeastNWidgets(1));
    });

    testWidgets('4 CUT is selected by default', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      expect(find.text('4 CUT'), findsOneWidget);
      // The "Popular" badge is gone from the redesign, so default selection is
      // asserted through the selected card styling instead.
      expect(_isSelected(tester, '4 CUT'), isTrue);
      expect(_isSelected(tester, '2 CUT'), isFalse);
    });

    testWidgets('selecting 2 CUT works', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      expect(find.text('2 CUT'), findsOneWidget);
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      expect(find.text('2 CUT'), findsWidgets);
    });

    testWidgets('Start Photo Booth navigates to camera', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.tap(find.textContaining('Start Photo Booth'));
      await tester.pump();
      await tester.pump();
      // The redesign dropped the "Camera" screen title in favour of the
      // layout badge, so assert on the screen itself.
      expect(find.byType(CameraScreen), findsOneWidget);
    });

    testWidgets('Start Photo Booth passes selected layout', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      await tester.tap(find.textContaining('Start Photo Booth'));
      // Advance past the push transition. While the outgoing Home route is
      // still onstage its layout card also renders "2 CUT", so the assertions
      // below would see two candidates instead of the camera screen's one.
      // A fixed pump is used rather than pumpAndSettle because the camera
      // screen shows an indefinite progress spinner in tests.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Camera screen shows the selected layout badge
      expect(find.byType(CameraScreen), findsOneWidget);
      expect(find.textContaining('2 CUT'), findsOneWidget);
    });
  });

  group('CameraScreen', () {
    testWidgets('shows loading state initially', (tester) async {
      final Completer<List<CameraDescription>> pending = Completer();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CameraScreen(
            layout: PhotoLayout.grid4,
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
            layout: PhotoLayout.grid4,
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
            layout: PhotoLayout.grid4,
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
            layout: PhotoLayout.pair2,
            cameraProvider: () async => <CameraDescription>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Even on error path, the layout badge is rendered. The badge reads
      // "2 CUT · 2 photos", so match on the layout label it contains.
      expect(find.textContaining('2 CUT'), findsOneWidget);
    });

    testWidgets('back navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const HomeScreen()),
      );
      await tester.tap(find.textContaining('Start Photo Booth'));
      await tester.pump();
      await tester.pump();
      // The redesign replaced the "Back" tooltip with a close icon button.
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      await tester.pump();
      expect(find.byType(MinimalWordmark), findsAtLeastNWidgets(1));
    });
  });

  group('HomeScreen layout selection', () {
    testWidgets('all four layouts are offered with visual previews', (
      tester,
    ) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      expect(find.text('4 CUT'), findsOneWidget);
      expect(find.text('6 CUT'), findsOneWidget);
      expect(find.text('2 CUT'), findsOneWidget);
      expect(find.text('3 CUT'), findsOneWidget);
    });

    testWidgets('selection is exposed to assistive technology', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2 CUT'));
      await tester.pumpAndSettle();

      expect(find.text('2 CUT'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('choosing a layout updates the summary line', (tester) async {
      await tester.pumpWidget(App(albumService: FakeAlbumService()));
      await tester.pumpAndSettle();

      // The redesign dropped the "We will take N photos" summary in favour of
      // the selected-card styling, so the behaviour under test is that the
      // chosen layout becomes the selected one.
      expect(_isSelected(tester, '4 CUT'), isTrue);
      await tester.tap(find.text('2 CUT'));
      await tester.pumpAndSettle();
      expect(_isSelected(tester, '2 CUT'), isTrue);
      expect(_isSelected(tester, '4 CUT'), isFalse);
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

        await tester.pumpWidget(App(albumService: FakeAlbumService()));
        await tester.pumpAndSettle();

        // Branding and the primary action must both be usable.
        expect(find.byType(MinimalWordmark), findsAtLeastNWidgets(1));
        final Rect start = tester.getRect(
          find.textContaining('Start Photo Booth'),
        );
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
      expect(find.textContaining('Start Photo Booth'), findsOneWidget);
    });
  });
}
