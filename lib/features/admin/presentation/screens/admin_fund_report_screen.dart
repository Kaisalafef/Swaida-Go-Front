// lib/features/admin/presentation/screens/admin_fund_report_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class AdminFundReportScreen extends StatefulWidget {
  const AdminFundReportScreen({super.key});

  @override
  State<AdminFundReportScreen> createState() => _AdminFundReportScreenState();
}

class _AdminFundReportScreenState extends State<AdminFundReportScreen> {
  final _repo = AdminRepository();

  List<FundTransfer> _transfers = [];
  FundSummary? _summary;
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
    _loadData();
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
      ]);
      if (mounted) {
        setState(() {
          _transfers = results[0] as List<FundTransfer>;
          _summary = results[1] as FundSummary;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              strokeWidth: 2.5,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCard()),
                  SliverToBoxAdapter(child: _buildListHeader()),
                  _transfers.isEmpty
                      ? const SliverFillRemaining(
                      child: _EmptyState())
                      : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TransferCard(
                            transfer: _transfers[i], index: i),
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B6B44), AppColors.primary, Color(0xFF2ECC8B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 14),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 16),
                ),
                onPressed: () => context.go('/admin/dashboard'),
              ),
              const SizedBox(width: 4),
              Text(
                'تقرير الصناديق',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_transfers.length} تحويل',
                  style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle شهري / سنوي
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ToggleTab(
                    label: 'شهري',
                    icon: Icons.calendar_view_month_rounded,
                    selected: _isMonthly,
                    onTap: () {
                      if (!_isMonthly) {
                        setState(() => _isMonthly = true);
                        _loadData();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _ToggleTab(
                    label: 'سنوي',
                    icon: Icons.calendar_today_rounded,
                    selected: !_isMonthly,
                    onTap: () {
                      if (_isMonthly) {
                        setState(() => _isMonthly = false);
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_isMonthly) ...[
                Expanded(
                  child: _StyledDropdown<int>(
                    label: 'الشهر',
                    value: _selectedMonth,
                    items: List.generate(
                      12,
                          (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_arabicMonths[i],
                            style: GoogleFonts.cairo(fontSize: 13)),
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
              SizedBox(
                width: _isMonthly ? 112 : double.infinity,
                child: _StyledDropdown<int>(
                  label: 'السنة',
                  value: _selectedYear,
                  items: [2024, 2025, 2026]
                      .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text('$y',
                        style: GoogleFonts.cairo(fontSize: 13)),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedYear = v);
                      _loadData();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E42), AppColors.primary],
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
        child: Stack(
          children: [
            Positioned(
              top: -30,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ملخص الفترة',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStatBox(
                        icon: Icons.arrow_downward_rounded,
                        iconBg: const Color(0x3369F0AE),
                        iconColor: const Color(0xFF69F0AE),
                        label: 'المقبوضات',
                        value: s != null
                            ? '\$${s.totalReceivedThisMonth.toStringAsFixed(0)}'
                            : '—',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.white.withOpacity(0.15),
                    ),
                    Expanded(
                      child: _SummaryStatBox(
                        icon: Icons.arrow_upward_rounded,
                        iconBg: const Color(0x33FFB74D),
                        iconColor: const Color(0xFFFFB74D),
                        label: 'المحوّل',
                        value: s != null
                            ? '\$${s.totalTransferredThisMonth.toStringAsFixed(0)}'
                            : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BalanceItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'صندوق التطبيق',
                        value: s != null
                            ? '\$${s.appFundBalance.toStringAsFixed(0)}'
                            : '—',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      _BalanceItem(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'صندوق الفريق التطوعي',
                        value: s != null
                            ? '\$${s.charityFundBalance.toStringAsFixed(0)}'
                            : '—',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF2ECC8B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'سجل التحويلات',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text(
              '${_transfers.length} تحويل',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
            colors: [Color(0xFF1B5E42), AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? Colors.white
                    : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.primarySoft,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
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
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
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
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.cairo(
                  fontSize: 11, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, required this.index});
  final FundTransfer transfer;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E42), AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.swap_horiz_rounded,
                          color: Colors.white, size: 24),
                    ),
                    Positioned(
                      bottom: -1,
                      left: -1,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              transfer.recipientName,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1B5E42), AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '\$${transfer.amount.toStringAsFixed(0)}',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.receipt_outlined,
                            label: transfer.receiptNumber,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: transfer.transferDate,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      if (transfer.note.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFFFE082), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notes_rounded,
                                  size: 12, color: Color(0xFFE65100)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  transfer.note,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    color: const Color(0xFFE65100),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
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
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.cairo(fontSize: 11.5, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primarySoft,
                  AppColors.primarySoft.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            'لا توجد تحويلات',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'لا توجد تحويلات مسجّلة في هذه الفترة',
            style: GoogleFonts.cairo(
                fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}