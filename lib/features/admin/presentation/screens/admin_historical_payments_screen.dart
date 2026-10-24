// lib/features/admin/presentation/screens/admin_historical_payments_screen.dart
//
// شاشة: تسجيل المدفوعات التاريخية
// الغرض: تمكين الأدمن من تعليم الأشهر الماضية كمدفوعة للمشتركين القدامى
//        الذين كانوا يدفعون قبل إطلاق التطبيق.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';

import '../../../../core/constants/app_colors.dart';
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
    with SingleTickerProviderStateMixin {
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
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _amountController.dispose();
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
    showAdminSnack(context, msg);
  }

  void _showSuccessDialog() {
    showAdminSuccessDialog(
      context,
      title: 'تم الحفظ بنجاح',
      message: 'تم تسجيل المدفوعات التاريخية\nوتحديث رصيد صندوق التطبيق.',
      buttonLabel: 'حسناً',
    );
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTokens.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AdminTokens.base,
              child: _selected == null
                  ? KeyedSubtree(
                key: const ValueKey('picker'),
                child: _buildSubscriberPicker(),
              )
                  : KeyedSubtree(
                key: const ValueKey('editor'),
                child: _buildPaymentEditor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return AdminHeaderBar(
      title: _selected == null ? 'تسجيل مدفوعات سابقة' : _selected!.fullName,
      subtitle: _selected?.phone,
      trailing: _selected == null
          ? null
          : AdminHeaderBadge(
          '${AdminFmt.money(_selected!.annualAmount)} / سنة'),
      onBack: () {
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
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AdminTokens.rMd),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  style: AdminText.body.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),

        // ── Search ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            style: AdminText.body,
            decoration: adminInputDecoration(
              hint: 'بحث بالاسم أو رقم الهاتف…',
              prefixIcon: Icons.search_rounded,
              fillColor: Colors.white,
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                tooltip: 'مسح البحث',
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.textMuted,
                onPressed: _searchCtrl.clear,
              ),
            ),
          ),
        ),

        // ── List ─────────────────────────────────────────
        Expanded(
          child: _loadingSubscribers
              ? const _PickerSkeleton()
              : _filtered.isEmpty
              ? const AdminEmptyState(
            icon: Icons.search_off_rounded,
            title: 'لا توجد نتائج',
            message: 'جرّب البحث باسم أو رقم هاتف آخر',
          )
              : ListView.builder(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) => _SubscriberTile(
              key: ValueKey(_filtered[i].id),
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
                ? const _MonthsSkeleton()
                : _buildMonthsSection(),
          ),

          // ── Bottom Panel ──────────────────────────────
          AnimatedSize(
            duration: AdminTokens.base,
            curve: AdminTokens.curve,
            alignment: Alignment.bottomCenter,
            child: _totalSelectedMonths > 0
                ? _buildSavePanel()
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthsSection() {
    final months = _serverMonths[_activeYear];
    if (months == null) {
      return Center(
        child: Text('اضغط على السنة لتحميل البيانات',
            style: AdminText.bodyMuted),
      );
    }

    final yearSelected = _selections[_activeYear] ?? {};
    final alreadyPaid = months.where((m) => m.status == 'paid').length;
    final canSelectAll = months.any((m) => m.status != 'paid');

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row: status chips + select all
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminPill(
                label: 'مدفوع: $alreadyPaid',
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
              ),
              AdminPill(
                label: 'محدد: ${yearSelected.length}',
                color: AdminTokens.select,
                icon: Icons.radio_button_checked_rounded,
              ),
              if (canSelectAll)
                _SmallButton(
                  label: 'تحديد الكل',
                  icon: Icons.select_all_rounded,
                  onTap: () => _selectAllForYear(_activeYear),
                ),
              if (yearSelected.isNotEmpty)
                _SmallButton(
                  label: 'إلغاء',
                  icon: Icons.deselect_rounded,
                  color: AppColors.error,
                  onTap: () => _clearYearSelection(_activeYear),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Months Grid (3 × 4) – fixed row height, no aspect-ratio overflow
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: months.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 68,
            ),
            itemBuilder: (ctx, i) {
              final m = months[i];
              return _MonthCell(
                monthName: _arabicMonths[m.monthNumber - 1],
                status: m.status,
                isSelected: yearSelected.contains(m.monthNumber),
                onTap: () =>
                    _toggleMonth(_activeYear, m.monthNumber, m.status),
              );
            },
          ),

          const SizedBox(height: 20),
          AdminCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminSectionTitle(
                  title: 'تفاصيل إضافية',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  style: AdminText.body,
                  decoration: adminInputDecoration(
                    label: 'المبلغ الشهري لهذا السجل (اختياري)',
                    hint: 'مثلاً: 12.5',
                    prefixIcon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style: AdminText.body,
                  decoration: adminInputDecoration(
                    label: 'ملاحظة (اختياري)',
                    hint: 'مثال: مشترك قبل إطلاق التطبيق',
                    prefixIcon: Icons.notes_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavePanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SummaryBadge(
                label: 'أشهر محددة',
                value: '$_totalSelectedMonths',
                icon: Icons.calendar_month_rounded,
                color: AdminTokens.select,
              ),
              const SizedBox(width: 12),
              _SummaryBadge(
                label: 'المبلغ الإجمالي',
                value: AdminFmt.money(_totalAmount, decimals: 2),
                icon: Icons.attach_money_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminButton(
            label: _saving ? 'جارٍ الحفظ…' : 'حفظ المدفوعات المحددة',
            icon: Icons.save_rounded,
            loading: _saving,
            height: 52,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) =>
        const AdminSkeleton(height: 72, radius: AdminTokens.rMd),
      ),
    );
  }
}

class _MonthsSkeleton extends StatelessWidget {
  const _MonthsSkeleton();

  @override
  Widget build(BuildContext context) {
    return AdminPulse(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 68,
        ),
        itemBuilder: (_, __) => const AdminSkeleton(radius: AdminTokens.rSm),
      ),
    );
  }
}

class _SubscriberTile extends StatelessWidget {
  const _SubscriberTile({
    super.key,
    required this.subscriber,
    required this.onTap,
  });
  final _SubscriberSimple subscriber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = subscriber.hasSubscription;

    return AdminCard(
      margin: const EdgeInsets.only(top: 10),
      radius: AdminTokens.rMd,
      padding: const EdgeInsets.all(14),
      onTap: active ? onTap : null,
      splashColor: AppColors.primary,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: active
                  ? AdminTokens.heroGradient
                  : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade300]),
              shape: BoxShape.circle,
            ),
            child: Text(
              subscriber.fullName.isNotEmpty ? subscriber.fullName[0] : '?',
              style: AdminText.title.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscriber.fullName,
                  style: active
                      ? AdminText.label
                      : AdminText.label.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subscriber.phone, style: AdminText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (active) ...[
            Text(
              '${AdminFmt.money(subscriber.annualAmount)} / سنة',
              style: AdminText.captionBold.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ] else
            const AdminPill(label: 'بدون اشتراك', color: AppColors.textMuted),
        ],
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
      height: 60,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final y = years[i];
          final active = y == activeYear;
          final count = selectionCount(y);

          return Semantics(
            button: true,
            selected: active,
            label: 'سنة $y',
            child: Material(
              color: active ? AppColors.primary : Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: StadiumBorder(
                side: BorderSide(
                  color: active
                      ? AppColors.primary
                      : AppColors.border.withOpacity(0.8),
                ),
              ),
              child: InkWell(
                onTap: () => onYearSelected(y),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$y',
                        style: AdminText.label.copyWith(
                          color: active ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: active
                                ? AdminTokens.onBrand20
                                : AdminTokens.select,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: AdminText.captionBold
                                  .copyWith(color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),
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
    IconData? icon;
    Color iconColor = AppColors.textMuted;
    String stateLabel;

    if (isPaid) {
      bg = AdminTokens.paidBg;
      border = AdminTokens.paidBorder;
      textColor = AdminTokens.paidFg;
      icon = Icons.check_circle_rounded;
      iconColor = AdminTokens.green;
      stateLabel = 'مدفوع';
    } else if (isSelected) {
      bg = AdminTokens.selectSoft;
      border = AdminTokens.select;
      textColor = const Color(0xFF1A56A8);
      icon = Icons.radio_button_checked_rounded;
      iconColor = AdminTokens.select;
      stateLabel = 'محدد';
    } else if (isOverdue) {
      bg = AdminTokens.overdueBg;
      border = AdminTokens.overdueBorder;
      textColor = AppColors.error;
      icon = Icons.warning_amber_rounded;
      iconColor = AppColors.error;
      stateLabel = 'متأخر';
    } else {
      bg = AdminTokens.pendingBg;
      border = AppColors.border;
      textColor = AppColors.textMuted;
      icon = null;
      stateLabel = 'غير مدفوع';
    }

    return Semantics(
      button: !isPaid,
      selected: isSelected,
      enabled: !isPaid,
      label: '$monthName، $stateLabel',
      excludeSemantics: true,
      onTap: isPaid ? null : onTap,
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        curve: AdminTokens.curve,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AdminTokens.rSm),
          border: Border.all(color: border, width: isSelected ? 1.8 : 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AdminTokens.rSm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isPaid ? null : onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(height: 3),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    monthName,
                    style: AdminText.body.copyWith(
                      fontWeight: isSelected || isPaid
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: textColor,
                    ),
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
    return Material(
      color: color.withOpacity(0.10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: AdminText.captionBold.copyWith(color: color)),
              ],
            ),
          ),
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
          borderRadius: BorderRadius.circular(AdminTokens.rSm),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AdminText.caption),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(value,
                        style: AdminText.label
                            .copyWith(fontSize: 16, color: color)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}