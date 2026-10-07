import 'package:camera/camera.dart';

import '../home/layout_model.dart';

/// A completed PhotoBooth capture session ready for review.
///
/// Holds the selected layout and the ordered list of captured photos.
/// The photos are stored as [XFile] references (temporary files owned by the
/// camera platform); callers should not assume persistence beyond the
/// application lifecycle unless explicitly saved.
class CapturedSession {
  const CapturedSession({
    required this.layout,
    required this.photos,
    this.aspectRatio,
  });

  /// The layout that was used for this session.
  final PhotoLayout layout;

  /// Captured photos in order (first = shot 1, etc.).
  final List<XFile> photos;

  /// The aspect ratio (width / height) of the captured frames.
  /// If null, a sensible default (0.56 for portrait) is used by the UI.
  final double? aspectRatio;

  /// How many shots this layout requires.
  int get requiredShots => layout.cols * layout.rows;

  /// Whether the session has all required shots.
  bool get isComplete => photos.length == requiredShots;
}
