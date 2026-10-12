import 'dart:typed_data';

import 'package:photo_booth/features/export/export_service.dart';

/// A no-op [ExportService] for widget tests that exercise layout rather than
/// the platform gallery or share sheet.
///
/// Extend it and override only the seam a test actually cares about.
class RecordingExportService implements ExportService {
  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {}

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {}

  @override
  String get saveLabel => 'Save to Photos';

  @override
  String get saveMessage => 'Saved to Photos!';

  @override
  String? get saveHint => null;
}