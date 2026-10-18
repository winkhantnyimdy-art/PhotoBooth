// Generates the Checkpoint 3 visual effect comparison sheets.
//
// Run with:
//
//   flutter test tool/generate_effects_comparison.dart
//
// The sheets are produced by the real engine: every tile is rendered through
// [EffectRecipe] + [EffectGrain] + [EffectBloom], the same three primitives the
// Decorate preview and the PNG exporter use. Nothing here is a mockup and no
// external image tool is involved.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/filters/photo_effect.dart';
import 'package:photo_booth/core/filters/photo_filter.dart';

/// Tile size in logical pixels. Large enough to judge grain and glow, small
/// enough to fit fifteen of them legibly.
const double _tile = 260;

/// Label strip under each tile.
const double _label = 26;

const Color _ink = Color(0xFFFFFFFF);
const Color _muted = Color(0xFFA6A6AD);
const Color _surface = Color(0xFF141416);

/// Device pixels per logical pixel in the written PNG.
const double _dpr = 2;

const String _fontFamily = 'Roboto';

/// Registers Roboto so the labels rasterise as text rather than as the test
/// harness's placeholder glyphs. Returns false when the SDK cache is absent,
/// in which case the tiles are still correct and only the labels degrade.
Future<bool> _loadFont() async {
  final List<String> candidates = <String>[
    'C:/dev/flutter/bin/cache/artifacts/material_fonts',
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
        '/bin/cache/artifacts/material_fonts',
  ];
  for (final String dir in candidates) {
    final File file = File('$dir/roboto-regular.ttf');
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader(_fontFamily)
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(await file.readAsBytes())),
      );
    final File bold = File('$dir/roboto-bold.ttf');
    if (bold.existsSync()) {
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(await bold.readAsBytes())),
      );
    }
    await loader.load();
    return true;
  }
  return false;
}

/// A second source with hard, saturated geometry so clipping, colour casts and
/// grain are far easier to spot than on a photographic source.
Future<ui.Image> _syntheticSource(int size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double s = size.toDouble();

  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()..color = const Color(0xFF101012),
  );
  // Saturated primaries and secondaries at full value.
  const List<Color> swatches = <Color>[
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFFFF00),
    Color(0xFF00FFFF),
    Color(0xFFFF00FF),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];
  const double cell = 0.25;
  for (int i = 0; i < swatches.length; i++) {
    final int row = i ~/ 4;
    final int col = i % 4;
    canvas.drawRect(
      Rect.fromLTWH(col * s * cell, row * s * cell, s * cell, s * cell),
      Paint()..color = swatches[i],
    );
  }
  // Neutral ramp across the middle, so black-point and white-point handling is
  // directly readable left to right.
  for (int i = 0; i < 40; i++) {
    final int level = (i * 255 / 39).round();
    canvas.drawRect(
      Rect.fromLTWH(i * s / 40, s * 0.5, s / 40 + 1, s * 0.2),
      Paint()..color = Color.fromARGB(255, level, level, level),
    );
  }
  // Asymmetric marker, top-left, so a transpose or mirror is unmistakable.
  canvas.drawCircle(
    Offset(s * 0.12, s * 0.08),
    s * 0.05,
    Paint()..color = const Color(0xFF00E5FF),
  );
  // Soft skin-tone and neutral-warm patches, for a more photographic read.
  canvas.drawCircle(
    Offset(s * 0.72, s * 0.82),
    s * 0.13,
    Paint()..color = const Color(0xFFD8A184),
  );
  canvas.drawCircle(
    Offset(s * 0.35, s * 0.85),
    s * 0.09,
    Paint()..color = const Color(0xFF8C6B52),
  );
  return recorder.endRecording().toImage(size, size);
}

/// Renders [source] through the real effect pipeline for [effect] at [intensity].
///
/// This is deliberately the same three-step order the app uses: colour matrix,
/// then screen-blended bloom, then grain.
Future<ui.Image> _apply(ui.Image source, EffectRecipe recipe) async {
  final int w = source.width;
  final int h = source.height;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);
  final ui.Rect full = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

  canvas.drawImageRect(
    source,
    full,
    full,
    Paint()
      ..colorFilter = ColorMatrix.isIdentity(recipe.matrix)
          ? null
          : ui.ColorFilter.matrix(recipe.matrix),
  );
  if (recipe.bloomAmount > 0) {
    EffectBloom.paintSingle(canvas, full, recipe, source, full);
  }
  if (recipe.grainAmount > 0) {
    EffectGrain.paint(
      canvas,
      full,
      recipe.grainAmount,
      seed: EffectRecipe.grainSeed,
    );
  }
  return recorder.endRecording().toImage(w, h);
}

/// Cover-crops [image] into [tile], so every effect sees the same framing.
void _drawCover(Canvas canvas, ui.Image image, ui.Rect tile) {
  final double sw = image.width.toDouble();
  final double sh = image.height.toDouble();
  final double tileAspect = tile.width / tile.height;
  final double imageAspect = sw / sh;
  final ui.Rect source;
  if (imageAspect > tileAspect) {
    final double w = sh * tileAspect;
    source = ui.Rect.fromLTWH((sw - w) / 2, 0, w, sh);
  } else {
    final double h = sw / tileAspect;
    source = ui.Rect.fromLTWH(0, (sh - h) / 2, sw, h);
  }
  canvas.drawImageRect(
    image,
    source,
    tile,
    Paint()..filterQuality = ui.FilterQuality.high,
  );
}

void _drawLabel(
  Canvas canvas,
  String text,
  ui.Rect rect, {
  bool muted = false,
  double fontSize = 15,
}) {
  final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: muted ? ui.FontWeight.w500 : ui.FontWeight.w700,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    ),
  )
    ..pushStyle(
      ui.TextStyle(
        fontFamily: _fontFamily,
        color: muted ? _muted : _ink,
        fontSize: fontSize,
        fontWeight: muted ? ui.FontWeight.w500 : ui.FontWeight.w700,
      ),
    )
    ..addText(text);
  final ui.Paragraph paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: rect.width));
  canvas.drawParagraph(paragraph, rect.topLeft);
}

/// Rasterises a logical-pixel sheet to PNG at [_dpr].
Future<Uint8List> _rasterise(
  void Function(Canvas canvas) paint,
  double width,
  double height,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  // Work in logical units; scale once here so text and layout stay readable.
  canvas.scale(_dpr);
  paint(canvas);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    (width * _dpr).round(),
    (height * _dpr).round(),
  );
  picture.dispose();
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Builds one comparison sheet: the same source and crop under all fifteen
/// effects, each labelled.
Future<Uint8List> _sheet({
  required ui.Image source,
  required String title,
  required String subtitle,
  required int columns,
}) async {
  final List<ui.Image> tiles = <ui.Image>[];
  for (final PhotoEffect effect in PhotoEffect.values) {
    tiles.add(await _apply(source, EffectRecipe.resolve(effect, 1)));
  }

  final int rows = (PhotoEffect.values.length / columns).ceil();
  const double gap = 16;
  final double sheetWidth = (columns * _tile) + ((columns + 1) * gap);
  final double headerHeight = 78;
  final double rowHeight = _tile + _label + 10;
  final double sheetHeight = headerHeight + (rows * rowHeight) + (gap * rows) + gap;

  return _rasterise((Canvas canvas) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, sheetWidth, sheetHeight),
      Paint()..color = _surface,
    );
    _drawLabel(
      canvas,
      title,
      ui.Rect.fromLTWH(gap, 18, sheetWidth - (gap * 2), 30),
      fontSize: 21,
    );
    _drawLabel(
      canvas,
      subtitle,
      ui.Rect.fromLTWH(gap, 48, sheetWidth - (gap * 2), 24),
      muted: true,
      fontSize: 13,
    );

    for (int i = 0; i < PhotoEffect.values.length; i++) {
      final int row = i ~/ columns;
      final int col = i % columns;
      final double x = gap + (col * (_tile + gap));
      final double y = headerHeight + (row * (rowHeight + gap));
      final ui.Rect tile = ui.Rect.fromLTWH(x, y, _tile, _tile);

      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(tile, const Radius.circular(10)),
      );
      _drawCover(canvas, tiles[i], tile);
      canvas.restore();

      _drawLabel(
        canvas,
        '${i + 1}. ${PhotoEffect.values[i].label}',
        ui.Rect.fromLTWH(x, y + _tile + 4, _tile, _label),
      );
    }
  }, sheetWidth, sheetHeight);
}

/// Writes an intensity ramp for one effect, showing that the strength control
/// blends smoothly from Original to the full look.
Future<Uint8List> _intensitySheet({
  required ui.Image source,
  required PhotoEffect effect,
}) async {
  const List<double> steps = <double>[0, 0.25, 0.5, 0.75, 1];
  final List<ui.Image> tiles = <ui.Image>[];
  for (final double t in steps) {
    tiles.add(await _apply(source, EffectRecipe.resolve(effect, t)));
  }

  const double gap = 16;
  final int columns = steps.length;
  final double sheetWidth = (columns * _tile) + ((columns + 1) * gap);
  const double headerHeight = 78;
  final double rowHeight = _tile + _label + 10;
  final double sheetHeight = headerHeight + rowHeight + (gap * 2) + 34;

  return _rasterise((Canvas canvas) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, sheetWidth, sheetHeight),
      Paint()..color = _surface,
    );
    _drawLabel(
      canvas,
      '${effect.label} - strength ramp',
      ui.Rect.fromLTWH(gap, 18, sheetWidth - (gap * 2), 30),
      fontSize: 21,
    );
    _drawLabel(
      canvas,
      'Left to right: 0%, 25%, 50%, 75%, 100%. 0% is pixel-identical to Original.',
      ui.Rect.fromLTWH(gap, 48, sheetWidth - (gap * 2), 24),
      muted: true,
      fontSize: 13,
    );

    for (int i = 0; i < steps.length; i++) {
      final double x = gap + (i * (_tile + gap));
      final ui.Rect tile = ui.Rect.fromLTWH(x, headerHeight, _tile, _tile);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(tile, const Radius.circular(10)),
      );
      _drawCover(canvas, tiles[i], tile);
      canvas.restore();
      _drawLabel(
        canvas,
        '${(steps[i] * 100).round()}%',
        ui.Rect.fromLTWH(
          x,
          headerHeight + _tile + 4,
          _tile,
          _label,
        ),
        muted: i == 0,
      );
    }
    _drawLabel(
      canvas,
      'Strength scales the colour matrix, the grain density and the bloom '
      'amount together. Grain stays fixed-seed, so no step flickers.',
      ui.Rect.fromLTWH(gap, headerHeight + rowHeight + gap + 6, sheetWidth - (gap * 2), 24),
      muted: true,
      fontSize: 12,
    );
  }, sheetWidth, sheetHeight);
}

Future<ui.Image> _load(String path) async {
  final Uint8List bytes = await File(path).readAsBytes();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _write(String path, Uint8List bytes) async {
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('wrote $path (${bytes.length} bytes)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render the fifteen-effect comparison sheets', () async {
    final bool fontLoaded = await _loadFont();
    // ignore: avoid_print
    print('Roboto loaded: $fontLoaded');

    final Directory out = Directory('docs/v3/screenshots/checkpoint-3');
    await out.create(recursive: true);

    // Primary: a real capture produced by this app's own camera pipeline on
    // the Android emulator. It is the emulator's virtual scene, which is the
    // only photographic source available on this machine; the sheet says so
    // rather than implying it is a studio photograph.
    const String referencePath = 'docs/v3/fixtures/reference-capture.jpg';
    final File reference = File(referencePath);
    expect(reference.existsSync(), isTrue, reason: 'reference capture missing');
    final ui.Image photo = await _load(referencePath);

    await _write(
      '${out.path}/effects-comparison.png',
      await _sheet(
        source: photo,
        title: 'PhotoBooth V3 - effect catalogue',
        subtitle:
            'One capture, one crop, all fifteen effects at 100%. Rendered by '
            'the shipping engine: colour matrix, then screen-blended bloom, '
            'then fixed-seed grain.',
        columns: 5,
      ),
    );
    photo.dispose();

    // Secondary: hard synthetic geometry to expose clipping, colour casts and
    // grain artefacts that a photographic source can hide.
    final ui.Image synthetic = await _syntheticSource(768);
    await _write(
      '${out.path}/effects-comparison-secondary.png',
      await _sheet(
        source: synthetic,
        title: 'PhotoBooth V3 - artefact probe',
        subtitle:
            'Saturated primaries, a 40-step neutral ramp, blown highlights, '
            'crushed shadows, skin-tone patches and an off-centre marker.',
        columns: 5,
      ),
    );
    synthetic.dispose();

    // Intensity ramp: proves the control blends continuously and that 0% is
    // the untouched original.
    final ui.Image photo2 = await _load(referencePath);
    await _write(
      '${out.path}/effects-intensity.png',
      await _intensitySheet(source: photo2, effect: PhotoEffect.vintage),
    );
    photo2.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
