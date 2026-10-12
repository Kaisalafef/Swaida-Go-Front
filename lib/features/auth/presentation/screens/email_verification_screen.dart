// lib/features/auth/presentation/screens/email_verification_screen.dart
//
// تعمل بـ Polling كل 5 ثوانٍ على:
//   GET /auth/email-verification-status?email=...
// عند نجاح التوثيق → تنتقل لـ /verify-phone (وليس /subscription-setup)
// لأن الـ Flow الصحيح: email ← phone ← subscription-setup

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_button.dart';
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
  String _userEmail = '';

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

  Future<void> _loadEmail() async {
    // نقرأ الإيميل المُخزَّن مؤقتاً بعد التسجيل
    final email = await _storage.read(key: 'pending_email') ?? '';
    if (mounted) setState(() => _userEmail = email);
  }

  // ── Polling: كل 5 ثوانٍ نسأل الـ Backend هل وثّق المستخدم بريده ──
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final verified = await _repo.checkEmailVerification();
        if (verified && mounted) {
          _pollTimer?.cancel();
          // ✅ البريد موثّق → الخطوة التالية: توثيق الهاتف
          context.go('/home');
        }
      } catch (_) {
        // نتجاهل أخطاء الشبكة ونستمر بالـ Polling
      }
    });
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await _repo.resendVerificationEmail();
      if (!mounted) return;
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // ── أيقونة البريد النابضة ──────────────────
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primarySoft,
                        ),
                      ),
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 70,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                Text(
                  AppStrings.checkEmail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  AppStrings.sentLinkTo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 4),

                // عرض الإيميل المُخزَّن
                Text(
                  _userEmail.isNotEmpty ? _userEmail : '...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  AppStrings.clickLinkInfo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 12),

                // نص توضيحي للـ Flow
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ' توثيق البريداخر خطوة لانشاء حسابك الامن ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const Spacer(),

                AppButton(
                  label: AppStrings.resendEmail,
                  onPressed: _resendEmail,
                  isLoading: _isResending,
                ),

                const SizedBox(height: 18),

                // مؤشر الـ Polling
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.checkingVerify,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    AppStrings.changeEmail,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}