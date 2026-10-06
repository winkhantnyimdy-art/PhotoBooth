import 'package:flutter/material.dart';

import '../../shared/placeholder_screen.dart';

/// Camera feature stub. No camera package is used yet.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Camera',
      hint: 'Live camera preview and capture will live here.',
      icon: Icons.photo_camera_rounded,
    );
  }
}
