// lib/shared/widgets/app_dialogs.dart
//
// حوار تأكيد موحّد للإجراءات التي لا رجعة فيها (تسجيل الخروج، التجديد …).
// RTL يأتي من MaterialApp (main.dart)، فلا حاجة لـ Directionality هنا.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/brand_tokens.dart';

/// يعرض حوار تأكيد ويُرجع true فقط إذا ضغط المستخدم زر التأكيد.
/// [destructive]: يلوّن زر التأكيد بالأحمر (خروج، حذف، إيقاف).
Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      String cancelLabel = 'إلغاء',
      bool destructive = false,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.cairo(
          fontSize: 14,
          height: 1.7,
          color: Brand.bodyOnLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text(
            cancelLabel,
            style: GoogleFonts.cairo(color: Brand.bodyOnLight),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text(
            confirmLabel,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: destructive ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
