import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export_service_contract.dart';

export 'export_service_contract.dart';

/// Production implementation of [ExportService] for Android/iOS.
///
/// Uses `gal` to write straight into the system photo library (which is what
/// makes "Save to Photos" true on these platforms) and `share_plus` for the
/// native share sheet.
class AppExportService implements ExportService {
  @override
  Future<void> saveToGallery(Uint8List bytes, String fileName) async {
    final String path = await _writeToTempFile(bytes, fileName);
    await Gal.putImage(path);
  }

  @override
  Future<void> shareImage(Uint8List bytes, String fileName) async {
    final String path = await _writeToTempFile(bytes, fileName);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'My PhotoBooth Strip!'),
    );
  }

  @override
  String get saveLabel => 'Save to Photos';

  @override
  String get saveMessage => 'Saved to Photos!';

  @override
  String? get saveHint => null;

  Future<String> _writeToTempFile(Uint8List bytes, String fileName) async {
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}