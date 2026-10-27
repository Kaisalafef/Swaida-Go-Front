// lib/features/auth/presentation/screens/forgot_password_screen.dart
//
// نسيت كلمة المرور — خطوتان في شاشة واحدة:
//   1) إدخال البريد            → POST /auth/forgot-password   (يصل رمز من 6 أرقام)
//   2) الرمز + كلمة مرور جديدة → POST /auth/reset-password
// بعد النجاح يعود المستخدم لشاشة الدخول ليسجّل بكلمة المرور الجديدة.
//
// التصميم: AuthScaffold (نفس هوية الـ Splash/Onboarding). المنطق دون تغيير،
// ومعه: زر الرجوع في الشاشة وزر الرجوع في النظام يتصرفان بنفس الطريقة
// (الخطوة 2 → الخطوة 1، ثم خروج من الشاشة).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_scaffold.dart';
import '../../../../shared/widgets/back_guard.dart';
import '../../data/repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// يُمرَّر من شاشة الدخول إن كان المستخدم كتب بريده
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _repo = AuthRepository();

  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false; // false = الخطوة 1، true = الخطوة 2
  bool _busy = false;
  String? _error;

  Timer? _timer;
  int _cooldown = 0; // ثواني حتى يُسمح بإعادة الإرسال

  @override
  void initState() {
    super.initState();
    final e = widget.initialEmail?.trim();
    if (e != null && e.isNotEmpty) _email.text = e;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Step 1: إرسال الرمز ──────────────────────────────────
  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_emailKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wait = await _repo.forgotPassword(email: _email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown(wait);
      if (resend) _snack('أعدنا إرسال الرمز إن كان البريد مسجلاً');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 2: تعيين كلمة المرور ────────────────────────────
  Future<void> _reset() async {
    if (!_resetKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      _snack('تم تعيين كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.');
      context.go('/login');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToEmail() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _cooldown = 0;
      _error = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  /// نفس سلوك سهم الرجوع السابق.
  void _onBackPressed() {
    if (_codeSent && !_busy) {
      _backToEmail();
    } else {
      context.canPop() ? context.pop() : context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // \u2066 … \u2069: يعزل البريد (LTR) داخل نص عربي فلا ينقلب ترتيبه.
    final email = '\u2066${_email.text.trim()}\u2069';

    return BackGuard(
      onBack: () async {
        if (_codeSent) {
          if (!_busy) _backToEmail();
        } else {
          context.canPop() ? context.pop() : context.go('/login');
        }
      },
      child: AuthScaffold(
        icon: _codeSent
            ? Icons.mark_email_read_rounded
            : Icons.lock_reset_rounded,
        title: _codeSent ? 'أدخل الرمز' : 'نسيت كلمة المرور؟',
        subtitle: _codeSent
            ? 'إن كان البريد $email مسجلاً لدينا فقد وصله رمز من 6 أرقام.'
            : 'اكتب بريدك الإلكتروني وسنرسل إليه رمزاً من 6 أرقام لإعادة تعيين كلمة المرور.',
        onBack: _onBackPressed,
        child: AnimatedSwitcher(
          duration: Brand.fast,
          child: KeyedSubtree(
            key: ValueKey<bool>(_codeSent),
            child: _codeSent ? _buildResetStep() : _buildEmailStep(),
          ),
        ),
      ),
    );
  }

  // ── الخطوة 1 ────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'البريد الإلكتروني',
            hint: 'name@example.com',
            controller: _email,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _sendCode(),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'البريد الإلكتروني مطلوب';
              if (!_emailRe.hasMatch(t)) return 'صيغة البريد غير صحيحة';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'إرسال الرمز',
            isLoading: _busy,
            onPressed: _busy ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  // ── الخطوة 2 ────────────────────────────────────────────
  Widget _buildResetStep() {
    return Form(
      key: _resetKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الرمز صالح 15 دقيقة. افحص الرسائل غير المرغوبة أيضاً.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: Brand.bodyOnLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.cairo(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: AppColors.primary),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: GoogleFonts.cairo(
                  fontSize: 28, letterSpacing: 10, color: AppColors.border),
              filled: true,
              fillColor: AppColors.primarySoft,
              errorStyle: GoogleFonts.cairo(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: _border(AppColors.border),
              enabledBorder: _border(AppColors.border),
              focusedBorder: _border(AppColors.primary, 2),
              errorBorder: _border(AppColors.error),
              focusedErrorBorder: _border(AppColors.error, 2),
            ),
            validator: (v) =>
            (v ?? '').length != 6 ? 'الرمز يتكون من 6 أرقام' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'كلمة المرور الجديدة',
            hint: '8 أحرف على الأقل',
            controller: _password,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) =>
            (v ?? '').length < 8 ? 'كلمة المرور 8 أحرف على الأقل' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'تأكيد كلمة المرور',
            hint: 'أعد كتابتها',
            controller: _confirm,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _reset(),
            validator: (v) =>
            v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(_error!),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'تعيين كلمة المرور',
            isLoading: _busy,
            onPressed: _busy ? null : _reset,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: (_cooldown > 0 || _busy)
                    ? null
                    : () => _sendCode(resend: true),
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text(
                  _cooldown > 0
                      ? 'إعادة الإرسال بعد $_cooldown ث'
                      : 'إعادة إرسال الرمز',
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Text('·', style: TextStyle(color: AppColors.textMuted)),
              TextButton(
                onPressed: _busy ? null : _backToEmail,
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text('تغيير البريد',
                    style: GoogleFonts.cairo(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── UI helpers ──────────────────────────────────────────
  OutlineInputBorder _border(Color c, [double w = 1.3]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  Widget _errorBox(String text) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.cairo(
                    fontSize: 12.5, color: AppColors.error)),
          ),
        ],
      ),
    ),
  );
}
