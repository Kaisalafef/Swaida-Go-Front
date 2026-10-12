// lib/features/auth/presentation/screens/register_screen.dart
//
// بعد نجاح التسجيل → /verify-email  (وليس /verify-phone مباشرةً)
// لأن الـ Backend يُرسل رابط توثيق البريد أولاً عند Register
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _repo = AuthRepository();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Validation helpers ─────────────────────────────────
  bool _isValidEmail(String email) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email);

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.nameRequired;
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return AppStrings.nameThreeParts;
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.emailRequired;
    if (!_isValidEmail(value.trim())) return AppStrings.emailInvalid;
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.phoneRequired;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 9) return AppStrings.phoneInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passRequired;
    if (value.length < 8) return AppStrings.passMin8;
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return AppStrings.confirmRequired;
    if (value != _passwordController.text) return AppStrings.passMismatch;
    return null;
  }

  // ── Submit ─────────────────────────────────────────────
  // Flow: register → /verify-email (توثيق البريد أولاً)
  //       ثم /verify-email تنتقل تلقائياً → /verify-phone بعد نجاح التوثيق
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _repo.register(
        fullName: _nameController.text.trim(),
        email:    _emailController.text.trim(),
        phone:    _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // ← الانتقال لشاشة توثيق البريد أولاً
      context.go('/verify-email');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.primary),
            onPressed: () => context.go('/onboarding'),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Illustration area ────────────────────────
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primarySoft, AppColors.secondary],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_add_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.createAccount,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.enterDataStart,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Fields card ──────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      AppTextField(
                        label: AppStrings.fullName,
                        hint: AppStrings.fullNameHint,
                        controller: _nameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: _validateName,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: AppStrings.email,
                        hint: AppStrings.emailHint,
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        validator: _validateEmail,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: AppStrings.phone,
                        hint: AppStrings.phoneHint,
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        validator: _validatePhone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: AppStrings.password,
                        hint: AppStrings.passwordHint,
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: _validatePassword,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: AppStrings.confirmPass,
                        hint: AppStrings.confirmHint,
                        controller: _confirmController,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: _validateConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitForm(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                AppButton(
                  label: AppStrings.registerBtn,
                  onPressed: _submitForm,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.haveAccount,
                      style: GoogleFonts.cairo(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        AppStrings.login,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}