import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';
import 'photo_strip_renderer.dart';
import 'export_service.dart';

/// Export screen that renders the final image and provides save/share options.
///
/// The finished strip is the hero: it is presented as a printed keepsake on a
/// white surface, constrained to its real aspect ratio so nothing is stretched
/// or cropped, with the three actions always reachable without scrolling.
///
/// Platform I/O ([exportService]) and rendering ([renderer]) are injectable so
/// the save, share, failure and retry paths can be verified with a fake.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.layout,
    required this.photos,
    required this.decorationState,
    this.exportService,
    this.renderer,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final DecorationState decorationState;

  /// Platform I/O used for save/share. Defaults to [AppExportService].
  final ExportService? exportService;

  /// Renderer used to produce the strip bytes. Defaults to
  /// [PhotoStripRenderer]. Injectable so tests can simulate render failures.
  final PhotoStripRenderer? renderer;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late final PhotoStripRenderer _renderer;
  late final ExportService _exportService;

  Uint8List? _renderedImage;
  bool _isPreparing = true;
  bool _isSaving = false;
  bool _isSharing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _renderer = widget.renderer ?? PhotoStripRenderer();
    _exportService = widget.exportService ?? AppExportService();
    _prepareExport();
  }

  Future<void> _prepareExport() async {
    if (!mounted) return;
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final bytes = await _renderer.render(
        layout: widget.layout,
        photos: widget.photos,
        decorationState: widget.decorationState,
      );
      if (!mounted) return;
      setState(() {
        _renderedImage = bytes;
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to render photo strip. Please try again.';
        _isPreparing = false;
      });
    }
  }

  String _generateFileName() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'PhotoBooth_$timestamp.png';
  }

  Future<void> _handleSave() async {
    final Uint8List? image = _renderedImage;
    if (image == null || _isSaving || _isSharing) return;

    setState(() => _isSaving = true);
    try {
      await _exportService.saveToGallery(image, _generateFileName());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.onDark,
                size: 20,
              ),
              const SizedBox(width: S.sm + S.xs),
              const Expanded(child: Text('Saved to Photos!')),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: S.sm + S.xs),
              const Expanded(child: Text('Failed to save image.')),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleShare() async {
    final Uint8List? image = _renderedImage;
    // Guard both ways: a share must not start while a save is still writing,
    // and vice versa, otherwise the two platform calls can interleave.
    if (image == null || _isSharing || _isSaving) return;

    setState(() => _isSharing = true);
    try {
      await _exportService.shareImage(image, _generateFileName());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: S.sm + S.xs),
              const Expanded(child: Text('Failed to share image.')),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your photos'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : _isPreparing
            ? _buildPreparing()
            : _buildReady(),
      ),
    );
  }

  /// Preparing state: a calm, centred progress treatment.
  Widget _buildPreparing() => Center(
    child: Padding(
      padding: const EdgeInsets.all(S.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: S.md),
          Text('Preparing your strip...', style: AppText.label),
          const SizedBox(height: S.xs),
          Text(
            'Rendering at full resolution.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    ),
  );

  /// Error state with a retry affordance.
  Widget _buildError() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(S.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(S.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: R.all(R.lg),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: R.all(R.xl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: S.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppText.heading,
            ),
            const SizedBox(height: S.xs),
            Text(
              'Nothing was saved. Try rendering the strip again.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: S.lg),
            PressableScale(
              child: FilledButton.icon(
                onPressed: _prepareExport,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Ready state: keepsake preview plus the three actions.
  ///
  /// The preview takes the slack space and the action block keeps a fixed
  /// height, so every action stays on screen from 320dp upward without
  /// scrolling on short screens.
  Widget _buildReady() {
    final double aspect = PhotoStripGeometry.aspectRatio(widget.layout);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // On a short screen the headline steps down and the subtitle is
        // dropped: the strip and the actions matter more than the greeting,
        // and it keeps every action above the fold at large text scales.
        final bool compact = constraints.maxHeight < 520;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(S.lg, S.xs, S.lg, S.md),
              child: Column(
                children: <Widget>[
                  Text(
                    'Your photos are ready!',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Capped so the headline cannot wrap into a tall block
                    // that pushes the actions off a short screen.
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.3),
                    style: compact ? AppText.title : AppText.display,
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: S.xs),
                    Text(
                      'Your ${widget.layout.photoCount}-photo strip is ready '
                      'to save or share.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _KeepsakePreview(
                      bytes: _renderedImage!,
                      aspectRatio: aspect,
                    ),
                  ),
                ),
              ),
            ),
            _ActionBar(
              isSaving: _isSaving,
              isSharing: _isSharing,
              onSave: _handleSave,
              onShare: _handleShare,
              onMakeAnother: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }
}

/// The finished strip presented like a printed keepsake.
///
/// Sized by the strip's real aspect ratio so the export is never stretched or
/// cropped, and floated over a soft shadow to read as physical paper.
class _KeepsakePreview extends StatelessWidget {
  const _KeepsakePreview({required this.bytes, required this.aspectRatio});

  final Uint8List bytes;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preview of your finished photo strip',
      image: true,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.94, end: 1),
          duration: AppMotion.of(context, AppMotion.slow),
          curve: AppMotion.curve,
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(S.xs + S.xxs),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: R.all(R.md),
              border: Border.all(color: AppColors.line),
              boxShadow: AppShadows.lifted,
            ),
            child: ClipRRect(
              borderRadius: R.all(R.sm),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

/// Save (primary), Share (secondary) and Make Another (tertiary).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isSaving,
    required this.isSharing,
    required this.onSave,
    required this.onShare,
    required this.onMakeAnother,
  });

  final bool isSaving;
  final bool isSharing;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMakeAnother;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        S.lg,
        S.md,
        S.lg,
        S.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PressableScale(
            enabled: !isSaving && !isSharing,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              // The label stays constant so the control keeps a stable
              // accessible name while the work is in flight.
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: const Text('Save to Photos'),
            ),
          ),
          const SizedBox(height: S.sm + S.xs),
          PressableScale(
            enabled: !isSaving && !isSharing,
            child: OutlinedButton.icon(
              onPressed: isSharing ? null : onShare,
              icon: isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 20),
              label: const Text('Share'),
            ),
          ),
          const SizedBox(height: S.xxs),
          PressableScale(
            child: TextButton.icon(
              onPressed: onMakeAnother,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Make Another'),
            ),
          ),
        ],
      ),
    );
  }
}
