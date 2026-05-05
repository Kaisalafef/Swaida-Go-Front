// lib/features/auth/presentation/screens/phone_verification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/repositories/auth_repository.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AuthRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _otpController = TextEditingController();
  // Used to trigger shake / clear from parent
  final StreamController<ErrorAnimationType> _errorController =
      StreamController<ErrorAnimationType>();

  String _otp = '';
  bool _isLoading = false;
  bool _isResending = false;
  int _secondsRemaining = 60;
  Timer? _countdownTimer;
  String _userPhone = '';

  // Shake animation for wrong OTP
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _loadPhone();
    _startCountdown();
  }

  Future<void> _loadPhone() async {
    final phone = await _storage.read(key: 'user_phone') ?? '';
    if (mounted) setState(() => _userPhone = phone);
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;
    setState(() => _isLoading = true);

    try {
      await _repo.verifyPhone(otp);
      if (!mounted) return;
      context.go('/subscription-setup');
    } catch (e) {
      if (!mounted) return;

      // Trigger shake + clear
      _errorController.add(ErrorAnimationType.shake);
      _otpController.clear();
      setState(() => _otp = '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.otpInvalid, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      await _repo.resendOtp();
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.otpResent, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    _errorController.close();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // ── Phone icon ───────────────────────────────
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primarySoft,
                        AppColors.secondary,
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ────────────────────────────────────
              Text(
                AppStrings.enterOtp,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),

              const SizedBox(height: 10),

              // ── Subtitle ─────────────────────────────────
              Text(
                AppStrings.sentOtpTo,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _userPhone.isNotEmpty ? _userPhone : '...',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 40),

              // ── OTP field ────────────────────────────────
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                errorAnimationController: _errorController,
                obscureText: false,
                animationType: AnimationType.fade,
                textStyle: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 46,
                  activeFillColor: AppColors.white,
                  inactiveFillColor: AppColors.primarySoft,
                  selectedFillColor: AppColors.white,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  selectedColor: AppColors.primary,
                  borderWidth: 2,
                ),
                enableActiveFill: true,
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() => _otp = value),
                onCompleted: _verifyOtp,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                cursorColor: AppColors.primary,
                animationDuration: const Duration(milliseconds: 200),
              ),

              const SizedBox(height: 32),

              // ── Verify button ────────────────────────────
              AppButton(
                label: AppStrings.verifyBtn,
                onPressed: _otp.length == 6 ? () => _verifyOtp(_otp) : null,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 28),

              // ── Countdown / Resend ───────────────────────
              if (_secondsRemaining > 0) ...[
                Text(
                  AppStrings.resendAfter,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_secondsRemaining ${AppStrings.seconds}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _secondsRemaining / 60,
                    backgroundColor: AppColors.primarySoft,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ] else ...[
                if (_isResending)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  Center(
                    child: TextButton(
                      onPressed: _resendOtp,
                      child: Text(
                        AppStrings.resendOtp,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
