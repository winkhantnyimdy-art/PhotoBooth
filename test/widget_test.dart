import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/app/app.dart';
import 'package:photo_booth/core/art/bubble_logo.dart';
import 'package:photo_booth/core/theme/app_colors.dart';
import 'package:photo_booth/core/theme/app_theme.dart';
import 'package:photo_booth/features/home/home_screen.dart';

import 'support/fake_album.dart';

void main() {
  testWidgets('app shell boots and shows the brand', (
    WidgetTester tester,
  ) async {
    // The shell now boots through an album bootstrap, so the test supplies an
    // in-memory album instead of touching IndexedDB or the filesystem.
    await tester.pumpWidget(App(albumService: FakeAlbumService()));

    expect(find.byType(PhotoBoothBubbleLogo), findsOneWidget);
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
