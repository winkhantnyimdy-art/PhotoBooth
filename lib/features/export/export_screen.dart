import 'package:flutter/material.dart';

import '../../shared/placeholder_screen.dart';

/// Export feature stub. Save/share is not implemented yet.
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Export',
      hint: 'Saving and sharing the finished strip will live here.',
      icon: Icons.share_rounded,
    );
  }
}
