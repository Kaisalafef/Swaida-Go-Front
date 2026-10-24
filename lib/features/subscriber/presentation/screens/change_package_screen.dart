// lib/features/subscriber/presentation/screens/change_package_screen.dart
//
// تعديل الباقة (زيادة أو تقليل المبلغ السنوي).
// القاعدة (يحسبها الخادم ويعرضها هنا قبل التأكيد):
//   • المبلغ الجديد يسري على الأشهر غير المدفوعة من الشهر الحالي فصاعداً.
//   • الأشهر المدفوعة والمتأخرات السابقة تبقى كما هي.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_cards.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';

class ChangePackageScreen extends StatefulWidget {
  const ChangePackageScreen({super.key});

  @override
  State<ChangePackageScreen> createState() => _ChangePackageScreenState();
}

class _ChangePackageScreenState extends State<ChangePackageScreen> {
  static const double _minAnnual = PackageRules.minAnnual;
  static const double _maxAnnual = PackageRules.maxAnnual;

  final _repo = SubscriberRepository();
  final _controller = TextEditingController();
  Timer? _debounce;

  SubscriptionInfo? _sub;
  bool _loading = true;
  String? _loadError;

  PackageChangePlan? _plan;
  bool _previewing = false;
  String? _previewError;
  bool _saving = false;
  bool _ready = false; // لا نعالج تغييرات الحقل قبل تعبئته الأولية

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onAmountChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────
  double? get _value {
    final t = _controller.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? get _inputError {
    final v = _value;
    if (_controller.text.trim().isEmpty || v == null) return null;
    if (v < _minAnnual) return 'الحد الأدنى ${_minAnnual.toInt()}\$ سنوياً';
    if (v > _maxAnnual) return 'الحد الأقصى ${_maxAnnual.toInt()}\$ سنوياً';
    return null;
  }

  bool get _isSameAsCurrent {
    final v = _value;
    final s = _sub;
    return v != null && s != null && (v - s.annualAmount).abs() < 0.005;
  }

  // ── Load current subscription ───────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _repo.getUserProfile();
      final sub = profile.subscription;
      if (!mounted) return;
      if (sub == null) {
        setState(() => _loadError = 'لا يوجد اشتراك حالي لتعديله');
      } else {
        _sub = sub;
        final a = sub.annualAmount;
        _controller.text = a == a.roundToDouble()
            ? a.toInt().toString()
            : a.toStringAsFixed(2);
        _ready = true;
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Live preview (debounced) ────────────────────────────
  void _onAmountChanged() {
    if (!_ready) return;
    _debounce?.cancel();

    setState(() {
      _plan = null;
      _previewError = null;
      _previewing = false;
    });

    final v = _value;
    if (v == null || _inputError != null || _isSameAsCurrent) return;

    setState(() => _previewing = true);
    _debounce = Timer(const Duration(milliseconds: 550), () => _fetchPreview(v));
  }

  Future<void> _fetchPreview(double requested) async {
    try {
      final plan = await _repo.previewPackageChange(annualAmount: requested);
      // تجاهل نتيجة قديمة إذا تغيّر المبلغ أثناء الانتظار
      if (!mounted || _value != requested) return;
      setState(() => _plan = plan);
    } catch (e) {
      if (!mounted || _value != requested) return;
      setState(() => _previewError = e.toString());
    } finally {
      if (mounted && _value == requested) {
        setState(() => _previewing = false);
      }
    }
  }

  // ── Confirm + save ──────────────────────────────────────
  Future<void> _confirm() async {
    final plan = _plan;
    final v = _value;
    if (plan == null || v == null || !plan.canChange) return;

    final up = plan.direction == 'increase';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تأكيد تغيير الباقة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Text(
            'سيصبح قسطك الشهري ${Fmt.money(plan.newMonthly)} بدل '
                '${Fmt.money(plan.currentMonthly)} ابتداءً من ${Fmt.month(plan.effectiveMonth)} '
                '(${Fmt.months(plan.affectedCount)} غير مدفوعة).\n\n'
                '${up ? 'ستدفع' : 'ستوفّر'} ${Fmt.money(plan.difference.abs())} '
                'عن بقية هذا العام مقارنة بالباقة الحالية.',
            style: GoogleFonts.cairo(fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _repo.changePackage(annualAmount: v);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.accent),
          title: Text('تعديل الباقة',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.accent)),
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
          ),
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
            ? _buildLoadError()
            : _buildBody(),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final sub = _sub!;
    final plan = _plan;
    final canSubmit = plan != null && plan.canChange && !_saving;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              // ── الباقة الحالية ───────────────────────────
              _card(
                child: Row(
                  children: [
                    const Icon(Icons.card_membership_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('باقتك الحالية',
                              style: GoogleFonts.cairo(
                                  fontSize: 12, color: AppColors.textMuted)),
                          Text(
                            '${Fmt.money(sub.annualAmount)} سنوياً  ·  ${Fmt.money(sub.monthlyAmount)} شهرياً',
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── المبلغ الجديد ────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المبلغ السنوي الجديد',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.accent)),
                    const SizedBox(height: 4),
                    Text(
                      'بين ${_minAnnual.toInt()}\$ و${_maxAnnual.toInt()}\$ — يُقسَّم على 12 شهراً',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: AppColors.primary),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: AppColors.textMuted),
                        errorText: _inputError,
                        errorStyle: GoogleFonts.cairo(fontSize: 12),
                        filled: true,
                        fillColor: AppColors.primarySoft,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                            const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.border, width: 1.5)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                            const BorderSide(color: AppColors.error)),
                        focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.error, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [60, 120, 180, 240, 360, 600].map((a) {
                        final selected = _value == a.toDouble();
                        return ChoiceChip(
                          label: Text('\$$a',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.primary)),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                          side: const BorderSide(color: AppColors.border),
                          showCheckmark: false,
                          onSelected: (_) => _controller.text = a.toString(),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── المعاينة ─────────────────────────────────
              _buildPreview(plan),
            ],
          ),
        ),

        // ── زر التأكيد (أسفل الشاشة: في متناول الإبهام) ──
        Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: AppButton(
                label: 'تأكيد تغيير الباقة',
                isLoading: _saving,
                onPressed: canSubmit ? _confirm : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(PackageChangePlan? plan) {
    if (_previewing) {
      return _card(
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text('جارٍ حساب الأثر…',
                style: GoogleFonts.cairo(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_previewError != null) {
      return _notice(_previewError!, AppColors.error, AppColors.errorLight,
          Icons.error_outline_rounded);
    }

    if (plan == null) {
      return _card(
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSameAsCurrent
                    ? 'هذا هو مبلغ باقتك الحالية. أدخل مبلغاً مختلفاً لمعاينة التغيير.'
                    : 'أدخل المبلغ الجديد لمعاينة أثره قبل التأكيد.',
                style: GoogleFonts.cairo(
                    fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    final up = plan.direction == 'increase';
    final accent = up ? AppColors.primary : AppColors.success;

    final monthsText = plan.affectedMonths.isEmpty
        ? '—'
        : plan.affectedCount <= 4
        ? plan.affectedMonths.map((m) => Fmt.month(m)).join('، ')
        : 'من ${Fmt.month(plan.affectedMonths.first)} إلى ${Fmt.month(plan.affectedMonths.last)} (${Fmt.months(plan.affectedCount)})';

    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('ما الذي سيتغيّر؟',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.accent)),
                  ),
                  if (plan.direction != 'same')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              up
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 16,
                              color: accent),
                          const SizedBox(width: 4),
                          Text(up ? 'زيادة' : 'تخفيض',
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: accent)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _changeRow('القسط الشهري', Fmt.money(plan.currentMonthly),
                  Fmt.money(plan.newMonthly), accent),
              const Divider(height: 22),
              _changeRow('المتبقي هذا العام', Fmt.money(plan.remainingBefore),
                  Fmt.money(plan.remainingAfter), accent),
              const Divider(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('يسري على',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(monthsText,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'الأشهر المدفوعة والمتأخرات السابقة تبقى كما هي. '
                    'رسوم الدفع (العمولة) تُضاف عند كل عملية دفع كالمعتاد.',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        if (!plan.canChange && plan.blockedReason != null) ...[
          const SizedBox(height: 12),
          _notice(plan.blockedReason!, AppColors.warningText,
              AppColors.warningLight, Icons.hourglass_bottom_rounded),
        ],
      ],
    );
  }

  Widget _changeRow(String label, String from, String to, Color accent) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style:
              GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted)),
        ),
        const SizedBox(width: 12),
        Text(from,
            style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough)),
        const SizedBox(width: 8),
        // forward يُعكس تلقائياً في RTL فيشير نحو القيمة الجديدة (اليسار)
        const Icon(Icons.arrow_forward_rounded,
            size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(to,
            style: GoogleFonts.cairo(
                fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
      ],
    );
  }

  Widget _card({required Widget child}) => AppCard(child: child);

  Widget _notice(String text, Color fg, Color bg, IconData icon) =>
      AppNotice(text: text, fg: fg, bg: bg, icon: icon);
}
