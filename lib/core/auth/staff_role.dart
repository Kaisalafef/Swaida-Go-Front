// lib/core/auth/staff_role.dart
//
// مصدر واحد لصلاحيات حسابات الإدارة.
// كان فحص role == 'admin' مكتوباً يدوياً في 4 أماكن (login / splash / router)؛
// الآن كلها تستدعي هذا الملف، وإضافة أي دور جديد تتم هنا فقط.
//
//   admin       : كل شيء
//   accountant  : قراءة فقط (اللوحة + كل التقارير)، بلا أي عملية مالية

class StaffRole {
  StaffRole._();

  static const String admin = 'admin';
  static const String accountant = 'accountant';

  /// أي حساب إدارة (يدخل لوحة الإدارة)
  static bool isStaff(String? role) => role == admin || role == accountant;

  /// تسجيل دفعات + تحويل الصناديق (الأدمن وحده)
  static bool canManageFinance(String? role) => role == admin;

  /// تعديل نسبة العمولة
  static bool canEditCommission(String? role) => role == admin;

  static bool canManageStaff(String? role) => role == admin;

  static String label(String? role) {
    switch (role) {
      case admin:
        return 'مدير';
      case accountant:
        return 'محاسب';
      default:
        return 'مشترك';
    }
  }
}
