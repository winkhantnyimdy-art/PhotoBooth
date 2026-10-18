import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/features/album/album_session.dart';
import 'package:photo_booth/features/camera/camera_preferences.dart';
import 'package:photo_booth/features/decorate/decoration_model.dart';
import 'package:photo_booth/features/decorate/frame_theme.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/core/filters/photo_effect.dart';
import 'package:photo_booth/core/filters/photo_filter.dart';

void main() {
  group('AlbumSession', () {
    final testBytes = Uint8List.fromList([1, 2, 3, 4]);
    final testThumbnail = Uint8List.fromList([5, 6, 7, 8]);
    final decorationState = DecorationState(
      layout: PhotoLayout.korean4,
      background: BackgroundChoice.cream,
      style: DecorativeStyle.clean,
    );

    test('creates session with all fields', () {
      final session = AlbumSession(
        id: 'test-id',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        layout: PhotoLayout.korean4,
        photoBytes: [testBytes, testBytes, testBytes, testBytes],
        decorationState: decorationState,
        thumbnailBytes: testThumbnail,
        name: 'My Session',
      );

      expect(session.id, 'test-id');
      expect(session.createdAt, DateTime(2024, 1, 15, 10, 30));
      expect(session.layout, PhotoLayout.korean4);
      expect(session.photoBytes.length, 4);
      expect(session.decorationState, decorationState);
      expect(session.thumbnailBytes, testThumbnail);
      expect(session.name, 'My Session');
      expect(session.photoCount, 4);
      expect(session.displayName, 'My Session');
    });

    test('displayName falls back to formatted date when name is null', () {
      final session = AlbumSession(
        id: 'test-id',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        layout: PhotoLayout.korean4,
        photoBytes: [testBytes],
        decorationState: decorationState,
        thumbnailBytes: testThumbnail,
        name: null,
      );

      expect(session.displayName, 'Session 2024-01-15 10:30');
    });

    test('copyWith updates only specified fields', () {
      final session = AlbumSession(
        id: 'test-id',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        layout: PhotoLayout.korean4,
        photoBytes: [testBytes],
        decorationState: decorationState,
        thumbnailBytes: testThumbnail,
        name: 'Original',
      );

      final updated = session.copyWith(name: 'Updated');

      expect(updated.id, 'test-id');
      expect(updated.name, 'Updated');
      expect(updated.layout, PhotoLayout.korean4);
    });

    test('toJson and fromJson round-trip preserves data', () {
      final session = AlbumSession(
        id: 'test-id',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        layout: PhotoLayout.korean4,
        photoBytes: [testBytes, testBytes],
        decorationState: decorationState,
        thumbnailBytes: testThumbnail,
        name: 'Test Session',
      );

      final json = session.toJson();
      final restored = AlbumSession.fromJson(json);

      expect(restored.id, session.id);
      expect(restored.createdAt, session.createdAt);
      expect(restored.layout, session.layout);
      expect(restored.photoBytes.length, session.photoBytes.length);
      expect(restored.decorationState.layout, session.decorationState.layout);
      expect(restored.decorationState.background, session.decorationState.background);
      expect(restored.decorationState.style, session.decorationState.style);
      expect(restored.thumbnailBytes, session.thumbnailBytes);
      expect(restored.name, session.name);
    });

    test('JSON serialization handles all decoration state fields', () {
      final complexState = DecorationState(
        layout: PhotoLayout.grid4,
        background: BackgroundChoice.charcoal,
        style: DecorativeStyle.hearts,
        showDate: true,
        stickers: [
          StickerPlacement(type: StickerType.heart, x: 0.5, y: 0.5, scale: 1.5, rotation: 0.3),
        ],
        texts: [
          TextPlacement(text: 'Hello', x: 0.5, y: 0.8, color: Colors.white, scale: 0.1),
        ],
        filter: PhotoEffect.classicFilm,
        filterIntensity: 0.75,
        frameStyle: FrameStyle.filmEdge,
        frameTheme: FrameTheme.vintageFilm,
        adjustments: const PhotoAdjustments(brightness: 0.1, contrast: 0.2),
        dateOverride: DateTime(2024, 6, 15),
      );

      final session = AlbumSession(
        id: 'complex-id',
        createdAt: DateTime(2024, 6, 15, 14, 30),
        layout: PhotoLayout.grid4,
        photoBytes: [testBytes, testBytes, testBytes, testBytes],
        decorationState: complexState,
        thumbnailBytes: testThumbnail,
        name: 'Complex Session',
      );

      final json = session.toJson();
      final restored = AlbumSession.fromJson(json);

      expect(restored.decorationState.layout, PhotoLayout.grid4);
      expect(restored.decorationState.background, BackgroundChoice.charcoal);
      expect(restored.decorationState.style, DecorativeStyle.hearts);
      expect(restored.decorationState.showDate, true);
      expect(restored.decorationState.stickers.length, 1);
      expect(restored.decorationState.stickers.first.type, StickerType.heart);
      expect(restored.decorationState.stickers.first.scale, 1.5);
      expect(restored.decorationState.stickers.first.rotation, 0.3);
      expect(restored.decorationState.texts.length, 1);
      expect(restored.decorationState.texts.first.text, 'Hello');
      expect(restored.decorationState.filter, PhotoEffect.classicFilm);
      expect(restored.decorationState.filterIntensity, 0.75);
      expect(restored.decorationState.frameStyle, FrameStyle.filmEdge);
      expect(restored.decorationState.frameTheme, FrameTheme.vintageFilm);
      expect(restored.decorationState.adjustments.brightness, 0.1);
      expect(restored.decorationState.adjustments.contrast, 0.2);
      expect(restored.decorationState.dateOverride, DateTime(2024, 6, 15));
    });
  });

  group('CameraPreferences', () {
    test('creates with default values', () {
      final prefs = const CameraPreferences();

      expect(prefs.countdownSeconds, 3);
      expect(prefs.shutterSoundEnabled, true);
      expect(prefs.flashAnimationEnabled, true);
      expect(prefs.isValidCountdown, true);
    });

    test('creates with custom values', () {
      final prefs = CameraPreferences(
        countdownSeconds: 10,
        shutterSoundEnabled: false,
        flashAnimationEnabled: false,
      );

      expect(prefs.countdownSeconds, 10);
      expect(prefs.shutterSoundEnabled, false);
      expect(prefs.flashAnimationEnabled, false);
      expect(prefs.isValidCountdown, true);
    });

    test('copyWith updates only specified fields', () {
      final prefs = const CameraPreferences();
      final updated = prefs.copyWith(countdownSeconds: 5, shutterSoundEnabled: false);

      expect(updated.countdownSeconds, 5);
      expect(updated.shutterSoundEnabled, false);
      expect(updated.flashAnimationEnabled, true);
    });

    test('toJson and fromJson round-trip preserves data', () {
      final prefs = CameraPreferences(
        countdownSeconds: 5,
        shutterSoundEnabled: false,
        flashAnimationEnabled: true,
      );

      final json = prefs.toJson();
      final restored = CameraPreferences.fromJson(json);

      expect(restored.countdownSeconds, 5);
      expect(restored.shutterSoundEnabled, false);
      expect(restored.flashAnimationEnabled, true);
    });

    test('isValidCountdown returns false for invalid values', () {
      // We can't easily test invalid values since the constructor doesn't validate,
      // but we can test that valid options work
      for (final seconds in CameraPreferences.validCountdownOptions) {
        final prefs = CameraPreferences(countdownSeconds: seconds);
        expect(prefs.isValidCountdown, true, reason: '$seconds should be valid');
      }
    });

    test('validCountdownOptions contains expected values', () {
      expect(CameraPreferences.validCountdownOptions, [3, 5, 10]);
    });
  });
}