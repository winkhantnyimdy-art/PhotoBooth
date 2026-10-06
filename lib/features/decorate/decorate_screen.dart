import 'package:flutter/material.dart';

import '../../shared/placeholder_screen.dart';

/// Decorate feature stub.
class DecorateScreen extends StatelessWidget {
  const DecorateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Decorate',
      hint: 'Filters, frames, stickers, and text will live here.',
      icon: Icons.auto_awesome_rounded,
    );
  }
}
