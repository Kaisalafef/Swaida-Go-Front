// lib/features/admin/presentation/screens/admin_historical_payments_screen.dart
//
// شاشة: تسجيل المدفوعات التاريخية
// الغرض: تمكين الأدمن من تعليم الأشهر الماضية كمدفوعة للمشتركين القدامى
//        الذين كانوا يدفعون قبل إطلاق التطبيق.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

// ══════════════════════════════════════════════════════════════
// MODELS  (مؤقتة داخل الملف — يمكن نقلها إلى admin_models.dart)
// ══════════════════════════════════════════════════════════════

class _SubscriberSimple {
  final int id;
  final String fullName;
  final String phone;
  final int? subscriptionId;
  final double annualAmount;
  final double monthlyAmount;
  final bool hasSubscription;

  const _SubscriberSimple({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.subscriptionId,
    required this.annualAmount,
    required this.monthlyAmount,
    required this.hasSubscription,
  });

  factory _SubscriberSimple.fromJson(Map<String, dynamic> j) =>
      _SubscriberSimple(
        id: (j['id'] as num).toInt(),
        fullName: j['full_name'] as String,
        phone: j['phone'] as String,
        subscriptionId: j['subscription_id'] != null
            ? (j['subscription_id'] as num).toInt()
            : null,
        annualAmount: (j['annual_amount'] as num).toDouble(),
        monthlyAmount: (j['monthly_amount'] as num).toDouble(),
        hasSubscription: j['has_subscription'] == true,
      );
}

class _MonthEntry {
  final int monthNumber;
  final String status; // 'paid' | 'overdue' | 'pending' | 'no_record'
  final double amount;

  const _MonthEntry({
    required this.monthNumber,
    required this.status,
    required this.amount,
  });
}

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════

class AdminHistoricalPaymentsScreen extends StatefulWidget {
  const AdminHistoricalPaymentsScreen({super.key});

  @override
  State<AdminHistoricalPaymentsScreen> createState() =>
      _AdminHistoricalPaymentsScreenState();
}

class _AdminHistoricalPaymentsScreenState
    extends State<AdminHistoricalPaymentsScreen>
    with TickerProviderStateMixin {
  final _repo = AdminRepository();

  // ── State ─────────────────────────────────────────────────
  List<_SubscriberSimple> _allSubscribers = [];
  List<_SubscriberSimple> _filtered = [];
  _SubscriberSimple? _selected;
  final TextEditingController _amountController = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loadingSubscribers = true;
  bool _loadingMonths = false;
  bool _saving = false;

  // سنوات متاحة للاختيار (من 2020 حتى السنة الحالية)
  late final List<int> _availableYears;
  int _activeYear = DateTime.now().year;

  // خريطة: year → List<_MonthEntry> (الحالة من السيرفر)
  final Map<int, List<_MonthEntry>> _serverMonths = {};

  // الاختيارات التي سيضغطها الأدمن: year → Set<int months>
  final Map<int, Set<int>> _selections = {};

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل',
    'مايو', 'يونيو', 'يوليو', 'أغسطس',
    'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  // ── Init ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().year;
    _availableYears = List.generate(now - 2019, (i) => now - i);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadSubscribers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────
  Future<void> _loadSubscribers() async {
    setState(() => _loadingSubscribers = true);
    try {
      final resp = await _repo.dio.get('/admin/subscribers-list');
      final list = (resp.data['data'] as List)
          .map((e) => _SubscriberSimple.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _allSubscribers = list;
          _filtered = list;
        });
      }
    } catch (e) {
      _showError('تعذّر تحميل قائمة المشتركين');
    } finally {
      if (mounted) setState(() => _loadingSubscribers = false);
    }
  }

  Future<void> _loadMonthsForYear(int year) async {
    if (_selected == null) return;
    if (_serverMonths.containsKey(year)) return; // مُحمَّل مسبقاً

    setState(() => _loadingMonths = true);
    try {
      final resp = await _repo.dio.get(
        '/admin/subscriber-payments/${_selected!.id}',
        queryParameters: {'year': year},
      );
      final rawMonths = resp.data['months'] as List;
      _serverMonths[year] = rawMonths
          .map((m) => _MonthEntry(
        monthNumber: (m['month_number'] as num).toInt(),
        status: m['status'] as String,
        amount: (m['amount'] as num).toDouble(),
      ))
          .toList();
    } catch (e) {
      // إذا فشل التحميل، نُنشئ أشهراً فارغة (no_record)
      _serverMonths[year] = List.generate(
        12,
            (i) => _MonthEntry(
          monthNumber: i + 1,
          status: 'no_record',
          amount: _selected!.monthlyAmount,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMonths = false);
    }
  }

  // ── Search ────────────────────────────────────────────────
  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allSubscribers
          : _allSubscribers.where((s) =>
      s.fullName.toLowerCase().contains(q) ||
          s.phone.contains(q)).toList();
    });
  }

  // ── Select Subscriber ─────────────────────────────────────
  Future<void> _selectSubscriber(_SubscriberSimple sub) async {
    setState(() {
      _selected = sub;
      _serverMonths.clear();
      _selections.clear();
      _activeYear = DateTime.now().year;
    });
    _fadeCtrl.forward(from: 0);
    await _loadMonthsForYear(_activeYear);
  }

  // ── Toggle Month Selection ────────────────────────────────
  void _toggleMonth(int year, int month, String serverStatus) {
    // لا نسمح بتغيير الأشهر المدفوعة فعلاً
    if (serverStatus == 'paid') return;

    setState(() {
      _selections[year] ??= {};
      if (_selections[year]!.contains(month)) {
        _selections[year]!.remove(month);
      } else {
        _selections[year]!.add(month);
      }
    });
  }

  void _selectAllForYear(int year) {
    final months = _serverMonths[year];
    if (months == null) return;
    setState(() {
      _selections[year] = months
          .where((m) => m.status != 'paid')
          .map((m) => m.monthNumber)
          .toSet();
    });
  }

  void _clearYearSelection(int year) {
    setState(() => _selections[year]?.clear());
  }

  int get _totalSelectedMonths =>
      _selections.values.fold(0, (sum, set) => sum + set.length);

  double get _totalAmount {
    double total = 0;
    for (final entry in _selections.entries) {
      final year = entry.key;
      final months = entry.value;
      for (final m in months) {
        final serverEntry = _serverMonths[year]
            ?.firstWhere((e) => e.monthNumber == m,
            orElse: () => _MonthEntry(
                monthNumber: m,
                status: 'no_record',
                amount: _selected!.monthlyAmount));
        total += serverEntry?.amount ?? _selected!.monthlyAmount;
      }
    }
    return total;
  }

  // ── Save ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selected == null || _totalSelectedMonths == 0) return;

    // بناء entries: قائمة {year, months} لكل سنة تحتوي أشهرًا محددة
    final entries = <Map<String, dynamic>>[];
    for (final e in _selections.entries) {
      if (e.value.isNotEmpty) {
        entries.add({'year': e.key, 'months': e.value.toList()});
      }
    }

    if (entries.isEmpty) return;

    setState(() => _saving = true);
    try {
      final customAmount = double.tryParse(_amountController.text.trim());

      await _repo.dio.post('/admin/mark-historical-paid', data: {
        'user_id': _selected!.id,
        'entries': entries,
        'custom_amount': customAmount,
        'note': _noteCtrl.text.trim().isNotEmpty
            ? _noteCtrl.text.trim()
            : 'تسجيل يدوي بواسطة المدير – مشترك قبل إطلاق التطبيق',
      });

      _serverMonths.clear();
      _selections.clear();
      await _loadMonthsForYear(_activeYear);

      if (mounted) _showSuccessDialog();
    } catch (e) {
      debugPrint('=== FULL ERROR ===');
      if (e is DioException && e.response?.data is Map) {
        debugPrint('SERVER ERROR: ${e.response?.data['error']}');
      }
      _showError('فشل حفظ المدفوعات. يرجى المحاولة مجدداً.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  // ── UI Helpers ────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B6B44), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 18, offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              Text('تم الحفظ بنجاح',
                  style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent)),
              const SizedBox(height: 8),
              Text(
                'تم تسجيل المدفوعات التاريخية\nوتحديث رصيد صندوق التطبيق.',
                style: GoogleFonts.cairo(
                    fontSize: 13, color: AppColors.textMuted, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('حسناً',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _selected == null
                ? _buildSubscriberPicker()
                : _buildPaymentEditor(),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 14),
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
                onPressed: () {
                  if (_selected != null) {
                    setState(() {
                      _selected = null;
                      _serverMonths.clear();
                      _selections.clear();
                    });
                  } else {
                    context.go('/admin/dashboard');
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selected == null
                          ? 'تسجيل مدفوعات سابقة'
                          : _selected!.fullName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_selected != null)
                      Text(
                        _selected!.phone,
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8)),
                      ),
                  ],
                ),
              ),
              if (_selected != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '\$${_selected!.annualAmount.toStringAsFixed(0)}/سنة',
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

  // ══════════════════════════════════════════════════════════
  // STEP 1 – Subscriber Picker
  // ══════════════════════════════════════════════════════════
  Widget _buildSubscriberPicker() {
    return Column(
      children: [
        // ── Info Banner ──────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1B6B44).withOpacity(0.08),
                AppColors.primary.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_edu_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'اختر مشتركاً لتسجيل دفعاته السابقة قبل إطلاق التطبيق.',
                  style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.accent,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),

        // ── Search ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رقم الهاتف…',
              hintStyle:
              GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            style: GoogleFonts.cairo(fontSize: 14),
          ),
        ),

        const SizedBox(height: 10),

        // ── List ─────────────────────────────────────────
        Expanded(
          child: _loadingSubscribers
              ? const Center(
              child:
              CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
              ? Center(
            child: Text('لا توجد نتائج',
                style: GoogleFonts.cairo(
                    color: AppColors.textMuted, fontSize: 14)),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) =>
                _SubscriberTile(
                  subscriber: _filtered[i],
                  onTap: () => _selectSubscriber(_filtered[i]),
                ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // STEP 2 – Payment Editor
  // ══════════════════════════════════════════════════════════
  Widget _buildPaymentEditor() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          // ── Year Tabs ─────────────────────────────────
          _YearTabBar(
            years: _availableYears,
            activeYear: _activeYear,
            selectionCount: (y) => _selections[y]?.length ?? 0,
            onYearSelected: (y) async {
              setState(() => _activeYear = y);
              await _loadMonthsForYear(y);
            },
          ),

          // ── Months Grid ───────────────────────────────
          Expanded(
            child: _loadingMonths
                ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
                : _buildMonthsSection(),
          ),

          // ── Bottom Panel ──────────────────────────────
          if (_totalSelectedMonths > 0) _buildSavePanel(),
        ],
      ),
    );
  }

  Widget _buildMonthsSection() {
    final months = _serverMonths[_activeYear];
    if (months == null) {
      return Center(
        child: Text('اضغط على السنة لتحميل البيانات',
            style: GoogleFonts.cairo(color: AppColors.textMuted)),
      );
    }

    final yearSelected = _selections[_activeYear] ?? {};
    final alreadyPaid = months.where((m) => m.status == 'paid').length;
    final canSelectAll = months.any((m) => m.status != 'paid');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: status chips + select all
          Row(
            children: [
              _StatusChip(
                  label: 'مدفوع', count: alreadyPaid, color: AppColors.success),
              const SizedBox(width: 8),
              _StatusChip(
                label: 'محدد',
                count: yearSelected.length,
                color: const Color(0xFF1A73E8),
              ),
              const Spacer(),
              if (canSelectAll)
                _SmallButton(
                  label: 'تحديد الكل',
                  icon: Icons.select_all_rounded,
                  onTap: () => _selectAllForYear(_activeYear),
                ),
              if (yearSelected.isNotEmpty) ...[
                const SizedBox(width: 6),
                _SmallButton(
                  label: 'إلغاء',
                  icon: Icons.deselect_rounded,
                  color: AppColors.error,
                  onTap: () => _clearYearSelection(_activeYear),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Months Grid (4 × 3)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: months.map((m) {
              final isSelected = yearSelected.contains(m.monthNumber);
              return _MonthCell(
                monthName: _arabicMonths[m.monthNumber - 1],
                status: m.status,
                isSelected: isSelected,
                onTap: () =>
                    _toggleMonth(_activeYear, m.monthNumber, m.status),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          // داخل الـ build أو مكان عرض المدخلات
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'المبلغ الشهري لهذا السجل (اختياري)',
              hintText: 'مثلاً: 12.5',
              prefixIcon: Icon(Icons.money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Note field
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'ملاحظة (اختياري) — مثال: مشترك قبل إطلاق التطبيق',
              hintStyle:
              GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: AppColors.border.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            style: GoogleFonts.cairo(fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSavePanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _SummaryBadge(
                  label: 'أشهر محددة',
                  value: '$_totalSelectedMonths',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF1A73E8)),
              const SizedBox(width: 16),
              _SummaryBadge(
                  label: 'المبلغ الإجمالي',
                  value: '\$${_totalAmount.toStringAsFixed(2)}',
                  icon: Icons.attach_money_rounded,
                  color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(
                _saving ? 'جارٍ الحفظ…' : 'حفظ المدفوعات المحددة',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════

class _SubscriberTile extends StatelessWidget {
  const _SubscriberTile(
      {required this.subscriber, required this.onTap});
  final _SubscriberSimple subscriber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: subscriber.hasSubscription ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: subscriber.hasSubscription
                    ? const LinearGradient(
                  colors: [Color(0xFF1B6B44), AppColors.primary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
                    : LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade200]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  subscriber.fullName.isNotEmpty
                      ? subscriber.fullName[0]
                      : '?',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subscriber.fullName,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: subscriber.hasSubscription
                              ? AppColors.textDark
                              : AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(subscriber.phone,
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (subscriber.hasSubscription) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${subscriber.annualAmount.toStringAsFixed(0)}/سنة',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary, size: 20),
                ],
              ),
            ] else
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('بدون اشتراك',
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: AppColors.textMuted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _YearTabBar extends StatelessWidget {
  const _YearTabBar({
    required this.years,
    required this.activeYear,
    required this.selectionCount,
    required this.onYearSelected,
  });
  final List<int> years;
  final int activeYear;
  final int Function(int year) selectionCount;
  final ValueChanged<int> onYearSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final y = years[i];
          final active = y == activeYear;
          final count = selectionCount(y);
          return GestureDetector(
            onTap: () => onYearSelected(y),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? AppColors.primary
                      : AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$y',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight:
                      active ? FontWeight.bold : FontWeight.w500,
                      color: active ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFF1A73E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.monthName,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });
  final String monthName;
  final String status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'paid';
    final isOverdue = status == 'overdue';

    Color bg;
    Color border;
    Color textColor;
    Widget? icon;

    if (isPaid) {
      bg = const Color(0xFFB9F6CA);
      border = const Color(0xFF66BB6A);
      textColor = const Color(0xFF1B5E20);
      icon = const Icon(Icons.check_circle_rounded,
          size: 14, color: Color(0xFF2E7D32));
    } else if (isSelected) {
      bg = const Color(0xFFE3F0FF);
      border = const Color(0xFF1A73E8);
      textColor = const Color(0xFF1A56A8);
      icon = const Icon(Icons.radio_button_checked_rounded,
          size: 14, color: Color(0xFF1A73E8));
    } else if (isOverdue) {
      bg = const Color(0xFFFFEBEE);
      border = const Color(0xFFEF9A9A);
      textColor = AppColors.error;
      icon = const Icon(Icons.warning_amber_rounded,
          size: 13, color: AppColors.error);
    } else {
      bg = const Color(0xFFF5F5F5);
      border = AppColors.border;
      textColor = AppColors.textMuted;
      icon = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: border,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFF1A73E8).withOpacity(0.18),
              blurRadius: 8, offset: const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon, const SizedBox(height: 3)],
            Text(monthName,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight:
                    isSelected || isPaid ? FontWeight.bold : FontWeight.w500,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: AppColors.textMuted)),
                Text(value,
                    style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}