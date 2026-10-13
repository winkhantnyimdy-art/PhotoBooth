import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../album/album_scope.dart';
import '../album/album_screen.dart';
import '../album/album_service_contract.dart';
import '../album/album_thumbnail.dart';
import '../camera/camera_preferences.dart';
import '../camera/preferences_service.dart';

/// Camera and storage preferences.
///
/// Every change is written to disk immediately, so a preference survives
/// closing the app rather than being held in memory until a clean exit.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.preferencesService});

  final PreferencesService preferencesService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late CameraPreferences _preferences;
  int? _albumBytes;
  bool _albumUsageKnown = false;
  bool _usageRequested = false;

  @override
  void initState() {
    super.initState();
    // PreferencesService is already constructed by the caller, so the saved
    // values can be read synchronously - no loading gate needed.
    _preferences = widget.preferencesService.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Album usage is read from the inherited album, and an inherited widget
    // must not be read from initState. Guarded so it runs once per mount.
    if (_usageRequested) return;
    _usageRequested = true;
    _loadAlbumUsage();
  }

  Future<void> _loadAlbumUsage() async {
    final AlbumService? album = maybeAlbumOf(context);
    if (album == null) return;
    final AlbumResult<int?> usage = await album.getStorageUsage();
    if (!mounted) return;
    setState(() {
      _albumBytes = usage is AlbumSuccess<int?> ? usage.value : null;
      _albumUsageKnown = true;
    });
  }

  /// Applies a preference change and persists it immediately.
  Future<void> _update(CameraPreferences next) async {
    final CameraPreferences previous = _preferences;
    // Optimistic: the switch/segment moves on the same frame as the tap.
    setState(() => _preferences = next);
    final bool saved = await widget.preferencesService.save(next);
    if (!mounted) return;
    if (!saved) {
      setState(() => _preferences = previous);
      _showSnackBar('Could not save that setting', isError: true);
    }
  }

  Future<void> _clearAlbum() async {
    final AlbumService? album = maybeAlbumOf(context);
    if (album == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear the whole album?'),
        content: const Text(
          'Every saved session and its original photos will be permanently '
          'deleted. This cannot be undone.',
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
    if (confirmed != true || !mounted) return;

    final AlbumResult<void> result = await album.clearAll();
    if (!mounted) return;
    switch (result) {
      case AlbumSuccess():
        _showSnackBar('Album cleared');
        await _loadAlbumUsage();
      case AlbumFailure(:final String error):
        _showSnackBar('Could not clear the album: $error', isError: true);
    }
  }

  void _openAlbum() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AlbumScreen(
          albumService: albumOf(context),
          photoFiles: createPlatformAlbumPhotoFiles(),
        ),
      ),
    ).then((_) => _loadAlbumUsage());
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
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildCameraSection(),
                    const SizedBox(height: S.md),
                    _buildStorageSection(),
                    const SizedBox(height: S.md),
                    _buildAboutSection(),
                  ],
                ),
              ),
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
        children: <Widget>[
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Settings',
                style: AppText.title.copyWith(color: AppColors.onDark),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildCameraSection() => _Section(
        title: 'Camera',
        icon: Icons.camera_alt_rounded,
        children: <Widget>[
          _CountdownPicker(
            value: _preferences.countdownSeconds,
            onChanged: (int seconds) => _update(
              _preferences.copyWith(countdownSeconds: seconds),
            ),
          ),
          const SizedBox(height: S.sm),
          _ToggleRow(
            title: 'Shutter sound',
            subtitle: 'Play a click when a photo is taken',
            icon: Icons.volume_up_rounded,
            value: _preferences.shutterSoundEnabled,
            onChanged: (bool value) => _update(
              _preferences.copyWith(shutterSoundEnabled: value),
            ),
          ),
          const SizedBox(height: S.sm),
          _ToggleRow(
            title: 'Flash animation',
            subtitle: 'Flash the screen when a photo is taken',
            icon: Icons.flash_on_rounded,
            value: _preferences.flashAnimationEnabled,
            onChanged: (bool value) => _update(
              _preferences.copyWith(flashAnimationEnabled: value),
            ),
          ),
          const SizedBox(height: S.sm),
          _ToggleRow(
            title: 'Mirror selfies',
            subtitle: 'On = front-camera photos are saved mirrored, as they '
                'look in the viewfinder. Off = saved in natural orientation. '
                'The back camera is never mirrored either way.',
            icon: Icons.flip_camera_android_rounded,
            value: _preferences.mirrorSelfies,
            onChanged: (bool value) => _update(
              _preferences.copyWith(mirrorSelfies: value),
            ),
          ),
        ],
      );

  Widget _buildStorageSection() {
    final AlbumService? album = maybeAlbumOf(context);
    final String usage = !_albumUsageKnown
        ? 'Checking…'
        : _albumBytes == null
            ? kIsWeb
                ? 'Not measurable in this browser'
                : 'Not measurable on this device'
            : formatAlbumBytes(_albumBytes!);

    return _Section(
      title: 'Storage',
      icon: Icons.storage_rounded,
      children: <Widget>[
        _InfoRow(
          title: 'Album size',
          subtitle: '$usage · stored in ${album?.backendName ?? 'local storage'}',
          icon: Icons.sd_storage_rounded,
        ),
        const SizedBox(height: S.sm),
        _InfoRow(
          title: 'Album',
          subtitle: 'Reopen, edit or delete saved sessions',
          icon: Icons.photo_library_rounded,
          onTap: album == null ? null : _openAlbum,
        ),
        const SizedBox(height: S.sm),
        _InfoRow(
          title: 'Clear album',
          subtitle: 'Delete every saved session and photo',
          icon: Icons.delete_forever_rounded,
          destructive: true,
          onTap: album == null ? null : _clearAlbum,
        ),
        const SizedBox(height: S.sm),
        _Note(
          kIsWeb
              ? 'Sessions are stored only on this device. Clearing this site\'s data '
                  'in your browser, or uninstalling the app, will erase them.'
              : 'Sessions are stored only on this device. Uninstalling the app, '
                  'or clearing the app\'s data, will erase them.',
        ),
      ],
    );
  }

  Widget _buildAboutSection() => _Section(
        title: 'About',
        icon: Icons.info_outline_rounded,
        children: <Widget>[
          const _InfoRow(
            title: 'Version',
            subtitle: '1.0.0',
            icon: Icons.tag_rounded,
          ),
          const SizedBox(height: S.sm),
          const _InfoRow(
            title: 'Privacy',
            subtitle: 'No accounts, no cloud, no analytics. Photos never leave '
                'your device.',
            icon: Icons.privacy_tip_rounded,
          ),
        ],
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkElevated,
        borderRadius: R.all(R.lg),
        border: Border.all(color: AppColors.darkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.sm),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: AppColors.hotPink),
                const SizedBox(width: S.sm),
                Text(
                  title.toUpperCase(),
                  style: AppText.overline.copyWith(color: AppColors.darkMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPicker extends StatelessWidget {
  const _CountdownPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: R.all(R.md),
        border: Border.all(color: AppColors.darkLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.timer_rounded, size: 20, color: AppColors.onDark),
              const SizedBox(width: S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Countdown',
                      style: AppText.label.copyWith(color: AppColors.onDark),
                    ),
                    Text(
                      'Seconds before each photo is taken',
                      style: AppText.caption.copyWith(color: AppColors.darkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.md),
          Wrap(
            spacing: S.sm,
            runSpacing: S.sm,
            children: <Widget>[
              for (final int seconds in CameraPreferences.validCountdownOptions)
                _CountdownChip(
                  seconds: seconds,
                  selected: value == seconds,
                  onTap: () => onChanged(seconds),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$seconds second countdown',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: ValueKey<String>('countdown-$seconds'),
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsets.symmetric(
            horizontal: S.lg,
            vertical: S.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.hotPink : AppColors.darkSurface,
            borderRadius: R.pillRadius,
            border: Border.all(
              color: selected ? AppColors.hotPink : AppColors.darkLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '$seconds sec',
            style: AppText.buttonSmall.copyWith(
              color: selected ? AppColors.onAccent : AppColors.onDark,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.sm, S.sm),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: R.all(R.md),
        border: Border.all(color: AppColors.darkLine),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: AppColors.onDark),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppText.label.copyWith(color: AppColors.onDark),
                ),
                Text(
                  subtitle,
                  style: AppText.caption.copyWith(color: AppColors.darkMuted),
                ),
              ],
            ),
          ),
          Switch(
            key: ValueKey<String>('toggle-$title'),
            value: value,
            activeThumbColor: AppColors.hotPink,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color accent = destructive ? AppColors.danger : AppColors.onDark;
    return Material(
      color: AppColors.darkSurface,
      borderRadius: R.all(R.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            borderRadius: R.all(R.md),
            border: Border.all(
              color: destructive
                  ? AppColors.danger.withValues(alpha: 0.5)
                  : AppColors.darkLine,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: accent),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: AppText.label.copyWith(color: accent)),
                    Text(
                      subtitle,
                      style: AppText.caption.copyWith(color: AppColors.darkMuted),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.darkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: S.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.darkMuted),
          const SizedBox(width: S.xs),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: AppColors.darkMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
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
      color: AppColors.darkElevated,
      shape: const CircleBorder(side: BorderSide(color: AppColors.darkLine)),
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