import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/minimal_dark.dart';
import '../../shared/pressable.dart';
import '../album/album_builder.dart';
import '../album/album_service.dart';
import '../home/layout_geometry.dart';
import '../home/layout_model.dart';
import '../decorate/decoration_model.dart';
import 'photo_strip_renderer.dart';
import 'export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.layout,
    required this.photos,
    required this.decorationState,
    this.exportService,
    this.renderer,
    this.albumService,
    this.albumSessionId,
  });

  final PhotoLayout layout;
  final List<XFile> photos;
  final DecorationState decorationState;
  final ExportService? exportService;
  final PhotoStripRenderer? renderer;

  /// Album used for the "Save to Album" action. Null keeps the button out of
  /// the flow entirely rather than showing an action that cannot work.
  final AlbumService? albumService;

  /// Id of the album session being edited, so re-saving replaces it instead of
  /// creating a second copy.
  final String? albumSessionId;

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
  bool _isSavingToAlbum = false;
  bool _savedToAlbum = false;
  String? _albumError;
  String? _errorMessage;

  /// Whether this exact render has already been written to the device
  /// gallery. The Save action goes inert once it has, because a second tap
  /// would write a byte-identical duplicate; [Share] stays available.
  bool _gallerySaved = false;

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
    // Inert once saved: a second write of the same render is a duplicate
    // the user did not ask for.
    if (image == null || _isSaving || _isSharing || _gallerySaved) return;

    setState(() => _isSaving = true);
    try {
      await _exportService.saveToGallery(image, _generateFileName());
      if (!mounted) return;
      setState(() => _gallerySaved = true);
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
              Expanded(child: Text(_exportService.saveMessage)),
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

  /// Saves the composition to the offline album so it can be reopened and
  /// edited later.
  ///
  /// This stores the original photos plus the decoration state, not the
  /// rendered PNG: the album is an editable project, and the export is
  /// re-rendered from the source when the user asks for it.
  Future<void> _handleSaveToAlbum() async {
    final AlbumService? album = widget.albumService;
    if (album == null || _isSavingToAlbum || _isSaving || _isSharing) return;

    setState(() {
      _isSavingToAlbum = true;
      _albumError = null;
    });

    try {
      final session = await buildAlbumSession(
        layout: widget.layout,
        photos: widget.photos,
        decorationState: widget.decorationState,
        existingId: widget.albumSessionId,
      );
      final AlbumResult<void> result = await album.saveSession(session);
      if (!mounted) return;
      setState(() {
        _isSavingToAlbum = false;
        _savedToAlbum = result is AlbumSuccess;
      });
      if (result case AlbumFailure(:final String error)) {
        setState(() => _albumError = error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.albumSessionId == null
                  ? 'Saved to your album'
                  : 'Album session updated',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingToAlbum = false;
        _albumError = 'Could not save to the album: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: _errorMessage != null
            ? _buildError()
            : _isPreparing
                ? _buildPreparing()
                : _buildReady(),
      ),
    );
  }

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
                  style: AppText.heading.copyWith(color: AppColors.onDark),
                ),
                const SizedBox(height: S.xs),
                Text(
                  'Nothing was saved. Try rendering the strip again.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.darkMuted),
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

  Widget _buildReady() {
    final double aspect = PhotoStripGeometry.aspectRatio(widget.layout);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.xs),
          child: Row(
            children: <Widget>[
              MinimalIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close and discard',
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    header: true,
                    child: Text('Ready!', style: AppText.title),
                  ),
                ),
              ),
              MinimalIconButton(
                icon: Icons.home_rounded,
                tooltip: 'Back to Home',
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
        // The strip is the completion screen's whole point, so it claims every
        // pixel between the header and the actions instead of living inside a
        // fixed-height box. AspectRatio keeps it whole and centred: a tall
        // 4 CUT ribbon scales to the available height, a wide strip to the
        // available width - never cropped, never distorted.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.lg, 0, S.lg, S.sm),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: _KeepsakePreview(bytes: _renderedImage!),
              ),
            ),
          ),
        ),
        Text(
          'Save or share it ✨',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        _ActionBar(
          isSaving: _isSaving,
          isSharing: _isSharing,
          saveLabel: _exportService.saveLabel,
          saveHint: _exportService.saveHint,
          savedToGallery: _gallerySaved,
          onSave: _handleSave,
          onShare: _handleShare,
          albumAvailable: widget.albumService != null,
          isSavingToAlbum: _isSavingToAlbum,
          savedToAlbum: _savedToAlbum,
          albumError: _albumError,
          isEditingAlbumSession: widget.albumSessionId != null,
          onSaveToAlbum: _handleSaveToAlbum,
          onMakeAnother: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }
}

class _KeepsakePreview extends StatelessWidget {
  const _KeepsakePreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preview of your finished photo strip',
      image: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.94, end: 1),
        duration: AppMotion.of(context, AppMotion.slow),
        curve: AppMotion.curve,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        // A thin silver border and a soft shadow read as a finished print
        // without the retro sticker confetti, which fought the Minimal Dark
        // direction on the one screen where the work itself is the star.
        // The owner of the aspect box is the caller, so this fills whatever
        // box it is given rather than imposing its own ratio.
        child: Container(
          decoration: BoxDecoration(
            borderRadius: R.all(R.xs + 2),
            border: Border.all(color: AppColors.darkLine),
            boxShadow: AppShadows.lifted,
          ),
          child: ClipRRect(
            borderRadius: R.all(R.xs),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isSaving,
    required this.isSharing,
    required this.saveLabel,
    required this.saveHint,
    required this.onSave,
    required this.onShare,
    required this.onMakeAnother,
    this.savedToGallery = false,
    this.albumAvailable = false,
    this.isSavingToAlbum = false,
    this.savedToAlbum = false,
    this.albumError,
    this.isEditingAlbumSession = false,
    this.onSaveToAlbum,
  });

  final bool isSaving;
  final bool isSharing;

  /// The gallery write already succeeded for this exact render, so the
  /// primary action shows a persistent "Saved" state and does not offer a
  /// second click that would write a duplicate.
  final bool savedToGallery;

  /// Platform-specific primary action label ("Save to Photos" / "Download PNG").
  final String saveLabel;

  /// Extra guidance for the browser, or null on native.
  final String? saveHint;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMakeAnother;

  final bool albumAvailable;
  final bool isSavingToAlbum;
  final bool savedToAlbum;
  final String? albumError;
  final bool isEditingAlbumSession;
  final VoidCallback? onSaveToAlbum;

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
        color: AppColors.darkSurface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PressableScale(
            enabled: !isSaving && !isSharing && !savedToGallery,
            child: FilledButton.icon(
              onPressed: savedToGallery ? null : (isSaving ? null : onSave),
              icon: savedToGallery
                  ? const Icon(Icons.check_circle_rounded, size: 20)
                  : isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
              label: Text(savedToGallery ? 'Saved' : saveLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.hotPink,
                disabledBackgroundColor: savedToGallery
                    // Keep the filled, clearly-successful look after the save
                    // instead of sinking the button to disabled grey: "saved"
                    // is a result, not a dead control.
                    ? AppColors.success
                    : null,
                disabledForegroundColor: savedToGallery
                    ? AppColors.onAccent
                    : null,
                shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
              ),
            ),
          ),
          if (saveHint != null) ...<Widget>[
            const SizedBox(height: S.sm + S.xs),
            Text(
              saveHint!,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.darkMuted),
            ),
          ],
          const SizedBox(height: S.xxs),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                // The global theme paints outlined buttons on the light
                // paper surface; on this dark screen an inherited white fill
                // would swallow the white label, so both surfaces are set
                // explicitly: a lifted dark pill with a light label.
                backgroundColor: AppColors.darkElevated,
                foregroundColor: AppColors.onDark,
                disabledForegroundColor: AppColors.darkMuted,
                side: const BorderSide(color: AppColors.darkLine, width: 2),
                shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
              ),
            ),
          ),
          if (albumAvailable) ...<Widget>[
            const SizedBox(height: S.sm + S.xs),
            PressableScale(
              enabled: !isSaving && !isSharing && !isSavingToAlbum,
              child: OutlinedButton.icon(
                onPressed: isSavingToAlbum ? null : onSaveToAlbum,
                icon: isSavingToAlbum
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.hotPink,
                        ),
                      )
                    : Icon(
                        savedToAlbum
                            ? Icons.check_circle_rounded
                            : Icons.photo_library_rounded,
                        size: 20,
                        color: savedToAlbum ? AppColors.popYellow : null,
                      ),
                label: Text(
                  savedToAlbum
                      ? (isEditingAlbumSession ? 'Album updated' : 'Saved to album')
                      : (isEditingAlbumSession
                          ? 'Update album session'
                          : 'Save to album'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.darkElevated,
                  foregroundColor: AppColors.onDark,
                  disabledForegroundColor: AppColors.darkMuted,
                  side: const BorderSide(color: AppColors.darkLine),
                  shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                ),
              ),
            ),
            if (albumError != null)
              Padding(
                padding: const EdgeInsets.only(top: S.xs),
                child: Text(
                  albumError!,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.danger),
                ),
              ),
          ],
          const SizedBox(height: S.xxs),
          PressableScale(
            child: TextButton.icon(
              onPressed: onMakeAnother,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Make Another'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

