import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Reads the encoded bytes of a captured photo straight off the local file.
///
/// Used by the strip renderer and the filter pipeline.
Future<Uint8List> readPhotoBytes(XFile photo) => File(photo.path).readAsBytes();

/// Paints a captured photo on Android/iOS.
///
/// Delegates to [Image.file] so the existing decode/cache behaviour is
/// unchanged for the native builds.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
  });

  final XFile photo;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(photo.path),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
    );
  }
}