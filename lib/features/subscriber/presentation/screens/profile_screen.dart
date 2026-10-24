// lib/features/subscriber/presentation/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../data/models/subscriber_models.dart';
import '../../data/repositories/subscriber_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SubscriberRepository();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isLoadingHistory = false;

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
    _loadProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _repo.getUserProfile();
      if (mounted) {
        setState(() => _profile = profile);
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditProfile() async {
    await context.push('/edit-profile');
    if (mounted) _loadProfile(); // يعكس أي تعديل (الاسم، الهاتف، طلب بريد معلّق)
  }

  Future<void> _openChangePackage() async {
    final changed = await context.push<bool>('/change-package');
    if (changed == true && mounted) {
      _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم تغيير الباقة بنجاح', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  bool _loggingOut = false;

  /// كان الخروج فورياً بلمسة واحدة (الأيقونة بجوار الرجوع + زر المنطقة الحمراء).
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cairo()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatMonths(List<int> months) {
    return months.map(Fmt.month).join('، ');
  }

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
            child: _buildBody(_profile!),
          ),
        ),
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
          Text('تعذّر تحميل البيانات',
              style: GoogleFonts.cairo(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('إعادة المحاولة',
                style: GoogleFonts.cairo(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(UserProfile user) {
    final sub = user.subscription;
    final history = user.paymentHistory;
    final paidCount = _paidCount;

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar ─────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.white, size: 20),
            ),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.white, size: 18),
              ),
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient
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
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  right: -30,
                  child: Container(
                    width: 220,
                    height: 220,
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
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  Text(
                                    user.email,
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: AppColors.white.withOpacity(0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'مشترك منذ ${user.joinedAt}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: AppColors.white.withOpacity(0.9),
                                      ),
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

        // ── Content ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // A) Subscription Details Card
                if (sub != null) ...[
                  _SectionCard(
                    title: 'تفاصيل الاشتراك',
                    icon: Icons.card_membership_rounded,
                    child: Column(
                      children: [
                        _InfoRow(label: 'المبلغ السنوي', value: '\$${sub.annualAmount.toStringAsFixed(2)}'),
                        _InfoRow(label: 'القسط الشهري', value: '\$${sub.monthlyAmount.toStringAsFixed(2)}'),
                        _InfoRow(label: 'تاريخ البدء', value: sub.startDate),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: paidCount / 12,
                            backgroundColor: AppColors.primarySoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                            minHeight: 6,
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
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openChangePackage,
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(
                              'تعديل الباقة (زيادة أو تقليل)',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // B) Personal Info Card
                _SectionCard(
                  title: 'معلومات الحساب',
                  icon: Icons.person_outline_rounded,
                  trailing: TextButton.icon(
                    onPressed: _openEditProfile,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text('تعديل',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 40)),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(label: 'الاسم الكامل', value: user.fullName),
                      _InfoRow(label: 'البريد الإلكتروني', value: user.email),
                      _InfoRow(label: 'رقم الهاتف', value: user.phone),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // C) Payment History Card
                _SectionCard(
                  title: 'سجل الدفعات',
                  icon: Icons.receipt_long_rounded,
                  trailing: Text(
                    Fmt.payments(history.length),
                    style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
                  ),
                  child: _isLoadingHistory
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                      : history.isEmpty
                      ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا توجد دفعات بعد',
                      style: GoogleFonts.cairo(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : Column(
                    children: List.generate(history.length, (i) {
                      final record = history[i];
                      return Column(
                        children: [
                          _PaymentHistoryItem(
                            record: record,
                            formatMonths: _formatMonths,
                          ),
                          if (i < history.length - 1)
                            const Divider(color: AppColors.border, height: 1),
                        ],
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // D) Danger Zone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تسجيل الخروج',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              'سيتم إنهاء جلستك الحالية',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.error.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text(
                          'خروج',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  _SectionCard
// ─────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  _InfoRow
// ─────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          // Expanded: البريد أو الاسم الطويل يلتف بدل overflow
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  _PaymentHistoryItem
// ─────────────────────────────────────────────────────────
class _PaymentHistoryItem extends StatelessWidget {
  final PaymentRecord record;
  final String Function(List<int>) formatMonths;

  const _PaymentHistoryItem({
    required this.record,
    required this.formatMonths,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أشهر ${formatMonths(record.months)}',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  record.paidAt,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${record.amount.toStringAsFixed(2)}',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.success,
                ),
              ),
              Text(
                record.receiptNumber,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}