import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/export_screen.dart';
import 'package:photo_booth/features/export/export_service.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

class _FakeExportService implements ExportService {
  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {}

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {}
}

/// Renders the real strip so the preview has genuine bytes to lay out.
class _RealRenderer extends PhotoStripRenderer {}

/// Always throws, to exercise the error/retry presentation.
class _AlwaysFailingRenderer extends PhotoStripRenderer {
  @override
  Future<Uint8List> render({
    required PhotoLayout layout,
    required List<XFile> photos,
    required DecorationState decorationState,
  }) async {
    throw StateError('renderer unavailable');
  }
}

/// Drives the export screen until the finished strip is available.
///
/// Rasterization runs off the widget test's fake-async zone, so each step
/// yields to the real event loop before pumping a frame.
Future<void> _settleRender(WidgetTester tester) async {
  for (int i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.text('Save to Photos').evaluate().isNotEmpty) return;
  }
  fail('export never reached the ready state');
}

const DecorationState _cleanCream = DecorationState(
  layout: PhotoLayout.cut4,
  background: BackgroundChoice.cream,
  style: DecorativeStyle.clean,
);

/// Logical widths the design must support.
const List<double> _widths = <double>[320, 375, 390, 430];

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

void main() {
  group('ExportScreen responsive layout', () {
    for (final double width in _widths) {
      testWidgets('all actions are reachable at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 700 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            ExportScreen(
              layout: PhotoLayout.cut4,
              photos: const <XFile>[],
              decorationState: _cleanCream,
              exportService: _FakeExportService(),
              renderer: _RealRenderer(),
            ),
          ),
        );
        await _settleRender(tester);

        // The header reads as a finished keepsake, not a technical dump.
        expect(find.text('Your photos are ready!'), findsOneWidget);
        // The old technical label must not come back.
        expect(find.textContaining('Layout:'), findsNothing);

        for (final String label in <String>[
          'Save to Photos',
          'Share',
          'Make Another',
        ]) {
          final Finder finder = find.text(label);
          expect(finder, findsOneWidget, reason: '$label must be present');

          // On screen and tappable: nothing clipped or pushed off-viewport.
          final Rect rect = tester.getRect(finder);
          expect(
            rect.left,
            greaterThanOrEqualTo(0),
            reason: '$label is clipped on the left',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(width),
            reason: '$label is clipped on the right at ${width}px',
          );
          expect(rect.height, greaterThan(0));
        }
      });
    }

    testWidgets('save and share stay enabled when idle', (tester) async {
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut2,
            photos: const <XFile>[],
            decorationState: _cleanCream.copyWith(layout: PhotoLayout.cut2),
            exportService: _FakeExportService(),
            renderer: _RealRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save to Photos'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Share'),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('ExportScreen accessibility', () {
    testWidgets('preview is announced as an image', (tester) async {
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: _RealRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      expect(
        find.bySemanticsLabel('Preview of your finished photo strip'),
        findsOneWidget,
      );
    });

    testWidgets('each action keeps a distinct accessible name', (tester) async {
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: _RealRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      expect(find.bySemanticsLabel('Save to Photos'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      expect(find.bySemanticsLabel('Make Another'), findsOneWidget);
    });
  });

  group('ExportScreen error state', () {
    testWidgets('error fits a small screen and offers retry', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 480 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: _AlwaysFailingRenderer(),
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(
        find.text('Failed to render photo strip. Please try again.'),
        findsOneWidget,
      );
      final Rect retry = tester.getRect(find.text('Retry'));
      expect(retry.height, greaterThan(0));
      expect(retry.left, greaterThanOrEqualTo(0));
      expect(retry.right, lessThanOrEqualTo(320));
    });
  });
}
