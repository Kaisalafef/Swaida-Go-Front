// lib/features/admin/data/repositories/admin_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/admin_models.dart';

class AdminException implements Exception {
  final String message;
  const AdminException(this.message);
  @override
  String toString() => message;
}

class AdminRepository {
  AdminRepository() {
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

  /// Getter عام يُتيح للشاشات استخدام _dio مباشرةً
  /// (مثلاً AdminHistoricalPaymentsScreen)
  Dio get dio => _dio;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── getDashboardStats ─────────────────────────────────────
  // GET /api/admin/dashboard-stats
  // Response: { total_subscribers, app_fund_balance, charity_fund_balance, this_month_payments }
  Future<DashboardStats> getDashboardStats() async {
    try {
      final response = await _dio.get('/admin/dashboard-stats');
      return DashboardStats.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getSubscribersReport ──────────────────────────────────
  // GET /api/admin/subscribers-report?month=&year=
  // Response: { data: [ { id, full_name, phone, annual_amount, monthly_amount, months: [12 strings] } ] }
  Future<List<SubscriberReport>> getSubscribersReport({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/subscribers-report',
        queryParameters: {'month': month, 'year': year},
      );
      final parsed = _parseResponse(response.data);
      final list = parsed['data'] as List;
      return list
          .map((e) => _subscriberFromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      print(e);
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getFundTransfers ──────────────────────────────────────
  // GET /api/admin/fund-transfers?type=&month=&year=
  // Response: { data: [ { id, amount, recipient_name, receipt_number, transfer_date, note } ] }
  Future<List<FundTransfer>> getFundTransfers({
    required String type,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/fund-transfers',
        queryParameters: {'type': type, 'month': month, 'year': year},
      );
      final parsed = _parseResponse(response.data);
      final raw = parsed.containsKey('data') ? parsed['data'] : parsed;
      final list = raw as List;
      return list
          .map((e) => FundTransfer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getFundSummary ────────────────────────────────────────
  // GET /api/admin/fund-summary?type=&month=&year=
  // Response: { total_received_this_month, total_transferred_this_month,
  //             app_fund_balance, charity_fund_balance }
  Future<FundSummary> getFundSummary({
    required String type,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/fund-summary',
        queryParameters: {'type': type, 'month': month, 'year': year},
      );
      return FundSummary.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── transferFunds ─────────────────────────────────────────
  // POST /api/admin/fund-transfers
  // Body: { amount, recipient_name, receipt_number, transfer_date, note }
  // Response: { message, transfer }
  Future<void> transferFunds({
    required double amount,
    required String recipientName,
    required String receiptNumber,
    required DateTime transferDate,
    required String note,
  }) async {
    try {
      await _dio.post('/admin/fund-transfers', data: {
        'amount': amount,
        'recipient_name': recipientName,
        'receipt_number': receiptNumber,
        'transfer_date':
        '${transferDate.year}-${transferDate.month.toString().padLeft(2, '0')}-${transferDate.day.toString().padLeft(2, '0')}',
        'note': note,
      });
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getCommission ─────────────────────────────────────────
  // GET /api/settings/commission
  // Response: { commission: double } أو { value: double }
  Future<CommissionSetting> getCommission() async {
    try {
      final response = await _dio.get('/settings/commission');
      return CommissionSetting.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── updateCommission ──────────────────────────────────────
  // POST /api/admin/settings/commission
  // Body: { commission: double }
  // Response: { message, commission }
  Future<CommissionSetting> updateCommission(double value) async {
    try {
      final response = await _dio.post(
        '/admin/settings/commission',
        data: {'commission_percentage': value},
      );
      return CommissionSetting.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  SubscriberReport _subscriberFromJson(Map<String, dynamic> json) {
    final monthsRaw = json['months'] as List;
    final months = monthsRaw.asMap().entries.map((e) {
      final s = e.value as String;
      return MonthPayment(
        monthNumber: e.key + 1,
        status: s == 'paid'
            ? PaymentStatus.paid
            : s == 'overdue'
            ? PaymentStatus.overdue
            : PaymentStatus.pending,
      );
    }).toList();

    return SubscriberReport(
      id: (json['id'] as num).toInt(),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      annualAmount: (json['annual_amount'] as num).toDouble(),
      monthlyAmount: (json['monthly_amount'] as num).toDouble(),
      months: months,
    );
  }

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
// داخل ملف admin_repository.dart

  Future<void> markHistoricalPaid({
    required int userId,
    required int year,
    required List<int> months,
    double? customAmount, // إضافة هذا الحقل
    String? note,
  }) async {
    try {
      await _dio.post('/admin/mark-historical-paid', data: {
        'user_id': userId,
        'year': year,
        'months': months,
        'custom_amount': customAmount, // إرساله للسيرفر
        'note': note,
      });
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }
  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'تعذر الاتصال، تحقق من الإنترنت';
    }
    final status = e.response?.statusCode;
    final rawData = _parseResponse(e.response?.data);
    final serverMessage = rawData['message'];
    if (status == 401) return 'غير مصرح لك بهذه العملية';
    if (status == 400) return serverMessage?.toString() ?? 'الرصيد غير كافٍ أو بيانات غير صحيحة';
    if (status != null && status >= 500) return 'خطأ في الخادم، يرجى المحاولة لاحقاً';
    return serverMessage?.toString() ?? 'خطأ في الخادم، يرجى المحاولة لاحقاً';
  }
}