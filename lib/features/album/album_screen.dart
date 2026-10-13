import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../decorate/decoration_model.dart';
import '../decorate/decorate_screen.dart';
import 'album_record.dart';
import 'album_service.dart';
import 'album_session.dart';
import 'album_thumbnail.dart';

/// The offline album: every session the user has saved, newest first.
///
/// Tapping a session reopens it in the Decorate editor with its original
/// photos and its full decoration state intact, so the user can keep editing
/// and re-export instead of starting over.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({
    super.key,
    required this.albumService,
    required this.photoFiles,
  });

  final AlbumService albumService;
  final AlbumPhotoFiles photoFiles;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<AlbumSummary> _sessions = <AlbumSummary>[];
  bool _loading = true;
  String? _errorMessage;
  int? _usageBytes;
  String? _openingSessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    // Temporary files written while materialising a session are no longer
    // needed once the album closes.
    widget.photoFiles.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    final AlbumResult<List<AlbumSummary>> result =
        await widget.albumService.listSessions();
    if (!mounted) return;

    switch (result) {
      case AlbumSuccess(:final List<AlbumSummary> value):
        setState(() {
          _sessions = value;
          _loading = false;
        });
      case AlbumFailure(:final String error):
        setState(() {
          _errorMessage = error;
          _loading = false;
        });
    }

    await _loadUsage();
  }

  Future<void> _loadUsage() async {
    final AlbumResult<int?> usage = await widget.albumService.getStorageUsage();
    if (!mounted) return;
    setState(() {
      _usageBytes = usage is AlbumSuccess<int?> ? usage.value : null;
    });
  }

  Future<void> _deleteSession(AlbumSummary session) async {
    final bool? confirm = await _showDeleteDialog(context, session.displayName);
    if (confirm != true || !mounted) return;

    final AlbumResult<void> result =
        await widget.albumService.deleteSession(session.id);
    if (!mounted) return;

    switch (result) {
      case AlbumSuccess():
        setState(() {
          _sessions.removeWhere((AlbumSummary s) => s.id == session.id);
        });
        _showSnackBar('Session deleted');
        await _loadUsage();
      case AlbumFailure(:final String error):
        _showSnackBar('Could not delete: $error', isError: true);
    }
  }

  Future<void> _clearAll() async {
    final bool? confirm = await _showClearAllDialog(context, _sessions.length);
    if (confirm != true || !mounted) return;

    final AlbumResult<void> result = await widget.albumService.clearAll();
    if (!mounted) return;

    switch (result) {
      case AlbumSuccess():
        setState(() => _sessions = <AlbumSummary>[]);
        _showSnackBar('Album cleared');
        await _loadUsage();
      case AlbumFailure(:final String error):
        _showSnackBar('Could not clear the album: $error', isError: true);
    }
  }

  /// Loads the session's original photos, then hands them to the editor.
  Future<void> _reopenSession(AlbumSummary session) async {
    if (_openingSessionId != null) return;
    setState(() => _openingSessionId = session.id);

    final AlbumResult<AlbumSession> loaded =
        await widget.albumService.loadSession(session.id);

    if (!mounted) {
      _openingSessionId = null;
      return;
    }
    setState(() => _openingSessionId = null);

    switch (loaded) {
      case AlbumFailure(:final String error):
        _showSnackBar(error, isError: true);
        // The stored rows may now be inconsistent with the blobs, so refresh
        // the grid to show the damaged state honestly.
        await _loadSessions();
      case AlbumSuccess(:final AlbumSession value):
        await _openInEditor(value);
    }
  }

  Future<void> _openInEditor(AlbumSession session) async {
    final List<XFile> photos = <XFile>[];
    for (int i = 0; i < session.photoBytes.length; i++) {
      photos.add(
        await widget.photoFiles.materialize(
          session.photoBytes[i],
          '${session.id}_$i.jpg',
        ),
      );
    }

    if (!mounted) return;

    await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (BuildContext context) => DecorateScreen(
          layout: session.layout,
          photos: photos,
          // Restoring the saved state is what makes this an *edit* rather than
          // a fresh composition: frame theme, stickers, captions, filter and
          // adjustments all come back exactly as they were saved.
          initialDecorationState: session.decorationState,
          albumSessionId: session.id,
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this session?'),
        content: Text(
          '"$name" and its original photos will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showClearAllDialog(BuildContext context, int count) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear the whole album?'),
        content: Text(
          count == 0
              ? 'There is nothing to clear.'
              : 'All $count saved session${count == 1 ? '' : 's'} and their '
                  'original photos will be permanently deleted. This cannot '
                  'be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.hotPink),
                    )
                  : _errorMessage != null
                      ? _buildError()
                      : _sessions.isEmpty
                          ? _buildEmptyState()
                          : _buildSessionGrid(),
            ),
            if (_sessions.isNotEmpty) _buildStorageFooter(),
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
        children: <Widget>[
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
            icon: Icons.delete_sweep_rounded,
            tooltip: 'Clear all sessions',
            onPressed: _sessions.isEmpty ? null : _clearAll,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageFooter() {
    final String usage = _usageBytes == null
        ? kIsWeb
            ? 'Storage used: not measurable in this browser'
            : 'Storage used: not measurable on this device'
        : 'Storage used: ${formatAlbumBytes(_usageBytes!)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        S.md,
        S.sm,
        S.md,
        S.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$usage  ·  Saved on this device only',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.darkMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            kIsWeb
                ? 'Clearing this site\'s data in your browser will erase the album.'
                : 'Uninstalling the app will erase the album.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.darkMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(S.lg),
          child: Container(
            padding: const EdgeInsets.all(S.lg),
            decoration: BoxDecoration(
              color: AppColors.darkElevated,
              borderRadius: R.all(R.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                  'Could not read the album',
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
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.hotPink,
                      shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmptyState() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
                'Take photos, decorate them, then tap "Save to Album" on the '
                'export screen. Saved sessions stay editable here.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.darkMuted),
              ),
              const SizedBox(height: S.lg),
              PressableScale(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((Route<void> r) => r.isFirst),
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
          padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: S.md,
            crossAxisSpacing: S.md,
            childAspectRatio: 0.8,
          ),
          itemCount: _sessions.length,
          itemBuilder: (BuildContext context, int index) {
            final AlbumSummary session = _sessions[index];
            return _SessionCard(
              session: session,
              busy: _openingSessionId == session.id,
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
    required this.busy,
    required this.onTap,
    required this.onLongPress,
  });

  final AlbumSummary session;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool damaged = session.isDamaged;
    return Semantics(
      button: true,
      label: damaged
          ? '${session.displayName}, photos missing, cannot reopen'
          : '${session.displayName}, ${session.photoCount} photos, '
              'tap to edit',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          key: ValueKey<String>('album-session-${session.id}'),
          duration: AppMotion.of(context, AppMotion.fast),
          decoration: BoxDecoration(
            color: AppColors.darkElevated,
            borderRadius: R.all(R.md),
            border: Border.all(
              color: damaged ? AppColors.danger : AppColors.darkLine,
              width: damaged ? 1.5 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: session.thumbnail != null
                          ? Image.memory(
                              session.thumbnail!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          : const ColoredBox(color: AppColors.darkElevated),
                    ),
                    if (busy)
                      const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.hotPink,
                            ),
                          ),
                        ),
                      ),
                    if (!damaged && !busy)
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: RetroSticker(type: StickerType.star, size: 20),
                      ),
                    if (damaged)
                      const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 30,
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(S.sm, S.xs, S.sm, S.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      session.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(color: AppColors.onDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      damaged
                          ? 'Photos missing'
                          : '${session.photoCount} photo'
                              '${session.photoCount == 1 ? '' : 's'}'
                              ' · ${albumLayoutLabel(session.layoutName)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: damaged ? AppColors.danger : AppColors.darkMuted,
                        fontSize: 10,
                      ),
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
  const _CircleButton({required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget button = Material(
      color: enabled ? AppColors.darkElevated : AppColors.darkSurface,
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
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}