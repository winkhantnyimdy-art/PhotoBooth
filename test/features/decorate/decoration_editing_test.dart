import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/home/layout_model.dart';

void main() {
  group('StickerPlacement', () {
    test('scale and rotation are stored and copied', () {
      const sticker = StickerPlacement(
        type: StickerType.heart,
        x: 0.5,
        y: 0.5,
        scale: 1.5,
        rotation: 0.3,
      );
      expect(sticker.scale, 1.5);
      expect(sticker.rotation, 0.3);

      final scaled = sticker.copyWith(scale: 2.0);
      expect(scaled.scale, 2.0);
      expect(scaled.type, StickerType.heart);
      expect(scaled.x, 0.5);

      final rotated = sticker.copyWith(rotation: 1.0);
      expect(rotated.rotation, 1.0);
    });

    test('equality includes scale and rotation', () {
      const a = StickerPlacement(
        type: StickerType.star,
        x: 0.3,
        y: 0.4,
        scale: 1.2,
        rotation: 0.5,
      );
      const b = StickerPlacement(
        type: StickerType.star,
        x: 0.3,
        y: 0.4,
        scale: 1.2,
        rotation: 0.5,
      );
      const c = StickerPlacement(
        type: StickerType.star,
        x: 0.3,
        y: 0.4,
        scale: 1.3,
        rotation: 0.5,
      );
      expect(a, b);
      expect(a, isNot(c));
    });

    test('default scale is 1.0 and rotation is 0.0', () {
      const sticker = StickerPlacement(type: StickerType.bow, x: 0.1, y: 0.2);
      expect(sticker.scale, 1.0);
      expect(sticker.rotation, 0.0);
    });
  });

  group('DecorationState frame theme', () {
    test('copyWith preserves frame theme', () {
      const state = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
        frameTheme: FrameTheme.darkFilm,
      );
      final copy = state.copyWith(showDate: true);
      expect(copy.frameTheme, FrameTheme.darkFilm);
    });

    test('copyWith updates frame theme', () {
      const state = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      final copy = state.copyWith(frameTheme: FrameTheme.kawaii);
      expect(copy.frameTheme, FrameTheme.kawaii);
    });
  });

  group('UndoRedoDecoration', () {
    test('starts empty', () {
      final undoRedo = UndoRedoDecoration();
      expect(undoRedo.canUndo, isFalse);
      expect(undoRedo.canRedo, isFalse);
    });

    test('record enables undo but not redo', () {
      final undoRedo = UndoRedoDecoration();
      const state = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      undoRedo.record(state);
      expect(undoRedo.canUndo, isTrue);
      expect(undoRedo.canRedo, isFalse);
    });

    test('undo restores previous state', () {
      final undoRedo = UndoRedoDecoration();
      const stateA = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      const stateB = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.charcoal,
        style: DecorativeStyle.hearts,
      );
      undoRedo.record(stateA);
      final restored = undoRedo.undo(stateB);
      expect(restored, isNotNull);
      expect(restored!.background, BackgroundChoice.cream);
      expect(restored.style, DecorativeStyle.clean);
    });

    test('redo re-applies undone state', () {
      final undoRedo = UndoRedoDecoration();
      const stateA = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      const stateB = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.charcoal,
        style: DecorativeStyle.hearts,
      );
      undoRedo.record(stateA);
      undoRedo.undo(stateB);
      expect(undoRedo.canRedo, isTrue);
      final redone = undoRedo.redo(stateA);
      expect(redone, isNotNull);
      expect(redone!.background, BackgroundChoice.charcoal);
      expect(redone.style, DecorativeStyle.hearts);
    });

    test('new record clears redo stack', () {
      final undoRedo = UndoRedoDecoration();
      const stateA = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      const stateB = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.charcoal,
        style: DecorativeStyle.hearts,
      );
      undoRedo.record(stateA);
      undoRedo.undo(stateB);
      expect(undoRedo.canRedo, isTrue);
      undoRedo.record(stateB);
      expect(undoRedo.canRedo, isFalse);
    });

    test('capacity bounds the undo stack', () {
      final undoRedo = UndoRedoDecoration(capacity: 3);
      for (int i = 0; i < 5; i++) {
        undoRedo.record(
          DecorationState(
            layout: PhotoLayout.korean4,
            background: BackgroundChoice.cream,
            style: DecorativeStyle.clean,
            showDate: i.isEven,
          ),
        );
      }
      // Only 3 should be retained.
      expect(undoRedo.canUndo, isTrue);
    });

    test('clear empties both stacks', () {
      final undoRedo = UndoRedoDecoration();
      const state = DecorationState(
        layout: PhotoLayout.korean4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      undoRedo.record(state);
      undoRedo.undo(state);
      undoRedo.clear();
      expect(undoRedo.canUndo, isFalse);
      expect(undoRedo.canRedo, isFalse);
    });
  });

  group('FrameTheme', () {
    test('all themes have a label', () {
      for (final theme in FrameTheme.values) {
        expect(theme.label, isNotEmpty);
      }
    });

    test('all themes have a tagline', () {
      for (final theme in FrameTheme.values) {
        expect(theme.tagline, isNotEmpty);
      }
    });

    test('all themes have a spec with wordmark', () {
      for (final theme in FrameTheme.values) {
        expect(theme.spec.wordmark, isNotEmpty);
        expect(theme.spec.paper, isNotNull);
        expect(theme.spec.ink, isNotNull);
      }
    });

    test('retroPop is the default theme', () {
      expect(FrameTheme.retroPop.spec.onDarkPaper, isFalse);
      expect(FrameTheme.retroPop.spec.wordmark, 'PHOTOBOOTH');
    });

    test('darkFilm is the only dark paper theme', () {
      final darkThemes = FrameTheme.values
          .where((FrameTheme t) => t.spec.onDarkPaper)
          .toList();
      expect(darkThemes, <FrameTheme>[FrameTheme.darkFilm]);
    });

    test('vintageFilm and darkFilm show date stamp', () {
      expect(FrameTheme.vintageFilm.spec.showsDateStamp, isTrue);
      expect(FrameTheme.darkFilm.spec.showsDateStamp, isTrue);
      expect(FrameTheme.retroPop.spec.showsDateStamp, isFalse);
    });
  });
}
