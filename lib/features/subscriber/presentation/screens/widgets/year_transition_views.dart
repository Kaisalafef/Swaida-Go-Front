// lib/features/subscriber/presentation/screens/widgets/year_transition_views.dart
//
// شاشتا بداية السنة الجديدة للمشترك:
//   YearMustPayView : متأخرات من سنوات سابقة → دفع إجباري فوراً
//   YearRenewalView : لا متأخرات → تجديد / تغيير الباقة / إيقاف
//                     (المتوقف سابقاً: تجديد أو تغيير فقط)
//
// الشاشتان بلا منطق شبكة: كل العمليات تُمرَّر كـ callbacks من SubscriberHomeScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/widgets/app_dialogs.dart';
import '../../../data/models/subscriber_models.dart';

// ═══════════════════════════════════════════════════════════
// 1) دفع المتأخرات (إجباري)
// ═══════════════════════════════════════════════════════════

class YearMustPayView extends StatelessWidget {
  const YearMustPayView({
    super.key,
    required this.status,
    required this.commissionRate,
    required this.fixedFee,
    required this.busy,
    required this.onPay,
    this.onLogout,
  });

  final YearStatus status;
  final double commissionRate; // نسبة مئوية
  final double fixedFee;
  final bool busy;
  final VoidCallback onPay;

  /// خروج من الحساب: الشاشة إجبارية فلا مسار آخر للمستخدم.
  final VoidCallback? onLogout;

  double get _commission => status.overdueTotal * (commissionRate / 100);
  double get _total => status.overdueTotal + _commission + fixedFee;

  Widget _row(String label, String value, {bool bold = false}) {
    final style = GoogleFonts.cairo(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? AppColors.accent : AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = status.overdueItems.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _IconBadge(
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              soft: AppColors.errorLight,
            ),
            const SizedBox(height: 16),
            Text(
              'أشهر متأخرة من السنوات السابقة',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بدأت سنة جديدة ولديك ${Fmt.months(count)} لم تُدفع. '
                  'ادفعها الآن لتتمكن من متابعة اشتراكك.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: status.overdueItems.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${Fmt.month(item.monthNumber)} ${item.year} — ${Fmt.money2(item.amount)}',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 28),
                  _row('المبلغ الأساسي', Fmt.money2(status.overdueTotal)),
                  _row('العمولة (${commissionRate.toStringAsFixed(0)}%)',
                      Fmt.money2(_commission)),
                  _row('رسم ثابت', Fmt.money2(fixedFee)),
                  const Divider(height: 20),
                  _row('الإجمالي', Fmt.money2(_total), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: busy
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.white),
              )
                  : Text(
                'ادفع ${Fmt.money2(_total)} الآن',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 8),
              _LogoutLink(onTap: busy ? null : onLogout),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2) تجديد / تغيير / إيقاف
// ═══════════════════════════════════════════════════════════

class YearRenewalView extends StatelessWidget {
  const YearRenewalView({
    super.key,
    required this.status,
    required this.busy,
    required this.onRenew,
    required this.onChange,
    required this.onStop,
    this.onLogout,
  });

  final YearStatus status;
  final bool busy;
  final VoidCallback onRenew;
  final void Function(double annualAmount) onChange;
  final VoidCallback onStop;

  /// خروج من الحساب: الشاشة إجبارية فلا مسار آخر للمستخدم.
  final VoidCallback? onLogout;

  bool get _isStopped => status.state == YearState.stopped;

  Future<void> _askAmount(BuildContext context) async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _ChangeAmountDialog(status: status),
    );
    if (v != null) onChange(v);
  }

  /// التجديد يُنشئ دفعات سنة كاملة: لا يُنفَّذ بلمسة واحدة (الإيقاف له تأكيد أصلاً).
  Future<void> _confirmRenew(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: _isStopped ? 'إعادة تفعيل الاشتراك؟' : 'تجديد الاشتراك؟',
      message:
      'سيُجدَّد اشتراكك لسنة ${status.currentYear} بنفس المبلغ السنوي '
          '${Fmt.money(status.annualAmount)} (${Fmt.money2(status.monthlyAmount)} شهرياً)، '
          'وتظهر أشهر السنة لتدفعها.',
      confirmLabel: 'تجديد',
    );
    if (ok) onRenew();
  }

  Future<void> _confirmStop(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إيقاف الاشتراك؟',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Text(
            'لن تُولَّد دفعات للسنة الجديدة. يمكنك تجديد اشتراكك لاحقاً في أي وقت.',
            style: GoogleFonts.cairo(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('تراجع',
                  style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('إيقاف',
                  style: GoogleFonts.cairo(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) onStop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IconBadge(
              icon: _isStopped
                  ? Icons.pause_circle_outline_rounded
                  : Icons.autorenew_rounded,
              color: AppColors.primary,
              soft: AppColors.primarySoft,
            ),
            const SizedBox(height: 16),
            Text(
              _isStopped
                  ? 'اشتراكك متوقف'
                  : 'سنة ${status.currentYear} — جدّد اشتراكك',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isStopped
                  ? 'يمكنك إعادة تفعيل اشتراكك بتجديده أو بتغيير الباقة.'
                  : 'أتممت دفع كل أشهرك السابقة. اختر ما تريده للسنة الجديدة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _stat('باقتك الحالية', '${Fmt.money(status.annualAmount)} / سنة'),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.border.withOpacity(0.5),
                  ),
                  _stat('القسط الشهري', Fmt.money2(status.monthlyAmount)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.autorenew_rounded,
              color: AppColors.primary,
              title: 'تجديد',
              subtitle:
              'بنفس المبلغ السنوي ${Fmt.money(status.annualAmount)} (${Fmt.money2(status.monthlyAmount)} شهرياً)',
              enabled: !busy,
              onTap: () => _confirmRenew(context),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.tune_rounded,
              color: AppColors.accent,
              title: 'تغيير الباقة',
              subtitle: 'اختر مبلغاً سنوياً جديداً، ثم يُجدَّد اشتراكك به',
              enabled: !busy,
              onTap: () => _askAmount(context),
            ),
            if (status.canStop) ...[
              const SizedBox(height: 12),
              _OptionCard(
                icon: Icons.pause_circle_outline_rounded,
                color: AppColors.error,
                title: 'إيقاف الاشتراك',
                subtitle: 'لن تُولَّد دفعات جديدة، ويمكنك التجديد لاحقاً',
                enabled: !busy,
                onTap: () => _confirmStop(context),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'بعد التجديد تظهر أشهر السنة الجديدة لتدفعها.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 8),
              _LogoutLink(onTap: busy ? null : onLogout),
            ],
            if (busy) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared pieces
// ═══════════════════════════════════════════════════════════

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.soft,
  });

  final IconData icon;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 36),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.35), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // chevron_right يُعكس في RTL فيشير يساراً (اتجاه «تابع»)
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangeAmountDialog extends StatefulWidget {
  const _ChangeAmountDialog({required this.status});

  final YearStatus status;

  @override
  State<_ChangeAmountDialog> createState() => _ChangeAmountDialogState();
}

class _ChangeAmountDialogState extends State<_ChangeAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final a = widget.status.annualAmount;
    _controller = TextEditingController(
      text: a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _value {
    final t = _controller.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? get _error {
    final v = _value;
    if (v == null) return null;
    if (v < widget.status.minAnnual) {
      return 'الحد الأدنى ${widget.status.minAnnual.toInt()}\$ سنوياً';
    }
    if (v > widget.status.maxAnnual) {
      return 'الحد الأقصى ${widget.status.maxAnnual.toInt()}\$ سنوياً';
    }
    return null;
  }

  bool get _valid => _value != null && _error == null;

  @override
  Widget build(BuildContext context) {
    final v = _value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تغيير الباقة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بين ${widget.status.minAnnual.toInt()}\$ و${widget.status.maxAnnual.toInt()}\$ — يُقسَّم على 12 شهراً',
              style:
              GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                fontSize: 26,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                errorText: _error,
                errorStyle: GoogleFonts.cairo(fontSize: 12),
                filled: true,
                fillColor: AppColors.primarySoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _valid ? 'القسط الشهري: ${Fmt.money2(v! / 12)}' : ' ',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء',
                style: GoogleFonts.cairo(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: _valid ? () => Navigator.of(context).pop(_value) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('تغيير وتجديد',
                style: GoogleFonts.cairo(color: AppColors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  رابط «تسجيل الخروج» (مخرج من الشاشات الإجبارية)
// ─────────────────────────────────────────────────────────
class _LogoutLink extends StatelessWidget {
  const _LogoutLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
