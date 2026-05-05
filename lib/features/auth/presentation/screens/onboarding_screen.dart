// lib/features/auth/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_button.dart';

// ── Data model ─────────────────────────────────────────────
class _OnboardingData {
  const _OnboardingData({
    required this.badge,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String badge;
  final String title;
  final String body;
  final IconData icon;
}

const _pages = [
  _OnboardingData(
    badge: AppStrings.ob1Badge,
    title: AppStrings.ob1Title,
    body: AppStrings.ob1Body,
    icon: Icons.card_membership_rounded,
  ),
  _OnboardingData(
    badge: AppStrings.ob2Badge,
    title: AppStrings.ob2Title,
    body: AppStrings.ob2Body,
    icon: Icons.payment_rounded,
  ),
  _OnboardingData(
    badge: AppStrings.ob3Badge,
    title: AppStrings.ob3Title,
    body: AppStrings.ob3Body,
    icon: Icons.bar_chart_rounded,
  ),
];

// ── Screen ─────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/register');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Stack(
        children: [
          // ── PageView ────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) =>
                _OnboardingPageWidget(data: _pages[index]),
          ),

          // ── Skip button (top right in RTL = top left visually) ──
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, // left in RTL layout = right on screen
              child: TextButton(
                onPressed: () => context.go('/register'),
                child: Text(
                  AppStrings.skip,
                  style: GoogleFonts.cairo(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // ── Bottom controls ──────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.white,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action button
                  AppButton(
                    label: _currentPage < _pages.length - 1
                        ? AppStrings.next
                        : AppStrings.getStarted,
                    onPressed: _goToNextPage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single page widget ────────────────────────────────────
class _OnboardingPageWidget extends StatelessWidget {
  const _OnboardingPageWidget({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomCardTop = size.height * 0.38;

    return Stack(
      children: [
        // ── Illustration area (top 40%) ──────────────────
        Container(
          width: double.infinity,
          height: bottomCardTop + 40,
          color: AppColors.secondary,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 48),
              Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft,
                ),
                child: Icon(
                  data.icon,
                  size: 66,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // ── White card (bottom 60%) ──────────────────────
        Positioned(
          top: bottomCardTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.badge,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Title
                Text(
                  data.title,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                // Body
                Text(
                  data.body,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 1.85,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
