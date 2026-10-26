// lib/features/subscriber/presentation/screens/confirmation_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';

class ConfirmationScreen extends StatefulWidget {
  final PaymentSession session;

  const ConfirmationScreen({super.key, required this.session});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriberRepository();

  PaymentRecord? _receipt;
  bool _isLoadingReceipt = true;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    _loadReceipt();
  }

  bool _motionInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionInit) return;
    _motionInit = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.value = 1; // «تقليل الحركة»: بلا أنيميشن
    } else {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipt() async {
    try {
      final receipt = await _repo.getLatestReceipt();
      if (mounted) setState(() => _receipt = receipt);
    } catch (_) {
      // Non-critical — don't block UI
    } finally {
      if (mounted) setState(() => _isLoadingReceipt = false);
    }
  }

  String _formatMonths(List<int> months) {
    return months.map(Fmt.month).join('، ');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ── Success Animation ──────────────────────
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 68,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title & Subtitle ───────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        Text(
                          'تم الدفع بنجاح!',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            color: AppColors.accent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تمّت معالجة دفعتك وتحديث حالة اشتراكك.',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Payment Summary Card ───────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'تفاصيل الدفعة',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 16),

                          _infoRow(
                            'الأشهر المدفوعة',
                            _formatMonths(widget.session.months),
                          ),
                          const SizedBox(height: 12),
                          _infoRow(
                            'عدد الأشهر',
                            Fmt.months(widget.session.months.length),
                          ),
                          const SizedBox(height: 12),
                          _infoRow(
                            'المبلغ الإجمالي',
                            '\$${widget.session.totalAmount.toStringAsFixed(2)}',
                            valueColor: AppColors.success,
                            valueBold: true,
                          ),

                          // Receipt Info (if loaded)
                          if (!_isLoadingReceipt && _receipt != null) ...[
                            const SizedBox(height: 12),
                            const Divider(color: AppColors.border, height: 1),
                            const SizedBox(height: 12),
                            _infoRow('رقم الإيصال', _receipt!.receiptNumber),
                            const SizedBox(height: 12),
                            _infoRow('تاريخ الدفع', _receipt!.paidAt),
                          ] else if (_isLoadingReceipt) ...[
                            const SizedBox(height: 16),
                            const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Months Chips ───────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأشهر التي تم دفعها',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.session.months.map((month) {
                            final name = Fmt.month(month);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      color: AppColors.success, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Actions ────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      AppButton(
                        label: 'العودة للرئيسية',
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'عرض الملف الشخصي',
                        onPressed: () => context.go('/profile'),
                        outlined: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
      String label,
      String value, {
        Color? valueColor,
        bool valueBold = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textDark,
            ),
            textAlign: TextAlign.left,
            // المبالغ والأرقام فقط LTR؛ فرض LTR على الأشهر العربية كان يعكس ترتيبها.
            textDirection: RegExp(r'^[\$#\d]').hasMatch(value)
                ? TextDirection.ltr
                : null,
          ),
        ),
      ],
    );
  }
}
