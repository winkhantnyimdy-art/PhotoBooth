import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/art/checkerboard.dart';
import '../../core/art/retro_sticker.dart';
import '../../core/media/browser_capabilities.dart';
import '../../core/media/photo_source.dart';
import '../decorate/decoration_model.dart';
import '../home/layout_geometry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pressable.dart';
import '../home/layout_model.dart';
import '../review/review_screen.dart';
import 'captured_session.dart';
import 'camera_preferences.dart';
import 'selfie_mirroring.dart';
import 'photo_viewfinder.dart';
import 'preferences_service.dart';
import 'session_state.dart';
import 'session_runner.dart';
import 'shutter_sound.dart';
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
    this.retakeIndex,
    this.shutterSound,
  });

  final PhotoLayout layout;
  final Future<List<CameraDescription>> Function()? cameraProvider;
  final Future<XFile?> Function()? captureProvider;
  final ControllerFactory? controllerFactory;
  final Timing? timing;
  final void Function(CameraSessionState state, {int? countdown, int? shot})?
      onStateChange;

  /// Sound played on capture.
  ///
  /// Defaults to a platform [ShutterSoundService]; tests inject a fake so the
  /// capture flow never depends on a registered audio plugin.
  final ShutterSoundService? shutterSound;

  /// When set, the screen captures a **single** frame and pops it instead of
  /// running a full session.
  ///
  /// This is what powers an individual retake from Review: the caller passes
  /// the index being replaced and swaps the returned photo into that slot, so
  /// every other shot - and any edits made to them - survive.
  final int? retakeIndex;

  /// True when this screen is replacing one photo rather than capturing a set.
  bool get isRetake => retakeIndex != null;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraUnavailableReason? _error;
  bool _loading = true;
  bool _initialized = false;
  CameraSessionState _sessionState = CameraSessionState.ready;
  int _countdownNumber = 0;
  int _sessionCount = 0;

  /// Index of the active entry in [_cameras].
  ///
  /// Tracked explicitly rather than matched on [CameraDescription.name]: on the
  /// web the browser only exposes device labels after permission is granted, so
  /// names can be empty or duplicated and would make matching unreliable.
  int _cameraIndex = 0;

  /// True while the controller is being swapped during a camera switch.
  bool _switching = false;
  final List<XFile> _capturedPhotos = [];
  CancellationToken _cancelToken = CancellationToken();
  double? _aspectRatio;

  /// Camera preferences loaded from persistent storage.
  CameraPreferences _preferences = const CameraPreferences();

  /// Shutter click playback.
  ///
  /// Created lazily and tolerated as absent: audio is a nicety, and a device
  /// that cannot play it must still be able to take photos.
  ShutterSoundService? _shutterSound;

  /// The injected sound service, if a test supplied one.
  ShutterSoundService? get _injectedSound => widget.shutterSound;

  /// Resolves the sound service, creating the platform one on first use.
  ShutterSoundService? _soundService() {
    if (_injectedSound != null) return _injectedSound;
    if (_shutterSound != null) return _shutterSound;
    try {
      _shutterSound = ShutterSoundService();
    } on Object {
      // No audio backend: capture continues silently.
      return null;
    }
    return _shutterSound;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _initCamera();
  }

  Future<void> _loadPreferences() async {
    final service = await PreferencesService.create();
    if (mounted) {
      setState(() {
        _preferences = service.load();
      });
    }
  }

  void _initCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // On the web this runs before any permission prompt so the user gets
    // "you need HTTPS" instead of a bare NotAllowedError.
    if (!BrowserCapabilities.isSecureContext) {
      _setError(BrowserCapabilities.insecureContextReason);
      return;
    }
    if (!BrowserCapabilities.hasCameraSupport) {
      _setError(BrowserCapabilities.unsupportedReason);
      return;
    }

    try {
      _cameras = await (widget.cameraProvider ?? availableCameras)();
    } catch (e) {
      _setError(_classifyCameraError(e));
      return;
    }

    if (_cameras.isEmpty) {
      _setError(
        BrowserCapabilities.describeCameraError('cameraNotFound') ??
            const CameraUnavailableReason(
              title: 'No cameras detected',
              detail: 'Check that a camera is available, then try again.',
            ),
      );
      return;
    }

    _cameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_cameraIndex < 0) _cameraIndex = 0;
    final front = _cameras[_cameraIndex];

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
      _setError(_classifyCameraError(e));
    }
  }

  /// Turns a plugin exception into copy the user can act on.
  ///
  /// `camera_web` throws `CameraException`s whose codes are documented in its
  /// `CameraErrorCode` enum; [BrowserCapabilities.describeCameraError] maps
  /// them, and anything unrecognised falls back to the generic message.
  CameraUnavailableReason _classifyCameraError(Object error) {
    final String? code = switch (error) {
      CameraException(code: final String c) => c,
      _ => null,
    };
    return BrowserCapabilities.describeCameraError(code) ??
        CameraUnavailableReason.unknown;
  }

  void _setError(CameraUnavailableReason reason) {
    if (mounted) {
      setState(() {
        _error = reason;
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
    // ignore: discarded_futures
    _shutterSound?.dispose();
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
    if (_cameras.length <= 1 || _switching) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    final newCamera = _cameras[nextIndex];

    // The previous controller is disposed before the next one exists, so the
    // preview must stop rendering it — on the web the backing <video> element
    // is torn down with the controller.
    setState(() => _switching = true);
    await _controller?.dispose();
    _controller = (widget.controllerFactory ?? CameraController.new)(
      newCamera,
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
        _cameraIndex = nextIndex;
        _switching = false;
        _initialized = true;
        _loading = false;
      });
    } catch (e) {
      _switching = false;
      _setError(_classifyCameraError(e));
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

    // Prime audio while this tap's user activation is still live. Without it,
    // iOS Safari would refuse to play the click seconds later, after the
    // countdown has finished.
    //
    // Deliberately not awaited: arming the audio session must not delay the
    // capture sequence, and the call has to *start* inside the gesture, not
    // finish inside it.
    if (_preferences.shutterSoundEnabled) {
      _soundService()?.prepare();
    }

    final timing = widget.timing ?? SystemTiming();

    // A retake captures exactly one frame: same countdown and flash feedback,
    // but no multi-shot run and no navigation to Review.
    final int totalShots = widget.isRetake ? 1 : widget.layout.photoCount;

    final runner = SessionRunner(
      timing: timing,
      takePicture: widget.captureProvider ?? _controller!.takePicture,
      onStep: (state, {countdown, shot}) {
        if (!mounted) return;
        // The click belongs to the capture itself, not to the countdown.
        if (state == CameraSessionState.capturing &&
            _preferences.shutterSoundEnabled) {
          _soundService()?.play();
        }
        setState(() {
          _sessionState = state;
          _countdownNumber = countdown ?? 0;
          if (state == CameraSessionState.betweenShots) _sessionCount++;
        });
        widget.onStateChange?.call(state, countdown: countdown, shot: shot);
      },
      cancelToken: _cancelToken,
      countdownSeconds: _preferences.countdownSeconds,
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

    if (widget.isRetake) {
      final NavigatorState navigator = Navigator.of(context);
      navigator.pop<XFile>(result.success && result.photos.isNotEmpty
          ? await _applySelfieMirroring(result.photos.first)
          : null);
      return;
    }

    if (result.success && result.photos.length == totalShots) {
      setState(() {
        _sessionState = CameraSessionState.complete;
      });
      // Normalise orientation here, at capture time, so Review, Decorate, the
      // album and the exported PNG all agree. A preview-only transform would
      // leave the saved bytes in whatever orientation the platform happened to
      // produce, which is what made front-camera selfies come out mirrored on
      // iOS Safari.
      final List<XFile> photos = await _applySelfieMirroringAll(result.photos);
      if (!mounted) return;
      setState(() {
        _capturedPhotos.addAll(photos);
      });
      _navigateToReview();
    } else {
      setState(() {
        _sessionState = CameraSessionState.error;
        _error = CameraUnavailableReason(
          title: result.error ?? 'Capture failed',
          detail:
              'The camera stopped responding mid-session. Check that no other '
              'app is using it, then try again.',
        );
      });
    }
  }

  /// Whether freshly captured photos need a horizontal flip.
  bool get _shouldFlipCaptured {
    final CameraLensDirection? direction =
        _controller?.description.lensDirection;
    if (direction == null) return false;
    return SelfieMirroring.shouldFlipCapturedPhoto(
      direction: direction,
      mirrorSelfies: _preferences.mirrorSelfies,
    );
  }

  /// Applies the selfie-mirroring preference to one freshly captured photo.
  Future<XFile> _applySelfieMirroring(XFile photo) async {
    if (!_shouldFlipCaptured) return photo;
    return flipPhotoIfNeeded(photo, flipHorizontal: true);
  }

  /// Applies the selfie-mirroring preference to a whole captured session.
  Future<List<XFile>> _applySelfieMirroringAll(List<XFile> photos) async {
    if (!_shouldFlipCaptured) return photos;
    final List<XFile> out = <XFile>[];
    for (final XFile photo in photos) {
      out.add(await _applySelfieMirroring(photo));
    }
    return out;
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
      !_switching &&
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
                  color: AppColors.darkElevated,
                  borderRadius: R.pillRadius,
                  border: Border.all(color: AppColors.darkLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        widget.isRetake
                            ? 'Retake photo ${widget.retakeIndex! + 1}'
                            : '${widget.layout.label} · ${widget.layout.photoCount} photos',
                        style: AppText.buttonSmall.copyWith(
                          color: AppColors.onDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.darkMuted,
                    ),
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
          child: Container(
            padding: const EdgeInsets.all(S.lg),
            decoration: BoxDecoration(
              color: AppColors.darkElevated,
              borderRadius: R.all(R.lg),
              border: Border.all(color: AppColors.darkLine),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.hotPink.withValues(alpha: 0.16),
                    borderRadius: R.all(R.xl),
                  ),
                  child: const Icon(
                    Icons.no_photography_rounded,
                    size: 30,
                    color: AppColors.hotPink,
                  ),
                ),
                const SizedBox(height: S.md),
                Text(
                  _error!.title,
                  textAlign: TextAlign.center,
                  style: AppText.heading.copyWith(color: AppColors.onDark),
                ),
                const SizedBox(height: S.xs),
                Text(
                  _error!.detail,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.darkMuted),
                ),
                const SizedBox(height: S.lg),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.onDark,
                    side: const BorderSide(color: AppColors.darkLine),
                    shape: RoundedRectangleBorder(borderRadius: R.pillRadius),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildCameraPreview() {
    final CameraController? controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    // The viewfinder fills the entire available area. The old implementation
    // letterboxed a 16:9 box inside this viewport, which produced the narrow
    // horizontal band with black bars reported on the iPhone.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.md),
      child: ClipRRect(
        borderRadius: R.all(R.lg),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.previewBackdrop),
          child: Stack(
            key: const ValueKey('camera-viewport'),
            fit: StackFit.expand,
            children: <Widget>[
              KeyedSubtree(
                key: ValueKey<CameraController>(controller),
                child: PhotoViewfinder(
                  controller: controller,
                  borderRadius: R.all(R.lg),
                  // Shows exactly the window that becomes one photo cell.
                  overlay: ViewfinderCropGuide(
                    outputAspect:
                        PhotoStripGeometry.cellWidth(widget.layout) /
                        PhotoStripGeometry.cellHeight(widget.layout),
                  ),
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
              if (_sessionState == CameraSessionState.capturing &&
                  _preferences.flashAnimationEnabled)
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
                      total: widget.isRetake
                          ? 1
                          : widget.layout.photoCount,
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
          color: AppColors.darkSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // In retake mode there is a single shot, so the numbered strip
                // would be misleading; show the slot being replaced instead.
                if (widget.isRetake)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.darkElevated,
                        border: Border.all(
                          color: AppColors.hotPink,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Replacing shot ${widget.retakeIndex! + 1}',
                        style: AppText.buttonSmall.copyWith(
                          color: AppColors.onDark,
                        ),
                      ),
                    ),
                  )
                else
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
                            : AppColors.darkElevated,
                        border: Border.all(
                          color: i < _sessionCount
                              ? AppColors.accentDeep
                              : AppColors.darkLine,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: i < _sessionCount
                              ? AppColors.popInk
                              : AppColors.darkMuted,
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
                      child: PhotoImage(photo: _capturedPhotos.last),
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
      color: enabled ? AppColors.darkElevated : AppColors.darkSurface,
      shape: CircleBorder(side: BorderSide(color: AppColors.darkLine)),
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
              shape: const CircleBorder(side: BorderSide(color: AppColors.darkLine)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Icon(
                  icon,
                  size: 21,
                  color: enabled ? AppColors.onDark : AppColors.darkMuted,
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
                  color: enabled ? AppColors.hotPink : AppColors.darkElevated,
                ),
                child: Center(
                  child: Icon(
                    busy ? Icons.stop_rounded : Icons.camera_alt_rounded,
                    color: enabled ? AppColors.onAccent : AppColors.darkMuted,
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

/// The capture flash: a short white bloom that fades out immediately.
///
/// The previous implementation was a flat opaque white box that covered the
/// viewfinder for the whole duration of the capture step, which read as a
/// frozen screen rather than a flash. This one peaks instantly and decays, and
/// it respects the user's "reduced motion" setting by collapsing to a single
/// dim frame.
class _FlashOverlay extends StatefulWidget {
  const _FlashOverlay({super.key});

  @override
  State<_FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<_FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          // Hold near-white for the first fifth of the curve, then fall away, so
          // the flash reads as a flash and not as a fade-in.
          final double opacity = t < 0.2 ? 1.0 : (1.0 - (t - 0.2) / 0.8);
          return ColoredBox(
            color: AppColors.onDark.withValues(alpha: opacity.clamp(0.0, 1.0)),
          );
        },
      ),
    );
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
