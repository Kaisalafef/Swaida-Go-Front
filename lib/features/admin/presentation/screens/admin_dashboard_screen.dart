// lib/features/admin/presentation/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  DashboardStats? _stats;
  CommissionSetting? _commission;
  bool _isLoading = true;

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
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
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
        _repo.getDashboardStats(),
        _repo.getCommission(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as DashboardStats;
          _commission = results[1] as CommissionSetting;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) context.go('/login');
  }

  // ── فتح BottomSheet لتعديل العمولة ────────────────────────
  void _showEditCommissionSheet() {
    final controller = TextEditingController(
      text: _commission != null
          ? _commission!.value.toStringAsFixed(2)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommissionEditSheet(
        controller: controller,
        currentValue: _commission?.value,
        onSave: (newValue) async {
          try {
            final updated = await _repo.updateCommission(newValue);
            if (mounted) {
              setState(() => _commission = updated);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✓ تم تحديث العمولة إلى ${newValue.toStringAsFixed(2)}%',
                    style: GoogleFonts.cairo()),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(e.toString(), style: GoogleFonts.cairo()),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatGrid(),
                        const SizedBox(height: 16),
                        _buildCommissionCard(),
                        const SizedBox(height: 28),
                        _buildSectionHeader(
                            'الوصول السريع', Icons.grid_view_rounded),
                        const SizedBox(height: 14),
                        _buildQuickAccess(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap:() => context.push('/notifications'),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B6B44),
                    AppColors.primary,
                    Color(0xFF2ECC8B)
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              right: 30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'لوحة الإدارة',
                              style: GoogleFonts.cairo(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF69F0AE),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'مرحباً بك — ملخص اليوم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
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
        Icon(icon, color: AppColors.primary, size: 17),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    final s = _stats;

    final cards = [
      _StatCardData(
        icon: Icons.people_rounded,
        gradient: const [Color(0xFF1B5E42), AppColors.primary],
        label: 'إجمالي المشتركين',
        value: s != null ? '${s.totalSubscribers}' : '—',
        trend: '+3 هذا الشهر',
        trendIcon: Icons.trending_up_rounded,
      ),
      _StatCardData(
        icon: Icons.account_balance_wallet_rounded,
        gradient: const [Color(0xFF1565C0), Color(0xFF1E88E5)],
        label: 'صندوق التطبيق',
        value: s != null ? '\$${s.appFundBalance.toStringAsFixed(0)}' : '—',
        trend: 'متاح للتحويل',
        trendIcon: Icons.check_circle_outline_rounded,
      ),
      _StatCardData(
        icon: Icons.volunteer_activism_rounded,
        gradient: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
        label: 'صندوق الفريق التطوعي',
        value:
        s != null ? '\$${s.charityFundBalance.toStringAsFixed(0)}' : '—',
        trend: 'الرصيد الحالي',
        trendIcon: Icons.account_balance_rounded,
      ),
      _StatCardData(
        icon: Icons.payments_rounded,
        gradient: const [Color(0xFF2E7D32), Color(0xFF43A047)],
        label: 'دفعات هذا الشهر',
        value:
        s != null ? '\$${s.thisMonthPayments.toStringAsFixed(0)}' : '—',
        trend: 'هذا الشهر',
        trendIcon: Icons.calendar_month_rounded,
      ),
    ];

    if (_isLoading) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: List.generate(4, (_) => _ShimmerCard()),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }

  // ── بطاقة العمولة ─────────────────────────────────────────
  Widget _buildCommissionCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withOpacity(0.07),
      elevation: 2,
      child: InkWell(
        onTap: _showEditCommissionSheet,
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFFE65100).withOpacity(0.06),
        highlightColor: const Color(0xFFE65100).withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // أيقونة العمولة
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.percent_rounded,
                    color: Color(0xFFE65100), size: 23),
              ),
              const SizedBox(width: 14),
              // النص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة العمولة',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اقتطاع تلقائي من كل دفعة',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // القيمة الحالية
              if (_isLoading)
                Container(
                  width: 60,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              else
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE65100).withOpacity(0.2)),
                  ),
                  child: Text(
                    _commission != null
                        ? '${_commission!.value.toStringAsFixed(2)}%'
                        : '—',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // سهم التعديل
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFFE65100).withOpacity(0.7),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    final items = [
      _QuickItem(
        icon: Icons.people_alt_rounded,
        iconBg: AppColors.primarySoft,
        iconColor: AppColors.primary,
        accentColor: AppColors.primary,
        title: 'تقرير المشتركين',
        subtitle: 'عرض وتصدير بيانات الاشتراكات',
        onTap: () => context.go('/admin/subscribers-report'),
        badge: '${_stats?.totalSubscribers ?? 0}',
      ),
      _QuickItem(
        icon: Icons.swap_horiz_rounded,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        accentColor: const Color(0xFF1565C0),
        title: 'تحويل الصناديق',
        subtitle: 'نقل المبالغ من صندوق التطبيق',
        onTap: () => context.go('/admin/fund-transfer'),
        badge: null,
      ),
      _QuickItem(
        icon: Icons.assessment_rounded,
        iconBg: const Color(0xFFF3E5F5),
        iconColor: const Color(0xFF6A1B9A),
        accentColor: const Color(0xFF6A1B9A),
        title: 'تقرير الصناديق',
        subtitle: 'متابعة حركة الأموال والتحويلات',
        onTap: () => context.go('/admin/fund-report'),
        badge: null,
      ),
      _QuickItem(
        icon: Icons.history_edu_rounded,
        iconBg: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
        accentColor: const Color(0xFF2E7D32),
        title: 'مدفوعات سابقة',
        subtitle: 'تسجيل دفعات مشتركين قبل التطبيق',
        onTap: () => context.go('/admin/historical-payments'),
        badge: null,
      ),

    ];

    return Column(
      children: items.map((item) => _QuickAccessCard(item: item)).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COMMISSION EDIT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class _CommissionEditSheet extends StatefulWidget {
  const _CommissionEditSheet({
    required this.controller,
    required this.currentValue,
    required this.onSave,
  });

  final TextEditingController controller;
  final double? currentValue;
  final Future<void> Function(double) onSave;

  @override
  State<_CommissionEditSheet> createState() => _CommissionEditSheetState();
}

class _CommissionEditSheetState extends State<_CommissionEditSheet> {
  bool _isSaving = false;
  String? _error;

  Future<void> _submit() async {
    final raw = widget.controller.text.trim();
    final value = double.tryParse(raw);

    if (value == null || value < 0 || value > 100) {
      setState(() => _error = 'أدخل قيمة صحيحة بين 0 و 100');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(value);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.percent_rounded,
                    color: Color(0xFFE65100), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعديل نسبة العمولة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (widget.currentValue != null)
                    Text(
                      'الحالية: ${widget.currentValue!.toStringAsFixed(2)}%',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // حقل الإدخال
          Text(
            'النسبة الجديدة',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
            ],
            autofocus: true,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              suffixText: '%',
              suffixStyle: GoogleFonts.cairo(
                fontSize: 18,
                color: AppColors.textMuted,
              ),
              hintText: '0.00',
              hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
              errorText: _error,
              errorStyle: GoogleFonts.cairo(fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: Color(0xFFE65100), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // أزرار
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                  _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    'حفظ التغييرات',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════

class _StatCardData {
  final IconData icon;
  final List<Color> gradient;
  final String label;
  final String value;
  final String trend;
  final IconData trendIcon;

  const _StatCardData({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.value,
    required this.trend,
    required this.trendIcon,
  });
}

class _QuickItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  const _QuickItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}

// ═══════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color:
          Color.lerp(Colors.grey.shade200, Colors.grey.shade100, _anim.value),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            left: -12,
            child: Container(
              width: 60,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 38,
                    height: 12,
                    child: Icon(data.icon, color: Colors.white, size: 20),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(data.trendIcon,
                            size: 10, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(width: 3),
                        Text(
                          data.trend,
                          style: GoogleFonts.cairo(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.value,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.75),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.item});
  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        shadowColor: Colors.black.withOpacity(0.06),
        elevation: 2,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: item.accentColor.withOpacity(0.06),
          highlightColor: item.accentColor.withOpacity(0.03),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: item.accentColor.withOpacity(0.2), width: 1),
                    ),
                    child: Text(
                      item.badge!,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: item.iconColor.withOpacity(0.7),
                    size: 12,
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