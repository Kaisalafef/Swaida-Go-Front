// lib/features/notifications/data/repositories/notification_repository.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/notification_model.dart';

class NotificationRepository {
  static const String _baseUrl = 'https://sd-ku.com/api'; // ← غيّر للـ base URL الخاص بك

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> _getToken() => _storage.read(key: 'auth_token');

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// جلب كافة الإشعارات
  Future<List<AppNotification>> getAll() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/notifications'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => AppNotification.fromJsonSafe(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('فشل تحميل الإشعارات');
  }

  /// جلب عدد الإشعارات غير المقروءة فقط
  Future<List<AppNotification>> getUnread() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/notifications/unread'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => AppNotification.fromJsonSafe(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('فشل تحميل الإشعارات');
  }

  /// تحديد إشعار معين كمقروء
  Future<void> markAsRead(String id) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/notifications/$id/read'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw Exception('فشل تحديث الإشعار');
  }

  /// تحديد الكل كمقروء
  Future<void> markAllAsRead() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/notifications/read-all'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) throw Exception('فشل تحديث الإشعارات');
  }
}