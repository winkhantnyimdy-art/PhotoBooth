import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/home_screen.dart';

/// Root widget: wires the centralized theme to the top-level screen.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTheme.brand,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
