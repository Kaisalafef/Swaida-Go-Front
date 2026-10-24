// lib/features/auth/presentation/screens/onboarding_screen.dart
//
// Back behaviour (this screen is the root of its stack because the splash
// reaches it with context.go):
//   - page 2 or 3 → Android Back / on-screen back button → previous page
//   - page 1      → Android Back → default (leave the app); no loop, and the
//                   splash is not in the stack to return to
// Completion (Next on the last page, or Skip) runs once: it saves the
// "completed" flag, then context.go('/register').
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/storage/onboarding_store.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/back_guard.dart';
import '../../../../shared/widgets/brand_backdrop.dart';

// ── Data model ─────────────────────────────────────────────
class _OnboardingData {
  const _OnboardingData({
    required this.badge,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String badge;
  final String title;
  final String body;
  final IconData icon;

  /// Glow / icon color for the dark hero. Taken from the app icon's palette.
  final Color accent;
}

const _pages = [
  _OnboardingData(
    badge: AppStrings.ob1Badge,
    title: AppStrings.ob1Title,
    body: AppStrings.ob1Body,
    icon: Icons.card_membership_rounded,
    accent: Brand.blueOnDark,
  ),
  _OnboardingData(
    badge: AppStrings.ob2Badge,
    title: AppStrings.ob2Title,
    body: AppStrings.ob2Body,
    icon: Icons.payment_rounded,
    accent: Brand.yellow,
  ),
  _OnboardingData(
    badge: AppStrings.ob3Badge,
    title: AppStrings.ob3Title,
    body: AppStrings.ob3Body,
    icon: Icons.bar_chart_rounded,
    accent: Brand.green,
  ),
];

// ── Screen ─────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  final PageController _controller = PageController();
  int _page = 0;
  bool _animating = false;
  bool _finishing = false;

  bool get _isFirst => _page == 0;
  bool get _isLast => _page == _pages.length - 1;

  /// Ignores taps while a page animation is running, so rapid taps cannot
  /// stack overlapping animations.
  Future<void> _animateTo(int target) async {
    if (_animating || _finishing || !_controller.hasClients) return;
    final duration =
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : Brand.base;
    setState(() => _animating = true);
    try {
      await _controller.animateToPage(
        target,
        duration: duration,
        curve: Brand.enter,
      );
    } finally {
      if (mounted) setState(() => _animating = false);
    }
  }

  void _onNext() {
    if (_isLast) {
      _finish();
    } else {
      _animateTo(_page + 1);
    }
  }

  void _onBack() {
    if (!_isFirst) _animateTo(_page - 1);
  }

  /// Runs once. Used by both "get started" and "skip".
  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingStore.markCompleted(); // never throws
    if (!mounted) return;
    context.go('/register');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back never closes the app directly:
      //   page 2/3 → previous page
      //   page 1   → "press back again to exit" (ExitConfirm)
      canPop: false,
      // `onPopInvoked` is the API on Flutter < 3.22. On 3.22+ it still works
      // (deprecated); switch to onPopInvokedWithResult after upgrading.
      onPopInvoked: (didPop) {
        if (didPop || _animating || _finishing) return;
        if (_isFirst) {
          ExitConfirm.handle(context);
        } else {
          _onBack();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay,
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, index) =>
                          _OnboardingPage(data: _pages[index]),
                    ),
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: 56,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                _FadeWhen(
                                  visible: !_isFirst,
                                  child: IconButton(
                                    onPressed: _onBack,
                                    tooltip: AppStrings.back,
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                      Colors.white.withAlpha(20),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _FadeWhen(
                                  visible: !_isLast,
                                  child: TextButton(
                                    onPressed: _finishing ? null : _finish,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: Text(
                                      AppStrings.skip,
                                      style: GoogleFonts.cairo(
                                        color: Colors.white.withAlpha(217),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                page: _page,
                isLast: _isLast,
                finishing: _finishing,
                onPressed: _finishing ? null : _onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fades a control in/out without changing the layout ─────
class _FadeWhen extends StatelessWidget {
  const _FadeWhen({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Brand.fast,
          child: child,
        ),
      ),
    );
  }
}

// ── Bottom bar: page indicator + primary action ────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.isLast,
    required this.finishing,
    required this.onPressed,
  });

  final int page;
  final bool isLast;
  final bool finishing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: AppStrings.onboardingPageOf(page + 1, _pages.length),
              liveRegion: true,
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                      (i) => AnimatedContainer(
                    duration: Brand.base,
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == page ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: isLast ? AppStrings.getStarted : AppStrings.next,
              isLoading: finishing && isLast,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single page: dark hero + light sheet ───────────────────
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  static const double _overlap = Brand.sheetRadius;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hero takes ~40% of the available height, bounded for tiny and
        // tall screens. The sheet below scrolls if text scaling needs room.
        final heroHeight =
        math.min(math.max(constraints.maxHeight * 0.4, 190.0), 340.0);
        final artSize =
        math.max(72.0, math.min(168.0, heroHeight - topInset - 64));

        return Stack(
          children: [
            // ── Hero (continues the splash) ───────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight + _overlap,
              child: BlueBackdrop(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topInset + 56,
                    bottom: _overlap + 8,
                  ),
                  child: Center(
                    child: _HeroArt(data: data, size: artSize),
                  ),
                ),
              ),
            ),

            // ── Sheet ─────────────────────────────────────
            Positioned(
              top: heroHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Brand.sheetRadius),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
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
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          data.title,
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.body,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Brand.bodyOnLight,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Decorative hero art (hidden from screen readers) ───────
// Two thin rings, a glass tile with the page icon, and four tiny dots in the
// app icon's colors on the outer ring.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.data, required this.size});

  final _OnboardingData data;
  final double size;

  static const List<Alignment> _dotSpots = [
    Alignment(-1, 0),
    Alignment(0, -1),
    Alignment(1, 0),
    Alignment(0, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final tile = size * 0.5;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: data.accent.withAlpha(150)),
              ),
              child: SizedBox(width: size, height: size),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(24),
              ),
              child: SizedBox(width: size * 0.78, height: size * 0.78),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tile * 0.3),
                color: Colors.white.withAlpha(40),
                border: Border.all(color: Colors.white.withAlpha(90)),
              ),
              child: SizedBox(
                width: tile,
                height: tile,
                child: Icon(data.icon, size: tile * 0.52, color: Colors.white),
              ),
            ),
            for (var i = 0; i < _dotSpots.length; i++)
              Align(
                alignment: _dotSpots[i],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Brand.iconSequence[i],
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 8, height: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
