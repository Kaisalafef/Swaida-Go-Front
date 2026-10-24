// lib/core/network/session_guard.dart
//
// معالجة مركزية لانتهاء الجلسة (HTTP 401).
//
// المشكلة: بعد تعطيل حساب أو تغيير دوره أو بريده يُلغي الخادم توكناته، فيرجع 401،
// لكن التطبيق كان يبقي التوكن القديم في التخزين الآمن؛ فيظن الـ router أن المستخدم
// ما زال مسجّلاً، وتفشل كل الطلبات برسالة «انتهت الجلسة» حتى يسجّل الخروج يدوياً.
//
// الحل: عند 401 على طلب كان يحمل توكناً فعلاً → نمسح الجلسة ونُعيد المستخدم
// إلى /login مع رسالة، تلقائياً.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionGuard {
  SessionGuard._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// يُزاد عند انتهاء الجلسة. الـ router يستمع إليه (refreshListenable)
  /// فيُعيد تقييم الوجهة ويرسل المستخدم إلى /login.
  static final ValueNotifier<int> expiredTick = ValueNotifier<int>(0);

  static bool _expired = false;
  static bool _handling = false;

  /// هل انتهت الجلسة للتو ولم تُعرض الرسالة بعد؟ (يقرؤه الـ router فقط)
  static bool get expired => _expired;

  /// تستدعيها شاشة الدخول مرة واحدة: ترجع true إن كان يجب عرض
  /// رسالة «انتهت جلستك»، وتُصفّر العلامة.
  static bool consumeExpiredNotice() {
    final was = _expired;
    _expired = false;
    return was;
  }

  /// مسارات لا يعني فيها 401 «انتهاء جلسة»:
  ///  - /login: 401 = بيانات دخول خاطئة (والطلب قد يحمل توكناً قديماً).
  ///  - /logout: المستخدم يخرج بإرادته؛ لا نريد رسالة «انتهت الجلسة».
  ///  - /register و /auth/*: مسارات عامة.
  static bool _isPublicPath(String path) {
    return path.endsWith('/login') ||
        path.endsWith('/logout') ||
        path.endsWith('/register') ||
        path.contains('/auth/');
  }

  static Future<void> handleUnauthorized(RequestOptions request) async {
    if (_handling) return;
    if (_isPublicPath(request.uri.path)) return;

    // لا نتصرف إلا إن كان الطلب قد أُرسل بتوكن فعلاً.
    final header = request.headers['Authorization']?.toString() ?? '';
    final sentToken = header.replaceFirst('Bearer ', '').trim();
    if (sentToken.isEmpty) return;

    _handling = true;
    try {
      // إن كان التوكن المخزَّن اليوم مختلفاً عمّا أُرسل (سجّل المستخدم دخوله
      // من جديد أثناء وجود طلب قديم في الطريق) فهذا 401 قديم: لا نمسح الجلسة الجديدة.
      final stored = await _storage.read(key: 'auth_token');
      if (stored == null || stored.isEmpty || stored != sentToken) return;

      await _storage.deleteAll(); // نفس ما يفعله logout()
      _expired = true;
      expiredTick.value++; // ← الـ router يُعيد التوجيه إلى /login
    } catch (_) {
      // لا نكسر تدفق الخطأ الأصلي بسبب فشل التخزين.
    } finally {
      _handling = false;
    }
  }
}

/// أضِفه إلى كل مثيل Dio يرسل توكناً، بعد interceptor إضافة الـ Authorization:
///   _dio.interceptors.add(SessionExpiredInterceptor());
class SessionExpiredInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // لا ننتظر: الخطأ الأصلي يكمل طريقه للشاشة كالمعتاد.
      SessionGuard.handleUnauthorized(err.requestOptions);
    }
    handler.next(err);
  }
}
