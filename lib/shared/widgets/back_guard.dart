// lib/shared/widgets/back_guard.dart
//
// سياسة زر الرجوع في أندرويد (يعمل مع go_router 13 / Flutter 3.19):
//   • شاشة فوقها شاشة أخرى في المكدس (push)  → رجوع عادي (pop)
//   • شاشة لها onBack مخصص                    → يُنفَّذ onBack
//   • شاشة فرعية وصلنا لها بـ context.go       → تعود للشاشة الأم [fallback]
//   • شاشة جذرية (login / home / dashboard)    → «اضغط مرة أخرى للخروج»
//
// السبب الجذري: PopScope لا يُستدعى على الشاشة الجذرية مع go_router 13،
// فنعترض زر النظام بـ WidgetsBindingObserver يُسجَّل قبل الـ Router
// (BackGuardObserver.install() في main()).
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

class BackGuard extends StatefulWidget {
  const BackGuard({
    super.key,
    required this.child,
    this.fallback,
    this.swallow = false,
    this.onBack,
  });

  final Widget child;

  /// الشاشة الأم التي يعود إليها زر الرجوع حين لا يوجد ما يُسحب من المكدس.
  /// null = شاشة جذرية → «اضغط مرة أخرى للخروج».
  final String? fallback;

  /// يتجاهل زر الرجوع تماماً (للـ Splash أثناء التحميل).
  final bool swallow;

  /// سلوك مخصص للشاشة (onboarding، forgot-password، payment). له الأولوية.
  final Future<void> Function()? onBack;

  @override
  State<BackGuard> createState() => _BackGuardState();
}

class _BackGuardState extends State<BackGuard> {
  @override
  void initState() {
    super.initState();
    BackGuardObserver._active.add(this);
  }

  @override
  void dispose() {
    BackGuardObserver._active.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // canPop:false يُعلم أندرويد 13+ أن Flutter هو من يعالج الرجوع.
    // المعالجة الفعلية تتم في BackGuardObserver.
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {},
      child: widget.child,
    );
  }
}

class BackGuardObserver with WidgetsBindingObserver {
  BackGuardObserver._();

  static final List<_BackGuardState> _active = <_BackGuardState>[];
  static bool _installed = false;

  /// استدعِها مرة واحدة في main() قبل runApp.
  static void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(BackGuardObserver._());
  }

  @override
  Future<bool> didPopRoute() async {
    // الشاشة الحالية الظاهرة فقط (إن كان حوار/شيت مفتوحاً فهو الحالي
    // فنترك الرجوع الافتراضي يغلقه).
    _BackGuardState? current;
    for (final s in _active.reversed) {
      if (!s.mounted) continue;
      final route = ModalRoute.of(s.context);
      if (route != null && route.isCurrent) {
        current = s;
        break;
      }
    }
    if (current == null) return false;

    final w = current.widget;
    if (w.swallow) return true;

    if (w.onBack != null) {
      await w.onBack!();
      return true;
    }

    if (!current.mounted) return true;
    final router = GoRouter.of(current.context);
    if (router.canPop()) {
      router.pop();
      return true;
    }
    final target = w.fallback;
    if (target != null) {
      router.go(target);
      return true;
    }
    ExitConfirm.handle(current.context);
    return true;
  }
}