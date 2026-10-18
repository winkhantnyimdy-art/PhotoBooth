import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../media/preview_decode.dart';
import 'photo_effect.dart';
import 'photo_filter.dart';

/// Paints a captured photo with a resolved [EffectRecipe].
///
/// ## Why this exists
///
/// Flutter has no widget that screen-blends a blurred copy of an image over the
/// original. `ShaderMask` only blends against a *flat* shader, which lifts the
/// blacks as well as the highlights, and `BlendMask` does not exist in this
/// Flutter version. Rather than approximate the glow differently on screen and
/// in the export - which is how previews and exports drift apart - the
/// preview paints through the same canvas primitives the exporter uses.
///
/// Decoding still goes through Flutter's `ImageCache` (the provider is an
/// ordinary `FileImage`/`ResizeImage`), so nothing here introduces a second
/// bitmap cache.
class EffectImage extends StatefulWidget {
  const EffectImage({
    super.key,
    required this.photo,
    required this.recipe,
    this.decodeWidth,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
  });

  final XFile photo;

  /// The resolved effect. Consumed verbatim, exactly as the exporter does.
  final EffectRecipe recipe;

  /// Caps the decode so a 12 MP frame does not become a 48 MB bitmap for a
  /// small preview cell.
  final int? decodeWidth;

  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  State<EffectImage> createState() => _EffectImageState();
}

class _EffectImageState extends State<EffectImage> {
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant EffectImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.path != widget.photo.path ||
        oldWidget.decodeWidth != widget.decodeWidth) {
      _detach();
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
    _provider = null;
    _image = null;
  }

  void _resolve() {
    final ImageProvider<Object> provider = widget.decodeWidth == null
        ? FileImage(File(widget.photo.path)) as ImageProvider<Object>
        : ResizeImage.resizeIfNeeded(
            widget.decodeWidth,
            null,
            FileImage(File(widget.photo.path)),
          );
    if (identical(provider, _provider)) return;

    _detach();
    _provider = provider;
    final ImageStream stream = provider.resolve(
      // Configuration is irrelevant for a static file; keeps the code total.
      createLocalImageConfiguration(context),
    );
    _stream = stream;
    _listener = ImageStreamListener((ImageInfo info, _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    });
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _image;
    if (image == null) {
      return const SizedBox.expand();
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _EffectPainter(
          image: image,
          recipe: widget.recipe,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _EffectPainter extends CustomPainter {
  const _EffectPainter({
    required this.image,
    required this.recipe,
    required this.fit,
    required this.filterQuality,
  });

  final ui.Image image;
  final EffectRecipe recipe;
  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ui.Rect target = Offset.zero & size;
    final ui.Rect source = _sourceRect(target);

    // 1. Base pass: the colour matrix, identical maths to the exporter.
    canvas.drawImageRect(
      image,
      source,
      target,
      ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = filterQuality == FilterQuality.medium
            ? ui.FilterQuality.medium
            : ui.FilterQuality.none
        ..colorFilter = ColorMatrix.isIdentity(recipe.matrix)
            ? null
            : ui.ColorFilter.matrix(recipe.matrix),
    );

    // 2. Bloom: blurred, screen-blended. The same EffectBloom the exporter
    //    calls, so the glow cannot differ between preview and export.
    //
    //    Grain is deliberately NOT painted here. The seed is shared and fixed,
    //    so painting it per cell would stamp the identical speck pattern into
    //    every cell. The caller lays one grain pass over the whole photo area
    //    instead, which is also what the exporter does.
    if (recipe.bloomAmount > 0) {
      EffectBloom.paintSingle(
        canvas,
        target,
        recipe,
        image,
        source,
      );
    }
  }

  /// The source rect for [target] under [fit].
  ui.Rect _sourceRect(ui.Rect target) {
    final double sourceAspect = image.width / image.height;
    final double targetAspect = target.width / target.height;
    if (fit == BoxFit.fill ||
        sourceAspect.isNaN ||
        targetAspect.isNaN) {
      return ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    }
    final bool cropWidth = switch (fit) {
      BoxFit.cover => sourceAspect > targetAspect,
      BoxFit.contain => sourceAspect < targetAspect,
      _ => false,
    };
    if (!cropWidth) return ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (fit == BoxFit.cover) {
      final double w = image.height * targetAspect;
      return ui.Rect.fromLTWH((image.width - w) / 2, 0, w, image.height.toDouble());
    }
    final double h = image.width / targetAspect;
    return ui.Rect.fromLTWH(0, (image.height - h) / 2, image.width.toDouble(), h);
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) =>
      old.image != image ||
      old.recipe.intensity != recipe.intensity ||
      old.recipe.effect != recipe.effect ||
      old.fit != fit;
}

/// Convenience: the decode width a preview cell of [logicalWidth] should use.
int? previewDecodeWidth(double logicalWidth, double devicePixelRatio) =>
    PreviewDecode.forWidth(logicalWidth, devicePixelRatio);