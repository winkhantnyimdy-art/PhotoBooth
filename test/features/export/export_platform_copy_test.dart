import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/media/camera_unavailable_reason.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/export/export_screen.dart';
import 'package:photo_booth/features/export/export_service.dart';
import 'package:photo_booth/features/export/photo_strip_renderer.dart';
import 'package:photo_booth/features/home/layout_model.dart';

import '../../support/fake_export_service.dart';

/// An [ExportService] that reports the way a browser does: a download rather
/// than a write into the system photo library.
class _BrowserStyleExportService extends RecordingExportService {
  @override
  String get saveLabel => 'Download PNG';

  @override
  String get saveMessage => 'PNG downloaded';

  @override
  String? get saveHint =>
      'On iPhone the PNG saves to Files  Etap Share and choose '
      '"Save Image" to keep it in Photos.';
}

/// Renders instantly so the ready state is reachable without a real decode.
class _StubRenderer extends PhotoStripRenderer {
  @override
  Future<Uint8List> render({
    required PhotoLayout layout,
    required List<XFile> photos,
    required DecorationState decorationState,
  }) async {
    // A 1x1 opaque PNG is enough to satisfy the preview image.
    return _onePixelPng;
  }
}

/// A valid 1x1 opaque PNG, enough for the preview to have something to paint.
final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Future<void> pumpUntilReady(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Download PNG').evaluate().isNotEmpty ||
        find.text('Save to Photos').evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Export never reached the ready state');
}

Widget _app(ExportService service) => MaterialApp(
  theme: AppTheme.theme,
  home: ExportScreen(
    layout: PhotoLayout.grid4,
    photos: const <XFile>[],
    decorationState: const DecorationState(
      layout: PhotoLayout.grid4,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    ),
    exportService: service,
    renderer: _StubRenderer(),
  ),
);

void main() {
  group('ExportScreen platform-aware save copy', () {
    testWidgets('native copy promises a write into Photos', (tester) async {
      await tester.pumpWidget(_app(RecordingExportService()));
      await pumpUntilReady(tester);

      expect(find.text('Save to Photos'), findsOneWidget);
      // A browser-only caveat must never appear on native.
      expect(find.textContaining('saves to Files'), findsNothing);
    });

    testWidgets('browser copy offers a PNG download and explains Files', (
      tester,
    ) async {
      final _BrowserStyleExportService service = _BrowserStyleExportService();
      await tester.pumpWidget(_app(service));
      await pumpUntilReady(tester);

      expect(find.text('Download PNG'), findsOneWidget);
      expect(find.textContaining('saves to Files'), findsOneWidget);
      // The browser must not claim the photo landed in the photo library.
      expect(find.text('Save to Photos'), findsNothing);
    });

    testWidgets('browser save reports a download, not a gallery write', (
      tester,
    ) async {
      final _RecordingBrowserService service = _RecordingBrowserService();
      await tester.pumpWidget(_app(service));
      await pumpUntilReady(tester);

      await tester.tap(find.text('Download PNG'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(service.saveCalls, 1);
      expect(find.text('PNG downloaded'), findsOneWidget);
      expect(find.text('Saved to Photos!'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('CameraUnavailableReason', () {
    test('unknown reason carries actionable copy', () {
      expect(CameraUnavailableReason.unknown.title, isNotEmpty);
      expect(CameraUnavailableReason.unknown.detail, isNotEmpty);
    });
  });
}

class _RecordingBrowserService extends _BrowserStyleExportService {
  int saveCalls = 0;

  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {
    saveCalls++;
  }

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {}
}