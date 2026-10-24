// lib/features/subscriber/presentation/screens/subscriber_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';
import 'widgets/year_transition_views.dart';

class SubscriberHomeScreen extends StatefulWidget {
  const SubscriberHomeScreen({super.key});

  @override
  State<SubscriberHomeScreen> createState() => _SubscriberHomeScreenState();
}

class _SubscriberHomeScreenState extends State<SubscriberHomeScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriberRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  UserProfile? _profile;
  bool _isLoading = true;
  final Set<int> _selectedMonths = {};

  // ── بداية سنة جديدة (متأخرات إجبارية / تجديد / تغيير / إيقاف) ──
  YearStatus? _yearStatus;
  bool _actionBusy = false;
  bool _paying = false; // جلسة دفع قيد الإنشاء (يمنع الضغط المزدوج)
  bool _loggingOut = false;

  bool get _isGated {
    final s = _yearStatus?.state;
    return s == YearState.mustPay ||
        s == YearState.choose ||
        s == YearState.stopped;
  }

  // ── العمولة — تُجلب من الـ API ─────────────────────
  double _commissionRate = 0.0; // نسبة مئوية مثل 10.0
  static const double _fixedFee = 0.5;

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
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getUserProfile(),
        _repo.getCommission(),
        _loadYearStatus(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as UserProfile;
          _commissionRate = results[1] as double;
          _yearStatus = results[2] as YearStatus?;
          if (_isGated) _selectedMonths.clear();
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // فشل جلب حالة السنة لا يمنع فتح الشاشة (الخادم يبقى المرجع عند الدفع)
  Future<YearStatus?> _loadYearStatus() async {
    try {
      return await _repo.getYearStatus();
    } catch (_) {
      return null;
    }
  }

  // دفع متأخرات السنوات السابقة بمعرّفات الدفعات (لا بأرقام الأشهر، لاختلاف السنوات)
  Future<void> _payOverdue() async {
    final ys = _yearStatus;
    if (ys == null || ys.overdueIds.isEmpty || _actionBusy) return;

    setState(() => _actionBusy = true);
    try {
      final session = await _repo.initiatePayment(paymentIds: ys.overdueIds);
      if (mounted) context.go('/payment', extra: session);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  // annualAmount == null → تجديد بنفس المبلغ، وإلا تغيير الباقة ثم التجديد
  Future<void> _renewSubscription({double? annualAmount}) async {
    if (_actionBusy) return;

    setState(() => _actionBusy = true);
    try {
      await _repo.renewSubscription(annualAmount: annualAmount);
      if (!mounted) return;
      _showSuccess(annualAmount == null
          ? 'تم تجديد اشتراكك للسنة الجديدة'
          : 'تم تغيير الباقة وتجديد الاشتراك');
      await _loadData();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _stopSubscription() async {
    if (_actionBusy) return;

    setState(() => _actionBusy = true);
    try {
      await _repo.stopSubscription();
      if (!mounted) return;
      _showSuccess('تم إيقاف الاشتراك');
      await _loadData();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _toggleMonth(MonthPaymentInfo month) {
    if (month.status == MonthStatus.paid) return;
    setState(() {
      if (_selectedMonths.contains(month.monthNumber)) {
        _selectedMonths.remove(month.monthNumber);
      } else {
        _selectedMonths.add(month.monthNumber);
      }
    });
  }

  Future<void> _initiatePayment() async {
    // _paying: الضغط المزدوج كان ينشئ جلستي دفع.
    if (_selectedMonths.isEmpty || _paying) return;
    setState(() => _paying = true);

    try {
      final session = await _repo.initiatePayment(
        months: _selectedMonths.toList()..sort(),
      );
      if (mounted) {
        context.go('/payment', extra: session);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// تسجيل الخروج من الشاشات الإجبارية (متأخرات/تجديد) التي لا تصل منها للملف الشخصي.
  Future<void> _logout() async {
    if (_loggingOut) return;
    final ok = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد إنهاء جلستك الحالية؟',
      confirmLabel: 'تسجيل الخروج',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _loggingOut = true;
    await _storage.deleteAll();
    if (mounted) context.go('/login');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cairo()),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
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

  // المبلغ الأصلي بدون رسوم
  double get _selectedBase {
    final sub = _profile?.subscription;
    if (sub == null || _selectedMonths.isEmpty) return 0;
    return _selectedMonths.length * sub.monthlyAmount;
  }

  // العمولة على المبلغ المحدد
  double get _selectedCommission =>
      _selectedBase * (_commissionRate / 100);

  // الرسم الثابت لكل عملية دفع (0.5$ مرة واحدة)
  double get _selectedFixedFee =>
      _selectedMonths.isNotEmpty ? _fixedFee : 0;

  // الإجمالي الفعلي الذي سيُدفع
  double get _selectedTotal =>
      _selectedBase + _selectedCommission + _selectedFixedFee;

  int get _paidCount {
    return _profile?.subscription?.months
        .where((m) => m.status == MonthStatus.paid)
        .length ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary))
            : _profile == null
            ? _buildError()
            : FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildBody(),
          ),
        ),
        floatingActionButton: _selectedMonths.isNotEmpty && !_isGated
            ? _buildPayFAB()
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(
            'تعذّر تحميل البيانات',
            style: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('إعادة المحاولة', style: GoogleFonts.cairo(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ── بداية سنة جديدة: تحجب الشاشة العادية حتى تُحسم ──────
    final ys = _yearStatus;
    if (ys != null && ys.state == YearState.mustPay) {
      return YearMustPayView(
        status: ys,
        commissionRate: _commissionRate,
        fixedFee: _fixedFee,
        busy: _actionBusy,
        onPay: _payOverdue,
        onLogout: _logout,
      );
    }
    if (ys != null &&
        (ys.state == YearState.choose || ys.state == YearState.stopped)) {
      return YearRenewalView(
        status: ys,
        busy: _actionBusy,
        onRenew: () => _renewSubscription(),
        onChange: (v) => _renewSubscription(annualAmount: v),
        onStop: _stopSubscription,
        onLogout: _logout,
      );
    }

    final profile = _profile!;
    final sub = profile.subscription;

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar ───────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.white, size: 20),
              ),
              onPressed: () => context.go('/profile'),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.white, size: 20),
              ),
              onPressed: ()  => context.push('/notifications'),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.primary],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: -30,
                  left: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  right: -20,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                // User info
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً، ${profile.fullName}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  Text(
                                    profile.email,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.white.withOpacity(0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary Card ───────────────────────────
                if (sub != null) ...[
                  _buildSummaryCard(sub),
                  const SizedBox(height: 20),
                ],

                // ── Months Grid Title ──────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'أشهر الاشتراك',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedMonths.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${_selectedMonths.length} محدد',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Months Grid ────────────────────────────
                if (sub != null)
                  _buildMonthsGrid(sub.months)
                else
                  _buildNoSubscription(),

                const SizedBox(height: 8),

                // ── Legend ─────────────────────────────────
                _buildLegend(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(SubscriptionInfo sub) {
    final paidCount = _paidCount;
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              _buildStatItem('المبلغ السنوي', '\$${sub.annualAmount.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded),
              _buildDivider(),
              _buildStatItem('القسط الشهري', '\$${sub.monthlyAmount.toStringAsFixed(2)}', Icons.calendar_month_rounded),
              _buildDivider(),
              _buildStatItem('الأشهر المدفوعة', '$paidCount/12', Icons.check_circle_rounded),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: paidCount / 12,
              backgroundColor: AppColors.primarySoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$paidCount/12 شهراً',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${(paidCount / 12 * 100).round()}%',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
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
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: AppColors.border.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildMonthsGrid(List<MonthPaymentInfo> months) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        return _buildMonthCell(month);
      },
    );
  }

  Widget _buildMonthCell(MonthPaymentInfo month) {
    final isSelected = _selectedMonths.contains(month.monthNumber);
    final isPaid = month.status == MonthStatus.paid;
    final isOverdue = month.status == MonthStatus.overdue;
    final isPending = month.status == MonthStatus.pending;
    final isTappable = isOverdue || isPending;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData statusIcon;
    Color iconColor;

    if (isPaid) {
      bgColor = AppColors.success.withOpacity(0.08);
      borderColor = AppColors.success.withOpacity(0.3);
      textColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      iconColor = AppColors.success;
    } else if (isOverdue) {
      bgColor = isSelected
          ? AppColors.error.withOpacity(0.15)
          : AppColors.errorLight;
      borderColor = isSelected ? AppColors.error : AppColors.error.withOpacity(0.3);
      textColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
      iconColor = AppColors.error;
    } else {
      bgColor = isSelected
          ? AppColors.primarySoft
          : AppColors.white;
      borderColor = isSelected ? AppColors.primary : AppColors.border;
      textColor = isSelected ? AppColors.primary : AppColors.textMuted;
      statusIcon = Icons.schedule_rounded;
      iconColor = isSelected ? AppColors.primary : AppColors.textMuted;
    }

    return GestureDetector(
      onTap: isTappable ? () => _toggleMonth(month) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1.5),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              month.monthName,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (isSelected) ...[
              Text(
                '\$${month.amount.toStringAsFixed(2)}',
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '+ ${_commissionRate.toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 9,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppColors.success, Icons.check_circle_rounded, 'مدفوع'),
        const SizedBox(width: 16),
        _legendItem(AppColors.error, Icons.cancel_rounded, 'متأخر'),
        const SizedBox(width: 16),
        _legendItem(AppColors.textMuted, Icons.schedule_rounded, 'قادم'),
      ],
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildNoSubscription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_membership_rounded, color: AppColors.border, size: 48),
          const SizedBox(height: 12),
          Text(
            'لا يوجد اشتراك نشط',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.go('/subscription-setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('إعداد الاشتراك', style: GoogleFonts.cairo(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPayFAB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent], // أغمق: أبيض 12px عليه ≥ 5.7:1
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _initiatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // السطر الأول: زر الدفع مع الإجمالي
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _paying
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.white,
                      ),
                    )
                        : const Icon(Icons.payment_rounded, color: AppColors.white, size: 20),
                    const SizedBox(width: 8),
                    // Flexible: الخط الكبير/الشاشة الضيقة كان يسبب overflow
                    Flexible(
                      child: Text(
                        'ادفع ${Fmt.money2(_selectedTotal)} — ${Fmt.months(_selectedMonths.length)}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // السطر الثاني: تفاصيل الرسوم
                const SizedBox(height: 3),
                // \u2066…\u2069: يعزل كل رقم (LTR) فلا تنقلب علامات + في السياق العربي
                Text(
                  '\u2066${Fmt.money2(_selectedBase)}\u2069 + \u2066${_commissionRate.toStringAsFixed(0)}%\u2069 عمولة + \u2066${Fmt.money2(_selectedFixedFee)}\u2069 رسم',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.white.withOpacity(0.92),
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