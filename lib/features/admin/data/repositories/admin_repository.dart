// lib/features/admin/data/repositories/admin_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/admin_models.dart';
import '../../../../core/network/session_guard.dart';

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

    // 401 → مسح الجلسة والعودة تلقائياً لشاشة الدخول (انظر core/network/session_guard.dart)
    _dio.interceptors.add(SessionExpiredInterceptor());
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
      paidTotal: (json['paid_total'] as num?)?.toDouble() ?? 0,
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

  /// الخادم يتوقع entries = [{year, months}] — الشكل القديم (year/months في الجذر) كان يُرفض بخطأ 422.
  Future<void> markHistoricalPaid({
    required int userId,
    required int year,
    required List<int> months,
    double? customAmount,
    String? note,
  }) async {
    try {
      await _dio.post('/admin/mark-historical-paid', data: {
        'user_id': userId,
        'entries': [
          {'year': year, 'months': months},
        ],
        if (customAmount != null) 'custom_amount': customAmount,
        if (note != null) 'note': note,
      });
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getYearlyReport ───────────────────────────────────────
  // GET /api/admin/yearly-report?year=
  Future<YearlyReport> getYearlyReport({required int year}) async {
    try {
      final response =
      await _dio.get('/admin/yearly-report', queryParameters: {'year': year});
      return YearlyReport.fromJson(_parseResponse(response.data));
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // ── getReportYears ────────────────────────────────────────
  // GET /api/admin/report-years  → السنوات الموجودة فعلاً في البيانات
  // عند الفشل نرجع السنة الحالية فقط حتى لا تتعطل الشاشة.
  Future<List<int>> getReportYears() async {
    try {
      final response = await _dio.get('/admin/report-years');
      final list = _parseResponse(response.data)['years'] as List?;
      final years = (list ?? const []).map((e) => (e as num).toInt()).toList();
      if (years.isNotEmpty) return years;
    } catch (_) {}
    return [DateTime.now().year];
  }

  // ── Staff (الأدمن فقط) ────────────────────────────────────
  // GET /api/admin/staff
  Future<List<StaffMember>> getStaff() async {
    try {
      final response = await _dio.get('/admin/staff');
      final list = (_parseResponse(response.data)['data'] as List?) ?? const [];
      return list
          .map((e) => StaffMember.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // POST /api/admin/staff
  Future<StaffMember> createStaff({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role, // accountant
  }) async {
    try {
      final response = await _dio.post('/admin/staff', data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      });
      final data = _parseResponse(response.data)['data'] as Map;
      return StaffMember.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      throw AdminException(_mapDioError(e));
    }
  }

  // PATCH /api/admin/staff/{id}
  Future<StaffMember> updateStaff(
      int id, {
        String? fullName,
        String? role,
        bool? isActive,
        String? password,
      }) async {
    try {
      final response = await _dio.patch('/admin/staff/$id', data: {
        if (fullName != null) 'full_name': fullName,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      final data = _parseResponse(response.data)['data'] as Map;
      return StaffMember.fromJson(data.cast<String, dynamic>());
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
    if (status == 401) return 'انتهت الجلسة أو لا تملك صلاحية، سجّل الدخول من جديد';
    if (status == 403) return serverMessage?.toString() ?? 'ليست لديك صلاحية لهذه العملية';
    if (status == 400) return serverMessage?.toString() ?? 'الرصيد غير كافٍ أو بيانات غير صحيحة';
    if (status != null && status >= 500) return 'خطأ في الخادم، يرجى المحاولة لاحقاً';
    return serverMessage?.toString() ?? 'خطأ في الخادم، يرجى المحاولة لاحقاً';
  }
}