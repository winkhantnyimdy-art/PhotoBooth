import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';

/// Export feature placeholder that displays the decorated session
/// without performing final rendering/export/save/share.
class ExportScreen extends StatelessWidget {
  const ExportScreen({
    super.key,
    required this.layout,
    required this.photos,
    required this.decorationState,
  });

  /// The layout used for this session.
  final PhotoLayout layout;

  /// Captured photos in order.
  final List<XFile> photos;

  /// The decoration state from DecorateScreen.
  final DecorationState decorationState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Export'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(S.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your photo strip is ready.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: S.md),
              Text(
                'Layout: ${layout.label}',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                'Frame: ${decorationState.background.label}',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                'Style: ${decorationState.style.label}',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (decorationState.showDate)
                Text(
                  'Date: ${decorationState.displayDate.year}-'
                  '${decorationState.displayDate.month.toString().padLeft(2, '0')}-'
                  '${decorationState.displayDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (decorationState.stickers.isNotEmpty)
                Text(
                  'Stickers: ${decorationState.stickers.length} placed',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: S.lg),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Decorate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
