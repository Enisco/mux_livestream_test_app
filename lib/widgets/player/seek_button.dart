import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const SeekButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.0,
        height: 48.0,
        decoration: const BoxDecoration(
          color: AppColors.overlayLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 28.0),
      ),
    );
  }
}
