import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';
import 'photo_strip_renderer.dart';
import 'export_service.dart';

/// Export screen that renders the final image and provides save/share options.
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
  /// Injectable so tests can supply a fake without a DI framework.
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
    if (image == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _exportService.saveToGallery(image, _generateFileName());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Photos!'),
          backgroundColor: AppColors.accent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save image.'),
          backgroundColor: Colors.red,
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
    if (image == null || _isSharing) return;

    setState(() => _isSharing = true);
    try {
      await _exportService.shareImage(image, _generateFileName());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share image.'),
          backgroundColor: Colors.red,
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
        title: const Text('Export'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isPreparing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: S.md),
            const Text(
              'Preparing your strip...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: S.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: S.lg),
              FilledButton(
                onPressed: _prepareExport,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(S.md),
      child: Column(
        children: [
          // High-res preview scaled to fit screen
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.memory(_renderedImage!, fit: BoxFit.contain),
          ),
          const SizedBox(height: S.lg),

          // Layout Info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Layout: ${widget.layout.label}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: S.lg),

          // Primary Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save to Photos'),
              ),
              const SizedBox(height: S.sm),
              FilledButton.icon(
                onPressed: _isSharing ? null : _handleShare,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              const SizedBox(height: S.lg),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Make Another'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
