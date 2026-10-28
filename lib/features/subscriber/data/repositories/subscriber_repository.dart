// lib/features/subscriber/data/repositories/subscriber_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/subscriber_models.dart';
import '../../../../core/network/session_guard.dart';

// ── تغيير هذا السطر فقط عند الانتقال للـ API الحقيقي ──────
const bool _kUseMock = false;
// ──────────────────────────────────────────────────────────

class SubscriberException implements Exception {
  final String message;
  const SubscriberException(this.message);
  @override
  String toString() => message;
}

class SubscriberRepository {
  SubscriberRepository() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? 'https://api.example.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) => handler.next(error),
      ),
    );

    // 401 → مسح الجلسة والعودة تلقائياً لشاشة الدخول (انظر core/network/session_guard.dart)
    _dio.interceptors.add(SessionExpiredInterceptor());
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ══════════════════════════════════════════════════════
  //  MOCK DELAY
  // ══════════════════════════════════════════════════════
  Future<void> _mockDelay([int ms = 800]) =>
      Future.delayed(Duration(milliseconds: ms));

  // ══════════════════════════════════════════════════════
  //  MOCK DATA
  // ══════════════════════════════════════════════════════
  static final List<MonthPaymentInfo> _mockMonths = [
    const MonthPaymentInfo(monthNumber: 1, monthName: 'يناير', status: MonthStatus.paid, amount: 10.0, paidAt: '2025-01-05'),
    const MonthPaymentInfo(monthNumber: 2, monthName: 'فبراير', status: MonthStatus.paid, amount: 10.0, paidAt: '2025-02-03'),
    const MonthPaymentInfo(monthNumber: 3, monthName: 'مارس', status: MonthStatus.paid, amount: 10.0, paidAt: '2025-03-07'),
    const MonthPaymentInfo(monthNumber: 4, monthName: 'أبريل', status: MonthStatus.overdue, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 5, monthName: 'مايو', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 6, monthName: 'يونيو', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 7, monthName: 'يوليو', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 8, monthName: 'أغسطس', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 9, monthName: 'سبتمبر', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 10, monthName: 'أكتوبر', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 11, monthName: 'نوفمبر', status: MonthStatus.pending, amount: 10.0, paidAt: null),
    const MonthPaymentInfo(monthNumber: 12, monthName: 'ديسمبر', status: MonthStatus.pending, amount: 10.0, paidAt: null),
  ];

  static final SubscriptionInfo _mockSubscription = SubscriptionInfo(
    id: 1,
    annualAmount: 120.0,
    monthlyAmount: 10.0,
    startDate: '2025-01-01',
    months: _mockMonths,
  );

  static final List<PaymentRecord> _mockPaymentHistory = [
    const PaymentRecord(id: 1, months: [1], amount: 10.0, paidAt: '2025-01-05 14:30', receiptNumber: 'REC-SUB-001'),
    const PaymentRecord(id: 2, months: [2], amount: 10.0, paidAt: '2025-02-03 10:15', receiptNumber: 'REC-SUB-002'),
    const PaymentRecord(id: 3, months: [3], amount: 10.0, paidAt: '2025-03-07 09:45', receiptNumber: 'REC-SUB-003'),
  ];

  static final UserProfile _mockUserProfile = UserProfile(
    id: 1,
    fullName: 'أحمد محمد علي',
    email: 'ahmed@example.com',
    phone: '+963 933 111 222',
    joinedAt: '2025-01-01',
    subscription: _mockSubscription,
    paymentHistory: _mockPaymentHistory,
  );

  // ══════════════════════════════════════════════════════
  //  GET SUBSCRIPTION
  // ══════════════════════════════════════════════════════
  Future<SubscriptionInfo?> getSubscription() async {
    if (_kUseMock) {
      await _mockDelay();
      return _mockSubscription;
    }

    try {
      final response = await _dio.get('/subscription');
      final data = _parseResponse(response.data);
      if (data.isEmpty) return null;
      return SubscriptionInfo.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  GET USER PROFILE
  // ══════════════════════════════════════════════════════
  Future<UserProfile> getUserProfile() async {
    if (_kUseMock) {
      await _mockDelay();
      return _mockUserProfile;
    }

    try {
      final response = await _dio.get('/user');
      final data = _parseResponse(response.data);
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  CREATE SUBSCRIPTION
  // ══════════════════════════════════════════════════════
  Future<void> createSubscription({required double annualAmount}) async {
    if (_kUseMock) {
      await _mockDelay();
      return;
    }

    try {
      await _dio.post('/subscription', data: {
        'annual_amount': annualAmount,
      });
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  PROFILE EDIT (تعديل الملف الشخصي)
  // ══════════════════════════════════════════════════════
  /// PATCH /profile — الاسم والهاتف (يُرسل ما تغيّر فقط)
  Future<void> updateProfile({String? fullName, String? phone}) async {
    try {
      final response = await _dio.patch('/profile', data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
      });
      // نُحدّث النسخة المحلية التي تقرأ منها شاشات أخرى (التحية، الدفع…)
      final user = _parseResponse(response.data)['user'];
      if (user is Map) {
        if (user['full_name'] != null) {
          await _storage.write(
              key: 'user_full_name', value: user['full_name'].toString());
        }
        if (user['phone'] != null) {
          await _storage.write(
              key: 'user_phone', value: user['phone'].toString());
        }
      }
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  /// POST /profile/password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/profile/password', data: {
        'current_password': currentPassword,
        'password': newPassword,
      });
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  /// POST /profile/email — يرسل رابط تأكيد إلى البريد الجديد
  Future<String> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final response = await _dio.post('/profile/email', data: {
        'email': newEmail,
        'current_password': currentPassword,
      });
      return (_parseResponse(response.data)['message'] ?? '').toString();
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  /// POST /account/delete — حذف الحساب نهائياً (يتطلب كلمة المرور)
  Future<void> deleteAccount({required String password}) async {
    try {
      await _dio.post('/account/delete', data: {'password': password});
    } on DioException catch (e) {
      print(e);
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  PACKAGE CHANGE (زيادة / تقليل الباقة)
  // ══════════════════════════════════════════════════════
  /// معاينة الأثر دون حفظ أي شيء
  Future<PackageChangePlan> previewPackageChange({
    required double annualAmount,
  }) async {
    try {
      final response = await _dio.post('/subscription/change-preview',
          data: {'annual_amount': annualAmount});
      return PackageChangePlan.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  /// تنفيذ التغيير فعلياً
  Future<PackageChangePlan> changePackage({
    required double annualAmount,
  }) async {
    try {
      final response = await _dio
          .post('/subscription/change', data: {'annual_amount': annualAmount});
      return PackageChangePlan.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  INITIATE PAYMENT
  // ══════════════════════════════════════════════════════
  //  months      : أشهر السنة الحالية.
  //  paymentIds   : دفعات محددة بمعرّفها (متأخرات سنوات سابقة).
  //  يُرسل واحد منهما فقط؛ paymentIds له الأولوية إن وُجد.
  Future<PaymentSession> initiatePayment({
    List<int> months = const [],
    List<int> paymentIds = const [],
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      final count = paymentIds.isNotEmpty ? paymentIds.length : months.length;
      final total = count * _mockSubscription.monthlyAmount;
      return PaymentSession(
        checkoutUrl: 'https://checkout.paddle.com/mock',
        months: months,
        totalAmount: total,
      );
    }

    try {
      final response = await _dio.post('/payment/initiate',
          data: paymentIds.isNotEmpty
              ? {'payment_ids': paymentIds}
              : {'months': months});
      final data = _parseResponse(response.data);
      return PaymentSession.fromJson(data);
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  YEAR STATUS — بداية سنة جديدة
  //  must_pay | choose | stopped | ok | no_subscription
  // ══════════════════════════════════════════════════════
  Future<YearStatus> getYearStatus() async {
    if (_kUseMock) {
      await _mockDelay(200);
      return YearStatus.fromJson({'state': 'ok'});
    }

    try {
      final response = await _dio.get('/subscription/year-status');
      return YearStatus.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // annualAmount == null → تجديد بنفس المبلغ، وإلا تغيير الباقة ثم التجديد
  Future<void> renewSubscription({double? annualAmount}) async {
    if (_kUseMock) {
      await _mockDelay();
      return;
    }

    try {
      await _dio.post('/subscription/renew',
          data: annualAmount == null ? <String, dynamic>{} : {'annual_amount': annualAmount});
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  Future<void> stopSubscription() async {
    if (_kUseMock) {
      await _mockDelay();
      return;
    }

    try {
      await _dio.post('/subscription/stop');
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  VERIFY PAYMENT
  //  ──────────────────────────────────────────────────────
  //  في نظام الـ Mock Backend:
  //  mock-success ينفّذ العملية في DB مباشرة ثم يعمل redirect
  //  لـ /payment/success — يعني عندما يصل Flutter لهنا
  //  الدفع سبق وتم تسجيله. لا حاجة لـ API call إضافي.
  //
  //  في الإنتاج مع Paddle الحقيقي:
  //  Webhook هو المسؤول عن تسجيل الدفع، وهذا الـ endpoint
  //  يمكن استخدامه للتحقق الإضافي إن أردت.
  // ══════════════════════════════════════════════════════
  Future<bool> verifyPayment({required String sessionId}) async {
    if (_kUseMock) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    // ✅ تحقق حقيقي من الـ API
    try {
      final response = await _dio.get('/payment/latest-receipt');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  GET LATEST RECEIPT
  // ══════════════════════════════════════════════════════
  Future<PaymentRecord?> getLatestReceipt() async {
    if (_kUseMock) {
      await _mockDelay();
      if (_mockPaymentHistory.isEmpty) return null;
      return _mockPaymentHistory.last;
    }

    try {
      final response = await _dio.get('/payment/latest-receipt');
      final data = _parseResponse(response.data);
      if (data.isEmpty) return null;
      return PaymentRecord.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  GET COMMISSION RATE
  // ══════════════════════════════════════════════════════
  Future<double> getCommission() async {
    if (_kUseMock) {
      await _mockDelay(300);
      return 10.0;
    }

    try {
      final response = await _dio.get('/settings/commission');
      final data = _parseResponse(response.data);
      return (data['commission_percentage'] as num?)?.toDouble() ?? 0.0;
    } on DioException catch (e) {
      throw SubscriberException(_mapDioError(e));
    }
  }

  // ── Safe response parser ──────────────────────────────
  Map<String, dynamic> _parseResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) return responseData;
    if (responseData is String) {
      try {
        final decoded = jsonDecode(responseData);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {};
  }

  // ── Error mapper ──────────────────────────────────────
  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'خطأ في الاتصال بالشبكة. يرجى المحاولة مجدداً.';
    }

    final status = e.response?.statusCode;
    final rawData = _parseResponse(e.response?.data);
    final serverMessage = rawData['message'];

    if (status == 401) return 'انتهت الجلسة. يرجى تسجيل الدخول مجدداً.';
    if (status == 429) return 'محاولات كثيرة. انتظر دقيقة ثم أعد المحاولة.';
    if (status == 422) {
      if (serverMessage is String && _isArabic(serverMessage)) return serverMessage;
      final errors = rawData['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          final msg = firstError.first.toString();
          if (_isArabic(msg)) return msg;
        }
      }
      return 'بيانات غير صحيحة. يرجى المراجعة.';
    }
    if (status != null && status >= 500) return 'خطأ في الخادم. يرجى المحاولة لاحقاً.';

    return serverMessage?.toString() ?? 'حدث خطأ غير متوقع.';
  }

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}