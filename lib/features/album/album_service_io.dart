import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import 'album_service.dart';
import 'album_store_factory.dart';

export 'album_service.dart';

/// Filesystem [AlbumService] for Android/iOS and desktop.
///
/// Wraps [FileAlbumStore]; all behaviour is inherited from
/// [StoreBackedAlbumService].
class AppAlbumService extends StoreBackedAlbumService {
  AppAlbumService()
      : super(FileAlbumStore());
}

/// Materialises stored album bytes into temporary files the editor can read.
class AppAlbumPhotoFiles implements AlbumPhotoFiles {
  @override
  Future<XFile> materialize(Uint8List bytes, String fileName) async {
    final Directory dir = await getTemporaryDirectory();
    final Directory album = Directory('${dir.path}/photobooth_album');
    if (!await album.exists()) {
      await album.create(recursive: true);
    }
    final File file = File('${album.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: _mimeTypeFor(fileName));
  }

  @override
  Future<void> dispose() async {
    final Directory dir = await getTemporaryDirectory();
    final Directory album = Directory('${dir.path}/photobooth_album');
    if (await album.exists()) {
      try {
        await album.delete(recursive: true);
      } on Object {
        // Temp files are best-effort; the OS reclaims them anyway.
      }
    }
  }

  static String _mimeTypeFor(String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}