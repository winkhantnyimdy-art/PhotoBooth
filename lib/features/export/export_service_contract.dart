import 'dart:typed_data';

/// Interface for platform-specific export operations.
///
/// The browser implementation deliberately reports `shareSupported == false`
/// for a plain "save", because a browser download lands in the Files app (or
/// the Downloads folder) and *not* in the Apple Photos library. The UI reads
/// [saveMessage] so it never promises something the platform cannot deliver.
abstract class ExportService {
  /// Saves image bytes to the device photo gallery (native) or triggers a
  /// browser download (web).
  Future<void> saveToGallery(Uint8List bytes, String fileName);

  /// Shares image bytes using the native share sheet or the Web Share API,
  /// falling back to a download when file sharing is unavailable.
  Future<void> shareImage(Uint8List bytes, String fileName);

  /// Label for the primary action button.
  String get saveLabel;

  /// Confirmation shown after a successful [saveToGallery].
  String get saveMessage;

  /// Extra guidance rendered under the primary action, or null.
  String? get saveHint;
}