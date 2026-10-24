// lib/features/auth/presentation/screens/login_screen.dart
//
// Backend: POST /login  ← يقبل email + password
// Returns: {access_token, token_type, user}
//
// التصميم: AuthScaffold (نفس هوية الـ Splash/Onboarding). المنطق دون تغيير.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swida_go/core/auth/staff_role.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/session_guard.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_scaffold.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repo = AuthRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // وصلنا هنا بعد 401 (تعطيل الحساب/تغيير الدور أو البريد…): نُعلم المستخدم مرة واحدة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !SessionGuard.consumeExpiredNotice()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'انتهت جلستك (تغيّرت بيانات حسابك أو صلاحياته). يرجى تسجيل الدخول من جديد.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.emailRequired;
    // نفس regex شاشة التسجيل (مُثبَّت بنهاية النص، فلا يقبل «a@b.cc xyz»).
    final bool emailValid =
    RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(value.trim());
    if (!emailValid) return AppStrings.emailInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    // في الدخول نتحقق من الإدخال فقط؛ سياسة الطول للتسجيل (الـ Backend هو الحَكَم).
    if (value == null || value.isEmpty) return AppStrings.passRequired;
    return null;
  }

  // ── Submit ─────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final role = await _repo.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // ── توجيه حسب الدور ──────────────────────────────
      if (StaffRole.isStaff(role)) {
        context.go('/admin/dashboard');
      } else {
        context.go('/home');
      }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.lock_open_rounded,
      title: AppStrings.login,
      subtitle: 'أهلاً بك، سجّل دخولك للمتابعة',
      // سهم الرجوع فقط حين نأتي من شاشة أخرى (مثل التسجيل). كجذر لا سهم لها،
      // وزر النظام يعرض «اضغط مرة أخرى للخروج» (BackGuard في الـ router).
      onBack: context.canPop() ? () => context.pop() : null,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: AppStrings.email,
                hint: AppStrings.emailHint,
                controller: _emailController,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: AppStrings.password,
                hint: AppStrings.passwordHint,
                controller: _passwordController,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: _validatePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitForm(),
                autofillHints: const [AutofillHints.password],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push(
                    '/forgot-password',
                    extra: _emailController.text.trim(),
                  ),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: AppStrings.login,
                onPressed: _submitForm,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'ليس لديك حساب؟',
                    style: GoogleFonts.cairo(
                      color: Brand.bodyOnLight,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    // push: يبقى الدخول تحتها فيعود إليه الرجوع (سهماً أو زر النظام)
                    onPressed: () => context.push('/register'),
                    child: Text(
                      'إنشاء حساب',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
