// lib/core/utils/formatters.dart
//
// مصدر واحد لتنسيق المبالغ وأسماء الأشهر وصيغ الجمع العربية، بدل النسخ
// المكررة في profile / confirmation / change_package / year_transition_views.

class Fmt {
  Fmt._();

  static const List<String> monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// اسم الشهر من رقمه (1–12). خارج المدى لا يرمي RangeError بل يُرجع «شهر N».
  static String month(int m) =>
      (m >= 1 && m <= 12) ? monthNames[m - 1] : 'شهر $m';

  /// \$120 أو \$12.50 (بلا كسور إن كان العدد صحيحاً).
  static String money(double v) =>
      '\$${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  /// \$12.50 دائماً (خانتان عشريتان).
  static String money2(double v) => '\$${v.toStringAsFixed(2)}';

  /// شهر واحد / شهران / 3 أشهر … 10 أشهر / 11 شهراً …
  static String months(int n) {
    if (n == 1) return 'شهر واحد';
    if (n == 2) return 'شهران';
    if (n >= 3 && n <= 10) return '$n أشهر';
    return '$n شهراً';
  }

  /// دفعة واحدة / دفعتان / 3 دفعات … 10 دفعات / 11 دفعة …
  static String payments(int n) {
    if (n == 1) return 'دفعة واحدة';
    if (n == 2) return 'دفعتان';
    if (n >= 3 && n <= 10) return '$n دفعات';
    return '$n دفعة';
  }
}

/// حدود المبلغ السنوي للباقة: كانت 60–1200 في «تعديل الباقة» فقط،
/// أما «إعداد الاشتراك» فكان يقبل أي مبلغ أكبر من صفر.
class PackageRules {
  PackageRules._();

  static const double minAnnual = 60;
  static const double maxAnnual = 1200;

  static String get rangeMessage =>
      'المبلغ السنوي يجب أن يكون بين ${Fmt.money(minAnnual)} و${Fmt.money(maxAnnual)}';
}
