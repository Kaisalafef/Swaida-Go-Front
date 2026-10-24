// lib/features/auth/presentation/screens/splash_screen.dart
//
// Startup decision (unchanged behaviour, now bounded and single-shot):
//   - token + staff role (admin/accountant)        → /admin/dashboard
//   - token + any other role                       → /home
//   - no token + onboarding already completed      → /login
//   - no token + onboarding not completed          → /onboarding
//   - storage failure or > 4 s                     → /login
//
// Navigation uses context.go (replaces the stack), so the splash is never
// left behind the destination and Back can never return to it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swida_go/core/auth/staff_role.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/storage/onboarding_store.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/brand_backdrop.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Shortest time the splash stays up, so the entrance can finish and the
  /// screen never flashes by. Runs in parallel with the startup checks.
  static const Duration _minDisplay = Duration(milliseconds: 1600);

  /// Upper bound for the startup checks. Past this we fall back to /login.
  static const Duration _resolveTimeout = Duration(seconds: 4);

  /// Only if startup is genuinely slow do the brand dots start pulsing.
  static const Duration _slowAfter = Duration(milliseconds: 1800);

  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Brand.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _footerFade;

  Timer? _slowTimer;
  bool _didStart = false;
  bool _reduceMotion = false;
  bool _navigated = false;
  bool _slow = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(vsync: this, duration: Brand.entrance);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconFade = _entrance.drive(
      CurveTween(curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _iconScale = Tween<double>(begin: 0.86, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.0, 0.7, curve: Brand.enter)))
        .animate(_entrance);
    _textFade = _entrance.drive(
      CurveTween(curve: const Interval(0.35, 0.8, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .chain(CurveTween(curve: const Interval(0.35, 0.8, curve: Brand.enter)))
        .animate(_entrance);
    _footerFade = _entrance.drive(
      CurveTween(curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStart) return;
    _didStart = true;

    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Decode the icon before the first animated frame so it never pops in.
    precacheImage(
      const AssetImage(Brand.iconAsset),
      context,
      onError: (Object error, StackTrace? stack) {},
    );

    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }

    unawaited(_start());
  }

  Future<void> _start() async {
    _slowTimer = Timer(_slowAfter, _onSlow);

    // Both run concurrently: total time = max(minDisplay, checks), not the sum.
    final minWait = Future<void>.delayed(
      _reduceMotion ? const Duration(milliseconds: 400) : _minDisplay,
    );
    final destination = await _resolveDestination();
    await minWait;

    _goTo(destination);
  }

  /// Never throws and never hangs: any failure or timeout → /login.
  Future<String> _resolveDestination() async {
    try {
      return await _readDestination().timeout(_resolveTimeout);
    } catch (_) {
      return '/login';
    }
  }

  Future<String> _readDestination() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      final role = await _storage.read(key: 'user_role');
      return StaffRole.isStaff(role) ? '/admin/dashboard' : '/home';
    }
    final onboardingDone = await OnboardingStore.isCompleted();
    return onboardingDone ? '/login' : '/onboarding';
  }

  /// Single-shot: a second call (or a call after dispose) is ignored.
  void _goTo(String destination) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _slowTimer?.cancel();
    context.go(destination);
  }

  void _onSlow() {
    if (!mounted || _navigated) return;
    setState(() => _slow = true);
    if (!_reduceMotion) _pulse.repeat();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: Brand.ink,
        body: BrandBackdrop(
          glowCenter: const Alignment(0, -0.15),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _iconFade,
                            child: ScaleTransition(
                              scale: _iconScale,
                              child: const _IconTile(size: 120),
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeTransition(
                            opacity: _textFade,
                            child: SlideTransition(
                              position: _textSlide,
                              child: Column(
                                children: [
                                  Text(
                                    AppStrings.appName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.splashTagline,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withAlpha(184),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          FadeTransition(
                            opacity: _footerFade,
                            child: _BrandDots(pulse: _pulse, loading: _slow),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _footerFade,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      AppStrings.appRights,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.white.withAlpha(140),
                      ),
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

// ── App icon on a rounded tile ─────────────────────────────
// The icon is a JPG with a black background, so it is clipped to a rounded
// tile (like a launcher icon) and edged with a hairline ring instead of
// pretending it is transparent.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * Brand.tileRadiusFactor);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: Colors.black,
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Image.asset(
          Brand.iconAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          semanticLabel: AppStrings.appName,
          // If the asset is missing from pubspec.yaml, show a neutral mark
          // instead of a red error box.
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.groups_rounded, color: Colors.white, size: 56),
          ),
        ),
      ),
    );
  }
}

// ── Four brand dots (the icon's four colors) ───────────────
// Static signature by default; pulses in sequence only while startup is slow.
class _BrandDots extends StatelessWidget {
  const _BrandDots({required this.pulse, required this.loading});

  final Animation<double> pulse;
  final bool loading;

  double _scaleFor(int index) {
    final t = (pulse.value - index * 0.14) % 1.0;
    final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
    return 0.7 + 0.6 * Curves.easeInOut.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: loading ? AppStrings.loading : '',
      liveRegion: loading,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < Brand.iconSequence.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Transform.scale(
                    scale: loading ? _scaleFor(i) : 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Brand.iconSequence[i],
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
