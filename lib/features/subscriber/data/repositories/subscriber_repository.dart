// lib/features/subscriber/data/repositories/subscriber_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/subscriber_models.dart';

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
  //  INITIATE PAYMENT
  // ══════════════════════════════════════════════════════
  Future<PaymentSession> initiatePayment({required List<int> months}) async {
    if (_kUseMock) {
      await _mockDelay();
      final total = months.length * _mockSubscription.monthlyAmount;
      return PaymentSession(
        checkoutUrl: 'https://checkout.paddle.com/mock',
        months: months,
        totalAmount: total,
      );
    }

    try {
      final response = await _dio.post('/payment/initiate', data: {
        'months': months,
      });
      final data = _parseResponse(response.data);
      return PaymentSession.fromJson(data);
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