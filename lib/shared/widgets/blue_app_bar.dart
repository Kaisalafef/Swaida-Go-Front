// lib/shared/widgets/blue_app_bar.dart
//
// شريط علوي أزرق موحّد لشاشات المشترك (تعديل الملف، تعديل الباقة، إعداد
// الاشتراك، الدفع، حول التطبيق). كانت ثلاثة أنماط: أبيض، ومتدرج مسطح، وSliver.
// نفس خلفية شاشات الدخول (BlueBackdrop)، وزر رجوع بهدف لمس 48 وtooltip، وأيقونات
// شريط الحالة فاتحة.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_strings.dart';
import 'brand_backdrop.dart';

class BlueAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlueAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions,
  });

  final String title;
  final String? subtitle;

  /// null = بلا زر رجوع (شاشات جذرية/إجبارية).
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: const BlueBackdrop(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      leading: onBack == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                tooltip: AppStrings.back,
                onPressed: onBack,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(36),
                ),
                // arrow_back يُعكس تلقائياً في RTL فيشير يميناً (اتجاه «رجوع»)
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
      title: sub == null
          ? Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
              ],
            ),
      actions: actions,
    );
  }
}
