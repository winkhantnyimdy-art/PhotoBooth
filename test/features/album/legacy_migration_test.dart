import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/album/album_record.dart';
import 'package:photo_booth/features/album/album_service.dart';
import 'package:photo_booth/features/album/album_store.dart';
import 'package:photo_booth/features/album/album_session.dart';
import 'package:photo_booth/features/album/legacy_migration.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/home/layout_model.dart';

import '../../support/fake_album.dart';

/// A stand-in for the browser's localStorage during migration.
class _FakeLegacyStorage {
  _FakeLegacyStorage(this.payload);

  String? payload;
  String? backup;
  bool cleared = false;

  Future<String?> read() async => payload;

  Future<void> writeBackup(String value) async => backup = value;

  Future<void> clearPayload() async {
    cleared = true;
    payload = null;
  }
}

LegacyAlbumMigration _migration(
  _FakeLegacyStorage storage,
  AlbumStore store,
) =>
    LegacyAlbumMigration(
      readLegacyPayload: storage.read,
      backupLegacyPayload: storage.writeBackup,
      clearLegacyPayload: storage.clearPayload,
      store: store,
    );

/// A legacy payload exactly as the superseded localStorage backend wrote it.
String _legacyPayload(List<Map<String, dynamic>> sessions) =>
    jsonEncode(sessions);

Map<String, dynamic> _legacySession({
  required String id,
  required DateTime createdAt,
  int photoCount = 2,
}) {
  return <String, dynamic>{
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'layout': PhotoLayout.korean4.name,
    'photoBytes': <String>[
      for (int i = 0; i < photoCount; i++) base64Encode(testPngBytes()),
    ],
    'decorationState': decorationStateToJson(
      DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.skyBlue,
        style: DecorativeStyle.stars,
        showDate: true,
      ),
    ),
    'thumbnailBytes': base64Encode(testPngBytes()),
    'name': null,
  };
}

void main() {
  group('LegacyAlbumMigration', () {
    test('moves localStorage sessions into the new store', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(
        _legacyPayload(<Map<String, dynamic>>[
          _legacySession(id: 'a', createdAt: DateTime(2024, 2, 1)),
          _legacySession(id: 'b', createdAt: DateTime(2024, 3, 1), photoCount: 4),
        ]),
      );

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.migrated, 2);
      expect(report.verified, isTrue);

      final List<AlbumRecord> records = await store.readAllRecords();
      expect(records.map((AlbumRecord r) => r.id), containsAll(<String>['a', 'b']));

      // Photo bytes were moved out of the base64 payload into real blobs.
      expect(store.photoCount, 6);
      expect(store.photoKeys, contains('a/0'));
      expect(store.photoKeys, contains('b/3'));

      // Decoration survived the migration.
      final AlbumRecord a = records.firstWhere((AlbumRecord r) => r.id == 'a');
      final DecorationState decoration = decorationStateFromJson(a.decoration);
      expect(decoration.background, BackgroundChoice.skyBlue);
      expect(decoration.style, DecorativeStyle.stars);
      expect(decoration.showDate, isTrue);
    });

    test('clears the legacy payload only after verifying the move', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(
        _legacyPayload(<Map<String, dynamic>>[
          _legacySession(id: 'a', createdAt: DateTime(2024, 2, 1)),
        ]),
      );

      await _migration(storage, store).run();

      expect(storage.cleared, isTrue, reason: 'legacy data may be retired once verified');
      expect(
        storage.backup,
        isNotNull,
        reason: 'a backup copy must be kept before the original is dropped',
      );
      expect(await store.readAllRecords(), hasLength(1));
    });

    test('leaves the legacy payload untouched when verification fails',
        () async {
      // A store that silently drops everything it is given: the migration must
      // refuse to clear the user's data because it cannot prove the copy is
      // safe.
      final _SwallowingStore store = _SwallowingStore();
      final String payload =
          _legacyPayload(<Map<String, dynamic>>[
        _legacySession(id: 'a', createdAt: DateTime(2024, 2, 1)),
      ]);
      final _FakeLegacyStorage storage = _FakeLegacyStorage(payload);

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.verified, isFalse);
      expect(report.migrated, 0);
      expect(storage.cleared, isFalse);
      expect(storage.payload, payload, reason: 'original data must be recoverable');
    });

    test('is a no-op when there is no legacy payload', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(null);

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.didWork, isFalse);
      expect(report.migrated, 0);
      expect(storage.cleared, isFalse);
      expect(storage.backup, isNull);
    });

    test('unreadable legacy payloads are skipped, not thrown', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage('not json {{{');

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.migrated, 0);
      expect(report.message, isNotNull);
      // Nothing was migrated, so nothing may be destroyed.
      expect(storage.cleared, isFalse);
    });

    test('a payload that is not a list is skipped', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage('{"a":1}');

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.migrated, 0);
      expect(storage.cleared, isFalse);
    });

    test('corrupt legacy rows are counted and skipped without losing the rest',
        () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(
        jsonEncode(<Object?>[
          _legacySession(id: 'good1', createdAt: DateTime(2024, 1, 1)),
          <String, dynamic>{'id': 'bad', 'createdAt': 'nonsense'},
          _legacySession(id: 'good2', createdAt: DateTime(2024, 5, 1)),
        ]),
      );

      final LegacyMigrationReport report = await _migration(storage, store).run();

      expect(report.migrated, 2);
      expect(report.corrupt, 1);
      expect(
        (await store.readAllRecords()).map((AlbumRecord r) => r.id),
        containsAll(<String>['good1', 'good2']),
      );
      expect((await store.readAllRecords()).map((AlbumRecord r) => r.id),
          isNot(contains('bad')));
    });

    test('running twice is idempotent', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(
        _legacyPayload(<Map<String, dynamic>>[
          _legacySession(id: 'a', createdAt: DateTime(2024, 2, 1)),
        ]),
      );

      final StoreBackedAlbumService album =
          StoreBackedAlbumService(store, migrations: <LegacyAlbumMigration>[
        _migration(storage, store),
      ]);
      await album.initialize();
      await album.initialize();

      // Replaying with the payload still present must not duplicate rows.
      final List<AlbumSummary> summaries =
          (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value;
      expect(summaries.length, 1);
      expect(store.recordCount, 1);
      expect(store.photoCount, 2);
    });

    test('migrated sessions are immediately loadable through the service',
        () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final _FakeLegacyStorage storage = _FakeLegacyStorage(
        _legacyPayload(<Map<String, dynamic>>[
          _legacySession(id: 'legacy', createdAt: DateTime(2024, 2, 1)),
        ]),
      );
      final StoreBackedAlbumService album =
          StoreBackedAlbumService(store, migrations: <LegacyAlbumMigration>[
        _migration(storage, store),
      ]);

      final AlbumResult<AlbumSession> loaded = await album.loadSession('legacy');

      expect(loaded, isA<AlbumSuccess<AlbumSession>>());
      final AlbumSession session = (loaded as AlbumSuccess<AlbumSession>).value;
      expect(session.photoBytes.length, 2);
      expect(session.decorationState.background, BackgroundChoice.skyBlue);
    });
  });
}

/// A store that accepts writes but never keeps them, to simulate a failed
/// migration.
class _SwallowingStore extends InMemoryAlbumStore {
  @override
  Future<void> writeRecord(AlbumRecord record) async {}

  @override
  Future<void> writePhoto(String key, Uint8List bytes) async {}

  @override
  Future<void> deleteRecord(String id) async {}

  @override
  Future<void> deletePhotos(Iterable<String> keys) async {}
}