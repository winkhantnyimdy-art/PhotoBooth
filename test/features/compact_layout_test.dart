import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/export/export_screen.dart';
import 'package:photo_booth/features/export/export_service.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/home_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

class _FakeExportService implements ExportService {
  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {}

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {}
}

/// A transient profile: a small, short screen that is easy to break.
const Size _small = Size(320, 480);
const double _dpr = 3;

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

void _useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = Size(size.width * _dpr, size.height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
}

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

/// Every screen must lay out on a short screen without clipping its primary
/// action. An overflow throws during layout and fails the test.
void main() {
  group('Short-screen layout (320x480)', () {
    testWidgets('Home keeps the start action reachable', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();

      final Finder start = find.textContaining('Start Photo Booth');
      expect(start, findsOneWidget);
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(tester.getRect(start).width, lessThanOrEqualTo(320));
    });

    testWidgets('Review keeps both actions reachable', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      for (final String label in <String>['Next', 'Retake']) {
        final Finder finder = find.text(label);
        expect(finder, findsOneWidget, reason: label);
        final Rect rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
        expect(rect.height, greaterThan(0), reason: label);
      }
    });

    testWidgets('Decorate renders and keeps export reachable', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(
        _app(const DecorateScreen(layout: PhotoLayout.cut4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      final Finder export = find.textContaining('Finish & Save');
      expect(export, findsOneWidget);
      await tester.scrollUntilVisible(
        export,
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(export).right, lessThanOrEqualTo(320));
    });

    testWidgets('Export keeps all three actions reachable', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: PhotoStripRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      for (final String label in <String>[
        'Save to Photos',
        'Share',
        'Make Another',
      ]) {
        final Finder finder = find.text(label);
        expect(finder, findsOneWidget, reason: label);
        final Rect rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
        expect(rect.height, greaterThan(0), reason: label);

        // The control itself must still be a comfortable touch target, even
        // when vertical space is tight.
        final Size control = tester.getSize(
          find
              .ancestor(
                of: finder,
                // byType matches exact runtime types, so a predicate is needed
                // to catch every button subclass.
                matching: find.byWidgetPredicate(
                  (Widget w) => w is ButtonStyleButton,
                ),
              )
              .first,
        );
        expect(control.height, greaterThanOrEqualTo(44), reason: label);
        expect(control.width, lessThanOrEqualTo(320), reason: label);
      }
    });

    testWidgets('Export copy does not claim the strip is already saved', (
      tester,
    ) async {
      // A full-height surface, where the subtitle is shown.
      _useSurface(tester, const Size(390, 780));
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: PhotoStripRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      expect(find.text('Ready!'), findsOneWidget);
      expect(find.textContaining('Saved as'), findsNothing);
      expect(find.textContaining('Save or share it'), findsOneWidget);
    });

    testWidgets('Export drops the subtitle on a short screen', (tester) async {
      // Short screens prioritise the strip and the actions over the subtitle.
      _useSurface(tester, _small);
      await tester.pumpWidget(
        _app(
          ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: PhotoStripRenderer(),
          ),
        ),
      );
      await _settleRender(tester);

      expect(find.text('Ready!'), findsOneWidget);
      expect(find.textContaining('Save or share it'), findsNothing);
      // The copy must never claim it is saved before the user saves it.
      expect(find.textContaining('Saved as'), findsNothing);
    });
  });

  group('Text scaling', () {
    testWidgets('Home survives a 1.3x text scale', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const HomeScreen(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder start = find.textContaining('Start Photo Booth');
      expect(start, findsOneWidget);
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(tester.getRect(start).width, lessThanOrEqualTo(320));
    });

    testWidgets('Export actions survive a 1.3x text scale', (tester) async {
      _useSurface(tester, _small);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: ExportScreen(
            layout: PhotoLayout.cut4,
            photos: const <XFile>[],
            decorationState: _cleanCream,
            exportService: _FakeExportService(),
            renderer: PhotoStripRenderer(),
          ),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      );
      await _settleRender(tester);

      for (final String label in <String>[
        'Save to Photos',
        'Share',
        'Make Another',
      ]) {
        final Rect rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
      }
    });
  });
}
