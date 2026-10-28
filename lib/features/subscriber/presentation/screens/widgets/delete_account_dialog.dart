// lib/features/subscriber/presentation/screens/widgets/delete_account_dialog.dart
//
// حوار تأكيد حذف الحساب: يطلب كلمة المرور ويُرجعها، أو null عند الإلغاء.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swida_go/core/constants/app_colors.dart';
import 'package:swida_go/core/theme/brand_tokens.dart';

Future<String?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _controller.text.isNotEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'حذف الحساب نهائياً',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: AppColors.error,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم حذف اسمك وبريدك ورقم هاتفك وإشعاراتك، وإلغاء الأشهر غير '
              'المدفوعة من اشتراكك. ستبقى سجلات الدفعات السابقة مجهولة الهوية '
              'لأغراض محاسبية. لا يمكن التراجع عن هذا الإجراء.',
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                height: 1.7,
                color: Brand.bodyOnLight,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'أدخل كلمة المرور للتأكيد',
                labelStyle: GoogleFonts.cairo(fontSize: 13),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text('إلغاء', style: GoogleFonts.cairo(color: Brand.bodyOnLight)),
        ),
        TextButton(
          onPressed:
              canConfirm ? () => Navigator.of(context).pop(_controller.text) : null,
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: Text(
            'حذف حسابي',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: canConfirm ? AppColors.error : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
