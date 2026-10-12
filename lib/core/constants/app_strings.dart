// lib/core/constants/app_strings.dart

class AppStrings {
  AppStrings._();

  // App
  static const String appName        = 'Swida Go';
  static const String appRights      = 'جميع الحقوق محفوظة © 2025';

  // Onboarding
  static const String skip           = 'تخطي';
  static const String next           = 'التالي';
  static const String getStarted     = 'ابدأ الآن';

  static const String ob1Badge       = '01';
  static const String ob1Title       = 'اشترك بمبلغك المختار';
  static const String ob1Body        =
      'حدد قيمة اشتراكك السنوي بحرية تامة، والمنصة تقسمه تلقائياً على 12 شهراً بدون أي رسوم إضافية';

  static const String ob2Badge       = '02';
  static const String ob2Title       = 'ادفع بالطريقة التي تناسبك';
  static const String ob2Body        =
      'اختر الأشهر التي تريد دفعها — شهر أو ثلاثة أو ستة دفعة واحدة. الحرية كاملة في يدك';

  static const String ob3Badge       = '03';
  static const String ob3Title       = 'تطبيق مجاني مقدم من شركة FlashPay للحوالات المالية';
  static const String ob3Body        =
      'شبكة واضحة تُظهر جميع أشهرك — المدفوعة بعلامة خضراء، والمتأخرة باللون الأحمر، والقادمة في انتظارك';

  // Register
  static const String createAccount  = 'إنشاء حساب جديد';
  static const String enterDataStart = 'أدخل بياناتك للبدء';
  static const String fullName       = 'الاسم الثلاثي';
  static const String fullNameHint   = 'أدخل اسمك الكامل';
  static const String email          = 'البريد الإلكتروني';
  static const String emailHint      = 'example@email.com';
  static const String phone          = 'رقم الهاتف';
  static const String phoneHint      = '+963 XXX XXX XXX';
  static const String password       = 'كلمة المرور';
  static const String passwordHint   = '8 أحرف على الأقل';
  static const String confirmPass    = 'تأكيد كلمة المرور';
  static const String confirmHint    = 'أعد إدخال كلمة المرور';
  static const String registerBtn    = 'إنشاء الحساب';
  static const String haveAccount    = 'لديك حساب بالفعل؟';
  static const String login          = 'تسجيل الدخول';

  // Validation
  static const String nameRequired   = 'الاسم الثلاثي مطلوب';
  static const String nameThreeParts = 'يرجى إدخال الاسم الثلاثي كاملاً';
  static const String emailRequired  = 'البريد الإلكتروني مطلوب';
  static const String emailInvalid   = 'صيغة البريد الإلكتروني غير صحيحة';
  static const String phoneRequired  = 'رقم الهاتف مطلوب';
  static const String phoneInvalid   = 'رقم الهاتف غير صحيح';
  static const String passRequired   = 'كلمة المرور مطلوبة';
  static const String passMin8       = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
  static const String confirmRequired= 'تأكيد كلمة المرور مطلوب';
  static const String passMismatch   = 'كلمتا المرور غير متطابقتين';

  // Email Verification
  static const String checkEmail     = 'تحقق من بريدك الإلكتروني';
  static const String sentLinkTo     = 'أرسلنا رابط التوثيق إلى';
  static const String clickLinkInfo  = 'افتح بريدك الإلكتروني وانقر على الرابط لتفعيل حسابك';
  static const String resendEmail    = 'لم أستلم البريد — أعد الإرسال';
  static const String checkingVerify = 'جاري التحقق من التوثيق...';
  static const String changeEmail    = 'تغيير البريد الإلكتروني';
  static const String emailResent    = 'تم إرسال البريد مجدداً';

  // Phone Verification
  static const String enterOtp       = 'أدخل رمز التحقق';
  static const String sentOtpTo      = 'أرسلنا رمزاً مكوناً من 6 أرقام إلى';
  static const String verifyBtn      = 'تحقق من الرمز';
  static const String resendAfter    = 'يمكنك إعادة الإرسال بعد';
  static const String seconds        = 'ثانية';
  static const String resendOtp      = 'لم تستلم الرمز؟ أعد الإرسال';
  static const String otpInvalid     = 'الرمز غير صحيح، حاول مجدداً';
  static const String otpResent      = 'تم إرسال رمز جديد إلى هاتفك';

  // API Errors
  static const String errUnauthorized = 'بيانات الدخول غير صحيحة';
  static const String errValidation   = 'البيانات المدخلة غير صحيحة';
  static const String errServer       = 'خطأ في الخادم، يرجى المحاولة لاحقاً';
  static const String errNetwork      = 'تعذر الاتصال، تحقق من الإنترنت';
}
