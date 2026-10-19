import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/shared/strip_inspector.dart';

/// Full-screen strip inspection.
///
/// One shared surface for the Decorate editor and the album, so the gesture
/// contract here applies everywhere a finished strip can be seen large:
/// pinch zoom 1x-8x, pan, a Fit action that is inert until actually zoomed,
/// and an explicit Close that reaches the button without needing gestures.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.theme,
    home: StripInspector(
      semanticLabel: 'Full-screen preview of the strip',
      title: 'Preview',
      aspectRatio: 0.4,
      child: ColoredBox(
        color: const Color(0xFFB0BEC5),
        child: SizedBox.expand(
          child: Container(color: const Color(0xFF78909C)),
        ),
      ),
    ),
  );

  testWidgets('opens at fit scale with the inspect semantics attached', (
    tester,
  ) async {
    await tester.pumpWidget(host(Container(color: const Color(0xFF78909C))));

    expect(find.text('Preview'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Full-screen preview of the strip'),
      findsOneWidget,
    );
    // At fit scale there is nothing to reset, so the Fit control reads as
    // inert rather than pretending zoom state exists.
    expect(
      find.bySemanticsLabel('Already showing the whole strip'),
      findsOneWidget,
    );
    expect(find.text('Pinch to zoom, drag to pan'), findsOneWidget);
  });

  testWidgets('zooming arms Fit, and Fit returns to fit scale', (tester) async {
    await tester.pumpWidget(host(Container(color: const Color(0xFF78909C))));
    final Offset center = tester.getCenter(find.byType(InteractiveViewer));

    // Pinch out with two fingers; the zoom scale crosses the 1x threshold.
    final TestGesture finger1 = await tester.startGesture(
      center - const Offset(12, 0),
      pointer: 11,
    );
    final TestGesture finger2 = await tester.startGesture(
      center + const Offset(12, 0),
      pointer: 12,
    );
    await tester.pump();
    await finger1.moveBy(const Offset(-90, 0));
    await finger2.moveBy(const Offset(90, 0));
    await tester.pump();
    await finger1.moveBy(const Offset(-60, 0));
    await finger2.moveBy(const Offset(60, 0));
    await tester.pump();
    await finger1.up();
    await finger2.up();
    await tester.pump();

    expect(
      find.bySemanticsLabel('Reset zoom to fit the strip'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Reset zoom to fit the strip'));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Already showing the whole strip'),
      findsOneWidget,
    );
  });

  testWidgets('Close pops the inspection', (tester) async {
    bool popped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () {
              showStripInspection(
                context,
                semanticLabel: 'Full-screen preview of the strip',
                title: 'Preview',
                aspectRatio: 0.4,
                child: Container(color: const Color(0xFF78909C)),
              ).then<void>((_) => popped = true);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(StripInspector), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(StripInspector), findsNothing);
    expect(popped, isTrue);
  });
}
