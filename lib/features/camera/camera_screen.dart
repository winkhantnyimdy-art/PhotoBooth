import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/art/retro_sticker.dart';
import '../decorate/decoration_model.dart';
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

typedef ControllerFactory = CameraController Function(
  CameraDescription description,
  ResolutionPreset resolutionPreset,
);

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

  final PhotoLayout layout;
  final Future<List<CameraDescription>> Function()? cameraProvider;
  final Future<XFile?> Function()? captureProvider;
  final ControllerFactory? controllerFactory;
  final Timing? timing;
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
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopBar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildError()
                        : Column(
                            children: <Widget>[
                              Expanded(child: _buildCameraPreview()),
                              _buildControls(),
                            ],
                          ),
              ),
              const CheckerboardPattern(height: 20),
            ],
          ),
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
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: R.pillRadius,
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${widget.layout.label} · ${widget.layout.photoCount} photos',
                      style: AppText.buttonSmall,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.flash_on_rounded,
            onPressed: null,
          ),
        ],
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

  Widget _buildCameraPreview() {
    final CameraController? controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md),
      child: ClipRRect(
        borderRadius: R.all(R.lg),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.previewBackdrop),
          child: Stack(
            key: const ValueKey('camera-viewport'),
            children: <Widget>[
              Center(
                child: KeyedSubtree(
                  key: ValueKey<CameraController>(controller),
                  child: CameraPreview(controller),
                ),
              ),
              Positioned(
                left: S.lg,
                top: S.lg,
                child: RetroSticker(type: StickerType.heart, size: 28),
              ),
              Positioned(
                right: S.lg,
                bottom: S.lg,
                child: RetroSticker(type: StickerType.bunny, size: 50),
              ),
              Positioned(
                left: S.md,
                bottom: S.md,
                child: RetroSticker(type: StickerType.star, size: 22),
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

  Widget _buildControls() => Container(
        padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.md),
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < widget.layout.photoCount; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _sessionCount
                            ? AppColors.popYellow
                            : AppColors.surface,
                        border: Border.all(
                          color: i < _sessionCount
                              ? AppColors.accentDeep
                              : AppColors.line,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: i < _sessionCount
                              ? AppColors.popInk
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: S.md),
            Row(
              children: <Widget>[
                if (_capturedPhotos.isNotEmpty)
                  ClipRRect(
                    borderRadius: R.all(R.sm),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Image.file(
                        // ignore: avoid_dynamic_calls
                        File(_capturedPhotos.last.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 44, height: 44),
                Expanded(
                  child: Center(
                    child: _ShutterButton(
                      enabled: _sessionState.isReady,
                      busy: _sessionState.isActive,
                      onPressed: _startSession,
                    ),
                  ),
                ),
                _CircleControl(
                  icon: Icons.cameraswitch_rounded,
                  tooltip: 'Switch camera',
                  onPressed: _isSwitchingAllowed ? _switchCamera : null,
                ),
              ],
            ),
          ],
        ),
      );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Material(
      color: enabled ? AppColors.surface : AppColors.surfaceMuted,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

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
            color: enabled ? AppColors.surface : Colors.transparent,
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
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: enabled ? AppColors.hotPink : AppColors.lineStrong,
                  width: 3,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.hotPink.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? AppColors.hotPink : AppColors.surfaceMuted,
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
            border: Border.all(color: AppColors.hotPink, width: 3),
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

class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.white);
  }
}

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
                    color: i < captured ? AppColors.hotPink : AppColors.onDark,
                    border: Border.all(
                      color: i < captured
                          ? AppColors.hotPink
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
