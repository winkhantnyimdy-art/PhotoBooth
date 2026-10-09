import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';

void main() {
  testWidgets('app shell boots and shows the brand', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    expect(find.text(AppTheme.brand), findsAtLeastNWidgets(1));
    expect(find.byType(HomeScreen), findsOneWidget);
    // Feature stubs must not leak onto the initial screen.
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Decorate'), findsNothing);
  });

  test('light theme is built from the shared tokens', () {
    final ThemeData theme = AppTheme.theme;

    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.useMaterial3, true);
  });
}
