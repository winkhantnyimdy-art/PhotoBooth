import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_filter.dart';
import 'package:photo_booth/features/album/album_record.dart';
import 'package:photo_booth/features/album/album_service.dart';
import 'package:photo_booth/features/album/album_session.dart';
import 'package:photo_booth/features/album/album_store.dart';
import 'package:photo_booth/features/album/legacy_migration.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/home/layout_model.dart';

import '../../support/fake_album.dart';

void main() {
  group('AlbumRecord', () {
    test('photo keys are derived from the session id and index', () {
      final AlbumRecord record = AlbumRecord(
        id: 'abc',
        createdAt: DateTime(2024, 1, 1),
        layoutName: PhotoLayout.grid4.name,
        decoration: decorationStateToJson(
          DecorationState(
            layout: PhotoLayout.grid4,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
          ),
        ),
        photoKeys: const <String>['stale/0', 'stale/1'],
      );

      expect(record.photoKey(0), 'abc/0');
      expect(record.photoKey(3), 'abc/3');
      // Keys are regenerated positionally, so a stale or tampered key list
      // cannot point a session at another session's photos.
      expect(
        record.resolvePhotoKeys(),
        <String>['abc/0', 'abc/1'],
      );
      expect(record.photoCount, 2);
    });

    test('round-trips through JSON including the thumbnail', () {
      final AlbumRecord original = AlbumRecord(
        id: 's1',
        createdAt: DateTime(2024, 3, 4, 5, 6),
        layoutName: PhotoLayout.korean4.name,
        decoration: decorationStateToJson(
          DecorationState(
            layout: PhotoLayout.korean4,
            background: BackgroundChoice.charcoal,
            style: DecorativeStyle.stars,
            showDate: true,
            filter: PhotoFilterType.retroFilm,
            filterIntensity: 0.4,
            frameTheme: FrameTheme.vintageFilm,
          ),
        ),
        photoKeys: const <String>['s1/0', 's1/1'],
        thumbnail: testPngBytes(),
        name: 'Trip',
      );

      final AlbumRecord restored = AlbumRecord.decodeTolerant(original.toJson())!;

      expect(restored.id, 's1');
      expect(restored.createdAt, original.createdAt);
      expect(restored.layoutName, original.layoutName);
      expect(restored.name, 'Trip');
      expect(restored.photoKeys, original.photoKeys);
      expect(restored.thumbnail, isNotNull);
      expect(
        decorationStateFromJson(restored.decoration).filter,
        PhotoFilterType.retroFilm,
      );
      expect(
        decorationStateFromJson(restored.decoration).frameTheme,
        FrameTheme.vintageFilm,
      );
    });

    test('decodeTolerant rejects unusable rows instead of throwing', () {
      expect(AlbumRecord.decodeTolerant(null), isNull);
      expect(AlbumRecord.decodeTolerant('not a map'), isNull);
      expect(AlbumRecord.decodeTolerant(<String, Object?>{}), isNull);
      expect(
        AlbumRecord.decodeTolerant(<String, Object?>{'id': 'x'}),
        isNull,
        reason: 'a row without createdAt/decoration is unusable',
      );
      expect(
        AlbumRecord.decodeTolerant(<String, Object?>{
          'id': 'x',
          'createdAt': 'not a date',
          'decoration': <String, Object?>{},
        }),
        isNull,
      );
    });

    test('summary reports missing photos as damaged', () {
      final AlbumRecord record = AlbumRecord(
        id: 's1',
        createdAt: DateTime(2024),
        layoutName: PhotoLayout.pair2.name,
        decoration: decorationStateToJson(
          DecorationState(
            layout: PhotoLayout.pair2,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
          ),
        ),
        photoKeys: const <String>['s1/0', 's1/1'],
      );

      final AlbumSummary healthy = record.toSummary(missingPhotos: 0);
      final AlbumSummary broken = record.toSummary(missingPhotos: 1);

      expect(healthy.isDamaged, isFalse);
      expect(healthy.photoCount, 2);
      expect(broken.isDamaged, isTrue);
    });
  });

  group('StoreBackedAlbumService persistence', () {
    late FakeAlbumService album;
    late InMemoryAlbumStore store;

    setUp(() {
      album = FakeAlbumService();
      store = album.memoryStore;
    });

    test('starts empty', () async {
      final AlbumResult<List<AlbumSummary>> result = await album.listSessions();
      expect(result, isA<AlbumSuccess<List<AlbumSummary>>>());
      expect((result as AlbumSuccess<List<AlbumSummary>>).value, isEmpty);
    });

    test('saving then listing returns a summary without photo bytes',
        () async {
      await album.seed(buildTestSession(id: 's1', photoCount: 4));

      final AlbumSummary summary = (await album.listSessions()
          as AlbumSuccess<List<AlbumSummary>>).value.single;

      expect(summary.id, 's1');
      expect(summary.photoCount, 4);
      expect(summary.isDamaged, isFalse);
      // The grid summary deliberately carries no full-resolution photos.
      expect(summary.thumbnail, isNotNull);

      // Photos are stored as separate blobs, one per shot.
      expect(store.photoCount, 4);
      expect(store.photoKeys, contains('s1/0'));
      expect(store.photoKeys, contains('s1/3'));
    });

    test('loadSession returns the original photo bytes and decoration',
        () async {
      final DecorationState decoration = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.lavender,
        style: DecorativeStyle.hearts,
        showDate: true,
        filter: PhotoFilterType.dreamyPink,
        filterIntensity: 0.6,
        frameTheme: FrameTheme.kawaii,
        stickers: <StickerPlacement>[
          StickerPlacement(type: StickerType.heart, x: 0.4, y: 0.6),
        ],
        texts: <TextPlacement>[
          TextPlacement(text: 'Hello!', x: 0.5, y: 0.9),
        ],
      );
      await album.seed(
        buildTestSession(id: 's1', photoCount: 4, decorationState: decoration),
      );

      final loaded =
          await album.loadSession('s1') as AlbumSuccess<AlbumSession>;

      expect(loaded.value.photoBytes.length, 4);
      expect(loaded.value.layout, PhotoLayout.korean4);
      expect(loaded.value.decorationState.background, BackgroundChoice.lavender);
      expect(loaded.value.decorationState.style, DecorativeStyle.hearts);
      expect(loaded.value.decorationState.showDate, isTrue);
      expect(loaded.value.decorationState.filter, PhotoFilterType.dreamyPink);
      expect(loaded.value.decorationState.filterIntensity, 0.6);
      expect(loaded.value.decorationState.frameTheme, FrameTheme.kawaii);
      expect(loaded.value.decorationState.stickers.single.type, StickerType.heart);
      expect(loaded.value.decorationState.texts.single.text, 'Hello!');
    });

    test('a session with evicted photos fails without browser wording', () async {
      // Regression test for the Android release: the failure used to blame
      // "the browser" on every platform. Widget tests run on the VM
      // (kIsWeb == false), so this covers the native copy.
      await album.seed(buildTestSession(id: 's1', photoCount: 2));
      await store.deletePhotos(<String>['s1/0', 's1/1']);

      final AlbumResult<AlbumSession> result = await album.loadSession('s1');

      expect(result, isA<AlbumFailure<AlbumSession>>());
      final String error = (result as AlbumFailure<AlbumSession>).error;
      expect(error, contains('could not be found'));
      expect(error.toLowerCase(), isNot(contains('browser')));
    });

    test('re-saving the same id updates in place instead of duplicating',
        () async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));

      await album.saveSession(
        buildTestSession(id: 's1', photoCount: 2, name: 'Renamed').copyWith(
          decorationState: DecorationState(
            layout: PhotoLayout.pair2,
            background: BackgroundChoice.charcoal,
            style: DecorativeStyle.sparkle,
          ),
        ),
      );

      final List<AlbumSummary> sessions =
          (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value;

      expect(sessions.length, 1, reason: 'an edit must not create a second entry');
      expect(sessions.single.name, 'Renamed');

      final AlbumSession reloaded =
          (await album.loadSession('s1') as AlbumSuccess<AlbumSession>).value;
      expect(
        reloaded.decorationState.background,
        BackgroundChoice.charcoal,
        reason: 'the edit replaced the decoration',
      );
    });

    test('sessions are listed newest first', () async {
      await album.seed(
        buildTestSession(id: 'old', createdAt: DateTime(2024, 1, 1)),
      );
      await album.seed(
        buildTestSession(id: 'new', createdAt: DateTime(2024, 6, 1)),
      );
      await album.seed(
        buildTestSession(id: 'mid', createdAt: DateTime(2024, 3, 1)),
      );

      final List<AlbumSummary> sessions =
          (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value;

      expect(sessions.map((AlbumSummary s) => s.id), <String>['new', 'mid', 'old']);
    });

    test('delete removes the record and its photo blobs', () async {
      await album.seed(buildTestSession(id: 's1', photoCount: 3));
      expect(store.photoCount, 3);

      final AlbumResult<void> result = await album.deleteSession('s1');

      expect(result, isA<AlbumSuccess<void>>());
      expect(store.recordCount, 0);
      expect(store.photoCount, 0, reason: 'orphaned photos must not be left behind');
    });

    test('deleting an unknown id is a no-op, not an error', () async {
      final AlbumResult<void> result = await album.deleteSession('nope');
      expect(result, isA<AlbumSuccess<void>>());
    });

    test('clearAll empties records and photos', () async {
      await album.seed(buildTestSession(id: 'a', photoCount: 2));
      await album.seed(buildTestSession(id: 'b', photoCount: 2));

      await album.clearAll();

      expect(store.recordCount, 0);
      expect(store.photoCount, 0);
    });

    test('storage usage sums thumbnails and photo blobs', () async {
      await album.seed(buildTestSession(id: 'a', photoCount: 2));
      final AlbumResult<int?> usage = await album.getStorageUsage();

      expect(usage, isA<AlbumSuccess<int?>>());
      final int? bytes = (usage as AlbumSuccess<int?>).value;
      expect(bytes, isNotNull);
      expect(bytes!, greaterThan(0));
    });
  });

  group('StoreBackedAlbumService resilience', () {
    test('a session whose photos vanished is reported as damaged and cannot '
        'be opened', () async {
      final FakeAlbumService album = FakeAlbumService();
      await album.seed(buildTestSession(id: 's1', photoCount: 4));

      // Simulate the browser evicting blobs (or site data being cleared)
      // while the metadata row survives.
      await album.memoryStore.deletePhotos(<String>['s1/1', 's1/2']);

      final AlbumSummary summary = (await album.listSessions()
          as AlbumSuccess<List<AlbumSummary>>).value.single;
      expect(summary.isDamaged, isTrue);
      expect(summary.missingPhotos, 2);

      final AlbumResult<AlbumSession> opened = await album.loadSession('s1');
      expect(opened, isA<AlbumFailure<AlbumSession>>());
      expect(
        (opened as AlbumFailure<AlbumSession>).kind,
        AlbumErrorKind.corrupt,
      );
      expect(opened.error, contains('2 of 4'));
    });

    test('loading a missing session fails cleanly', () async {
      final FakeAlbumService album = FakeAlbumService();
      final AlbumResult<AlbumSession> result = await album.loadSession('ghost');

      expect(result, isA<AlbumFailure<AlbumSession>>());
      expect(
        (result as AlbumFailure<AlbumSession>).kind,
        AlbumErrorKind.corrupt,
      );
    });

    test('a session with no photos is refused rather than stored empty',
        () async {
      final FakeAlbumService album = FakeAlbumService();
      final AlbumResult<void> result = await album.saveSession(
        buildTestSession(id: 'empty', photoCount: 0),
      );

      expect(result, isA<AlbumFailure<void>>());
      expect(album.memoryStore.recordCount, 0);
    });

    test('a corrupt stored row is skipped without hiding healthy sessions',
        () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final FakeAlbumService album = FakeAlbumService(store: store);
      await album.seed(buildTestSession(id: 'good'));

      // A row written by an older build, or truncated by a failed write.
      await store.writeRecord(
        AlbumRecord(
          id: 'broken',
          createdAt: DateTime(2024, 1, 1),
          layoutName: PhotoLayout.grid4.name,
          decoration: <String, dynamic>{},
          photoKeys: const <String>['broken/0'],
        ),
      );

      final List<AlbumSummary> sessions =
          (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value;

      // "broken" has an unusable decoration map, so only the healthy row shows.
      expect(sessions.map((AlbumSummary s) => s.id), <String>['good']);
    });

    test('quota errors surface a storage-full message', () async {
      final _QuotaStore store = _QuotaStore();
      final StoreBackedAlbumService album = StoreBackedAlbumService(store);
      await album.initialize();

      final AlbumResult<void> result = await album.saveSession(
        buildTestSession(id: 's1'),
      );

      expect(result, isA<AlbumFailure<void>>());
      final AlbumFailure<void> failure = result as AlbumFailure<void>;
      expect(failure.kind, AlbumErrorKind.quotaExceeded);
      expect(failure.error, contains('out of storage space'));
      expect(
        failure.error,
        isNot(contains('QuotaExceededError')),
        reason: 'raw driver strings must never reach the user',
      );
    });
  });

  group('StoreBackedAlbumService migrations', () {
    test('runs registered migrations once on first use', () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      int runs = 0;
      final StoreBackedAlbumService album = StoreBackedAlbumService(
        store,
        migrations: <LegacyAlbumMigration>[
          _countingMigration(store, () => runs++),
        ],
      );

      await album.initialize();
      await album.initialize();
      await album.listSessions();

      expect(runs, 1, reason: 'migrations must not re-run on every read');
    });

    test('a throwing migration does not prevent the album from opening',
        () async {
      final InMemoryAlbumStore store = InMemoryAlbumStore();
      final StoreBackedAlbumService album = StoreBackedAlbumService(
        store,
        migrations: <LegacyAlbumMigration>[_throwingMigration(store)],
      );

      final AlbumResult<void> result = await album.initialize();

      expect(result, isA<AlbumSuccess<void>>());
    });
  });
}

LegacyAlbumMigration _countingMigration(AlbumStore store, void Function() onRun) =>
    LegacyAlbumMigration(
      readLegacyPayload: () async {
        onRun();
        return null;
      },
      backupLegacyPayload: (String payload) async {},
      clearLegacyPayload: () async {},
      store: store,
    );

LegacyAlbumMigration _throwingMigration(AlbumStore store) => LegacyAlbumMigration(
      readLegacyPayload: () async => throw StateError('boom'),
      backupLegacyPayload: (String payload) async {},
      clearLegacyPayload: () async {},
      store: store,
    );

/// Minimal stand-in for a quota-exhausted store.
class _QuotaStore implements AlbumStore {
  final Map<String, AlbumRecord> _records = <String, AlbumRecord>{};

  @override
  String get backendName => 'Quota store';

  @override
  bool get supportsUsageReporting => true;

  @override
  Future<void> open() async {}

  @override
  Future<List<AlbumRecord>> readAllRecords() async => _records.values.toList();

  @override
  Future<AlbumRecord?> readRecord(String id) async => _records[id];

  @override
  Future<void> writeRecord(AlbumRecord record) async {
    throw const AlbumStorageError(
      'QuotaExceededError',
      kind: AlbumErrorKind.quotaExceeded,
    );
  }

  @override
  Future<void> deleteRecord(String id) async => _records.remove(id);

  @override
  Future<void> clear() async => _records.clear();

  @override
  Future<Uint8List?> readPhoto(String key) async => null;

  @override
  Future<void> writePhoto(String key, Uint8List bytes) async {
    throw const AlbumStorageError(
      'QuotaExceededError',
      kind: AlbumErrorKind.quotaExceeded,
    );
  }

  @override
  Future<void> deletePhotos(Iterable<String> keys) async {}

  @override
  Future<List<String>> listPhotoKeys() async => const <String>[];

  @override
  Future<int?> usageBytes() async => 0;

  @override
  Future<void> close() async {}
}