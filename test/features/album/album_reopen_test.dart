import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_filter.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/album/album_builder.dart';
import 'package:photo_booth/features/album/album_record.dart';
import 'package:photo_booth/features/album/album_scope.dart';
import 'package:photo_booth/features/album/album_screen.dart';
import 'package:photo_booth/features/album/album_service.dart';
import 'package:photo_booth/features/album/album_session.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/export/export_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';

import '../../support/fake_album.dart';

/// Boots the album screen with a real album wired through [AlbumScope].
///
/// [AlbumScope] sits outside `MaterialApp`, mirroring production, so routes
/// pushed by the album screen can still resolve the album.
Widget buildAlbumHost({
  required AlbumService album,
  required FakeAlbumPhotoFiles photos,
}) {
  return AlbumScope(
    service: album,
    child: MaterialApp(
      theme: AppTheme.theme,
      home: AlbumScreen(albumService: album, photoFiles: photos),
    ),
  );
}

/// Pumps until [finder] matches, letting real async work drain.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 200,
}) async {
  for (int i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}


void main() {
  group('Album session reopening', () {
    late Directory tempDir;
    late FakeAlbumService album;
    late FakeAlbumPhotoFiles photoFiles;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('album_reopen');
      album = FakeAlbumService();
      photoFiles = FakeAlbumPhotoFiles(directory: tempDir);
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } on Object {
        // Best effort.
      }
    });

    testWidgets('an empty album shows a clear empty state', (tester) async {
      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      expect(find.text('No saved sessions yet'), findsOneWidget);
      expect(find.text('Start Photo Booth'), findsOneWidget);
    });

    testWidgets('a saved session is listed with its photo count and layout',
        (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 4));

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('album-session-s1')), findsOneWidget);
      expect(find.text('4 photos · 4 CUT'), findsOneWidget);
    });

    testWidgets('tapping a session opens the editor with the saved state '
        'restored', (tester) async {
      final DecorationState saved = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.charcoal,
        style: DecorativeStyle.hearts,
        showDate: true,
        filter: PhotoFilterType.retroFilm,
        filterIntensity: 0.8,
        frameTheme: FrameTheme.vintageFilm,
        stickers: <StickerPlacement>[
          StickerPlacement(type: StickerType.bunny, x: 0.4, y: 0.6),
        ],
        texts: <TextPlacement>[
          TextPlacement(text: 'Reopened!', x: 0.5, y: 0.9),
        ],
        adjustments: const PhotoAdjustments(brightness: 0.2),
      );
      await album.seed(
        buildTestSession(id: 's1', photoCount: 4, decorationState: saved),
      );

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('album-session-s1')));
      await _pumpUntil(tester, find.byType(DecorateScreen));

      expect(find.byType(DecorateScreen), findsOneWidget);
      // Editing a saved session, not starting a new one.
      expect(find.text('Edit Session'), findsOneWidget);
      // The original photos were materialised for the editor.
      expect(photoFiles.materialisedNames, hasLength(4));

      // Sticker and caption came back.
      expect(find.bySemanticsLabel('Bunny sticker on the preview'), findsOneWidget);
      expect(find.bySemanticsLabel('Caption: Reopened!'), findsOneWidget);

      // The filter strength from the saved state is shown on the Filters tab.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(
        find.text('80%'),
        findsWidgets,
        reason: 'the saved filter intensity of 0.8 must be restored',
      );

      // The saved background colour is what the composition preview paints,
      // which is a direct read of the restored decoration state.
      expect(
        find.descendant(
          of: find.byType(DecorateScreen),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    BackgroundChoice.charcoal.color,
          ),
        ),
        findsWidgets,
      );

      // showDate came back, so the Frames tab switch is on.
      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(Switch),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('editing a reopened session and re-saving updates the album '
        'entry instead of duplicating it', (tester) async {
      await album.seed(
        buildTestSession(
          id: 's1',
          photoCount: 4,
          decorationState: DecorationState(
            layout: PhotoLayout.korean4,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
          ),
        ),
      );

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('album-session-s1')));
      await _pumpUntil(tester, find.byType(DecorateScreen));
      await tester.pumpAndSettle();

      // Make a real edit in the editor.
      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Lavender frame'),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.bySemanticsLabel('Lavender frame'));
      await tester.pumpAndSettle();

      // Finish and export.
      final Finder finish = find.textContaining('Finish & Save');
      await tester.scrollUntilVisible(
        finish,
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(finish);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _pumpUntil(tester, find.text('Save to Photos'));

      expect(find.byType(ExportScreen), findsOneWidget);
      // The export knows it is editing an existing album session.
      expect(find.text('Update album session'), findsOneWidget);

      await tester.tap(find.text('Update album session'));
      await _pumpUntil(tester, find.text('Album updated'));

      // The edit is persisted, and no second entry was created.
      final List<AlbumSummary> summaries =
          (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value;
      expect(summaries, hasLength(1));
      expect(summaries.single.id, 's1');

      final AlbumSession stored =
          (await album.loadSession('s1') as AlbumSuccess<AlbumSession>).value;
      expect(
        stored.decorationState.background,
        BackgroundChoice.lavender,
        reason: 'the re-save must carry the edited state',
      );
      expect(stored.photoBytes.length, 4);
    });

    testWidgets('a session with missing photos reports the problem instead of '
        'opening a broken editor', (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 4));
      // The browser evicted the blobs but kept the metadata row.
      await album.memoryStore.deletePhotos(<String>['s1/0', 's1/1', 's1/2', 's1/3']);

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      // The grid marks it as damaged rather than offering a broken reopen.
      expect(find.text('Photos missing'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('album-session-s1')));
      await tester.pumpAndSettle();

      expect(find.byType(DecorateScreen), findsNothing);
      expect(find.textContaining('could not be found'), findsOneWidget);
    });

    testWidgets('deleting a session asks for confirmation and then removes it',
        (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('album-session-s1')));
      await tester.pumpAndSettle();

      expect(find.text('Delete this session?'), findsOneWidget);

      // Backing out must not delete anything.
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('album-session-s1')), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('album-session-s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('album-session-s1')), findsNothing);
      expect(find.text('No saved sessions yet'), findsOneWidget);
      expect(await album.listSessions(), isA<AlbumSuccess<List<AlbumSummary>>>());
      expect(
        (await album.listSessions() as AlbumSuccess<List<AlbumSummary>>).value,
        isEmpty,
      );
    });

    testWidgets('clear-all requires explicit confirmation', (tester) async {
      await album.seed(buildTestSession(id: 'a', photoCount: 2));
      await album.seed(buildTestSession(id: 'b', photoCount: 2));

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Clear the whole album?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('album-session-a')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();

      expect(find.text('No saved sessions yet'), findsOneWidget);
      expect(album.memoryStore.recordCount, 0);
      expect(album.memoryStore.photoCount, 0);
    });

    testWidgets('the album explains that uninstalling erases it',
        (tester) async {
      await album.seed(buildTestSession(id: 's1', photoCount: 2));

      await tester.pumpWidget(buildAlbumHost(album: album, photos: photoFiles));
      await tester.pumpAndSettle();

      // Widget tests run on the VM (kIsWeb == false), so this covers the
      // native copy; the web copy keeps the browser wording.
      expect(
        find.textContaining('Uninstalling the app will erase the album.'),
        findsOneWidget,
      );
      expect(find.textContaining('Storage used:'), findsOneWidget);
    });
  });

  group('newAlbumSessionId', () {
    test('ids are unique across rapid successive saves', () {
      final Set<String> ids = <String>{
        for (int i = 0; i < 500; i++) newAlbumSessionId(),
      };
      expect(ids.length, 500);
    });
  });

  group('albumPhotoFiles', () {
    test('materialised files contain the exact original bytes', () async {
      final Directory dir = Directory.systemTemp.createTempSync('album_bytes');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final FakeAlbumPhotoFiles files = FakeAlbumPhotoFiles(directory: dir);

      final List<XFile> saved = <XFile>[
        XFile.fromData(testPngBytes(), name: 'a.png'),
      ];
      final List<Uint8List> originalBytes = <Uint8List>[testPngBytes()];

      final XFile restored = await files.materialize(originalBytes.first, 'a.png');

      expect(await restored.readAsBytes(), originalBytes.first);
      expect(saved, hasLength(1));
    });
  });
}
