// lib/features/admin/presentation/screens/admin_subscribers_report_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/services/report_exporter.dart';

// import 'package:permission_handler/permission_handler.dart';

class AdminSubscribersReportScreen extends StatefulWidget {
  const AdminSubscribersReportScreen({super.key});

  @override
  State<AdminSubscribersReportScreen> createState() =>
      _AdminSubscribersReportScreenState();
}

class _AdminSubscribersReportScreenState
    extends State<AdminSubscribersReportScreen> {
  final _repo = AdminRepository();

  List<SubscriberReport> _report = [];
  bool _isLoading = true;
  List<int> _years = [DateTime.now().year];

  late int _selectedMonth;
  late int _selectedYear;

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const _monthAbbrev = [
    'ي', 'ف', 'م', 'أ', 'م', 'ي', 'ي', 'أ', 'س', 'أ', 'ن', 'د',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadYears();
    _loadReport();
  }

  /// السنوات الموجودة فعلاً في البيانات (بدل القائمة الثابتة 2024–2026)
  Future<void> _loadYears() async {
    final years = await _repo.getReportYears();
    if (!mounted) return;
    setState(() {
      _years = years;
      if (!_years.contains(_selectedYear)) _years = [..._years, _selectedYear]..sort((a, b) => b.compareTo(a));
    });
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getSubscribersReport(
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (mounted) setState(() => _report = data);
    } catch (e) {
      if (mounted) showAdminSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _fullyPaidCount {
    return _report.where((s) {
      final past =
      s.months.where((m) => m.monthNumber <= _selectedMonth).toList();
      return past.isNotEmpty &&
          past.every((m) => m.status == PaymentStatus.paid);
    }).length;
  }

  int get _overdueCount => _report
      .where((s) => s.months.any((m) => m.status == PaymentStatus.overdue))
      .length;

  // المبلغ الفعلي المدفوع (من الخادم). الحساب القديم عدد الأشهر × القسط الحالي
  // كان يعطي رقماً خاطئاً بعد تعديل الباقة أو عند الدفعات بمبلغ مخصص.
  double _calcPaid(SubscriberReport s) => s.paidTotal;
  Future<void> _exportPdf() async {
    if (_report.isEmpty) {
      showAdminSnack(context, 'لا توجد بيانات لتصديرها');
      return;
    }
    final bytes = await ReportExporter.subscribersPdf(
      report: _report,
      month: _selectedMonth,
      year: _selectedYear,
      fullyPaid: _fullyPaidCount,
      overdue: _overdueCount,
    );
    await ReportExporter.sharePdf(
        bytes, 'subscribers_${_selectedYear}_$_selectedMonth.pdf');
  }

  Future<void> _exportExcel() async {
    if (_report.isEmpty) {
      showAdminSnack(context, 'لا توجد بيانات لتصديرها');
      return;
    }
    final bytes = ReportExporter.subscribersExcel(
      report: _report,
      month: _selectedMonth,
      year: _selectedYear,
    );
    await ReportExporter.shareExcel(
        bytes, 'subscribers_${_selectedYear}_$_selectedMonth.xlsx');
  }

  // ═════════════════════════════════════════════════════════
  // UI-ONLY HELPERS (no data / API logic)
  // ═════════════════════════════════════════════════════════

  /// Which export is currently running: 'pdf' | 'excel' | null.
  /// Only drives the button spinner and prevents double taps.
  String? _busyExport;

  Future<void> _runExport(String kind, Future<void> Function() action) async {
    if (_busyExport != null) return;
    setState(() => _busyExport = kind);
    try {
      await action();
    } catch (e) {
      if (mounted) showAdminSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busyExport = null);
    }
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTokens.bg,
      body: Column(
        children: [
          AdminHeaderBar(
            title: 'تقرير المشتركين',
            subtitle: '${_arabicMonths[_selectedMonth - 1]} $_selectedYear',
            onBack: () => context.go('/admin/dashboard'),
            trailing: AdminHeaderBadge('${_report.length} مشترك'),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FilterCard(
                      selectedMonth: _selectedMonth,
                      selectedYear: _selectedYear,
                      years: _years,
                      arabicMonths: _arabicMonths,
                      busyExport: _busyExport,
                      onMonthChanged: (v) {
                        setState(() => _selectedMonth = v);
                        _loadReport();
                      },
                      onYearChanged: (v) {
                        setState(() => _selectedYear = v);
                        _loadReport();
                      },
                      onExportPdf: () => _runExport('pdf', _exportPdf),
                      onExportExcel: () => _runExport('excel', _exportExcel),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _SummaryCard(
                      total: _report.length,
                      fullyPaid: _fullyPaidCount,
                      overdue: _overdueCount,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(child: _ListSkeleton())
                else if (_report.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AdminEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'لا توجد بيانات',
                      message: 'لا يوجد مشتركون في هذه الفترة',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        16, 0, 16, 32 + MediaQuery.of(context).padding.bottom),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _SubscriberCard(
                          key: ValueKey(_report[i].id),
                          report: _report[i],
                          paidAmount: _calcPaid(_report[i]),
                          highlightMonth: _selectedMonth,
                          monthNames: _arabicMonths,
                        ),
                        childCount: _report.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED STATUS STYLE
// ═══════════════════════════════════════════════════════════

class _CellStyle {
  const _CellStyle(this.bg, this.fg, this.icon, this.label);
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
}

_CellStyle _styleFor(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.paid:
      return const _CellStyle(
          AdminTokens.paidBg, AdminTokens.paidFg, Icons.check_rounded, 'مدفوع');
    case PaymentStatus.overdue:
      return const _CellStyle(AdminTokens.overdueBg, AppColors.error,
          Icons.close_rounded, 'متأخر');
    case PaymentStatus.pending:
      return const _CellStyle(AdminTokens.pendingBg, AppColors.textMuted,
          Icons.remove_rounded, 'لم يحن بعد');
  }
}

// ═══════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.selectedMonth,
    required this.selectedYear,
    required this.years,
    required this.arabicMonths,
    required this.busyExport,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  final int selectedMonth;
  final int selectedYear;
  final List<int> years;
  final List<String> arabicMonths;
  final String? busyExport;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final idle = busyExport == null;

    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminDropdown<int>(
                  label: 'الشهر',
                  value: selectedMonth,
                  items: List.generate(
                    12,
                        (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(arabicMonths[i], style: AdminText.body),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) onMonthChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 116,
                child: AdminDropdown<int>(
                  label: 'السنة',
                  value: selectedYear,
                  items: years
                      .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text('$y', style: AdminText.body),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onYearChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'تصدير PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  height: 46,
                  loading: busyExport == 'pdf',
                  onPressed: idle ? onExportPdf : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminButton(
                  label: 'تصدير Excel',
                  icon: Icons.table_chart_rounded,
                  color: const Color(0xFF1D6F42),
                  height: 46,
                  loading: busyExport == 'excel',
                  onPressed: idle ? onExportExcel : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.fullyPaid,
    required this.overdue,
  });
  final int total;
  final int fullyPaid;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppColors.border.withOpacity(0.6),
    );

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'المشتركين',
                    value: '$total',
                    color: AppColors.primary,
                    icon: Icons.people_rounded,
                  ),
                ),
                divider,
                Expanded(
                  child: _SummaryStat(
                    label: 'مدفوعون',
                    value: '$fullyPaid',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                divider,
                Expanded(
                  child: _SummaryStat(
                    label: 'متأخرون',
                    value: '$overdue',
                    color: AppColors.error,
                    icon: Icons.warning_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border.withOpacity(0.6)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final s in PaymentStatus.values) _LegendItem(style: _styleFor(s)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(value, style: AdminText.number.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AdminText.caption),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.style});
  final _CellStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(style.icon, size: 14, color: style.fg),
        ),
        const SizedBox(width: 6),
        Text(style.label, style: AdminText.caption),
      ],
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AdminPulse(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            AdminSkeleton(height: 150, radius: AdminTokens.rLg),
            SizedBox(height: 10),
            AdminSkeleton(height: 150, radius: AdminTokens.rLg),
            SizedBox(height: 10),
            AdminSkeleton(height: 150, radius: AdminTokens.rLg),
          ],
        ),
      ),
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({
    super.key,
    required this.report,
    required this.paidAmount,
    required this.highlightMonth,
    required this.monthNames,
  });

  final SubscriberReport report;
  final double paidAmount;
  final int highlightMonth;
  final List<String> monthNames;

  @override
  Widget build(BuildContext context) {
    final months = report.months;

    Widget monthRow(int from) {
      return Row(
        children: [
          for (var i = from; i < from + 6 && i < months.length; i++) ...[
            if (i != from) const SizedBox(width: 6),
            Expanded(
              child: _MonthCell(
                name: monthNames[months[i].monthNumber - 1],
                status: months[i].status,
                highlighted: months[i].monthNumber == highlightMonth,
              ),
            ),
          ],
        ],
      );
    }

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: AdminTokens.heroGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  report.fullName.isNotEmpty ? report.fullName[0] : '?',
                  style: AdminText.label.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.fullName,
                      style: AdminText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${AdminFmt.money(report.annualAmount)} / سنة',
                      style: AdminText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdminPill(
                label: 'مدفوع ${AdminFmt.money(paidAmount)}',
                color: AppColors.primary,
                icon: Icons.account_balance_wallet_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          monthRow(0),
          if (months.length > 6) ...[
            const SizedBox(height: 6),
            monthRow(6),
          ],
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.name,
    required this.status,
    required this.highlighted,
  });
  final String name;
  final PaymentStatus status;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final st = _styleFor(status);

    return Semantics(
      label: '$name، ${st.label}',
      excludeSemantics: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(10),
          border: highlighted
              ? Border.all(color: AppColors.primary, width: 1.6)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: AdminText.captionBold.copyWith(color: st.fg),
              ),
            ),
            const SizedBox(height: 2),
            Icon(st.icon, size: 14, color: st.fg),
          ],
        ),
      ),
    );
  }
}