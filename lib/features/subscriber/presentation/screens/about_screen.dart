// lib/features/subscriber/presentation/screens/about_screen.dart
//
// حول التطبيق: هوية التطبيق + الخصوصية والشروط والدعم.
// الروابط من core/constants/app_links.dart، وتُخفى الصفوف التي لم تُملأ بعد.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_links.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/app_cards.dart';
import '../../../../shared/widgets/blue_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر فتح الرابط', style: GoogleFonts.cairo()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (AppLinks.privacyPolicy.isNotEmpty)
        _LinkRow(
          icon: Icons.privacy_tip_outlined,
          label: 'سياسة الخصوصية',
          onTap: () => _open(context, Uri.parse(AppLinks.privacyPolicy)),
        ),
      if (AppLinks.terms.isNotEmpty)
        _LinkRow(
          icon: Icons.description_outlined,
          label: 'شروط الاستخدام',
          onTap: () => _open(context, Uri.parse(AppLinks.terms)),
        ),
      if (AppLinks.supportEmail.isNotEmpty)
        _LinkRow(
          icon: Icons.support_agent_rounded,
          label: 'تواصل مع الدعم',
          onTap: () => _open(
            context,
            Uri(scheme: 'mailto', path: AppLinks.supportEmail),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: BlueAppBar(
        title: 'حول التطبيق',
        onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 96,
                height: 96,
                color: Colors.black,
                child: Image.asset(
                  Brand.iconAsset,
                  fit: BoxFit.cover,
                  semanticLabel: AppStrings.appName,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          Text(
            AppStrings.splashTagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: Brand.bodyOnLight),
          ),
          const SizedBox(height: 24),
          if (rows.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: rows),
            ),
          const SizedBox(height: 24),
          Text(
            AppStrings.appRights,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 12, color: Brand.bodyOnLight),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              // chevron_right يُعكس في RTL فيشير يساراً (اتجاه «تابع»)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
