// lib/core/router/app_router.dart
//
// الـ Flow المُصحَّح:
//
//  /splash → يقرأ token + role + علامة إتمام الـ onboarding:
//             ├─ token + دور إدارة    → /admin/dashboard
//             ├─ token + أي دور آخر  → /home
//             ├─ لا token + أُتمّ الـ onboarding → /login
//             ├─ لا token + لم يُتمّ  → /onboarding
//             └─ فشل القراءة/انتهت المهلة → /login
//
//  زر الرجوع في أندرويد: BackGuard (shared/widgets/back_guard.dart) يلفّ كل شاشة
//  هنا — pop إن وُجدت شاشة تحتها، وإلا الشاشة الأم، وإلا «اضغط مرة أخرى للخروج».
//  استثناءات لها PopScope خاص: /onboarding، /forgot-password، /payment.
//
//  /onboarding → /register   (زر «ابدأ الآن» أو «تخطي»؛ يحفظ العلامة مرة واحدة)
//               → /verify-email   (Polling حتى يُوثَّق البريد)
//               → /home           (مباشرة بعد التوثيق — token محفوظ من checkEmailVerification)
//
//  /login  → يقرأ role من Response:
//             ├─ admin      → /admin/dashboard
//             └─ subscriber → /home

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swida_go/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:swida_go/core/auth/staff_role.dart';
import 'package:swida_go/features/subscriber/presentation/screens/change_package_screen.dart';
import 'package:swida_go/features/subscriber/presentation/screens/edit_profile_screen.dart';
import 'package:swida_go/features/auth/presentation/screens/forgot_password_screen.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_subscribers_report_screen.dart';
import '../../features/admin/presentation/screens/admin_fund_transfer_screen.dart';
import '../../features/admin/presentation/screens/admin_fund_report_screen.dart';
import '../../features/admin/presentation/screens/admin_historical_payments_screen.dart';
import '../../features/admin/presentation/screens/admin_staff_screen.dart';
import '../../features/subscriber/presentation/screens/subscription_setup_screen.dart';
import '../../features/subscriber/presentation/screens/subscriber_home_screen.dart';
import '../../features/subscriber/presentation/screens/payment_webview_screen.dart';
import '../../features/subscriber/presentation/screens/confirmation_screen.dart';
import '../../features/subscriber/presentation/screens/profile_screen.dart';
import '../../features/subscriber/data/models/subscriber_models.dart';
import '../constants/app_colors.dart';
import '../network/session_guard.dart';
import '../../shared/widgets/back_guard.dart';

// ── Storage ────────────────────────────────────────────────
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Router ─────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  // عند انتهاء الجلسة (401) يُعاد تقييم redirect فوراً فيُنقل المستخدم إلى /login
  refreshListenable: SessionGuard.expiredTick,
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;

    // ── حماية الصفحات المحمية ─────────────────────────────
    final protectedSubscriber = ['/home', '/payment', '/confirmation', '/profile', '/subscription-setup', '/change-package', '/edit-profile'];
    final protectedAdmin = ['/admin/dashboard', '/admin/subscribers-report', '/admin/fund-transfer', '/admin/fund-report', '/admin/historical-payments', '/admin/staff'];
    // عمليات مالية: للأدمن فقط (المحاسب للقراءة فقط)
    final financeOnly = ['/admin/fund-transfer', '/admin/historical-payments'];

    final token = await _storage.read(key: 'auth_token');
    final hasToken = token != null && token.isNotEmpty;

    // ── انتهت الجلسة (401): مُسح التوكن → إلى /login مع رسالة ──
    // (يعمل من أي شاشة، حتى غير المحمية كالإشعارات)
    if (!hasToken && SessionGuard.expired && location != '/login') {
      return '/login';
    }

    // إن لم يكن هناك token وحاول الوصول لصفحة محمية → splash
    if (!hasToken && (protectedSubscriber.contains(location) || protectedAdmin.contains(location))) {
      return '/splash';
    }

    // إن كان حساب إدارة (أدمن/محاسب) يحاول الوصول لصفحة subscriber → dashboard
    if (hasToken && protectedSubscriber.contains(location)) {
      final role = await _storage.read(key: 'user_role');
      if (StaffRole.isStaff(role)) return '/admin/dashboard';
    }

    // صفحات الإدارة: حسب الدور
    if (hasToken && protectedAdmin.contains(location)) {
      final role = await _storage.read(key: 'user_role');
      if (!StaffRole.isStaff(role)) return '/home'; // مشترك
      if (financeOnly.contains(location) && !StaffRole.canManageFinance(role)) {
        return '/admin/dashboard'; // محاسب (قراءة فقط)
      }
      if (location == '/admin/staff' && !StaffRole.canManageStaff(role)) {
        return '/admin/dashboard'; // غير الأدمن
      }
    }

    return null;
  },
  routes: [
    // ── Auth ─────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) =>
          BackGuard(swallow: true, child: const SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) =>
          BackGuard(fallback: '/onboarding', child: const RegisterScreen()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) =>
          BackGuard(child: const LoginScreen()),
    ),

    // ── توثيق البريد الإلكتروني ──────────────────────────
    // Polling كل 5 ثوانٍ → عند النجاح يحفظ access_token وينتقل تلقائياً لـ /home
    GoRoute(
      path: '/verify-email',
      name: 'verify-email',
      builder: (context, state) =>
          BackGuard(child: const EmailVerificationScreen()),
    ),

    // ── Subscriber ───────────────────────────────────────
    GoRoute(
      path: '/subscription-setup',
      name: 'subscription-setup',
      builder: (context, state) =>
          BackGuard(fallback: '/home', child: const SubscriptionSetupScreen()),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) =>
          ForgotPasswordScreen(initialEmail: state.extra is String ? state.extra as String : null),
    ),
    GoRoute(
      path: '/edit-profile',
      name: 'edit-profile',
      builder: (context, state) =>
          BackGuard(fallback: '/profile', child: const EditProfileScreen()),
    ),
    GoRoute(
      path: '/change-package',
      name: 'change-package',
      builder: (context, state) =>
          BackGuard(fallback: '/profile', child: const ChangePackageScreen()),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) =>
          BackGuard(child: const SubscriberHomeScreen()),
    ),
    GoRoute(
      path: '/payment',
      name: 'payment',
      builder: (context, state) {
        final session = state.extra as PaymentSession?;
        if (session == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'بيانات الدفع غير متوفرة',
                style: GoogleFonts.cairo(color: AppColors.error),
              ),
            ),
          );
        }
        return PaymentWebViewScreen(session: session);
      },
    ),
    GoRoute(
      path: '/confirmation',
      name: 'confirmation',
      builder: (context, state) {
        final session = state.extra as PaymentSession?;
        if (session == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'بيانات الدفعة غير متوفرة',
                style: GoogleFonts.cairo(color: AppColors.error),
              ),
            ),
          );
        }
        return BackGuard(
          fallback: '/home',
          child: ConfirmationScreen(session: session),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) =>
          BackGuard(fallback: '/home', child: const ProfileScreen()),
    ),

    // ── Admin ─────────────────────────────────────────────
    GoRoute(
      path: '/admin/dashboard',
      name: 'admin-dashboard',
      builder: (context, state) =>
          BackGuard(child: const AdminDashboardScreen()),
    ),
    GoRoute(
      path: '/admin/subscribers-report',
      name: 'admin-subscribers-report',
      builder: (context, state) =>
          BackGuard(fallback: '/admin/dashboard', child: const AdminSubscribersReportScreen()),
    ),
    GoRoute(
      path: '/admin/fund-transfer',
      name: 'admin-fund-transfer',
      builder: (context, state) =>
          BackGuard(fallback: '/admin/dashboard', child: const AdminFundTransferScreen()),
    ),
    GoRoute(
      path: '/admin/fund-report',
      name: 'admin-fund-report',
      builder: (context, state) =>
          BackGuard(fallback: '/admin/dashboard', child: const AdminFundReportScreen()),
    ),
    GoRoute(
      path: '/admin/historical-payments',
      name: 'admin-historical-payments',
      builder: (context, state) =>
          BackGuard(fallback: '/admin/dashboard', child: const AdminHistoricalPaymentsScreen()),
    ),
    GoRoute(
      path: '/admin/staff',
      name: 'admin-staff',
      builder: (context, state) =>
          BackGuard(fallback: '/admin/dashboard', child: const AdminStaffScreen()),
    ),

    GoRoute(
      path: '/notifications',
      builder: (context, state) =>
          BackGuard(fallback: '/home', child: const NotificationsScreen()),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'الصفحة غير موجودة: ${state.error}',
        style: GoogleFonts.cairo(),
      ),
    ),
  ),
);