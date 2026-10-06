import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../home/layout_model.dart';

/// Screen that shows a live camera preview with layout indication and control.
///
/// Only full‑screen preview + a shutter button and optional camera switch.
/// Photo capture is intentionally not implemented.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.layout, this.cameraProvider});

  /// The layout chosen on the home screen.
  final PhotoLayout layout;

  /// Optional provider used by tests to inject camera list.
  /// When null, native [availableCameras] is called.
  final Future<List<CameraDescription>> Function()? cameraProvider;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  void _initCamera() async {
    try {
      _cameras = await (widget.cameraProvider ?? availableCameras)();
    } catch (e) {
      setState(() {
        _error = 'Camera unavailable';
        _loading = false;
      });
      return;
    }

    if (_cameras.isEmpty) {
      setState(() {
        _error = 'No cameras detected';
        _loading = false;
      });
      return;
    }

    final front = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Camera failed to initialize';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller!.dispose();
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
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        ElevatedButton(
          onPressed: _initCamera,
          child: const Icon(Icons.refresh),
        ),
      ],
    ),
  );

  Widget _buildCameraPreview() => Padding(
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
  );

  Widget _constructControls() => SafeArea(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.md),
      child: Row(
        children: [
          if (_cameras.length > 1)
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
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.accentDeep,
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.onAccent,
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
