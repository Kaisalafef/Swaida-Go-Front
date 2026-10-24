// lib/shared/widgets/app_cards.dart
//
// بطاقة وإشعار موحّدان (كانا منسوخين في edit_profile وchange_package وغيرهما).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

/// بطاقة بيضاء بحواف 20 وظل خفيف.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// شريط إشعار بأيقونة ونص (تحذير افتراضياً).
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.text,
    required this.icon,
    this.fg = AppColors.warningText,
    this.bg = AppColors.warningLight,
  });

  final String text;
  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 13, color: fg, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
