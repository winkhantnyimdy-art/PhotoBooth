import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// Adds a gentle press-down scale to a control for tactile feedback.
///
/// Uses [Listener] rather than [GestureDetector] on purpose: the child is
/// usually a button that already owns the tap, and a competing gesture
/// recogniser would either lose the arena (no feedback) or double-fire the
/// action. Listening to raw pointer events keeps the visual response
/// independent of whichever descendant handles the tap.
///
/// The scale is skipped entirely when the platform requests reduced motion, so
/// the control still feels responsive through its ink ripple alone.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
  });

  final Widget child;

  /// When false the control does not react to presses.
  final bool enabled;

  /// How far the control shrinks while held.
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final double scale = (_pressed && !reduceMotion && widget.enabled)
        ? widget.pressedScale
        : 1;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled
          ? (PointerCancelEvent event) => _setPressed(false)
          : null,
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }
}
