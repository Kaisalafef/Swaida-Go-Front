// lib/features/subscriber/presentation/screens/subscription_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/repositories/subscriber_repository.dart';

class SubscriptionSetupScreen extends StatefulWidget {
  const SubscriptionSetupScreen({super.key});

  @override
  State<SubscriptionSetupScreen> createState() =>
      _SubscriptionSetupScreenState();
}

class _SubscriptionSetupScreenState extends State<SubscriptionSetupScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriberRepository();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  double _monthlyAmount = 0;

  // ── رسوم الدفع — تُجلب من الـ API ─────────────────
  static const double _fixedFee = 0.5;
  double _commissionRate = 0.0; // تُحدَّث من getCommission()
  bool _isLoadingCommission = true;

  double get _commissionPerMonth =>
      _monthlyAmount > 0 ? _monthlyAmount * (_commissionRate / 100) : 0;

  double get _totalPerMonth =>
      _monthlyAmount > 0 ? _monthlyAmount + _commissionPerMonth + _fixedFee : 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    _amountController.addListener(() {
      final text = _amountController.text.trim();
      final value = double.tryParse(text) ?? 0;
      setState(() {
        _monthlyAmount = value > 0 ? value / 12 : 0;
      });
    });

    // جلب نسبة العمولة من الـ API
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    try {
      final rate = await _repo.getCommission();
      if (mounted) setState(() => _commissionRate = rate);
    } catch (_) {
      // في حال الفشل تبقى 0
    } finally {
      if (mounted) setState(() => _isLoadingCommission = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showError('يرجى إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _repo.createSubscription(annualAmount: amount);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cairo()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── صف رسوم مساعد ─────────────────────────────────
  Widget _feeRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.primary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'إعداد الاشتراك',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Illustration Card ───────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.primary],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.savings_rounded,
                            color: AppColors.white.withOpacity(0.9),
                            size: 52,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'حدد مبلغ اشتراكك السنوي',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'المبلغ يُقسَّم تلقائياً على 12 شهراً',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.white.withOpacity(0.75),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Input Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المبلغ السنوي',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'أدخل المبلغ الذي تودّ دفعه سنوياً بالدولار الأمريكي',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Amount Field ────────────────────────────
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 36,
                              color: AppColors.primary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: GoogleFonts.cairo(
                                fontSize: 36,
                                color: AppColors.border,
                              ),
                              prefixText: '\$ ',
                              prefixStyle: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: AppColors.textMuted,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primary),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                              filled: true,
                              fillColor: AppColors.primarySoft,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال المبلغ السنوي';
                              }
                              final parsed = double.tryParse(value.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Monthly Preview + Fee Breakdown ─────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.06),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: _monthlyAmount > 0
                                ? Column(
                              key: const ValueKey('monthly-visible'),
                              children: [
                                // القسط الأصلي
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius:
                                    BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primaryLight
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.12),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'قسطك الشهري',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '\$${_monthlyAmount.toStringAsFixed(2)}',
                                        style: GoogleFonts.cairo(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── تفاصيل رسوم الدفع ──────────────
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8EC),
                                    borderRadius:
                                    BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFFFD580)
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // عنوان البطاقة
                                      Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFFFF9900)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                            ),
                                            child: const Icon(
                                              Icons
                                                  .account_balance_wallet_rounded,
                                              color: Color(0xFFFF9900),
                                              size: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'رسوم الدفع الإلكتروني (لكل شهر)',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                              const Color(0xFF7A4F00),
                                            ),
                                          ),
                                          if (_isLoadingCommission) ...[
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: Color(0xFFFF9900),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(
                                          color: Color(0xFFFFD580),
                                          height: 1),
                                      const SizedBox(height: 10),

                                      // صف: المبلغ الأصلي
                                      _feeRow(
                                        'مبلغ الاشتراك',
                                        '\$${_monthlyAmount.toStringAsFixed(2)}',
                                        const Color(0xFF5A3E00),
                                      ),
                                      const SizedBox(height: 6),

                                      // صف: عمولة ديناميكية
                                      _feeRow(
                                        'عمولة خدمة الدفع (${_commissionRate.toStringAsFixed(0)}%)',
                                        '+ \$${_commissionPerMonth.toStringAsFixed(2)}',
                                        const Color(0xFF5A3E00),
                                      ),
                                      const SizedBox(height: 6),

                                      // صف: رسم ثابت
                                      _feeRow(
                                        'رسم معالجة ثابت',
                                        '+ \$${_fixedFee.toStringAsFixed(2)}',
                                        const Color(0xFF5A3E00),
                                      ),

                                      const SizedBox(height: 10),
                                      const Divider(
                                          color: Color(0xFFFFD580),
                                          height: 1),
                                      const SizedBox(height: 10),

                                      // صف: الإجمالي
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(
                                            'إجمالي الدفعة الشهرية',
                                            style: GoogleFonts.cairo(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color:
                                              const Color(0xFF7A4F00),
                                            ),
                                          ),
                                          Text(
                                            '\$${_totalPerMonth.toStringAsFixed(2)}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color:
                                              const Color(0xFFFF9900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                                : const SizedBox.shrink(
                                key: ValueKey('monthly-hidden')),
                          ),

                          if (_monthlyAmount > 0) const SizedBox(height: 20),

                          // ── Quick Amount Chips ───────────────────────
                          Text(
                            'مبالغ مقترحة',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [60, 120, 180, 240, 360].map((amount) {
                              return GestureDetector(
                                onTap: () {
                                  _amountController.text = amount.toString();
                                  _amountController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: _amountController.text.length,
                                        ),
                                      );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '\$$amount',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Info Note ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.7),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'يمكنك دفع رسوم الاشتراك الشهرية بشكل منفصل أو مجمّعة لعدة أشهر في آنٍ واحد.',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Submit Button ─────────────────────────────────
                    AppButton(
                      label: 'تفعيل الاشتراك',
                      onPressed: _isLoading ? null : _submit,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}