import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
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
/// (multi-shot) → Review. Photo capture is implemented in this
/// checkpoint; decoration/export are later checkpoints.
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

    final totalShots = widget.layout.cols * widget.layout.rows;
    final timing = widget.timing ?? SystemTiming();

    final runner = SessionRunner(
      timing: timing,
      takePicture: widget.captureProvider ?? _controller!.takePicture,
      onStep: (state, {countdown, shot}) {
        if (!mounted) return;
        setState(() {
          _sessionState = state;
          _countdownNumber = countdown ?? 0;
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

  void _navigateToReview() {
    final session = CapturedSession(
      layout: widget.layout,
      photos: List<XFile>.unmodifiable(_capturedPhotos),
      aspectRatio: _aspectRatio,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          layout: session.layout,
          photos: session.photos,
          aspectRatio: session.aspectRatio,
        ),
      ),
    );
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
    final canPop = !_sessionState.isActive;
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
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _buildCameraPreview(),
        ),
        bottomSheet: _constructControls(),
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

  Widget _layoutBadge() => Align(
    alignment: Alignment.topRight,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: R.all(R.sm),
      ),
      child: Text(
        widget.layout.label,
        style: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(S.md),
    child: Column(
      children: [
        _layoutBadge(),
        const SizedBox(height: S.xl),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.accentDeep,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: S.sm),
        ElevatedButton(onPressed: _retry, child: const Icon(Icons.refresh)),
      ],
    ),
  );

  Widget _buildCameraPreview() => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.all(S.md),
        child: Column(
          children: [
            _layoutBadge(),
            const SizedBox(height: S.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: R.all(R.md),
                child: CameraPreview(_controller!),
              ),
            ),
          ],
        ),
      ),
      if (_sessionState == CameraSessionState.countdown)
        _CountdownOverlay(number: _countdownNumber),
      if (_sessionState == CameraSessionState.capturing) _FlashOverlay(),
      if (_sessionState.isActive)
        _ProgressIndicator(
          current: _sessionCount + 1,
          total: widget.layout.cols * widget.layout.rows,
        ),
    ],
  );

  Widget _constructControls() => SafeArea(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.md),
      child: Row(
        children: [
          if (_isSwitchingAllowed)
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _switchCamera,
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: SizedBox(
              height: 80,
              child: Center(
                child: ClipOval(
                  key: const ValueKey('shutter'),
                  child: Material(
                    color: AppColors.accentDeep,
                    child: InkWell(
                      onTap: _sessionState.isReady ? _startSession : null,
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: Icon(
                          _sessionState.isReady ? Icons.camera_alt : Icons.stop,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ),
  );
}

/// Countdown overlay showing a large number over the preview.
class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 120,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Flash overlay shown briefly on capture.
class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white);
  }
}

/// Progress indicator showing "N / M" during a session.
class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: S.md,
      left: S.md,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: R.all(R.sm),
        ),
        child: Text(
          '$current / $total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
