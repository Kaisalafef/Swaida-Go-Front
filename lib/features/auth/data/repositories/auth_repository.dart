// lib/features/auth/data/repositories/auth_repository.dart
//
// ══════════════════════════════════════════════════════════
//  الـ Flow الكامل (يوافق AuthController.php):
//
//  1. register()                → POST /register  {full_name, email, phone, password, fcm_token}
//                                  ↳ Laravel يُرسل رابط توثيق بريد تلقائياً
//                                  ↳ لا يُعاد token هنا
//  2. checkEmailVerification()  → GET  /auth/email-verification-status?email=...
//                                  ↳ Flutter يستدعيه كل 5 ثوانٍ (Polling)
//                                  ↳ يُعاد access_token هنا بعد التوثيق
//  3. resendVerificationEmail() → POST /auth/resend-email-verification
//  4. login()                   → POST /login  {email, password}
//                                  ↳ يُعاد access_token + role هنا
// ══════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/session_guard.dart';

// ── تغيير هذا السطر فقط عند الانتقال للـ API الحقيقي ──────
const bool _kUseMock = false;
// ─────────────────────────────────────────────────────────

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

    // 401 → مسح الجلسة والعودة تلقائياً لشاشة الدخول (انظر core/network/session_guard.dart)
    _dio.interceptors.add(SessionExpiredInterceptor());
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

  // ══════════════════════════════════════════════════════
  //  HELPER: قراءة FCM token بأمان مع logging
  // ══════════════════════════════════════════════════════
  Future<String?> _getFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      dev.log('[FCM] Permission: ${settings.authorizationStatus}', name: 'AuthRepo');

      final token = await FirebaseMessaging.instance.getToken();
      dev.log('[FCM] Token: ${token != null ? token.substring(0, 20) + "..." : "NULL"}', name: 'AuthRepo');
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (e) {
      dev.log('[FCM] getToken() فشل: $e', name: 'AuthRepo');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPER: إرسال FCM Token للسيرفر
  //  يجب استدعاؤه فقط بعد تأكيد حفظ auth_token في Storage
  //  الفشل لا يؤثر على تجربة المستخدم
  // ══════════════════════════════════════════════════════
  Future<void> _sendFcmToken() async {
    try {
      final fcmToken = await _getFcmToken();
      if (fcmToken == null) {
        dev.log('[FCM] لا يوجد token — تخطّي الإرسال', name: 'AuthRepo');
        return;
      }
      final authToken = await _storage.read(key: 'auth_token');
      if (authToken == null || authToken.isEmpty) {
        dev.log('[FCM] auth_token غير موجود في Storage — تخطّي الإرسال', name: 'AuthRepo');
        return;
      }
      dev.log('[FCM] إرسال FCM token للسيرفر...', name: 'AuthRepo');
      await _dio.post('/update-fcm-token', data: {'fcm_token': fcmToken});
      dev.log('[FCM] تم الإرسال بنجاح ✓', name: 'AuthRepo');
    } catch (e) {
      dev.log('[FCM] فشل الإرسال: $e', name: 'AuthRepo');
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPER: حفظ بيانات المستخدم في التخزين الآمن
  // ══════════════════════════════════════════════════════
  Future<void> _saveUserData(Map<dynamic, dynamic> user) async {
    final futures = <Future>[];
    if (user['phone'] != null) {
      futures.add(_storage.write(key: 'user_phone', value: user['phone'].toString()));
    }
    if (user['email'] != null) {
      futures.add(_storage.write(key: 'user_email', value: user['email'].toString()));
    }
    if (user['full_name'] != null) {
      futures.add(_storage.write(key: 'user_full_name', value: user['full_name'].toString()));
    }
    if (user['role'] != null) {
      futures.add(_storage.write(key: 'user_role', value: user['role'].toString()));
    }
    await Future.wait(futures);
  }

  // ══════════════════════════════════════════════════════
  //  1. REGISTER
  //     POST /register
  //     Returns: void  ← لا يُعاد token هنا إطلاقاً
  // ══════════════════════════════════════════════════════
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      await _storage.write(key: 'pending_email', value: email);
      return;
    }

    try {
      final fcmToken = await _getFcmToken();

      final response = await _dio.post('/register', data: {
        'full_name': fullName,
        'email':     email,
        'phone':     phone,
        'password':  password,
        if (fcmToken != null) 'fcm_token': fcmToken,
      });

      await _storage.write(key: 'pending_email', value: email);

      // تذكرة سرية من السيرفر: بدونها لا يُسلَّم توكن الدخول التلقائي بعد توثيق البريد
      // (كان أي شخص يعرف بريداً موثّقاً يحصل على توكنه).
      final data = _parseResponse(response.data);
      final ticket = data['verification_ticket']?.toString();
      if (ticket != null && ticket.isNotEmpty) {
        await _storage.write(key: 'verification_ticket', value: ticket);
      }
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  2. CHECK EMAIL VERIFICATION STATUS (Polling)
  //     GET /auth/email-verification-status?email=...
  //     Returns: bool
  //     عند التوثيق، السيرفر يُعيد access_token فنحفظه هنا مباشرةً
  // ══════════════════════════════════════════════════════
  Future<bool> checkEmailVerification() async {
    if (_kUseMock) {
      await _mockDelay(500);
      return false;
    }

    try {
      final email = await _storage.read(key: 'pending_email') ?? '';
      final ticket = await _storage.read(key: 'verification_ticket') ?? '';
      final response = await _dio.get(
        '/auth/email-verification-status',
        queryParameters: {'email': email, 'ticket': ticket},
      );
      final data = _parseResponse(response.data);
      final verified = data['email_verified'] == true;

      if (verified) {
        final token = data['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: 'auth_token', value: token);
          await _sendFcmToken();

          final user = data['user'];
          if (user is Map) await _saveUserData(user);

          await _storage.delete(key: 'pending_email');
          await _storage.delete(key: 'verification_ticket');
          return true;
        }
        // موثّق بلا توكن (لا يحدث مع التذكرة الصالحة) → لا ننتقل للشاشة التالية بلا جلسة
        return false;
      }

      return false;
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  3. RESEND EMAIL VERIFICATION
  //     POST /auth/resend-email-verification
  // ══════════════════════════════════════════════════════
  Future<void> resendVerificationEmail() async {
    if (_kUseMock) {
      await _mockDelay(800);
      return;
    }

    try {
      final email = await _storage.read(key: 'pending_email') ?? '';
      await _dio.post('/auth/resend-email-verification', data: {'email': email});
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ══════════════════════════════════════════════════════
  //  4. LOGIN
  //     POST /login  {email, password}
  //     Requires: email verified
  //     Returns: String (role) — لتحديد التوجيه في الشاشة
  // ══════════════════════════════════════════════════════
  Future<String> login({
    required String email,
    required String password,
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      await _storage.write(key: 'auth_token', value: 'mock_token_123');
      return 'subscriber';
    }

    try {
      final response = await _dio.post('/login', data: {
        'email':    email,
        'password': password,
      });
      final data = _parseResponse(response.data);

      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw const AuthException('لم يتم استلام رمز المصادقة من الخادم.');
      }

      await _storage.write(key: 'auth_token', value: token);
      await _sendFcmToken();

      String role = 'subscriber';
      final user = data['user'];
      if (user is Map) {
        await _saveUserData(user);
        if (user['role'] != null) role = user['role'].toString();
      }

      return role;
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
        await _dio.post('/logout');
      } catch (_) {}
    }
    await _storage.deleteAll();
  }

  // ── Stored values ─────────────────────────────────────
  Future<String?> getToken()        => _storage.read(key: 'auth_token');
  Future<String?> getUserPhone()    => _storage.read(key: 'user_phone');
  Future<String?> getUserEmail()    => _storage.read(key: 'user_email');
  Future<String?> getUserFullName() => _storage.read(key: 'user_full_name');
  Future<String?> getUserRole()     => _storage.read(key: 'user_role');
  Future<String?> getPendingEmail() => _storage.read(key: 'pending_email');

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
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

  // ══════════════════════════════════════════════════════
  //  5. FORGOT / RESET PASSWORD (رمز من 6 أرقام عبر البريد)
  //     POST /auth/forgot-password  {email}
  //     POST /auth/reset-password   {email, code, password}
  // ══════════════════════════════════════════════════════

  /// يطلب إرسال الرمز. الخادم يرد بنفس الرسالة سواء كان البريد مسجلاً أم لا.
  /// يُرجع عدد الثواني قبل السماح بإعادة الإرسال.
  Future<int> forgotPassword({required String email}) async {
    if (_kUseMock) {
      await _mockDelay();
      return 60;
    }
    try {
      final response =
      await _dio.post('/auth/forgot-password', data: {'email': email});
      final data = _parseResponse(response.data);
      final wait = data['resend_after_seconds'];
      return wait is num ? wait.toInt() : 60;
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  /// يعيّن كلمة المرور الجديدة بالرمز. لا يسجّل الدخول تلقائياً.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_kUseMock) {
      await _mockDelay();
      return;
    }
    try {
      await _dio.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'password': newPassword,
      });
    } on DioException catch (e) {
      throw AuthException(_mapDioError(e));
    }
  }

  // ── Error mapper ──────────────────────────────────────
  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return AppStrings.errNetwork;
    }

    final status    = e.response?.statusCode;
    final rawData   = _parseResponse(e.response?.data);
    final serverMsg = rawData['message'];

    if (status == 401) return AppStrings.errUnauthorized;

    if (status == 403) {
      if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
      return 'الوصول مرفوض.';
    }

    if (status == 422) {
      if (serverMsg is String && _isArabic(serverMsg)) return serverMsg;
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

    if (status == 429) {
      if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
      return 'طلبات كثيرة جداً. حاول لاحقاً.';
    }

    if (status == 400) {
      if (serverMsg is String && serverMsg.isNotEmpty) return serverMsg;
      return 'رمز التوثيق غير صحيح أو منتهي الصلاحية.';
    }

    if (status == 404) return 'المستخدم غير موجود.';

    if (status != null && status >= 500) return AppStrings.errServer;

    return serverMsg?.toString() ?? AppStrings.errServer;
  }

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}