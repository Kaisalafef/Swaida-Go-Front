// lib/core/router/app_router.dart
//
// الـ Flow المُصحَّح:
//
//  /splash → يقرأ token + role:
//             ├─ token + role==admin  → /admin/dashboard
//             ├─ token + أي دور آخر  → /home
//             └─ لا token            → /onboarding
//
//  /onboarding → /register
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
import '../../features/subscriber/presentation/screens/subscription_setup_screen.dart';
import '../../features/subscriber/presentation/screens/subscriber_home_screen.dart';
import '../../features/subscriber/presentation/screens/payment_webview_screen.dart';
import '../../features/subscriber/presentation/screens/confirmation_screen.dart';
import '../../features/subscriber/presentation/screens/profile_screen.dart';
import '../../features/subscriber/data/models/subscriber_models.dart';
import '../constants/app_colors.dart';

// ── Storage ────────────────────────────────────────────────
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Router ─────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;

    // ── حماية الصفحات المحمية ─────────────────────────────
    final protectedSubscriber = ['/home', '/payment', '/confirmation', '/profile', '/subscription-setup'];
    final protectedAdmin = ['/admin/dashboard', '/admin/subscribers-report', '/admin/fund-transfer', '/admin/fund-report', '/admin/historical-payments'];

    final token = await _storage.read(key: 'auth_token');
    final hasToken = token != null && token.isNotEmpty;

    // إن لم يكن هناك token وحاول الوصول لصفحة محمية → splash
    if (!hasToken && (protectedSubscriber.contains(location) || protectedAdmin.contains(location))) {
      return '/splash';
    }

    // إن كان admin يحاول الوصول لصفحة subscriber → dashboard
    if (hasToken && protectedSubscriber.contains(location)) {
      final role = await _storage.read(key: 'user_role');
      if (role == 'admin') return '/admin/dashboard';
    }

    // إن كان subscriber يحاول الوصول لصفحة admin → home
    if (hasToken && protectedAdmin.contains(location)) {
      final role = await _storage.read(key: 'user_role');
      if (role != 'admin') return '/home';
    }

    return null;
  },
  routes: [
    // ── Auth ─────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ── توثيق البريد الإلكتروني ──────────────────────────
    // Polling كل 5 ثوانٍ → عند النجاح يحفظ access_token وينتقل تلقائياً لـ /home
    GoRoute(
      path: '/verify-email',
      name: 'verify-email',
      builder: (context, state) => const EmailVerificationScreen(),
    ),

    // ── Subscriber ───────────────────────────────────────
    GoRoute(
      path: '/subscription-setup',
      name: 'subscription-setup',
      builder: (context, state) => const SubscriptionSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const SubscriberHomeScreen(),
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
        return ConfirmationScreen(session: session);
      },
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // ── Admin ─────────────────────────────────────────────
    GoRoute(
      path: '/admin/dashboard',
      name: 'admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/subscribers-report',
      name: 'admin-subscribers-report',
      builder: (context, state) => const AdminSubscribersReportScreen(),
    ),
    GoRoute(
      path: '/admin/fund-transfer',
      name: 'admin-fund-transfer',
      builder: (context, state) => const AdminFundTransferScreen(),
    ),
    GoRoute(
      path: '/admin/fund-report',
      name: 'admin-fund-report',
      builder: (context, state) => const AdminFundReportScreen(),
    ),
    GoRoute(
      path: '/admin/historical-payments',
      name: 'admin-historical-payments',
      builder: (context, state) => const AdminHistoricalPaymentsScreen(),
    ),

    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
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