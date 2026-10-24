// lib/shared/widgets/brand_backdrop.dart
//
// Shared dark background used by SplashScreen and the OnboardingScreen hero,
// so both screens read as one continuous experience.
// Static gradients only: no blur filters, no animation, cheap to paint.
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/brand_tokens.dart';

class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({
    super.key,
    this.accent = Brand.blueOnDark,
    this.glowCenter = Alignment.center,
    this.child,
  });

  /// Color of the soft ambient glow.
  final Color accent;

  /// Where the glow is centered.
  final Alignment glowCenter;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.inkSoft, Brand.ink],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: glowCenter,
            radius: 0.85,
            colors: [accent.withAlpha(64), accent.withAlpha(0)],
          ),
        ),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// خلفية الهيدر الأزرق للتطبيق (شاشات الدخول + Onboarding).
/// تدرّج من أزرق التطبيق الرئيسي مع دوائر ناعمة زخرفية؛ ثابتة بلا blur ولا أنيميشن.
/// الفاتح أعلى اليمين والداكن أسفل اليسار، فيبقى النص الأبيض بتباين ≥ 5.7:1.
class BlueBackdrop extends StatelessWidget {
  const BlueBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryLight, AppColors.primary, AppColors.accent],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: const _BubblesPainter(),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  const _BubblesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white.withAlpha(20);
    final soft = Paint()..color = Colors.white.withAlpha(14);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withAlpha(38);

    final r = size.shortestSide;
    final top = Offset(size.width * 0.92, size.height * 0.1);
    canvas.drawCircle(top, r * 0.42, fill);
    canvas.drawCircle(top, r * 0.62, ring);
    canvas.drawCircle(Offset(size.width * 0.04, size.height * 0.96), r * 0.34, soft);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 1.04), r * 0.2, soft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
