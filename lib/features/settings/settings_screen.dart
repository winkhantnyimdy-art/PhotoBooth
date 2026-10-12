import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../camera/camera_preferences.dart';
import '../camera/preferences_service.dart';

/// The Settings screen: manages camera preferences and app settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.preferencesService});

  final PreferencesService preferencesService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late CameraPreferences _preferences;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    _preferences = widget.preferencesService.load();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _updatePreferences(CameraPreferences newPrefs) async {
    final success = await widget.preferencesService.save(newPrefs);
    if (!mounted) return;
    setState(() {
      _preferences = newPrefs;
    });
    if (success) {
      _showSnackBar('Settings saved');
    } else {
      _showSnackBar('Failed to save settings', isError: true);
    }
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.hotPink))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(S.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSection(
                            title: 'Camera',
                            icon: Icons.camera_alt_rounded,
                            children: [
                              _buildCountdownPicker(),
                              const SizedBox(height: S.md),
                              _buildToggleTile(
                                title: 'Shutter Sound',
                                subtitle: 'Play a sound when capturing a photo',
                                icon: Icons.volume_up_rounded,
                                value: _preferences.shutterSoundEnabled,
                                onChanged: (v) => _updatePreferences(
                                  _preferences.copyWith(shutterSoundEnabled: v),
                                ),
                              ),
                              const SizedBox(height: S.md),
                              _buildToggleTile(
                                title: 'Flash Animation',
                                subtitle: 'Show a white flash on capture',
                                icon: Icons.flash_on_rounded,
                                value: _preferences.flashAnimationEnabled,
                                onChanged: (v) => _updatePreferences(
                                  _preferences.copyWith(flashAnimationEnabled: v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: S.lg),
                          _buildSection(
                            title: 'Storage',
                            icon: Icons.storage_rounded,
                            children: [
                              _buildInfoTile(
                                title: 'Album Storage',
                                subtitle: 'Manage saved sessions in the Album screen',
                                icon: Icons.photo_library_rounded,
                                onTap: () => Navigator.of(context).pushNamed('/album'),
                              ),
                            ],
                          ),
                          const SizedBox(height: S.lg),
                          _buildSection(
                            title: 'About',
                            icon: Icons.info_outline_rounded,
                            children: [
                              _buildInfoTile(
                                title: 'Version',
                                subtitle: '1.0.0',
                                icon: Icons.tag_rounded,
                              ),
                              _buildInfoTile(
                                title: 'Privacy',
                                subtitle: 'All data stays on your device. No cloud sync.',
                                icon: Icons.privacy_tip_rounded,
                              ),
                            ],
                          ),
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
        children: [
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
          const SizedBox(width: 44), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: R.all(R.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.xs),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.hotPink),
                const SizedBox(width: S.sm),
                Text(title, style: AppText.heading.copyWith(color: AppColors.onDark, fontSize: 16)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCountdownPicker() {
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: R.all(R.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 20, color: AppColors.onDark),
              const SizedBox(width: S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Countdown', style: AppText.label.copyWith(color: AppColors.onDark)),
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
            children: CameraPreferences.validCountdownOptions.map((seconds) {
              final selected = _preferences.countdownSeconds == seconds;
              return GestureDetector(
                onTap: () => _updatePreferences(
                  _preferences.copyWith(countdownSeconds: seconds),
                ),
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.fast),
                  padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.md),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.hotPink : AppColors.surface,
                    borderRadius: R.pillRadius,
                    border: Border.all(
                      color: selected ? AppColors.hotPink : AppColors.line,
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
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: R.all(R.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.onDark),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(color: AppColors.onDark)),
                Text(subtitle, style: AppText.caption.copyWith(color: AppColors.darkMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.hotPink,
            activeTrackColor: AppColors.hotPink.withValues(alpha: 0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.all(R.md),
        child: Container(
          padding: const EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: R.all(R.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.onDark),
              const SizedBox(width: S.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.label.copyWith(color: AppColors.onDark)),
                    Text(subtitle, style: AppText.caption.copyWith(color: AppColors.darkMuted)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: AppColors.darkMuted),
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