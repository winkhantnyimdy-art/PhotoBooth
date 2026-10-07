import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Interface for platform-specific export operations.
abstract class ExportService {
  /// Saves image bytes to the device photo gallery.
  Future<void> saveToGallery(Uint8List bytes, String fileName);

  /// Shares image bytes using the native share sheet.
  Future<void> shareImage(Uint8List bytes, String fileName);
}

/// Production implementation of [ExportService].
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

  Future<String> _writeToTempFile(Uint8List bytes, String fileName) async {
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
