import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/decorate/decorate_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';

/// Writes real portrait PNGs so the editor has genuine pixels to work with,
/// mirroring the harness used by decorate_layout_switch_test.dart.
Future<List<XFile>> _samplePhotos(int count) async {
  final Directory dir = await Directory.systemTemp.createTemp('pb_adjust');
  final List<XFile> photos = <XFile>[];
  const List<Color> colors = <Color>[
    Color(0xFF4D7DDB),
    Color(0xFFFFB6C1),
    Color(0xFFFED759),
    Color(0xFF8FD9C0),
  ];

  for (int i = 0; i < count; i++) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 96, 64),
      Paint()..color = colors[i % colors.length],
    );
    final ui.Image image = await recorder.endRecording().toImage(96, 64);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    final File file = File('${dir.path}/p$i.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    photos.add(XFile(file.path));
  }
  return photos;
}

/// Opens the editor on the Adjust tab with [count] photos.
Future<void> _openAdjustTab(WidgetTester tester, List<XFile> photos) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: DecorateScreen(
        layout: PhotoLayout.korean4,
        photos: photos,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  await tester.tap(find.text('Adjust'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Slider _firstSlider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider).first);

void main() {
  group('Adjust tab undo/redo', () {
    testWidgets('one slider gesture collapses into a single undo entry', (
      tester,
    ) async {
      final List<XFile> photos = (await tester.runAsync<List<XFile>>(
        () => _samplePhotos(4),
      ))!;
      await _openAdjustTab(tester, photos);
      expect(_firstSlider(tester).value, 0.0);

      // A drag fires onChanged many times; the gesture must record only the
      // pre-drag state, so one undo is enough to reach the neutral value.
      await tester.drag(find.byType(Slider).first, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, greaterThan(0.0));

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, 0.0);

      await tester.tap(find.byIcon(Icons.redo_rounded));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, greaterThan(0.0));
    });

    testWidgets('Adjust Reset is undoable like every other edit', (
      tester,
    ) async {
      final List<XFile> photos = (await tester.runAsync<List<XFile>>(
        () => _samplePhotos(4),
      ))!;
      await _openAdjustTab(tester, photos);

      // A leftward drag (negative brightness); the gesture records the
      // pre-drag state, so the section Reset has a recoverable snapshot.
      await tester.drag(find.byType(Slider).first, const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, isNot(0.0));

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, 0.0);

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();
      expect(_firstSlider(tester).value, isNot(0.0));
    });
  });
}
