import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/app_surface.dart';
import '../../shared/pressable.dart';
import '../home/layout_model.dart';
import '../review/review_screen.dart';
import 'captured_session.dart';
import 'session_state.dart';
import 'session_runner.dart';
import 'timing.dart';

/// Signature for creating a [CameraController] given a description and preset.
typedef ControllerFactory = CameraController Function(
  CameraDescription description,
  ResolutionPreset resolutionPreset,
);

/// Screen that shows a live camera preview with session flow.
///
/// Implements the PhotoBooth session: start → countdown → capture
/// (multi-shot) → Review. Capture timing, camera lifecycle and session state
/// handling are unchanged; only the presentation layer is styled.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.layout,
    this.cameraProvider,
    this.captureProvider,
    this.controllerFactory,
    this.timing,
    this.onStateChange,
  });

  /// The layout chosen on the home screen.
  final PhotoLayout layout;

  /// Optional provider used by tests to inject camera list.
  /// When null, native [availableCameras] is called.
  final Future<List<CameraDescription>> Function()? cameraProvider;

  /// Optional capture provider used by tests to fake [takePicture].
  /// When null, [CameraController.takePicture] is called.
  final Future<XFile?> Function()? captureProvider;

  /// Optional factory for creating [CameraController] instances.
  /// When null, the real [CameraController] constructor is used.
  final ControllerFactory? controllerFactory;

  /// Optional timing abstraction (defaults to [SystemTiming]).
  final Timing? timing;

  /// Optional callback for tests to record state transitions.
  final void Function(CameraSessionState state, {int? countdown, int? shot})?
  onStateChange;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  String? _error;
  bool _loading = true;
  bool _initialized = false;
  CameraSessionState _sessionState = CameraSessionState.ready;
  int _countdownNumber = 0;
  int _sessionCount = 0;
  final List<XFile> _capturedPhotos = [];
  CancellationToken _cancelToken = CancellationToken();
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  void _initCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _cameras = await (widget.cameraProvider ?? availableCameras)();
    } catch (e) {
      _setError('Camera unavailable');
      return;
    }

    if (_cameras.isEmpty) {
      _setError('No cameras detected');
      return;
    }

    final front = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = (widget.controllerFactory ?? CameraController.new)(
      front,
      ResolutionPreset.high,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      _aspectRatio = _controller!.value.previewSize != null
          ? _controller!.value.previewSize!.width /
                _controller!.value.previewSize!.height
          : null;
      setState(() {
        _loading = false;
        _initialized = true;
      });
    } catch (e) {
      _setError('Camera failed to initialize');
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _loading = false;
        _initialized = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelToken = CancellationToken(cancelled: true);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller!.dispose();
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_initialized) {
        _initCamera();
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    final currentIndex = _cameras.indexWhere(
      (c) => c.name == _controller!.description.name,
    );
    final nextIndex = (currentIndex + 1) % _cameras.length;
    final newCamera = _cameras[nextIndex];

    await _controller!.dispose();
    _controller = (widget.controllerFactory ?? CameraController.new)(
      newCamera,
      ResolutionPreset.high,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        _aspectRatio = _controller!.value.previewSize != null
            ? _controller!.value.previewSize!.width /
                  _controller!.value.previewSize!.height
            : null;
        setState(() {});
      }
    } catch (e) {
      _setError('Camera failed to initialize');
    }
  }

  Future<void> _startSession() async {
    if (_sessionState != CameraSessionState.ready) return;
    if (_controller == null || !_initialized) return;

    setState(() {
      _sessionCount = 0;
      _capturedPhotos.clear();
      _cancelToken = CancellationToken();
    });

    final totalShots = widget.layout.photoCount;
    final timing = widget.timing ?? SystemTiming();

    final runner = SessionRunner(
      timing: timing,
      takePicture: widget.captureProvider ?? _controller!.takePicture,
      onStep: (state, {countdown, shot}) {
        if (!mounted) return;
        setState(() {
          _sessionState = state;
          _countdownNumber = countdown ?? 0;
          // The runner emits betweenShots after every successful capture, which
          // is the only per-shot signal it reports. Counting those keeps the
          // "shots remaining" indicator truthful.
          if (state == CameraSessionState.betweenShots) _sessionCount++;
        });
        widget.onStateChange?.call(state, countdown: countdown, shot: shot);
      },
      cancelToken: _cancelToken,
    );

    setState(() {
      _sessionState = CameraSessionState.countdown;
    });

    final result = await runner.run(totalShots);

    if (!mounted) return;

    if (_cancelToken.cancelled) {
      setState(() {
        _sessionState = CameraSessionState.ready;
      });
      return;
    }

    if (result.success && result.photos.length == totalShots) {
      setState(() {
        _sessionState = CameraSessionState.complete;
        _capturedPhotos.addAll(result.photos);
      });
      _navigateToReview();
    } else {
      setState(() {
        _sessionState = CameraSessionState.error;
        _error = result.error ?? 'Capture failed';
      });
    }
  }

  Future<void> _navigateToReview() async {
    final session = CapturedSession(
      layout: widget.layout,
      photos: List<XFile>.unmodifiable(_capturedPhotos),
      aspectRatio: _aspectRatio,
    );
    final NavigatorState navigator = Navigator.of(context);
    await navigator.push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => ReviewScreen(
          layout: session.layout,
          photos: session.photos,
          aspectRatio: session.aspectRatio,
        ),
      ),
    );

    // Coming back from Review means the user chose Retake (or backed out), so
    // the session must be re-armed. Without this the camera screen is left in
    // the `complete` state and the shutter stays disabled, stranding the user.
    // If the whole flow was finished, this route is already gone and the
    // `mounted` check stops us touching a disposed state.
    if (!mounted) return;
    setState(() {
      _sessionState = CameraSessionState.ready;
      _capturedPhotos.clear();
      _cancelToken = CancellationToken();
    });
  }

  void _retry() {
    if (_controller == null || !_initialized) {
      _initCamera();
      return;
    }
    setState(() {
      _error = null;
      _capturedPhotos.clear();
      _sessionState = CameraSessionState.ready;
    });
  }

  bool get _isSwitchingAllowed =>
      _cameras.length > 1 &&
      (_sessionState == CameraSessionState.ready ||
          _sessionState == CameraSessionState.error);

  @override
  Widget build(BuildContext context) {
    final bool canPop = !_sessionState.isActive;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!canPop && !didPop) {
          _confirmLeaveSession(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Camera'),
          automaticallyImplyLeading: true,
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: S.md),
              child: _LayoutIndicator(
                layout: widget.layout,
                onSwitch: _isSwitchingAllowed ? _switchCamera : null,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              // The preview and the controls share one column so they can
              // never starve each other. As a Scaffold `bottomNavigationBar`
              // the control bar expanded to the full available height and
              // left the preview with zero height, which is what made the
              // viewfinder look like a blank white page.
              : Column(
                  children: <Widget>[
                    Expanded(child: _buildCameraPreview()),
                    _buildControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveSession(BuildContext context) async {
    final token = _cancelToken;
    final navigator = Navigator.of(context);
    final confirm = await _showLeaveDialog(context);
    if (confirm == true && mounted) {
      token.cancelled = true;
      navigator.pop();
    }
  }

  Future<bool?> _showLeaveDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the session?'),
        content: const Text(
          'Your current session will be cancelled and any captured photos will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  /// Friendly failure card. Keeps the retry affordance so a camera problem is
  /// always recoverable without leaving the screen.
  Widget _buildError() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(S.lg),
      child: AppSurface(
        semanticLabel: 'Camera error: $_error',
        padding: const EdgeInsets.all(S.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: R.all(R.xl),
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 30,
                color: AppColors.accentInk,
              ),
            ),
            const SizedBox(height: S.md),
            Text(_error!, textAlign: TextAlign.center, style: AppText.heading),
            const SizedBox(height: S.xs),
            Text(
              'Check that a camera is available, then try again.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: S.lg),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    ),
  );

  /// The preview is the hero: chrome hugs the edges so the live image itself
  /// is never obscured.
  ///
  /// The viewport is deliberately dark. The camera plugin renders the feed into
  /// a platform texture, and a device or emulator whose camera cannot deliver
  /// frames leaves that texture unpainted; against a dark backdrop that reads
  /// as an empty viewfinder instead of a blank white page.
  Widget _buildCameraPreview() {
    final CameraController? controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
      child: ClipRRect(
        borderRadius: R.all(R.lg),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.previewBackdrop),
          // fit: expand gives every layer the full viewport. A non-positioned
          // childless overlay (the capture flash) would otherwise collapse to
          // zero size and never be seen.
          child: Stack(
            key: const ValueKey('camera-viewport'),
            // Loose fit: the feed is the only non-positioned child, and it
            // needs loose constraints so CameraPreview's own AspectRatio can
            // letterbox it at its true shape. The overlays are positioned, so
            // they still fill the viewport exactly.
            children: <Widget>[
              // Keyed on the controller so switching cameras always builds a
              // fresh texture subtree instead of reusing a stale one.
              //
              // CameraPreview is used bare on purpose: it already applies its
              // own AspectRatio and StackFit.expand around the platform
              // texture, so wrapping it in a second aspect ratio here would
              // conflict with it and collapse the feed's box.
              Center(
                child: KeyedSubtree(
                  key: ValueKey<CameraController>(controller),
                  child: CameraPreview(controller),
                ),
              ),
              if (_sessionState == CameraSessionState.countdown)
                Positioned.fill(
                  child: _CountdownOverlay(number: _countdownNumber),
                ),
              if (_sessionState == CameraSessionState.capturing)
                const Positioned.fill(
                  child: _FlashOverlay(key: ValueKey('capture-flash')),
                ),
              if (_sessionState.isActive)
                Positioned(
                  top: S.md,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ProgressIndicator(
                      captured: _sessionCount,
                      total: widget.layout.photoCount,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom control bar: camera switch, shutter, shot hint.
  ///
  /// Sized to its content rather than the space it is offered, because a
  /// loose height constraint here would let it stretch and squeeze the
  /// preview out of existence.
  Widget _buildControls() => Container(
    padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: <Widget>[
          _CircleControl(
            icon: Icons.cameraswitch_rounded,
            tooltip: 'Switch camera',
            onPressed: _isSwitchingAllowed ? _switchCamera : null,
          ),
          Expanded(
            child: Center(
              child: _ShutterButton(
                enabled: _sessionState.isReady,
                busy: _sessionState.isActive,
                onPressed: _startSession,
              ),
            ),
          ),
          _ShotCountHint(total: widget.layout.photoCount),
        ],
      ),
    ),
  );
}

/// Compact layout pill in the app bar: how many photos this session takes.
class _LayoutIndicator extends StatelessWidget {
  const _LayoutIndicator({required this.layout, this.onSwitch});

  final PhotoLayout layout;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Layout ${layout.label}, ${layout.description}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: S.sm + S.xs,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: R.pillRadius,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.grid_view_rounded,
              size: 15,
              color: AppColors.accentInk,
            ),
            const SizedBox(width: 6),
            Text(
              layout.label,
              style: AppText.buttonSmall.copyWith(
                color: AppColors.accentInk,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${layout.photoCount} photos',
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (onSwitch != null) ...<Widget>[
              const SizedBox(width: 4),
              InkWell(
                onTap: onSwitch,
                borderRadius: R.pillRadius,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular icon button used for the camera switch.
class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: SizedBox(
          width: S.touchTarget,
          height: S.touchTarget,
          child: Material(
            color: enabled ? AppColors.surfaceMuted : Colors.transparent,
            shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                icon,
                size: 21,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Remaining-shot hint that balances the control bar.
class _ShotCountHint extends StatelessWidget {
  const _ShotCountHint({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: S.touchTarget,
      height: S.touchTarget,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.photo_camera_back_rounded,
              size: 20,
              color: AppColors.accentInk,
            ),
            Text(
              '$total',
              style: AppText.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chunky photo-booth shutter: white ring around a pink core.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Stop the session' : 'Take photos',
      child: PressableScale(
        key: const ValueKey('shutter'),
        enabled: enabled,
        pressedScale: 0.93,
        // PressableScale only supplies the visual press response; the tap
        // itself must be owned by the control, otherwise the shutter would be
        // inert and the whole capture flow unreachable.
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: enabled ? AppColors.accent : AppColors.lineStrong,
                  width: 2.5,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? AppColors.accent : AppColors.surfaceMuted,
                ),
                child: Center(
                  child: Icon(
                    busy ? Icons.stop_rounded : Icons.camera_alt_rounded,
                    color: enabled ? AppColors.onAccent : AppColors.textMuted,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Countdown badge over the preview.
///
/// Deliberately a centred disc instead of an opaque full-screen scrim: the
/// number is unmistakable while the live preview stays visible.
class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scrim,
      child: Center(
        child: Container(
          width: 148,
          height: 148,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textPrimary.withValues(alpha: 0.82),
            border: Border.all(color: AppColors.accent, width: 3),
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.medium),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$number',
              key: ValueKey<int>(number),
              style: AppText.numeric.copyWith(color: AppColors.onDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flash overlay shown briefly on capture.
///
/// Childless on purpose, so it relies on the parent [Stack]'s
/// `StackFit.expand` to fill the viewport.
class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.white);
  }
}

/// Shot progress pill: "2 of 4" plus a dot per photo, so the user always knows
/// how many shots remain.
class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.captured, required this.total});

  final int captured;
  final int total;

  @override
  Widget build(BuildContext context) {
    final int remaining = (total - captured).clamp(0, total);
    return Semantics(
      label: '$captured of $total photos taken, $remaining remaining',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.82),
          borderRadius: R.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$captured of $total',
              style: AppText.buttonSmall.copyWith(color: AppColors.onDark),
            ),
            const SizedBox(width: S.sm + S.xs),
            for (int i = 0; i < total; i++)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < captured ? AppColors.accent : AppColors.onDark,
                    border: Border.all(
                      color: i < captured
                          ? AppColors.accent
                          : AppColors.onDark.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
