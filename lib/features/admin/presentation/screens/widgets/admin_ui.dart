// lib/features/admin/presentation/screens/widgets/admin_ui.dart
//
// Shared design system for every admin screen.
// Presentation only: no API / state / business logic lives here.
//
//   AdminTokens  – colors, radii, spacing, shadows, motion
//   AdminText    – the type scale (Cairo, minimum 12sp)
//   AdminFmt     – money formatting
//   Widgets      – header, card, button, dropdown, segmented control,
//                  skeletons, empty state, dialogs, snackbar

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:swida_go/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════
// TOKENS
// ═══════════════════════════════════════════════════════════

class AdminTokens {
  AdminTokens._();

  // ── Surfaces ───────────────────────────────────────────
  static const Color bg = Color(0xFFF0F4F2);
  static const Color field = Color(0xFFF6F9F7);
  static const Color skeleton = Color(0xFFE2E8E5);

  // ── Brand ──────────────────────────────────────────────
  static const Color primaryDeep = Color(0xFF1B5E42);
  static const Color primaryDark = Color(0xFF1B6B44);
  static const Color mint = Color(0xFF2ECC8B);
  static const Color live = Color(0xFF69F0AE);

  // ── Accents (one pair per meaning) ─────────────────────
  static const Color blue = Color(0xFF1565C0);
  static const Color blueSoft = Color(0xFFE3F2FD);
  static const Color purple = Color(0xFF6A1B9A);
  static const Color purpleSoft = Color(0xFFF3E5F5);
  static const Color orange = Color(0xFFE65100);
  static const Color orangeSoft = Color(0xFFFFF3E0);
  static const Color green = Color(0xFF2E7D32);
  static const Color greenSoft = Color(0xFFE8F5E9);
  static const Color amber = Color(0xFF8D5A00);
  static const Color select = Color(0xFF1A73E8);
  static const Color selectSoft = Color(0xFFE3F0FF);
  static const Color warnBg = Color(0xFFFFF8E1);
  static const Color warnBorder = Color(0xFFFFE082);

  // ── Payment status ─────────────────────────────────────
  static const Color paidBg = Color(0xFFB9F6CA);
  static const Color paidFg = Color(0xFF1B5E20);
  static const Color paidBorder = Color(0xFF66BB6A);
  static const Color overdueBg = Color(0xFFFFEBEE);
  static const Color overdueBorder = Color(0xFFEF9A9A);
  static const Color pendingBg = Color(0xFFF1F4F2);

  // ── Translucent white used on gradients (pre-computed, const) ──
  static const Color onBrand05 = Color(0x0DFFFFFF);
  static const Color onBrand10 = Color(0x1AFFFFFF);
  static const Color onBrand15 = Color(0x26FFFFFF);
  static const Color onBrand18 = Color(0x2EFFFFFF);
  static const Color onBrand20 = Color(0x33FFFFFF);
  static const Color onBrand85 = Color(0xD9FFFFFF);
  static const Color onBrand90 = Color(0xE6FFFFFF);

  // ── Radii ──────────────────────────────────────────────
  static const double rSm = 12;
  static const double rField = 14;
  static const double rMd = 16;
  static const double rLg = 20;
  static const double rXl = 24;

  // ── Spacing (4-pt scale) ───────────────────────────────
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ── Gradients ──────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryDark, AppColors.primary, mint],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDeep, AppColors.primary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // ── Shadows ────────────────────────────────────────────
  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glow(Color c) => [
    BoxShadow(
      color: c.withOpacity(0.32),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Motion ─────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;
}

// ═══════════════════════════════════════════════════════════
// TYPE SCALE  (Cairo – nothing below 12sp)
// ═══════════════════════════════════════════════════════════

class AdminText {
  AdminText._();

  static TextStyle _c(double size, FontWeight w, Color color,
      {double? height}) =>
      GoogleFonts.cairo(
          fontSize: size, fontWeight: w, color: color, height: height);

  // On gradients
  static TextStyle get heroTitle =>
      _c(24, FontWeight.w800, Colors.white, height: 1.2);
  static TextStyle get headerTitle =>
      _c(19, FontWeight.w800, Colors.white, height: 1.25);
  static TextStyle get headerSub =>
      _c(12, FontWeight.w500, AdminTokens.onBrand85);
  static TextStyle get heroNumber =>
      _c(40, FontWeight.w800, Colors.white, height: 1.1);
  static TextStyle get statValue =>
      _c(24, FontWeight.w800, Colors.white, height: 1.1);
  static TextStyle get onBrandLabel =>
      _c(14, FontWeight.w700, AdminTokens.onBrand90);
  static TextStyle get onBrandCaption =>
      _c(12, FontWeight.w500, AdminTokens.onBrand85);

  // On surfaces
  static TextStyle get headline =>
      _c(20, FontWeight.w800, AppColors.accent, height: 1.3);
  static TextStyle get title =>
      _c(16, FontWeight.w800, AppColors.accent, height: 1.3);
  static TextStyle get label =>
      _c(14, FontWeight.w700, AppColors.textDark, height: 1.35);
  static TextStyle get body =>
      _c(14, FontWeight.w500, AppColors.textDark, height: 1.4);
  static TextStyle get bodyMuted =>
      _c(14, FontWeight.w500, AppColors.textMuted, height: 1.5);
  static TextStyle get caption =>
      _c(12, FontWeight.w500, AppColors.textMuted, height: 1.35);
  static TextStyle get captionBold =>
      _c(12, FontWeight.w700, AppColors.textDark, height: 1.35);
  static TextStyle get number =>
      _c(22, FontWeight.w800, AppColors.textDark, height: 1.1);

  // Buttons inherit their foreground color from the button style.
  static TextStyle get button =>
      GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700);
}

// ═══════════════════════════════════════════════════════════
// FORMATTING
// ═══════════════════════════════════════════════════════════

class AdminFmt {
  AdminFmt._();

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      b.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  /// `$12,500` / `$12,500.50`
  static String money(double v, {int decimals = 0}) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(decimals).split('.');
    final frac = parts.length > 1 ? '.${parts[1]}' : '';
    return '${neg ? '-' : ''}\$${_group(parts[0])}$frac';
  }

  /// No decimals for whole numbers, two decimals otherwise.
  static String moneyAuto(double v) =>
      money(v, decimals: v == v.roundToDouble() ? 0 : 2);
}

// ═══════════════════════════════════════════════════════════
// INPUT DECORATION
// ═══════════════════════════════════════════════════════════

InputDecoration adminInputDecoration({
  String? label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
  String? suffixText,
  String? errorText,
  Color focusColor = AppColors.primary,
  Color fillColor = AdminTokens.field,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AdminTokens.rField),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    labelText: label,
    labelStyle: AdminText.caption.copyWith(fontSize: 13),
    hintText: hint,
    hintStyle: AdminText.caption.copyWith(
        fontSize: 13, color: AppColors.textMuted.withOpacity(0.8)),
    errorText: errorText,
    errorStyle: AdminText.caption.copyWith(color: AppColors.error),
    suffixText: suffixText,
    suffixStyle: AdminText.bodyMuted.copyWith(fontSize: 16),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: AppColors.textMuted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor,
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(focusColor, 1.6),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 1.6),
  );
}

// ═══════════════════════════════════════════════════════════
// FEEDBACK  (snackbar + dialogs)
// ═══════════════════════════════════════════════════════════

void showAdminSnack(BuildContext context, String message,
    {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.error : AppColors.primary,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminTokens.rSm)),
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AdminText.label
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
}

Future<void> showAdminSuccessDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String buttonLabel,
      VoidCallback? onConfirm,
      Widget? extra,
      bool barrierDismissible = false,
    }) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminTokens.green, AppColors.success],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AdminTokens.glow(AppColors.success),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 42),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: AdminText.headline, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: AdminText.bodyMuted.copyWith(height: 1.7),
                textAlign: TextAlign.center),
            if (extra != null) ...[const SizedBox(height: 16), extra],
            const SizedBox(height: 24),
            AdminButton(
              label: buttonLabel,
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirm?.call();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> showAdminConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      String cancelLabel = 'إلغاء',
      Color confirmColor = AppColors.error,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: AdminText.headline, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: AdminText.bodyMuted.copyWith(height: 1.7),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AdminButton(
                    label: cancelLabel,
                    outlined: true,
                    color: AppColors.textDark,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminButton(
                    label: confirmLabel,
                    color: confirmColor,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ═══════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════

/// Frosted 44×44 icon button for use on gradient headers.
class AdminIconButton extends StatelessWidget {
  const AdminIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AdminTokens.onBrand18,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.rSm),
          side: const BorderSide(color: AdminTokens.onBrand10),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Count / status chip shown at the end of a header.
class AdminHeaderBadge extends StatelessWidget {
  const AdminHeaderBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminTokens.onBrand15,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTokens.onBrand10),
      ),
      child: Text(
        text,
        style: AdminText.captionBold.copyWith(color: Colors.white),
      ),
    );
  }
}

class AdminLiveDot extends StatelessWidget {
  const AdminLiveDot({super.key, this.size = 7});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AdminTokens.live,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The single gradient header used by every sub-screen.
class AdminHeaderBar extends StatelessWidget {
  const AdminHeaderBar({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AdminTokens.headerGradient,
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AdminTokens.rXl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 18),
          child: Row(
            children: [
              AdminIconButton(
                icon: Icons.arrow_back_ios_rounded,
                tooltip: 'رجوع',
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AdminText.headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AdminText.headerSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SURFACES
// ═══════════════════════════════════════════════════════════

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminTokens.s16),
    this.margin,
    this.onTap,
    this.radius = AdminTokens.rLg,
    this.splashColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? splashColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          splashColor: splashColor?.withOpacity(0.10),
          highlightColor: splashColor?.withOpacity(0.05),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: r,
        boxShadow: AdminTokens.shadowCard,
        border: Border.all(color: AppColors.border.withOpacity(0.35)),
      ),
      child: content,
    );
  }
}

/// Gradient surface with a soft decorative bubble (balance / summary cards).
class AdminHeroCard extends StatelessWidget {
  const AdminHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AdminTokens.rXl);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AdminTokens.heroGradient,
        borderRadius: r,
        boxShadow: AdminTokens.glow(AppColors.primary),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            PositionedDirectional(
              top: -30,
              start: -30,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AdminTokens.onBrand05,
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AdminTokens.mint],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(title,
              style: AdminText.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class AdminPill extends StatelessWidget {
  const AdminPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AdminText.captionBold.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primarySoft,
                    AppColors.primarySoft.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: AdminText.title.copyWith(fontSize: 17),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AdminText.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SKELETONS
// ═══════════════════════════════════════════════════════════

/// One controller pulses an entire skeleton subtree (cheap, respects
/// the OS "reduce motion" setting).
class AdminPulse extends StatefulWidget {
  const AdminPulse({super.key, required this.child});
  final Widget child;

  @override
  State<AdminPulse> createState() => _AdminPulseState();
}

class _AdminPulseState extends State<AdminPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  late final Animation<double> _a = Tween<double>(begin: 0.45, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: widget.child);
}

class AdminSkeleton extends StatelessWidget {
  const AdminSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AdminTokens.rSm,
    this.color = AdminTokens.skeleton,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CONTROLS
// ═══════════════════════════════════════════════════════════

class AdminButton extends StatelessWidget {
  const AdminButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color = AppColors.primary,
    this.outlined = false,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color color;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.rField));
    const padding = EdgeInsets.symmetric(horizontal: 16);

    final content = AnimatedSwitcher(
      duration: AdminTokens.fast,
      child: loading
          ? SizedBox(
        key: const ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: outlined ? color : Colors.white,
        ),
      )
          : Row(
        key: const ValueKey('content'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(label,
                style: AdminText.button,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return SizedBox(
      height: height,
      child: outlined
          ? OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: const BorderSide(color: AppColors.border),
          shape: shape,
          padding: padding,
        ),
        child: content,
      )
          : ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.55),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: shape,
          padding: padding,
        ),
        child: content,
      ),
    );
  }
}

class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AdminTokens.rSm),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textMuted),
      style: AdminText.body,
      decoration: adminInputDecoration(
        label: label,
        fillColor: AppColors.primarySoft,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// Sliding segmented control (2–3 options).
class AdminSegmented extends StatelessWidget {
  const AdminSegmented({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final x = n == 1 ? 0.0 : -1.0 + 2.0 * selectedIndex / (n - 1);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AdminTokens.rField),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: AdminTokens.base,
              curve: AdminTokens.curve,
              alignment: AlignmentDirectional(x, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AdminTokens.heroGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AdminTokens.glow(AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selectedIndex,
                      label: labels[i],
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onChanged(i),
                          child: Center(
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(
                                end: i == selectedIndex
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                              duration: AdminTokens.base,
                              builder: (_, c, __) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icons[i], size: 16, color: c),
                                  const SizedBox(width: 6),
                                  Text(labels[i],
                                      style: AdminText.label
                                          .copyWith(color: c)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}