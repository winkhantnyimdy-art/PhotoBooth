import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/home/layout_model.dart';

void main() {
  group('DecorationState', () {
    test('defaults showDate false and empty stickers', () {
      const state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );

      expect(state.showDate, isFalse);
      expect(state.stickers, isEmpty);
    });

    test('displayDate falls back to now when no override', () {
      final before = DateTime.now();
      const state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );
      final after = DateTime.now();

      expect(
        state.displayDate.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        state.displayDate.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('displayDate returns dateOverride when provided', () {
      final override = DateTime(2024, 1, 15);
      final state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
        dateOverride: override,
      );

      expect(state.displayDate, equals(override));
    });

    test('copyWith replaces only the given fields', () {
      const state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );

      final updated = state.copyWith(
        background: BackgroundChoice.charcoal,
        showDate: true,
      );

      expect(updated.layout, equals(PhotoLayout.cut4));
      expect(updated.background, equals(BackgroundChoice.charcoal));
      expect(updated.style, equals(DecorativeStyle.clean));
      expect(updated.showDate, isTrue);
      expect(updated.stickers, isEmpty);
    });

    test('copyWith preserves stickers list reference when not given', () {
      final sticker = const StickerPlacement(
        type: StickerType.heart,
        x: 0.5,
        y: 0.5,
      );
      final state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
        stickers: [sticker],
      );

      final updated = state.copyWith(style: DecorativeStyle.hearts);

      expect(updated.stickers, hasLength(1));
      expect(updated.stickers.first, equals(sticker));
    });

    test('copyWith can replace stickers list', () {
      final state = DecorationState(
        layout: PhotoLayout.cut4,
        background: BackgroundChoice.cream,
        style: DecorativeStyle.clean,
      );

      final updated = state.copyWith(
        stickers: const [
          StickerPlacement(type: StickerType.star, x: 0.2, y: 0.3),
          StickerPlacement(type: StickerType.smiley, x: 0.8, y: 0.7),
        ],
      );

      expect(updated.stickers, hasLength(2));
      expect(updated.stickers[0].type, equals(StickerType.star));
      expect(updated.stickers[1].type, equals(StickerType.smiley));
    });
  });

  group('BackgroundChoice', () {
    test('has expected labels', () {
      expect(BackgroundChoice.cream.label, equals('Cream'));
      expect(BackgroundChoice.softPink.label, equals('Soft Pink'));
      expect(BackgroundChoice.white.label, equals('White'));
      expect(BackgroundChoice.charcoal.label, equals('Charcoal'));
      expect(BackgroundChoice.lavender.label, equals('Lavender'));
      expect(BackgroundChoice.skyBlue.label, equals('Sky Blue'));
    });

    test('has distinct colors', () {
      final colors = BackgroundChoice.values.map((c) => c.color).toSet();
      expect(colors, hasLength(BackgroundChoice.values.length));
    });

    test('charcoal color is dark', () {
      expect(BackgroundChoice.charcoal.color.computeLuminance() < 0.2, isTrue);
    });
  });

  group('DecorativeStyle', () {
    test('has expected labels', () {
      expect(DecorativeStyle.clean.label, equals('Clean'));
      expect(DecorativeStyle.hearts.label, equals('Hearts'));
      expect(DecorativeStyle.stars.label, equals('Stars'));
      expect(DecorativeStyle.sparkle.label, equals('Sparkle'));
    });

    test('clean is the first value', () {
      expect(DecorativeStyle.values.first, equals(DecorativeStyle.clean));
    });
  });

  group('StickerPlacement', () {
    test('stores type and normalized coordinates', () {
      const placement = StickerPlacement(
        type: StickerType.heart,
        x: 0.25,
        y: 0.75,
      );

      expect(placement.type, equals(StickerType.heart));
      expect(placement.x, equals(0.25));
      expect(placement.y, equals(0.75));
    });

    test('copyWith replaces only given fields', () {
      const placement = StickerPlacement(
        type: StickerType.heart,
        x: 0.5,
        y: 0.5,
      );

      final moved = placement.copyWith(x: 0.1, y: 0.2);

      expect(moved.type, equals(StickerType.heart));
      expect(moved.x, equals(0.1));
      expect(moved.y, equals(0.2));
    });

    test('two placements with same values are equal', () {
      const a = StickerPlacement(type: StickerType.star, x: 0.3, y: 0.4);
      const b = StickerPlacement(type: StickerType.star, x: 0.3, y: 0.4);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('placements with different coordinates are not equal', () {
      const a = StickerPlacement(type: StickerType.star, x: 0.3, y: 0.4);
      const b = StickerPlacement(type: StickerType.star, x: 0.3, y: 0.5);

      expect(a, isNot(equals(b)));
    });
  });

  group('StickerType', () {
    test('provides a non-empty label for every type', () {
      for (final type in StickerType.values) {
        expect(type.label, isNotEmpty);
      }
    });

    test('labels are unique', () {
      final labels = StickerType.values.map((t) => t.label).toSet();
      expect(labels, hasLength(StickerType.values.length));
    });
  });
}
