import 'package:flutter/material.dart';

import '../../shared/placeholder_screen.dart';

/// Review feature stub.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Review',
      hint: 'Retake and accept individual shots will live here.',
      icon: Icons.refresh_rounded,
    );
  }
}
