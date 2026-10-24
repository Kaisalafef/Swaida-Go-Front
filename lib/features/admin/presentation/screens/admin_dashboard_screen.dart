// lib/features/admin/presentation/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:swida_go/features/admin/presentation/screens/widgets/admin_ui.dart';
import 'package:swida_go/core/auth/staff_role.dart';

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
  String? _role; // admin | accountant

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    // Entrance animation plays once when the screen opens, so the quick-access
    // links are always reachable even if the API call fails.
    _animController.forward();
    _loadRole();
    _loadData();
  }

  Future<void> _loadRole() async {
    final role = await _storage.read(key: 'user_role');
    if (mounted) setState(() => _role = role);
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
      }
    } catch (e) {
      if (mounted) showAdminSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmLogout() async {
    final ok = await showAdminConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من لوحة الإدارة؟',
      confirmLabel: 'تسجيل الخروج',
    );
    if (ok) await _logout();
  }

  // ── فتح BottomSheet لتعديل العمولة ────────────────────────
  void _showEditCommissionSheet() {
    if (!StaffRole.canEditCommission(_role)) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommissionEditSheet(
        currentValue: _commission?.value,
        onSave: (newValue) async {
          try {
            final updated = await _repo.updateCommission(newValue);
            if (mounted) {
              setState(() => _commission = updated);
              showAdminSnack(
                context,
                'تم تحديث العمولة إلى ${newValue.toStringAsFixed(2)}%',
                error: false,
              );
            }
          } catch (e) {
            if (mounted) showAdminSnack(context, e.toString());
          }
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTokens.bg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, 32 + MediaQuery.of(context).padding.bottom),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatGrid(),
                        const SizedBox(height: 16),
                        _buildCommissionCard(),
                        const SizedBox(height: 28),
                        const AdminSectionTitle(
                          title: 'الوصول السريع',
                          icon: Icons.grid_view_rounded,
                        ),
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

  // ── Header (scrolls away; no empty pinned bar) ────────────
  Widget _buildHeader() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: AdminTokens.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -50,
            start: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AdminTokens.onBrand05,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -40,
            end: 30,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AdminTokens.onBrand05,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 28),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AdminTokens.onBrand20,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminTokens.onBrand15),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('لوحة الإدارة',
                            style: AdminText.heroTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const AdminLiveDot(size: 6),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                  _role == null
                                      ? 'مرحباً بك — ملخص اليوم'
                                      : '${StaffRole.label(_role)} — ملخص اليوم',
                                  style: AdminText.headerSub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AdminIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'الإشعارات',
                    onTap: () => context.push('/notifications'),
                  ),
                  const SizedBox(width: 8),
                  AdminIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'تسجيل الخروج',
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ────────────────────────────────────────────────
  Widget _buildStatGrid() {
    final s = _stats;
    final showSkeleton = _isLoading && s == null;

    final cards = [
      _StatCardData(
        icon: Icons.people_rounded,
        gradient: const [AdminTokens.primaryDeep, AppColors.primary],
        label: 'إجمالي المشتركين',
        value: s != null ? '${s.totalSubscribers}' : '—',
        trend: '+3 هذا الشهر',
        trendIcon: Icons.trending_up_rounded,
      ),
      _StatCardData(
        icon: Icons.account_balance_wallet_rounded,
        gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
        label: 'صندوق التطبيق',
        value: s != null ? AdminFmt.money(s.appFundBalance) : '—',
        trend: 'متاح للتحويل',
        trendIcon: Icons.check_circle_outline_rounded,
      ),
      _StatCardData(
        icon: Icons.volunteer_activism_rounded,
        gradient: const [Color(0xFF4A148C), Color(0xFF8E24AA)],
        label: 'صندوق الفريق التطوعي',
        value: s != null ? AdminFmt.money(s.charityFundBalance) : '—',
        trend: 'الرصيد الحالي',
        trendIcon: Icons.account_balance_rounded,
      ),
      _StatCardData(
        icon: Icons.payments_rounded,
        gradient: const [Color(0xFF1B5E20), AdminTokens.green],
        label: 'دفعات هذا الشهر',
        value: s != null ? AdminFmt.money(s.thisMonthPayments) : '—',
        trend: 'هذا الشهر',
        trendIcon: Icons.calendar_month_rounded,
      ),
    ];

    return AnimatedSwitcher(
      duration: AdminTokens.base,
      child: showSkeleton
          ? const _StatGridSkeleton(key: ValueKey('stats-skeleton'))
          : Column(
        key: const ValueKey('stats-data'),
        children: [
          _statRow(cards[0], cards[1]),
          const SizedBox(height: 12),
          _statRow(cards[2], cards[3]),
        ],
      ),
    );
  }

  Widget _statRow(_StatCardData a, _StatCardData b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _StatCard(data: a)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(data: b)),
        ],
      ),
    );
  }

  // ── بطاقة العمولة ─────────────────────────────────────────
  Widget _buildCommissionCard() {
    const accent = AdminTokens.orange;
    final showSkeleton = _isLoading && _commission == null;
    final canEdit = StaffRole.canEditCommission(_role);

    return AdminCard(
      onTap: canEdit ? _showEditCommissionSheet : null,
      splashColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdminTokens.orangeSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.percent_rounded, color: accent, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نسبة العمولة', style: AdminText.label),
                const SizedBox(height: 2),
                Text('اقتطاع تلقائي من كل دفعة', style: AdminText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (showSkeleton)
            const AdminPulse(
              child: AdminSkeleton(width: 64, height: 30, radius: 10),
            )
          else
            AdminPill(
              label: _commission != null
                  ? '${_commission!.value.toStringAsFixed(2)}%'
                  : '—',
              color: accent,
            ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AdminTokens.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, color: accent, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    final items = [
      _QuickItem(
        icon: Icons.people_alt_rounded,
        iconBg: AppColors.primarySoft,
        accentColor: AppColors.primary,
        title: 'تقرير المشتركين',
        subtitle: 'عرض وتصدير بيانات الاشتراكات',
        onTap: () => context.go('/admin/subscribers-report'),
        badge: '${_stats?.totalSubscribers ?? 0}',
      ),
      _QuickItem(
        icon: Icons.swap_horiz_rounded,
        iconBg: AdminTokens.blueSoft,
        accentColor: AdminTokens.blue,
        title: 'تحويل الصناديق',
        subtitle: 'نقل المبالغ من صندوق التطبيق',
        onTap: () => context.go('/admin/fund-transfer'),
        badge: null,
      ),
      _QuickItem(
        icon: Icons.assessment_rounded,
        iconBg: AdminTokens.purpleSoft,
        accentColor: AdminTokens.purple,
        title: 'تقرير الصناديق',
        subtitle: 'متابعة حركة الأموال والتحويلات',
        onTap: () => context.go('/admin/fund-report'),
        badge: null,
      ),
      _QuickItem(
        icon: Icons.history_edu_rounded,
        iconBg: AdminTokens.greenSoft,
        accentColor: AdminTokens.green,
        title: 'مدفوعات سابقة',
        subtitle: 'تسجيل دفعات مشتركين قبل التطبيق',
        onTap: () => context.go('/admin/historical-payments'),
        badge: null,
      ),
    ];

    // items: 0 تقرير المشتركين | 1 تحويل الصناديق | 2 تقرير الصناديق | 3 مدفوعات سابقة
    // المحاسب يرى التقارير فقط؛ الأدمن يضيف العمليات المالية وإدارة الحسابات.
    final canFinance = StaffRole.canManageFinance(_role);
    final visible = <_QuickItem>[
      items[0],
      if (canFinance) items[1],
      items[2],
      if (canFinance) items[3],
      if (StaffRole.canManageStaff(_role))
        _QuickItem(
          icon: Icons.manage_accounts_rounded,
          iconBg: AdminTokens.selectSoft,
          accentColor: AdminTokens.select,
          title: 'إدارة الحسابات',
          subtitle: 'إنشاء حسابات المحاسبين وتعطيلها',
          onTap: () => context.go('/admin/staff'),
          badge: null,
        ),
    ];

    return Column(
      children: [
        for (final item in visible) _QuickAccessCard(item: item),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COMMISSION EDIT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class _CommissionEditSheet extends StatefulWidget {
  const _CommissionEditSheet({
    required this.currentValue,
    required this.onSave,
  });

  final double? currentValue;
  final Future<void> Function(double) onSave;

  @override
  State<_CommissionEditSheet> createState() => _CommissionEditSheetState();
}

class _CommissionEditSheetState extends State<_CommissionEditSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue != null
          ? widget.currentValue!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
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
    const accent = AdminTokens.orange;

    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdminTokens.orangeSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.percent_rounded,
                          color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تعديل نسبة العمولة', style: AdminText.title),
                          if (widget.currentValue != null)
                            Text(
                              'الحالية: ${widget.currentValue!.toStringAsFixed(2)}%',
                              style: AdminText.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('النسبة الجديدة', style: AdminText.captionBold),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}\.?\d{0,2}')),
                  ],
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _isSaving ? null : _submit(),
                  style: AdminText.number,
                  decoration: adminInputDecoration(
                    hint: '0.00',
                    suffixText: '%',
                    errorText: _error,
                    focusColor: accent,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AdminButton(
                        label: 'إلغاء',
                        outlined: true,
                        color: AppColors.textMuted,
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AdminButton(
                        label: 'حفظ التغييرات',
                        color: accent,
                        loading: _isSaving,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  const _QuickItem({
    required this.icon,
    required this.iconBg,
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

class _StatGridSkeleton extends StatelessWidget {
  const _StatGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row() => const Row(
      children: [
        Expanded(child: AdminSkeleton(height: 148, radius: 20)),
        SizedBox(width: 12),
        Expanded(child: AdminSkeleton(height: 148, radius: 20)),
      ],
    );

    return AdminPulse(
      child: Column(
        children: [row(), const SizedBox(height: 12), row()],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: ${data.value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AdminTokens.rLg),
          boxShadow: AdminTokens.glow(data.gradient.first),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AdminTokens.onBrand20,
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: Colors.white, size: 19),
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(data.value, style: AdminText.statValue),
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: AdminText.onBrandLabel.copyWith(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(data.trendIcon, size: 13, color: AdminTokens.onBrand85),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    data.trend,
                    style: AdminText.onBrandCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      child: AdminCard(
        onTap: item.onTap,
        splashColor: item.accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.accentColor, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AdminText.label),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: AdminText.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.badge != null) ...[
              AdminPill(label: item.badge!, color: item.accentColor),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}