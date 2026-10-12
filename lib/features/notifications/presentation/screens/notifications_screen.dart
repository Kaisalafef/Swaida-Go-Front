// lib/features/notifications/presentation/screens/notifications_screen.dart
//
// صفحة الإشعارات — مشتركة بين الأدمن والمشترك.
// الاستخدام:
//   context.push('/notifications');
// أو تُضاف لـ GoRouter كـ route عادي.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = NotificationRepository();

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _isMarkingAll = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadNotifications();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getAll();
      if (mounted) {
        setState(() => _notifications = data);
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(AppNotification notif) async {
    if (notif.isRead) return;
    try {
      await _repo.markAsRead(notif.id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == notif.id);
          if (idx != -1) {
            _notifications[idx] = AppNotification(
              id:        notif.id,
              type:      notif.type,
              data:      notif.data,
              readAt:    DateTime.now().toIso8601String(),
              createdAt: notif.createdAt,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;
    setState(() => _isMarkingAll = true);
    try {
      await _repo.markAllAsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) => AppNotification(
            id:        n.id,
            type:      n.type,
            data:      n.data,
            readAt:    n.readAt ?? DateTime.now().toIso8601String(),
            createdAt: n.createdAt,
          )).toList();
        });
        _showSnack('تم تحديد الكل كمقروء');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  // ── رمز الإشعار حسب الـ type ─────────────────────────────
  IconData _iconFor(String type) {
    if (type.contains('Payment'))   return Icons.payments_rounded;
    if (type.contains('Transfer'))  return Icons.swap_horiz_rounded;
    if (type.contains('Subscribe')) return Icons.person_add_rounded;
    if (type.contains('Admin'))     return Icons.admin_panel_settings_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorFor(String type) {
    if (type.contains('Payment'))   return const Color(0xFF2E7D32);
    if (type.contains('Transfer'))  return const Color(0xFF1565C0);
    if (type.contains('Subscribe')) return const Color(0xFF6A1B9A);
    if (type.contains('Admin'))     return AppColors.primary;
    return const Color(0xFF455A64);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primary,
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_notifications.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      children: _notifications
                          .map((n) => _NotificationTile(
                        notif:       n,
                        icon:        _iconFor(n.type),
                        iconColor:   _colorFor(n.type),
                        onTap:       () => _markAsRead(n),
                      ))
                          .toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 145,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ),
      actions: [
        if (!_isLoading && _unreadCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _isMarkingAll
                ? const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
                : GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  'قراءة الكل',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B6B44),
                    AppColors.primary,
                    Color(0xFF2ECC8B),
                  ],
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
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              right: 20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Header content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الإشعارات',
                              style: GoogleFonts.cairo(
                                fontSize: 22,
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
                                  decoration: BoxDecoration(
                                    color: _unreadCount > 0
                                        ? const Color(0xFF69F0AE)
                                        : Colors.white.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isLoading
                                      ? 'جارٍ التحميل...'
                                      : _unreadCount > 0
                                      ? '$_unreadCount غير مقروء'
                                      : 'كل الإشعارات مقروءة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
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

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 40,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد إشعارات',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ستظهر هنا إشعاراتك عند وصولها',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile widget ───────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notif,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final AppNotification notif;
  final IconData         icon;
  final Color            iconColor;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        shadowColor: Colors.black.withOpacity(0.05),
        elevation: isUnread ? 3 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: iconColor.withOpacity(0.06),
          highlightColor: iconColor.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notif.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: AppColors.textMuted.withOpacity(0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            notif.createdAt,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textMuted.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
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