import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/effect_image.dart';
import 'package:photo_booth/core/filters/photo_effect.dart';

/// The tree keys the EffectImage loading surfaces announce themselves with.
const Key kEffectImageLoading = ValueKey<String>('effect-image-loading');
const Key kEffectImageFallback = ValueKey<String>('effect-image-fallback');

/// Writes [edge]×[edge] real PNG pixels so the effect pipeline decodes
/// genuine bytes, mirroring the harness used by the decorate widget tests.
Future<XFile> _realPhoto(int edge, String prefix) async {
  final Directory dir = await Directory.systemTemp.createTemp(prefix);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, edge.toDouble(), edge.toDouble()),
    Paint()..color = const Color(0xFF4D7DDB),
  );
  final ui.Image image = await recorder.endRecording().toImage(edge, edge);
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  final File file = File('${dir.path}/real-$edge.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return XFile(file.path);
}

/// Bytes that are NOT a valid image, pointed at a .png name so the decode
/// attempt reaches the decoder and fails there (not at file-open).
Future<XFile> _brokenPhoto(String prefix) async {
  final Directory dir = await Directory.systemTemp.createTemp(prefix);
  final File file = File('${dir.path}/broken.png');
  await file.writeAsBytes('definitely not a png'.codeUnits);
  return XFile(file.path);
}

Widget _host(XFile photo) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 64,
          height: 64,
          child: EffectImage(
            photo: photo,
            recipe: EffectRecipe.resolve(PhotoEffect.grain, 1.0),
            decodeWidth: 64,
          ),
        ),
      ),
    ),
  );
}

bool _loadingVisible(WidgetTester tester) =>
    find.byKey(kEffectImageLoading).evaluate().isNotEmpty;

/// Pumps in short hops until a predicate over the widget tree holds.
///
/// Uses real-time delays so the engine's decode isolate can complete inside
/// the fake-async test binding; the decode landing is what the tests wait
/// for, not an animation.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 150),
  int limit = 60,
}) async {
  for (int i = 0; i < limit; i++) {
    if (condition()) return;
    await tester.pump(step);
    await tester.runAsync<void>(() => Future<void>.delayed(step));
  }
  fail('condition not reached within ${limit * step.inMilliseconds}ms');
}

void main() {
  group('EffectImage loading experience', () {
    testWidgets('shows a loading surface before the decode lands, then the graded image', (
      tester,
    ) async {
      final XFile photo = (await tester.runAsync<XFile>(
        () => _realPhoto(128, 'eb_ready'),
      ))!;
      await tester.pumpWidget(_host(photo));

      // First frame: the decode is still in flight, so the cell must show
      // the quiet loading surface rather than a silent blank.
      expect(_loadingVisible(tester), isTrue);

      // The loading surface disappears exactly when the decode lands, and
      // the settled tree holds no scheduled animation (the loading affordance
      // is deliberately static, so pumpAndSettle stays usable - a perpetual
      // spinner here proved to hang every editor pumpAndSettle test).
      await _pumpUntil(tester, () => !_loadingVisible(tester));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fails over to a defined surface when the decode fails', (
      tester,
    ) async {
      final XFile broken = (await tester.runAsync<XFile>(
        () => _brokenPhoto('eb_broken'),
      ))!;
      await tester.pumpWidget(_host(broken));
      expect(_loadingVisible(tester), isTrue);

      // The decode error must be absorbed (no unhandled FlutterError) and
      // the cell must land on the muted fallback instead of staying blank.
      await _pumpUntil(
        tester,
        () => find.byKey(kEffectImageFallback).evaluate().isNotEmpty,
      );
      expect(_loadingVisible(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a newer photo never stays stuck behind an in-flight decode', (
      tester,
    ) async {
      final XFile first = (await tester.runAsync<XFile>(
        () => _realPhoto(128, 'eb_switch_a'),
      ))!;
      final XFile second = (await tester.runAsync<XFile>(
        () => _realPhoto(96, 'eb_switch_b'),
      ))!;

      await tester.pumpWidget(_host(first));
      await _pumpUntil(tester, () => !_loadingVisible(tester));

      // Point the same cell at a second photo: a fresh decode must start
      // (the loading surface returns) instead of the old result lingering.
      await tester.pumpWidget(_host(second));
      expect(_loadingVisible(tester), isTrue);

      await _pumpUntil(tester, () => !_loadingVisible(tester));
      expect(find.byKey(kEffectImageFallback).evaluate().isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
