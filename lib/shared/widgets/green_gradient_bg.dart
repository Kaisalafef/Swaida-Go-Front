// lib/shared/widgets/green_gradient_bg.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GreenGradientBackground extends StatelessWidget {
  const GreenGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primarySoft, AppColors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
