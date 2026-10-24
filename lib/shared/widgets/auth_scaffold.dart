// lib/shared/widgets/auth_scaffold.dart
//
// هيكل موحّد لشاشات الدخول: login / register / verify-email / forgot-password.
// نفس هوية الـ Splash والـ Onboarding: هيدر داكن (BrandBackdrop) + ورقة بيضاء
// بحواف مدوّرة تحمل المحتوى.
//
// - الصفحة كلها قابلة للتمرير: لا overflow مع لوحة المفاتيح أو تكبير الخط.
// - الهيدر يتحرك مع المحتوى فلا يأكل مساحة الشاشات الصغيرة عند الكتابة.
// - لا يغيّر أي منطق: كل شاشة تمرّر onBack الخاص بها.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/brand_tokens.dart';
import 'brand_backdrop.dart';

class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
    this.heroIcon,
  });

  /// أيقونة الهيدر (تُتجاهل إن مُرّر [heroIcon]).
  final IconData icon;
  final String title;
  final String? subtitle;

  /// null = لا يظهر زر رجوع.
  final VoidCallback? onBack;

  /// بديل عن البلاطة الافتراضية (مثلاً أيقونة نابضة).
  final Widget? heroIcon;

  /// محتوى الورقة البيضاء.
  final Widget child;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = _enter.drive(CurveTween(curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .chain(CurveTween(curve: Brand.enter))
        .animate(_enter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              // الورقة تصعد فوق أسفل الهيدر بمقدار نصف قطر الحافة،
              // فتظهر زواياها المدوّرة فوق الخلفية الداكنة.
              Transform.translate(
                offset: const Offset(0, -Brand.sheetRadius),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(Brand.sheetRadius),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final subtitle = widget.subtitle;

    return Stack(
      children: [
        const Positioned.fill(child: BlueBackdrop()),
        Padding(
          padding: EdgeInsets.fromLTRB(24, top + 8, 24, Brand.sheetRadius + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (widget.onBack != null)
                      IconButton(
                        onPressed: widget.onBack,
                        tooltip: AppStrings.back,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(36),
                        ),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                    const Spacer(),
                    const _BrandDots(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              widget.heroIcon ?? AuthIconTile(icon: widget.icon),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withAlpha(235),
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// أربع نقاط بألوان أيقونة التطبيق (توقيع بصري صغير، زخرفي).
class _BrandDots extends StatelessWidget {
  const _BrandDots();

  static const List<Color> _colors = [
    Brand.green,
    Brand.red,
    Brand.yellow,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in _colors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: const SizedBox(width: 7, height: 7),
              ),
            ),
        ],
      ),
    );
  }
}

/// بلاطة الأيقونة في الهيدر (زخرفية، مخفية عن قارئ الشاشة).
class AuthIconTile extends StatelessWidget {
  const AuthIconTile({super.key, required this.icon, this.size = 64});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: Colors.white.withAlpha(77)),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}
