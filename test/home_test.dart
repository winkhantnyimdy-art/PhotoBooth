import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';
import 'package:photo_booth/features/home/layout_model.dart';
import 'package:photo_booth/features/home/pre_camera_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text(AppTheme.brand), findsOneWidget);
    });

    testWidgets('4 CUT is selected by default', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text('4 CUT'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
    });

    testWidgets('selecting 2 CUT works', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text('2 CUT'), findsOneWidget);
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      expect(find.text('2 CUT'), findsWidgets);
    });

    testWidgets('Start Photo Booth navigates to pre-camera', (tester) async {
      await tester.pumpWidget(const App());
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pumpAndSettle();
      expect(find.text('Ready to shoot'), findsOneWidget);
    });

    testWidgets('Start Photo Booth uses current selection', (tester) async {
      await tester.pumpWidget(const App());
      await tester.tap(find.text('2 CUT').first);
      await tester.pump();
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pumpAndSettle();
      expect(find.text('2 CUT'), findsWidgets);
      expect(find.text('Popular'), findsNothing);
    });
  });

  group('PreCameraScreen', () {
    testWidgets('receives and displays selected layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const PreCameraScreen(layout: PhotoLayout.cut4),
        ),
      );
      expect(find.text('4 CUT'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
    });

    testWidgets('back navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.theme, home: const HomeScreen()),
      );
      await tester.tap(find.text('Start Photo Booth'));
      await tester.pumpAndSettle();
      expect(find.text('Ready to shoot'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text(AppTheme.brand), findsOneWidget);
    });
  });
}
