import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const VideoPlayerApp());
}

class VideoPlayerApp extends StatelessWidget {
  const VideoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LandingScreen(),
    );
  }
}
