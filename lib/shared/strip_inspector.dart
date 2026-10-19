import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'minimal_dark.dart';

/// Opens a full-screen, zoomable inspection of a photostrip.
///
/// One gesture set for every surface that shows a finished strip:
/// pinch-zoom 1x-8x, one-finger pan (always available, unlike the editor's
/// zoom, which arms panning only while transformed, because here there are no
/// stickers underneath to steal drags from), Fit, and back.
Future<void> showStripInspection(
  BuildContext context, {
  required Widget child,
  required double aspectRatio,
  required String semanticLabel,
  String? title,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) => StripInspector(
        semanticLabel: semanticLabel,
        title: title,
        aspectRatio: aspectRatio,
        child: child,
      ),
    ),
  );
}

/// The inspection page itself.
///
/// Keep the background [AppColors.darkBackground] rather than a translucent
/// scrim: an inspection should look like a light table, not a dialog.
class StripInspector extends StatefulWidget {
  const StripInspector({
    super.key,
    required this.child,
    required this.aspectRatio,
    required this.semanticLabel,
    this.title,
  });

  final Widget child;
  final double aspectRatio;
  final String semanticLabel;
  final String? title;

  @override
  State<StripInspector> createState() => _StripInspectorState();
}

class _StripInspectorState extends State<StripInspector> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    // Listen rather than relying on onInteractionUpdate: a programmatic
    // reset (the Fit action) never generates interaction callbacks, so the
    // armed state would go stale and Fit would look enabled at fit scale.
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final bool next = _transform.value.getMaxScaleOnAxis() > 1.001;
    if (next != _zoomed) {
      setState(() => _zoomed = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(S.sm, S.sm, S.sm, S.xs),
              child: Row(
                children: <Widget>[
                  MinimalIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.title ?? 'Preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(color: AppColors.onDark),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    enabled: _zoomed,
                    label: _zoomed
                        ? 'Reset zoom to fit the strip'
                        : 'Already showing the whole strip',
                    child: TextButton.icon(
                      onPressed: _zoomed
                          ? () => _transform.value = Matrix4.identity()
                          : null,
                      icon: const Icon(Icons.fit_screen_rounded, size: 18),
                      label: const Text('Fit'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onDark,
                        backgroundColor: AppColors.darkSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transform,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 8.0,
                boundaryMargin: const EdgeInsets.all(120),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: Semantics(
                      label: widget.semanticLabel,
                      image: true,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: S.sm),
              child: Text(
                'Pinch to zoom, drag to pan',
                style: AppText.caption.copyWith(color: AppColors.darkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
