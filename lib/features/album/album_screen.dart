import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../decorate/decoration_model.dart';
import 'album_service.dart';
import 'album_session.dart';

/// The Album screen: shows saved sessions in a grid with thumbnails.
///
/// Users can tap a session to reopen it in the Decorate editor,
/// long-press to delete, or pull to refresh.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.albumService});

  final AlbumService albumService;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<AlbumSession> _sessions = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await widget.albumService.listSessions();
    if (!mounted) return;

    switch (result) {
      case AlbumSuccess(:final value):
        setState(() {
          _sessions = value;
          _loading = false;
        });
      case AlbumFailure(:final error):
        setState(() {
          _errorMessage = error;
          _loading = false;
        });
    }
  }

  Future<void> _deleteSession(AlbumSession session) async {
    final confirm = await _showDeleteDialog(context, session.displayName);
    if (confirm != true || !mounted) return;

    final result = await widget.albumService.deleteSession(session.id);
    if (!mounted) return;

    switch (result) {
      case AlbumSuccess():
        setState(() {
          _sessions.removeWhere((s) => s.id == session.id);
        });
        _showSnackBar('Session deleted');
      case AlbumFailure(:final error):
        _showSnackBar('Failed to delete: $error', isError: true);
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('"$name" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _reopenSession(AlbumSession session) async {
    // Convert photo bytes back to XFile objects for the Decorate screen
    // We need to create temporary files from the bytes
    // For now, navigate to DecorateScreen with the session data
    // The DecorateScreen expects List<XFile>, so we need to handle this
    // This is a limitation - we'd need to write bytes to temp files first
    _showSnackBar('Reopening sessions coming soon - need temp file creation');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _errorMessage != null
                      ? _buildError()
                      : _sessions.isEmpty
                          ? _buildEmptyState()
                          : _buildSessionGrid(),
            ),
            const CheckerboardPattern(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Album',
                style: AppText.title.copyWith(color: AppColors.onDark),
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.refresh_rounded,
            onPressed: _loadSessions,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: AppColors.hotPink),
      );

  Widget _buildError() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(S.lg),
          child: Container(
            padding: const EdgeInsets.all(S.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: R.all(R.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.16),
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
                  'Failed to load album',
                  textAlign: TextAlign.center,
                  style: AppText.heading.copyWith(color: AppColors.onDark),
                ),
                const SizedBox(height: S.xs),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.darkMuted),
                ),
                const SizedBox(height: S.lg),
                PressableScale(
                  child: FilledButton.icon(
                    onPressed: _loadSessions,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.hotPink.withValues(alpha: 0.16),
                  borderRadius: R.all(R.xl),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 40,
                  color: AppColors.hotPink,
                ),
              ),
              const SizedBox(height: S.md),
              Text(
                'No saved sessions yet',
                textAlign: TextAlign.center,
                style: AppText.heading.copyWith(color: AppColors.onDark),
              ),
              const SizedBox(height: S.xs),
              Text(
                'Capture and decorate photos, then save them to see them here.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.darkMuted),
              ),
              const SizedBox(height: S.lg),
              PressableScale(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Start Photo Booth'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.hotPink,
                    shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSessionGrid() => RefreshIndicator(
        onRefresh: _loadSessions,
        color: AppColors.hotPink,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md + 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: S.md,
            crossAxisSpacing: S.md,
            childAspectRatio: 0.85,
          ),
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];
            return _SessionCard(
              session: session,
              onTap: () => _reopenSession(session),
              onLongPress: () => _deleteSession(session),
            );
          },
        ),
      );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onLongPress,
  });

  final AlbumSession session;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Session ${session.displayName}, ${session.photoCount} photos',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: R.all(R.md),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        session.thumbnailBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: RetroSticker(type: StickerType.star, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(S.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(color: AppColors.onDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.photoCount} photo${session.photoCount == 1 ? '' : 's'} · ${session.layout.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.darkMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.surface : AppColors.background,
      shape: CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.onDark : AppColors.darkMuted,
          ),
        ),
      ),
    );
  }
}