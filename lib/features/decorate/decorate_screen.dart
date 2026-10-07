import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../shared/placeholder_screen.dart';
import '../home/layout_model.dart';

/// Decorate feature stub.
///
/// Accepts an optional [layout] and [photos] so a later checkpoint can
/// implement decoration. For Checkpoint 3 this remains a visual placeholder;
/// decoration is not implemented.
class DecorateScreen extends StatelessWidget {
  const DecorateScreen({super.key, this.layout, this.photos});

  final PhotoLayout? layout;
  final List<XFile>? photos;

  @override
  Widget build(BuildContext context) {
    if (photos == null && layout == null) {
      return const PlaceholderScreen(
        title: 'Decorate',
        hint: 'Filters, frames, stickers, and text will live here.',
        icon: Icons.auto_awesome_rounded,
      );
    }

    final count = photos?.length ?? 0;
    return PlaceholderScreen(
      title: 'Decorate',
      hint:
          '$count photo(s) ready to decorate with ${layout?.label ?? 'layout'}.',
      icon: Icons.auto_awesome_rounded,
    );
  }
}
