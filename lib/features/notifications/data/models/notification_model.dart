// lib/features/notifications/data/models/notification_model.dart

class AppNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  String get title => data['title'] as String? ?? 'إشعار جديد';
  String get body  => data['body']  as String? ?? '';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final Map<String, dynamic> dataMap = rawData is String
        ? Map<String, dynamic>.from(
      // Laravel يخزّن الـ data كـ JSON string أحياناً
        (rawData.isNotEmpty
            ? (throw UnimplementedError()) // سيُعالَج أدناه
            : {}))
        : Map<String, dynamic>.from(rawData as Map? ?? {});

    return AppNotification(
      id:        json['id'] as String,
      type:      json['type'] as String? ?? '',
      data:      dataMap,
      readAt:    json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  /// بما أن Laravel يُعيد data كـ Map مباشرة (بعد cast)
  static AppNotification fromJsonSafe(Map<String, dynamic> json) {
    final raw = json['data'];
    Map<String, dynamic> dataMap;
    if (raw is Map) {
      dataMap = Map<String, dynamic>.from(raw);
    } else {
      dataMap = {};
    }
    return AppNotification(
      id:        json['id'] as String,
      type:      json['type'] as String? ?? '',
      data:      dataMap,
      readAt:    json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}