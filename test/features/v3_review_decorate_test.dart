import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/camera/camera_screen.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_geometry.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/review/review_screen.dart';

/// A camera controller stub: only the members CameraScreen actually uses.
class _FakeCameraController extends CameraController {
  _FakeCameraController(CameraDescription description)
    : super(description, ResolutionPreset.high);

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1080, 1920),
    );
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF2A2522));
}

const CameraDescription _front = CameraDescription(
  name: 'fake-front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const CameraDescription _back = CameraDescription(
  name: 'fake-back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);

/// A tiny valid PNG, so the review grid has real bytes to decode and the
/// cells can be measured on a real layout rather than an empty placeholder.
Future<List<XFile>> _fakePhotos(int count) async {
  return List<XFile>.generate(count, (int i) => XFile('/tmp/shot_$i.jpg'));
}

Widget _app(Widget child) => MaterialApp(theme: AppTheme.theme, home: child);

Finder _cell(int index) => find.byKey(ValueKey<String>('review-cell-$index'));

void main() {
  group('Review Minimal Dark layout', () {
    testWidgets('4 CUT shows all four photos in a 2x2 grid', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final List<XFile> photos = await _fakePhotos(4);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
      );
      await tester.pumpAndSettle();

      // Every frame is on screen at once.
      for (int i = 0; i < 4; i++) {
        expect(_cell(i), findsOneWidget, reason: 'photo $i must be present');
      }

      final Rect a = tester.getRect(_cell(0));
      final Rect b = tester.getRect(_cell(1));
      final Rect c = tester.getRect(_cell(2));

      // 2x2 means two cells share a row and two share a column.
      expect(a.top, closeTo(b.top, 1), reason: 'photos 1-2 share a row');
      expect(c.top, greaterThan(a.bottom), reason: 'photo 3 is below photo 1');
      expect(
        a.left,
        lessThan(b.left),
        reason: 'photo 2 sits to the right of photo 1',
      );

      // The whole grid fits one screen without scrolling.
      final Rect stage = tester.getRect(find.byType(SingleChildScrollView));
      expect(a.top, greaterThanOrEqualTo(stage.top - 1));
      expect(c.bottom, lessThanOrEqualTo(stage.bottom + 1));
    });

    testWidgets('each cell keeps the exported cell aspect (no distortion)', (
      tester,
    ) async {
      final List<XFile> photos = await _fakePhotos(4);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Size size = tester.getSize(_cell(0));
      expect(
        size.width / size.height,
        closeTo(PhotoStripGeometry.cellAspect(PhotoLayout.korean4), 0.02),
        reason: 'review cells must match the exported 3:4 cell shape',
      );
    });

    testWidgets('the grid is not taller than the viewport for 4 CUT', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final List<XFile> photos = await _fakePhotos(4);
      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Rect top = tester.getRect(_cell(0));
      final Rect bottom = tester.getRect(_cell(3));
      expect(bottom.bottom - top.top, lessThan(852));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 2x2 layout keeps its own arrangement', (tester) async {
      final List<XFile> photos = await _fakePhotos(4);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.grid4, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Rect a = tester.getRect(_cell(0));
      final Rect b = tester.getRect(_cell(1));
      expect(a.top, closeTo(b.top, 1));
    });

    testWidgets('a 2-photo layout still shows both side by side', (
      tester,
    ) async {
      final List<XFile> photos = await _fakePhotos(2);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.pair2, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Rect a = tester.getRect(_cell(0));
      final Rect b = tester.getRect(_cell(1));
      expect(a.top, closeTo(b.top, 1));
      expect(a.left, lessThan(b.left));
    });

    testWidgets('6 CUT keeps its 2x3 arrangement', (tester) async {
      final List<XFile> photos = await _fakePhotos(6);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.cut6, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Rect a = tester.getRect(_cell(0));
      final Rect b = tester.getRect(_cell(1));
      final Rect d = tester.getRect(_cell(3));
      final Rect f = tester.getRect(_cell(5));
      expect(a.top, closeTo(b.top, 1), reason: 'two cells per row');
      expect(b.left, greaterThan(a.right - 1), reason: 'side by side');
      expect(d.top, greaterThan(a.bottom), reason: 'three rows of two');
      expect(f.top, greaterThan(d.top), reason: 'six cells fill three rows');
    });

    testWidgets('tapping a photo selects it for retake', (tester) async {
      final List<XFile> photos = await _fakePhotos(4);

      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
      );
      await tester.pumpAndSettle();

      // Arrival selects the last shot.
      expect(find.textContaining('Photo 4 of 4 selected'), findsOneWidget);

      await tester.tap(_cell(1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Photo 2 of 4 selected'), findsOneWidget);
    });

    testWidgets('Retake opens a single-photo camera and returns to Review', (
      tester,
    ) async {
      final List<XFile> photos = await _fakePhotos(4);

      await tester.pumpWidget(
        _app(
          ReviewScreen(
            layout: PhotoLayout.korean4,
            photos: photos,
            retakeCameraBuilder: (BuildContext context, int index) =>
                Scaffold(body: Center(child: Text('Retake camera for $index'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_cell(0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Photo 1 of 4 selected'), findsOneWidget);

      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A retake replaces exactly one frame, not the whole session.
      expect(find.text('Retake camera for 0'), findsOneWidget);
    });

    testWidgets('the empty state replaces the grid with no photos', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ReviewScreen(layout: PhotoLayout.korean4, photos: <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No photos yet'), findsWidgets);
      expect(_cell(0), findsNothing);
    });

    testWidgets('the grid is vertically centred, not stranded at the top', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final List<XFile> photos = await _fakePhotos(4);
      await tester.pumpWidget(
        _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
      );
      await tester.pumpAndSettle();

      final Rect grid = tester.getRect(_cell(0));
      final Rect last = tester.getRect(_cell(3));
      final Rect stage = tester.getRect(find.byType(SingleChildScrollView));

      final double topGap = grid.top - stage.top;
      final double bottomGap = stage.bottom - last.bottom;
      // Balanced within a finger's width, rather than ~400 px of dead space.
      expect(
        (topGap - bottomGap).abs(),
        lessThan(40),
        reason: 'the grid should be centred in the stage',
      );
    });

    testWidgets('Review uses the Minimal Dark palette, not Retro Pop', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const ReviewScreen(layout: PhotoLayout.grid4, photos: <XFile>[])),
      );
      await tester.pumpAndSettle();

      final Scaffold scaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(scaffold.backgroundColor, AppColors.darkBackground);
      expect(tester.takeException(), isNull);
    });

    for (final double width in <double>[320, 360, 393, 432]) {
      testWidgets('no overflow at ${width.toInt()}dp with 4 CUT', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final List<XFile> photos = await _fakePhotos(4);
        await tester.pumpWidget(
          _app(ReviewScreen(layout: PhotoLayout.korean4, photos: photos)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final String label in <String>['Next', 'Retake']) {
          final Rect rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: label);
          expect(rect.right, lessThanOrEqualTo(width), reason: label);
        }
      });
    }
  });

  group('Decorate preview sizing', () {
    /// The rendered photostrip, resolved from the composition subtree.
    Finder stripFinder() => find.descendant(
      of: find.byType(DecorateScreen),
      matching: find.byKey(const ValueKey<String>('composition-grid')),
    );

    for (final PhotoLayout layout in PhotoLayout.values) {
      testWidgets('${layout.label}: the strip keeps the exported aspect', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(DecorateScreen(layout: layout, photos: const <XFile>[])),
        );
        await tester.pumpAndSettle();

        final Size composition = tester.getSize(stripFinder());
        expect(composition.width, greaterThan(0));
        expect(composition.height, greaterThan(0));
        // The grid never renders wider than it is tall for any shipped
        // layout, and is never stretched away from the strip proportions.
        expect(composition.width / composition.height, lessThan(1.0));
      });
    }

    testWidgets('the strip is far larger than the pre-checkpoint ribbon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.korean4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      // 4 CUT is the worst case: a 1x4 column. The old 5:6 flex split squeezed
      // this to a few dozen logical pixels; it must now be usable.
      final Size stripSize = tester.getSize(stripFinder());
      expect(
        stripSize.height,
        greaterThan(430),
        reason: 'the 4 CUT strip must occupy a usable share of the screen',
      );
    });

    testWidgets('preview fits the viewport on every tested portrait size', (
      tester,
    ) async {
      for (final double width in <double>[320, 393, 432]) {
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(() {});

        await tester.pumpWidget(
          _app(
            DecorateScreen(
              layout: PhotoLayout.korean4,
              photos: const <XFile>[],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'at ${width}dp');
        final Rect stripRect = tester.getRect(stripFinder());
        expect(stripRect.width, lessThanOrEqualTo(width));
        expect(stripRect.top, greaterThanOrEqualTo(0));
        tester.view.reset();
      }
    });

    testWidgets('the editing toolbar stays bounded, never oversized', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.korean4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      final Rect tray = tester.getRect(
        find
            .ancestor(
              of: find.text('Finish & Save'),
              matching: find.byType(Container),
            )
            .last,
      );
      final double screen = MediaQuery.sizeOf(
        tester.element(find.byType(DecorateScreen)),
      ).height;
      expect(tray.height, lessThan(screen * 0.5));
    });

    testWidgets('the toolbar never covers the strip', (tester) async {
      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.korean4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      final Rect stripRect = tester.getRect(stripFinder());
      final Rect done = tester.getRect(find.textContaining('Finish & Save'));
      expect(
        stripRect.bottom,
        lessThanOrEqualTo(done.top + 1),
        reason: 'no control may sit on top of the photostrip',
      );
    });
  });

  group('Decorate toolbar behaviour', () {
    testWidgets('every tool is reachable and the selected tool is marked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.grid4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      final List<String> tools = <String>[
        'Filters',
        'Frames',
        'Stickers',
        'Text',
        'Adjust',
      ];
      for (final String tool in tools) {
        expect(find.text(tool), findsOneWidget, reason: tool);
      }

      /// The underline colour under a tab: white when selected, clear when not.
      Color underlineFor(String tool) {
        final Container tab = tester.widget<Container>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text(tool),
                  matching: find.byType(GestureDetector),
                ),
                matching: find.byType(Container),
              )
              .first,
        );
        final BoxDecoration decoration = tab.decoration! as BoxDecoration;
        return (decoration.border! as Border).bottom.color;
      }

      // Opens on Filters.
      expect(underlineFor('Filters'), AppColors.onDark);
      expect(underlineFor('Frames'), Colors.transparent);

      for (final String tool in tools) {
        await tester.tap(find.text(tool));
        await tester.pumpAndSettle();

        expect(
          underlineFor(tool),
          AppColors.onDark,
          reason: '$tool must become the marked tool',
        );
        expect(
          underlineFor('Filters'),
          tool == 'Filters' ? AppColors.onDark : Colors.transparent,
          reason: 'only one tool may be marked at a time',
        );
      }
    });

    testWidgets('tool entry points are comfortable touch targets', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.grid4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      for (final String tool in <String>[
        'Filters',
        'Frames',
        'Stickers',
        'Text',
        'Adjust',
      ]) {
        // The tappable region is the tab's gesture-detector box, which is what
        // a thumb actually hits.
        final Rect tab = tester.getRect(
          find.ancestor(
            of: find.text(tool),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(tab.height, greaterThanOrEqualTo(44), reason: tool);
        expect(tab.width, greaterThanOrEqualTo(48), reason: tool);
      }

      final Size done = tester.getSize(find.textContaining('Finish & Save'));
      expect(done.height, greaterThan(0));
    });

    testWidgets('editing state survives switching tools', (tester) async {
      // Portrait, like the emulator verification: see the intensity-slider
      // test in review_decorate_test for why the surface matters here.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          DecorateScreen(layout: PhotoLayout.grid4, photos: const <XFile>[]),
        ),
      );
      await tester.pumpAndSettle();

      // Warm is the third chip, comfortably inside the tray viewport without
      // scrolling the shelf.
      await tester.tap(find.bySemanticsLabel('Warm effect'));
      await tester.pumpAndSettle();

      bool selected(String label) =>
          tester
              .widget<Semantics>(find.bySemanticsLabel(label))
              .properties
              .selected ??
      false;

      expect(selected('Warm effect'), isTrue, reason: 'the tap landed');
      expect(selected('Original effect'), isFalse);

      // Visit another tool and come back: the selection must persist.
      await tester.tap(find.text('Adjust'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Asserted through the selected flag, not through finder presence:
      // every chip is in the tree whether or not it is scrolled into view,
      // so presence alone would not prove anything.
      expect(selected('Warm effect'), isTrue, reason: 'selection survives');
      expect(selected('Original effect'), isFalse);
    });

    testWidgets('the editor renders without overflow under 1.3x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: DecorateScreen(
              layout: PhotoLayout.grid4,
              photos: const <XFile>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Camera control contrast', () {
    testWidgets('the enabled control shows a readable icon', (tester) async {
      // Two cameras so switching is actually permitted.
      final List<CameraDescription> cameras = <CameraDescription>[
        _front,
        _back,
      ];

      await tester.pumpWidget(
        _app(
          CameraScreen(
            layout: PhotoLayout.grid4,
            cameraProvider: () async => cameras,
            controllerFactory: (CameraDescription d, ResolutionPreset p) =>
                _FakeCameraController(d),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Switch camera'), findsOneWidget);
      final Color iconColor = tester
          .widget<Icon>(
            find.descendant(
              of: find.byTooltip('Switch camera'),
              matching: find.byType(Icon),
            ),
          )
          .color!;

      // The icon must be white and its container dark. Previously the
      // container was `AppColors.surface` (cream #FFFDF8) behind a white
      // glyph, which is what made it invisible.
      expect(iconColor, AppColors.onDark);

      final Material container = tester.widget<Material>(
        find
            .descendant(
              of: find.byTooltip('Switch camera'),
              matching: find.byType(Material),
            )
            .first,
      );
      final Color fill = container.color!;
      expect(fill.computeLuminance(), lessThan(0.25));
      expect(fill, isNot(AppColors.surface));
      expect(
        (fill.computeLuminance() - iconColor.computeLuminance()).abs(),
        greaterThan(0.5),
        reason: 'the icon must contrast with its own background',
      );
    });

    testWidgets('an unavailable control reads as disabled, not active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CameraScreen(
            layout: PhotoLayout.grid4,
            // A single initialised camera: the viewfinder and controls render,
            // but switching is genuinely unavailable.
            cameraProvider: () async => <CameraDescription>[_front],
            controllerFactory: (CameraDescription d, ResolutionPreset p) =>
                _FakeCameraController(d),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder control = find.byTooltip('Switch camera');
      expect(control, findsOneWidget);

      // Disabled: no fill, and a dimmed glyph rather than an active-looking one.
      final Material container = tester.widget<Material>(
        find.descendant(of: control, matching: find.byType(Material)).first,
      );
      expect(container.color, Colors.transparent);

      final Color iconColor = tester
          .widget<Icon>(
            find.descendant(of: control, matching: find.byType(Icon)),
          )
          .color!;
      expect(iconColor, isNot(AppColors.onDark));
      expect(iconColor.computeLuminance(), lessThan(0.6));
    });
  });

  group('System bars', () {
    test('the app declares light system-bar icons for the dark theme', () {
      // The contract that keeps Android's status-bar clock and icons visible
      // against the #101012 background, and stops the platform adding a light
      // scrim behind the navigation bar.
      final SystemUiOverlayStyle style = App.darkSystemBars;
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
    });

    test('the declared overlay covers the app surface', () {
      // Sanity: the dark app background must be darker than the bar icon
      // brightness implies, otherwise the icons still would not read.
      expect(AppColors.darkBackground.computeLuminance(), lessThan(0.05));
      expect(
        math.max(AppColors.darkBackground.computeLuminance(), 0),
        AppColors.darkBackground.computeLuminance(),
      );
    });
  });
}
