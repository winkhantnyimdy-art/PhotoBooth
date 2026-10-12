import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/export_screen.dart';
import 'package:photo_booth/features/export/export_service.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

import '../../support/fake_export_service.dart';

/// Records every export call so the widget test can assert on the seam
/// instead of touching the platform gallery / share sheet.
class FakeExportService extends RecordingExportService {
  int saveCalls = 0;
  int shareCalls = 0;

  final List<Uint8List> savedBytes = [];
  final List<String> savedFileNames = [];
  final List<Uint8List> sharedBytes = [];
  final List<String> sharedFileNames = [];

  bool failSave = false;
  bool failShare = false;

  /// When set, save/share stay pending until the completer completes.
  Completer<void>? saveGate;
  Completer<void>? shareGate;

  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {
    saveCalls++;
    savedBytes.add(bytes);
    savedFileNames.add(fileName);
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw Exception('gallery unavailable');
  }

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {
    shareCalls++;
    sharedBytes.add(bytes);
    sharedFileNames.add(fileName);
    if (shareGate != null) await shareGate!.future;
    if (failShare) throw Exception('share unavailable');
  }
}

/// Delegates to the real renderer so the success path yields a decodable PNG,
/// but can be told to fail the first N render attempts.
class ControllableRenderer extends PhotoStripRenderer {
  ControllableRenderer({this.failuresBeforeSuccess = 0});

  int renderCalls = 0;
  int failuresBeforeSuccess;

  @override
  Future<Uint8List> render({
    required PhotoLayout layout,
    required List<XFile> photos,
    required DecorationState decorationState,
  }) async {
    renderCalls++;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('renderer unavailable');
    }
    return super.render(
      layout: layout,
      photos: photos,
      decorationState: decorationState,
    );
  }
}

/// Drives the screen until rendering reaches a terminal state.
///
/// Rasterization happens on the engine's raster thread, which the widget test
/// fake-async zone will not advance on its own, so each step yields to the real
/// event loop via [WidgetTester.runAsync] before pumping a frame. The
/// indeterminate progress indicator animates forever, which is why
/// `pumpAndSettle` can never be used while a render is in flight.
Future<void> pumpUntilRenderSettles(WidgetTester tester) async {
  for (int attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.text('Save to Photos').evaluate().isNotEmpty) return;
    if (find
        .text('Failed to render photo strip. Please try again.')
        .evaluate()
        .isNotEmpty) {
      return;
    }
  }
  fail('Export never reached a terminal render state');
}

/// Lets the auto-dismissing SnackBar timers expire so the test does not end
/// with pending timers.
Future<void> drainSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  final DecorationState decorationState = const DecorationState(
    layout: PhotoLayout.grid4,
    background: BackgroundChoice.cream,
    style: DecorativeStyle.clean,
  );

  Widget buildExport({
    required ExportService service,
    PhotoStripRenderer? renderer,
  }) {
    return MaterialApp(
      home: ExportScreen(
        layout: PhotoLayout.grid4,
        photos: const <XFile>[],
        decorationState: decorationState,
        exportService: service,
        renderer: renderer,
      ),
    );
  }

  group('ExportScreen', () {
    testWidgets('shows preparing state then ready state', (tester) async {
      final FakeExportService service = FakeExportService();

      await tester.pumpWidget(buildExport(service: service));

      expect(find.text('Preparing your strip...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpUntilRenderSettles(tester);

      expect(find.text('Preparing your strip...'), findsNothing);
      expect(find.text('Save to Photos'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Make Another'), findsOneWidget);
      expect(service.saveCalls, 0);
      expect(service.shareCalls, 0);
    });

    testWidgets('defaults to the production service when none is injected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExportScreen(
            layout: PhotoLayout.grid4,
            photos: const <XFile>[],
            decorationState: decorationState,
          ),
        ),
      );

      await pumpUntilRenderSettles(tester);

      expect(find.text('Save to Photos'), findsOneWidget);
    });

    testWidgets('surfaces a render failure and recovers on retry', (
      tester,
    ) async {
      final FakeExportService service = FakeExportService();
      final ControllableRenderer renderer = ControllableRenderer(
        failuresBeforeSuccess: 1,
      );

      await tester.pumpWidget(
        buildExport(service: service, renderer: renderer),
      );
      await pumpUntilRenderSettles(tester);

      expect(renderer.renderCalls, 1);
      expect(
        find.text('Failed to render photo strip. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Save to Photos'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await pumpUntilRenderSettles(tester);

      expect(renderer.renderCalls, 2);
      expect(
        find.text('Failed to render photo strip. Please try again.'),
        findsNothing,
      );
      expect(find.text('Save to Photos'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Save invokes the injected export service', (tester) async {
      final FakeExportService service = FakeExportService();

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Save to Photos'));
      await tester.pumpAndSettle();

      expect(service.saveCalls, 1);
      expect(service.shareCalls, 0);
      expect(service.savedBytes.single, isNotEmpty);
      expect(
        service.savedFileNames.single,
        matches(RegExp(r'^PhotoBooth_\d{8}_\d{6}\.png$')),
      );
      // The exact rendered strip bytes are handed to the service.
      expect(
        service.savedBytes.single.take(4),
        orderedEquals(<int>[0x89, 0x50, 0x4E, 0x47]),
      );

      await drainSnackBars(tester);
    });

    testWidgets('Share invokes the injected export service', (tester) async {
      final FakeExportService service = FakeExportService();

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(service.shareCalls, 1);
      expect(service.saveCalls, 0);
      expect(service.sharedBytes.single, isNotEmpty);
      expect(
        service.sharedFileNames.single,
        matches(RegExp(r'^PhotoBooth_\d{8}_\d{6}\.png$')),
      );
    });

    testWidgets('shows success feedback after a successful save', (
      tester,
    ) async {
      final FakeExportService service = FakeExportService();

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Save to Photos'));
      await tester.pump();

      expect(find.text('Saved to Photos!'), findsOneWidget);

      await drainSnackBars(tester);
    });

    testWidgets('shows friendly feedback when saving fails', (tester) async {
      final FakeExportService service = FakeExportService()..failSave = true;

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Save to Photos'));
      await tester.pump();

      expect(find.text('Saved to Photos!'), findsNothing);
      expect(find.text('Failed to save image.'), findsOneWidget);

      await drainSnackBars(tester);
    });

    testWidgets('shows friendly feedback when sharing fails', (tester) async {
      final FakeExportService service = FakeExportService()..failShare = true;

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Share'));
      await tester.pump();

      expect(find.text('Failed to share image.'), findsOneWidget);

      await drainSnackBars(tester);
    });

    testWidgets('repeated Save taps do not race', (tester) async {
      final Completer<void> gate = Completer<void>();
      final FakeExportService service = FakeExportService()..saveGate = gate;

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Save to Photos'));
      await tester.pump();
      expect(service.saveCalls, 1);

      // The in-flight save disables the action, so extra taps are inert.
      await tester.tap(find.text('Save to Photos'), warnIfMissed: false);
      await tester.tap(find.text('Save to Photos'), warnIfMissed: false);
      await tester.pump();
      expect(service.saveCalls, 1);
      expect(service.savedFileNames, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(service.saveCalls, 1);
      expect(find.text('Saved to Photos!'), findsOneWidget);

      await drainSnackBars(tester);
    });

    testWidgets('repeated Share taps do not race', (tester) async {
      final Completer<void> gate = Completer<void>();
      final FakeExportService service = FakeExportService()..shareGate = gate;

      await tester.pumpWidget(buildExport(service: service));
      await pumpUntilRenderSettles(tester);

      await tester.tap(find.text('Share'));
      await tester.pump();
      expect(service.shareCalls, 1);

      await tester.tap(find.text('Share'), warnIfMissed: false);
      await tester.tap(find.text('Share'), warnIfMissed: false);
      await tester.pump();
      expect(service.shareCalls, 1);
      expect(service.sharedFileNames, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();

      expect(service.shareCalls, 1);
    });

    testWidgets('Make Another returns to Home', (tester) async {
      final FakeExportService service = FakeExportService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExportScreen(
                      layout: PhotoLayout.grid4,
                      photos: const <XFile>[],
                      decorationState: decorationState,
                      exportService: service,
                    ),
                  ),
                ),
                child: const Text('Go to Export'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Export'));
      await tester.pump();
      await pumpUntilRenderSettles(tester);
      // Finish the push transition. The incoming route is offset horizontally
      // while it animates, which would put the action row outside the viewport
      // and make the tap below miss. A fixed pump is used rather than
      // pumpAndSettle because the export spinner animates indefinitely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Save to Photos'), findsOneWidget);

      await tester.tap(find.text('Make Another'));
      await tester.pumpAndSettle();

      expect(find.text('Go to Export'), findsOneWidget);
      expect(find.text('Make Another'), findsNothing);
      expect(find.text('Save to Photos'), findsNothing);
    });
  });
}
