// lib/features/auth/data/repositories/auth_repository.dart
//
// ══════════════════════════════════════════════════════════
//  🔧 MOCK MODE — للتطوير فقط قبل اكتمال الـ API
//  لتفعيل الـ API الحقيقي: غيّر   _kUseMock = false
// ══════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_strings.dart';

// ── تغيير هذا السطر فقط عند الانتقال للـ API الحقيقي ──────
const bool _kUseMock = true;
// ──────────────────────────────────────────────────────────

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository() {
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
  //  MOCK HELPERS
  // ══════════════════════════════════════════════════════

  Future<void> _mockDelay([int ms = 1200]) =>
      Future.delayed(Duration(milliseconds: ms));

  // كاونتر للـ polling — بعد 3 استدعاءات (~15 ثانية) يعتبر الإيميل verified
  int _emailPollCount = 0;

  // ══════════════════════════════════════════════════════
  //  REGISTER
  // ══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      await _storage.write(key: 'auth_token', value: 'mock_token_123');
      await _storage.write(key: 'user_email', value: email);
      await _storage.write(key: 'user_phone', value: phone);
      _emailPollCount = 0;
      return {
        'token': 'mock_token_123',
        'user': {'email': email, 'phone': phone, 'full_name': fullName},
      };
    }

    try {
      final response = await _dio.post('/api/register', data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
      });
      final data = _parseResponse(response.data);
      if (data['token'] != null) {
        await _storage.write(key: 'auth_token', value: data['token'].toString());
      }
      if (data['user']?['email'] != null) {
        await _storage.write(key: 'user_email', value: data['user']['email'].toString());
      }
      if (data['user']?['phone'] != null) {
        await _storage.write(key: 'user_phone', value: data['user']['phone'].toString());
      }
      return data;
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  EMAIL VERIFICATION (polling)
  //  Mock: يعود بـ true بعد 3 استدعاءات (~15 ثانية)
  // ══════════════════════════════════════════════════════
  Future<bool> checkEmailVerification() async {
    if (_kUseMock) {
      await _mockDelay(400);
      _emailPollCount++;
      return _emailPollCount >= 3;
    }

    try {
      final response = await _dio.get('/api/auth/email-verification-status');
      final data = _parseResponse(response.data);
      return data['email_verified'] == true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return false;
      }
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  RESEND VERIFICATION EMAIL
  // ══════════════════════════════════════════════════════
  Future<void> resendVerificationEmail() async {
    if (_kUseMock) {
      await _mockDelay(800);
      _emailPollCount = 0;
      return;
    }

    try {
      await _dio.post('/api/auth/resend-verification');
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  VERIFY PHONE OTP
  //  Mock: الرمز الصحيح هو 123456
  // ══════════════════════════════════════════════════════
  Future<void> verifyPhone(String otp) async {
    if (_kUseMock) {
      await _mockDelay();
      if (otp != '123456') {
        throw const AuthException('الرمز غير صحيح — استخدم 123456 للاختبار');
      }
      return;
    }

    try {
      await _dio.post('/api/verify-phone', data: {'otp': otp});
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  RESEND OTP
  // ══════════════════════════════════════════════════════
  Future<void> resendOtp() async {
    if (_kUseMock) {
      await _mockDelay(800);
      return;
    }

    try {
      await _dio.post('/api/auth/resend-otp');
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  LOGIN
  //  Mock: أي إيميل + كلمة مرور تعمل
  // ══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      await _storage.write(key: 'auth_token', value: 'mock_token_123');
      return {
        'token': 'mock_token_123',
        'user': {'email': email},
      };
    }

    try {
      final response = await _dio.post('/api/login', data: {
        'email': email,
        'password': password,
      });
      final data = _parseResponse(response.data);
      if (data['token'] != null) {
        await _storage.write(key: 'auth_token', value: data['token'].toString());
      }
      return data;
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  LOGOUT
  // ══════════════════════════════════════════════════════
  Future<void> logout() async {
    if (!_kUseMock) {
      try {
        await _dio.post('/api/logout');
      } catch (_) {}
    }
    await _storage.deleteAll();
  }

  // ── Stored values ─────────────────────────────────────
  Future<String?> getToken() => _storage.read(key: 'auth_token');
  Future<String?> getUserEmail() => _storage.read(key: 'user_email');
  Future<String?> getUserPhone() => _storage.read(key: 'user_phone');

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
      return AppStrings.errNetwork;
    }

    final status = e.response?.statusCode;
    final rawData = _parseResponse(e.response?.data);
    final serverMessage = rawData['message'];

    if (status == 401) return AppStrings.errUnauthorized;
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
      return AppStrings.errValidation;
    }
    if (status != null && status >= 500) return AppStrings.errServer;

    return serverMessage?.toString() ?? AppStrings.errServer;
  }

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}