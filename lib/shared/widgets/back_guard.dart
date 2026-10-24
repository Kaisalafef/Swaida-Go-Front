// lib/shared/widgets/back_guard.dart
//
// سياسة زر الرجوع في أندرويد — بدل أن يُغلق التطبيق فجأة:
//
//   • الشاشة فوقها شاشة أخرى في المكدس (push)  → رجوع عادي (pop)
//   • شاشة فرعية وصلنا لها بـ context.go          → تعود للشاشة الأم [fallback]
//   • شاشة جذرية (login / home / dashboard …)    → «اضغط مرة أخرى للخروج»
//
// السبب الجذري: التطبيق يتنقل بـ context.go (يستبدل المكدس كاملاً)، فتصير كل
// شاشة هي الوحيدة في المكدس وزر النظام لا يجد ما يرجع إليه فيُغلق التطبيق.
// تُطبَّق من app_router.dart في مكان واحد بدل تعديل كل شاشة.
//
// ملاحظة: لا تلفّ بها شاشة لديها PopScope/WillPopScope خاص بها (onboarding،
// forgot-password، payment)؛ فمع وجود اثنين يُستدعى كلاهما.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

/// «اضغط مرة أخرى للخروج»: الضغطة الأولى تُظهر تنبيهاً، والثانية خلال ثانيتين تُغلق.
class ExitConfirm {
  ExitConfirm._();

  static const Duration _window = Duration(seconds: 2);
  static DateTime? _lastBack;

  static void handle(BuildContext context) {
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < _window) {
      _lastBack = null;
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.pressBackAgain,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: _window,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.fromLTRB(48, 0, 48, 24),
      ),
    );
  }
}

class BackGuard extends StatelessWidget {
  const BackGuard({
    super.key,
    required this.child,
    this.fallback,
    this.swallow = false,
  });

  final Widget child;

  /// الشاشة الأم التي يعود إليها زر الرجوع حين لا يوجد ما يُسحب من المكدس.
  /// null = شاشة جذرية → «اضغط مرة أخرى للخروج».
  final String? fallback;

  /// يتجاهل زر الرجوع تماماً (للـ Splash أثناء التحميل).
  final bool swallow;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // يوجد شاشة تحتي → دع النظام يعمل pop عادياً (مع أنيميشنه).
      canPop: !swallow && context.canPop(),
      // onPopInvoked هو الـ API في Flutter < 3.22 (يعمل أيضاً في الأحدث).
      onPopInvoked: (didPop) {
        if (didPop || swallow) return;
        final target = fallback;
        if (target != null) {
          context.go(target);
        } else {
          ExitConfirm.handle(context);
        }
      },
      child: child,
    );
  }
}
