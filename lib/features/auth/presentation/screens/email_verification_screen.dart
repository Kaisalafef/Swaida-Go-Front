// lib/features/auth/presentation/screens/email_verification_screen.dart
//
// تعمل بـ Polling كل 5 ثوانٍ على:
//   GET /auth/email-verification-status?email=...
// عند نجاح التوثيق → /home
//
// التصميم: AuthScaffold (نفس هوية الـ Splash/Onboarding).
// تغييرات منطقية صغيرة: حارس لمنع تداخل طلبات الـ Polling ومنع التنقل المزدوج،
// وإيقاف النبض عند تفعيل «تقليل الحركة».

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/auth_scaffold.dart';
import '../../data/repositories/auth_repository.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AuthRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Timer? _pollTimer;
  bool _isResending = false;
  bool _checking = false; // طلب Polling قيد التنفيذ
  bool _navigated = false;
  bool _didInit = false;
  String _userEmail = '';
  int _cooldown = 0; // ثوانٍ متبقية قبل السماح بإعادة الإرسال
  Timer? _cooldownTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadEmail();
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
    }
  }

  Future<void> _loadEmail() async {
    // نقرأ الإيميل المُخزَّن مؤقتاً بعد التسجيل
    final email = await _storage.read(key: 'pending_email') ?? '';
    if (mounted) setState(() => _userEmail = email);
  }

  // ── Polling: كل 5 ثوانٍ نسأل الـ Backend هل وثّق المستخدم بريده ──
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_checking || _navigated) return; // لا تداخل بين الطلبات
      _checking = true;
      try {
        final verified = await _repo.checkEmailVerification();
        if (verified && mounted && !_navigated) {
          _navigated = true;
          _pollTimer?.cancel();
          // ✅ البريد موثّق
          context.go('/home');
        }
      } catch (_) {
        // نتجاهل أخطاء الشبكة ونستمر بالـ Polling
      } finally {
        _checking = false;
      }
    });
  }

  Future<void> _resendEmail() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await _repo.resendVerificationEmail();
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.emailResent, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// يمنع الضغط المتكرر على «إعادة الإرسال» (30 ثانية).
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.mark_email_read_outlined,
      title: AppStrings.checkEmail,
      subtitle: AppStrings.sentLinkTo,
      // Align في الخارج: النبض يكبّر البلاطة حول مركزها هي لا حول مركز الصف.
      heroIcon: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: const AuthIconTile(
            icon: Icons.mark_email_read_outlined,
            size: 72,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عرض الإيميل المُخزَّن (يُخفى إن لم يُقرأ بعد بدل «...»)
          if (_userEmail.isNotEmpty) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  _userEmail,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

          ],

          Text(
            AppStrings.clickLinkInfo,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Brand.bodyOnLight,
              height: 1.7,
            ),
          ),

          const SizedBox(height: 16),

          // نص توضيحي للـ Flow
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'توثيق البريد هو آخر خطوة لإنشاء حسابك بأمان',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // إعادة الإرسال إجراء ثانوي (التقدّم يحدث تلقائياً بالـ Polling)
          AppButton(
            label: _cooldown > 0
                ? 'إعادة الإرسال بعد $_cooldown ث'
                : AppStrings.resendEmail,
            onPressed: _cooldown > 0 ? null : _resendEmail,
            isLoading: _isResending,
            outlined: true,
          ),

          const SizedBox(height: 20),

          // مؤشر الـ Polling
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppStrings.checkingVerify,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: Brand.bodyOnLight,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            child: TextButton(
              onPressed: () => context.go('/register'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(
                AppStrings.changeEmail,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Brand.bodyOnLight,
                  decoration: TextDecoration.underline,
                  decorationColor: Brand.bodyOnLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
