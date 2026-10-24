// lib/features/admin/presentation/screens/admin_fund_report_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/services/report_exporter.dart';


class AdminFundReportScreen extends StatefulWidget {
  const AdminFundReportScreen({super.key});

  @override
  State<AdminFundReportScreen> createState() => _AdminFundReportScreenState();
}

class _AdminFundReportScreenState extends State<AdminFundReportScreen> {
  final _repo = AdminRepository();

  List<FundTransfer> _transfers = [];
  FundSummary? _summary;
  YearlyReport? _yearly;
  List<int> _years = [DateTime.now().year];
  bool _isLoading = true;
  bool _isMonthly = true;

  late int _selectedMonth;
  late int _selectedYear;

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadYears();
    _loadData();
  }

  /// السنوات الموجودة فعلاً في البيانات بدل القائمة الثابتة 2024–2026
  Future<void> _loadYears() async {
    final years = await _repo.getReportYears();
    if (!mounted) return;
    setState(() {
      _years = years;
      if (!_years.contains(_selectedYear)) {
        _years = [..._years, _selectedYear]..sort((a, b) => b.compareTo(a));
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final type = _isMonthly ? 'monthly' : 'annual';
      final results = await Future.wait([
        _repo.getFundTransfers(
            type: type, month: _selectedMonth, year: _selectedYear),
        _repo.getFundSummary(
            type: type, month: _selectedMonth, year: _selectedYear),
        // الجدول السنوي (12 شهراً) يُطلب فقط في الوضع السنوي
        if (!_isMonthly) _repo.getYearlyReport(year: _selectedYear),
      ]);
      if (mounted) {
        setState(() {
          _transfers = results[0] as List<FundTransfer>;
          _summary = results[1] as FundSummary;
          _yearly = _isMonthly ? null : results[2] as YearlyReport;
        });
      }
    } catch (e) {
      if (mounted) showAdminSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double v) => AdminFmt.moneyAuto(v);

  // ── التصدير (PDF / Excel) ────────────────────────────────
  /// 'pdf' | 'excel' | null — يتحكم بدوّار الزر ويمنع الضغط المزدوج.
  String? _busyExport;

  String get _fileSuffix =>
      _isMonthly ? '${_selectedYear}_$_selectedMonth' : '$_selectedYear';

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

  Future<void> _exportPdf() async {
    final s = _summary;
    if (s == null) {
      showAdminSnack(context, 'لا توجد بيانات لتصديرها');
      return;
    }
    final bytes = await ReportExporter.fundReportPdf(
      summary: s,
      transfers: _transfers,
      yearly: _isMonthly ? null : _yearly,
      periodLabel: _periodLabel,
      isMonthly: _isMonthly,
    );
    await ReportExporter.sharePdf(bytes, 'fund_report_$_fileSuffix.pdf');
  }

  Future<void> _exportExcel() async {
    final s = _summary;
    if (s == null) {
      showAdminSnack(context, 'لا توجد بيانات لتصديرها');
      return;
    }
    final bytes = ReportExporter.fundReportExcel(
      summary: s,
      transfers: _transfers,
      yearly: _isMonthly ? null : _yearly,
      periodLabel: _periodLabel,
      isMonthly: _isMonthly,
    );
    await ReportExporter.shareExcel(bytes, 'fund_report_$_fileSuffix.xlsx');
  }

  String get _periodLabel => _isMonthly
      ? '${_arabicMonths[_selectedMonth - 1]} $_selectedYear'
      : 'السنة $_selectedYear';

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
            title: 'تقرير الصناديق',
            subtitle: _periodLabel,
            onBack: () => context.go('/admin/dashboard'),
            trailing: AdminHeaderBadge('${_transfers.length} تحويل'),
          ),
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const _ReportSkeleton()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              backgroundColor: Colors.white,
              strokeWidth: 2.5,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCard()),
                  SliverToBoxAdapter(child: _buildBreakdownCard()),
                  if (!_isMonthly && _yearly != null)
                    SliverToBoxAdapter(
                        child: _buildYearlyTable(_yearly!)),
                  SliverToBoxAdapter(child: _buildListHeader()),
                  if (_transfers.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AdminEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'لا توجد تحويلات',
                        message: 'لا توجد تحويلات مسجّلة في هذه الفترة',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          32 + MediaQuery.of(context).padding.bottom),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) =>
                              _TransferCard(transfer: _transfers[i]),
                          childCount: _transfers.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────
  Widget _buildFilterCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminSegmented(
              labels: const ['شهري', 'سنوي'],
              icons: const [
                Icons.calendar_view_month_rounded,
                Icons.calendar_today_rounded,
              ],
              selectedIndex: _isMonthly ? 0 : 1,
              onChanged: (i) {
                final monthly = i == 0;
                if (monthly != _isMonthly) {
                  setState(() => _isMonthly = monthly);
                  _loadData();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isMonthly) ...[
                  Expanded(
                    child: AdminDropdown<int>(
                      label: 'الشهر',
                      value: _selectedMonth,
                      items: List.generate(
                        12,
                            (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_arabicMonths[i], style: AdminText.body),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedMonth = v);
                          _loadData();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // عرض ثابت في الوضع الشهري، و Expanded في الوضع السنوي
                // (SizedBox(width: double.infinity) داخل Row يكسر الـ layout).
                if (_isMonthly)
                  SizedBox(width: 116, child: _yearDropdown())
                else
                  Expanded(child: _yearDropdown()),
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
                    loading: _busyExport == 'pdf',
                    onPressed: (_busyExport == null && !_isLoading && _summary != null)
                        ? () => _runExport('pdf', _exportPdf)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AdminButton(
                    label: 'تصدير Excel',
                    icon: Icons.table_chart_rounded,
                    color: const Color(0xFF1D6F42),
                    height: 46,
                    loading: _busyExport == 'excel',
                    onPressed: (_busyExport == null && !_isLoading && _summary != null)
                        ? () => _runExport('excel', _exportExcel)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearDropdown() {
    return AdminDropdown<int>(
      label: 'السنة',
      value: _selectedYear,
      items: _years
          .map((y) => DropdownMenuItem(
        value: y,
        child: Text('$y', style: AdminText.body),
      ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _selectedYear = v);
          _loadData();
        }
      },
    );
  }

  // ── Summary hero ─────────────────────────────────────────
  Widget _buildSummaryCard() {
    final s = _summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AdminHeroCard(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AdminLiveDot(size: 6),
                const SizedBox(width: 8),
                Text('ملخص الفترة', style: AdminText.onBrandLabel),
              ],
            ),
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryStatBox(
                      icon: Icons.arrow_downward_rounded,
                      iconBg: const Color(0x3369F0AE),
                      iconColor: AdminTokens.live,
                      label: 'المقبوضات',
                      value: s != null
                          ? AdminFmt.money(s.totalReceivedThisMonth)
                          : '—',
                    ),
                  ),
                  const VerticalDivider(
                    color: AdminTokens.onBrand15,
                    width: 24,
                    thickness: 1,
                    indent: 4,
                    endIndent: 4,
                  ),
                  Expanded(
                    child: _SummaryStatBox(
                      icon: Icons.arrow_upward_rounded,
                      iconBg: const Color(0x33FFB74D),
                      iconColor: const Color(0xFFFFB74D),
                      label: 'المحوّل',
                      value: s != null
                          ? AdminFmt.money(s.totalTransferredThisMonth)
                          : '—',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AdminTokens.onBrand10,
                borderRadius: BorderRadius.circular(AdminTokens.rMd),
                border: Border.all(color: AdminTokens.onBrand10),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _BalanceItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'صندوق التطبيق',
                        value:
                        s != null ? AdminFmt.money(s.appFundBalance) : '—',
                      ),
                    ),
                    const VerticalDivider(
                      color: AdminTokens.onBrand20,
                      width: 20,
                      thickness: 1,
                    ),
                    Expanded(
                      child: _BalanceItem(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'صندوق الفريق التطوعي',
                        value: s != null
                            ? AdminFmt.money(s.charityFundBalance)
                            : '—',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // تفصيل الوارد حسب المصدر + المستحق والمحصّل
  // ───────────────────────────────────────────────────────
  Widget _buildBreakdownCard() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    final collectedRatio = s.expectedTotal > 0
        ? (s.collectedTotal / s.expectedTotal).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AdminCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionTitle(
              title: 'مصدر الوارد في الفترة',
              icon: Icons.account_tree_rounded,
            ),
            const SizedBox(height: 12),
            _SourceRow(
                icon: Icons.credit_card_rounded,
                label: 'دفع إلكتروني',
                value: _fmt(s.receivedGateway),
                color: AppColors.primary),
            _SourceRow(
                icon: Icons.edit_note_rounded,
                label: 'تسجيل يدوي',
                value: _fmt(s.receivedManual),
                color: AdminTokens.amber),
            _SourceRow(
                icon: Icons.history_rounded,
                label: 'دفعات قبل إطلاق التطبيق',
                value: _fmt(s.receivedHistorical),
                color: AppColors.textMuted),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(
                  height: 1, color: AppColors.border.withOpacity(0.6)),
            ),
            AdminSectionTitle(
              title: _isMonthly ? 'المستحق لهذا الشهر' : 'المستحق لهذه السنة',
              icon: Icons.fact_check_rounded,
              trailing: Text(
                '${(collectedRatio * 100).round()}%',
                style: AdminText.label.copyWith(color: AppColors.success),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: collectedRatio),
                duration: const Duration(milliseconds: 600),
                curve: AdminTokens.curve,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: AppColors.primarySoft,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                      label: 'المطلوب',
                      value: _fmt(s.expectedTotal),
                      color: AppColors.textDark),
                ),
                Expanded(
                  child: _MiniStat(
                      label: 'المحصّل',
                      value: _fmt(s.collectedTotal),
                      color: AppColors.success),
                ),
                Expanded(
                  child: _MiniStat(
                      label: 'المتأخر',
                      value: _fmt(s.overdueTotal),
                      color: AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AdminPill(
                    label: '${s.paidCount} مدفوعة',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded),
                AdminPill(
                    label: '${s.overdueCount} متأخرة',
                    color: AppColors.error,
                    icon: Icons.warning_amber_rounded),
                AdminPill(
                    label: '${s.pendingCount} لم يحن موعدها',
                    color: AppColors.textMuted,
                    icon: Icons.schedule_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // الجدول السنوي: 12 شهراً (يمرَّر أفقياً داخل حاويته فقط)
  // ───────────────────────────────────────────────────────
  Widget _buildYearlyTable(YearlyReport y) {
    final headerStyle = AdminText.captionBold.copyWith(color: AppColors.accent);
    final cellStyle = AdminText.caption.copyWith(color: AppColors.textDark);

    DataRow row(String name, YearlyMonthRow? r, {bool total = false}) {
      TextStyle st = total
          ? cellStyle.copyWith(fontWeight: FontWeight.w800)
          : cellStyle;
      String v(double Function(YearlyMonthRow) f, double totalValue) =>
          _fmt(total ? totalValue : f(r!));
      return DataRow(
        color: total ? MaterialStateProperty.all(AppColors.primarySoft) : null,
        cells: [
          DataCell(Text(name, style: st)),
          DataCell(Text(v((x) => x.expected, y.totalExpected), style: st)),
          DataCell(Text(v((x) => x.collected, y.totalCollected), style: st)),
          DataCell(Text(
              v((x) => x.receivedGateway, y.totalReceivedGateway),
              style: st)),
          DataCell(Text(v((x) => x.receivedManual, y.totalReceivedManual),
              style: st)),
          DataCell(Text(
              v((x) => x.receivedHistorical, y.totalReceivedHistorical),
              style: st)),
          DataCell(Text(v((x) => x.transferred, y.totalTransferred),
              style: st)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: AdminSectionTitle(
                title: 'التقرير السنوي ${y.year}',
                icon: Icons.table_chart_rounded,
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AdminTokens.rLg)),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: AppColors.border.withOpacity(0.4),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    columnSpacing: 22,
                    headingRowColor:
                    MaterialStateProperty.all(AppColors.primarySoft),
                    columns: [
                      DataColumn(label: Text('الشهر', style: headerStyle)),
                      DataColumn(label: Text('المطلوب', style: headerStyle)),
                      DataColumn(label: Text('المحصّل', style: headerStyle)),
                      DataColumn(label: Text('إلكتروني', style: headerStyle)),
                      DataColumn(label: Text('يدوي', style: headerStyle)),
                      DataColumn(
                          label: Text('قبل التطبيق', style: headerStyle)),
                      DataColumn(label: Text('المحوّل', style: headerStyle)),
                    ],
                    rows: [
                      for (final r in y.months)
                        row(_arabicMonths[r.month - 1], r),
                      row('الإجمالي', null, total: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: AdminSectionTitle(
        title: 'سجل التحويلات',
        trailing: AdminPill(
          label: '${_transfers.length} تحويل',
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AdminPulse(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            AdminSkeleton(height: 236, radius: AdminTokens.rXl),
            SizedBox(height: 14),
            AdminSkeleton(height: 220, radius: AdminTokens.rLg),
            SizedBox(height: 14),
            AdminSkeleton(height: 84, radius: AdminTokens.rLg),
            SizedBox(height: 10),
            AdminSkeleton(height: 84, radius: AdminTokens.rLg),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AdminText.body)),
          const SizedBox(width: 8),
          Text(value, style: AdminText.label),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: AdminText.label.copyWith(fontSize: 16, color: color)),
        ),
        Text(label, style: AdminText.caption),
      ],
    );
  }
}

class _SummaryStatBox extends StatelessWidget {
  const _SummaryStatBox({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AdminText.statValue.copyWith(fontSize: 26)),
        ),
        Text(label, style: AdminText.onBrandCaption),
      ],
    );
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AdminTokens.onBrand85, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: AdminText.onBrandCaption,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AdminText.statValue.copyWith(fontSize: 20)),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer});
  final FundTransfer transfer;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AdminTokens.heroGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: AdminTokens.glow(AppColors.primary),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transfer.recipientName,
                        style: AdminText.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AdminTokens.heroGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AdminFmt.moneyAuto(transfer.amount),
                        style: AdminText.label.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                        icon: Icons.receipt_outlined,
                        label: transfer.receiptNumber),
                    _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: transfer.transferDate),
                  ],
                ),
                if (transfer.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminTokens.warnBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminTokens.warnBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 14, color: AdminTokens.orange),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            transfer.note,
                            style: AdminText.caption
                                .copyWith(color: AdminTokens.orange),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AdminText.caption),
      ],
    );
  }
}