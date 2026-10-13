import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'package:photo_booth/features/album/album_record.dart';
import 'package:photo_booth/features/album/album_service.dart';
import 'package:photo_booth/features/album/album_store.dart';
import 'package:photo_booth/features/album/album_session.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// An album backed by memory, for tests.
///
/// Uses the production [StoreBackedAlbumService] logic on top of
/// [InMemoryAlbumStore], so persistence, listing, deletion and error handling
/// are exercised for real - only the byte-level storage is faked. That keeps
/// these tests meaningful instead of stubbing out the behaviour under test.
class FakeAlbumService extends StoreBackedAlbumService {
  FakeAlbumService({AlbumStore? store})
      : super(store ?? InMemoryAlbumStore());

  InMemoryAlbumStore get memoryStore => store as InMemoryAlbumStore;

  /// Seeds a session directly, bypassing the builder.
  Future<void> seed(AlbumSession session) => saveSession(session);
}

/// An [AlbumPhotoFiles] that writes real temporary files.
///
/// Deliberately not an in-memory `XFile.fromData`: the editor, the photo source
/// and the exporter all resolve photos by *path* on the VM, so only a real file
/// exercises the same code path a reopened session takes in production.
class FakeAlbumPhotoFiles implements AlbumPhotoFiles {
  FakeAlbumPhotoFiles({Directory? directory})
      : _directory = directory ??
            Directory('${Directory.systemTemp.path}/photobooth_test_album');

  final Directory _directory;
  final List<String> materialisedNames = <String>[];

  @override
  Future<XFile> materialize(Uint8List bytes, String fileName) async {
    materialisedNames.add(fileName);
    if (!await _directory.exists()) {
      await _directory.create(recursive: true);
    }
    final File file = File('${_directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: 'image/png');
  }

  @override
  Future<void> dispose() async {
    try {
      if (await _directory.exists()) await _directory.delete(recursive: true);
    } on Object {
      // Temp files are best-effort.
    }
  }
}

/// A tiny but structurally valid PNG used for photo and thumbnail fixtures.
///
/// Embedded as bytes rather than encoded at runtime so every fixture is
/// synchronously available, decodable by the real image pipeline, and cheap.
/// Decodes to a 1x1 image; tests assert on storage and routing behaviour, not
/// on picture content.
Uint8List testPngBytes() => Uint8List.fromList(_kTestPngBytes);

const List<int> _kTestPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, // IEND
  0xB0,
];

/// Builds a complete, valid [AlbumSession] for tests.
AlbumSession buildTestSession({
  String id = 'test-session',
  DateTime? createdAt,
  PhotoLayout layout = PhotoLayout.korean4,
  int photoCount = 4,
  DecorationState? decorationState,
  Uint8List? thumbnail,
  String? name,
}) {
  return AlbumSession(
    id: id,
    createdAt: createdAt ?? DateTime(2024, 5, 1, 12, 0),
    layout: layout,
    photoBytes: <Uint8List>[
      for (int i = 0; i < photoCount; i++) testPngBytes(),
    ],
    decorationState: decorationState ??
        DecorationState(
          layout: layout,
          background: BackgroundChoice.cream,
          style: DecorativeStyle.clean,
        ),
    thumbnailBytes: thumbnail ?? testPngBytes(),
    name: name,
  );
}

/// Convenience summary builder used by album-grid assertions.
AlbumSummary buildTestSummary({
  String id = 'test-session',
  DateTime? createdAt,
  PhotoLayout layout = PhotoLayout.korean4,
  int photoCount = 4,
  int missingPhotos = 0,
  Uint8List? thumbnail,
  String? name,
}) {
  return AlbumSummary(
    id: id,
    createdAt: createdAt ?? DateTime(2024, 5, 1, 12, 0),
    layoutName: layout.name,
    photoCount: photoCount,
    thumbnail: thumbnail,
    name: name,
    missingPhotos: missingPhotos,
  );
}