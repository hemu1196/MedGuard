import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType {
  medicine,
  appointment,
  emergency,
  healthTip,
  general,
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  bool isRead;
  final String? targetRoute;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'targetRoute': targetRoute,
      };

  factory InAppNotificationItem.fromJson(Map<String, dynamic> json) {
    return InAppNotificationItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      targetRoute: json['targetRoute'],
    );
  }
}

class InAppNotificationService extends ChangeNotifier {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal() {
    loadNotifications();
  }

  static const String _storageKey = 'medguard_in_app_notifications_v1';
  List<InAppNotificationItem> _items = [];
  bool _initialized = false;

  List<InAppNotificationItem> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  List<InAppNotificationItem> get unreadItems =>
      _items.where((item) => !item.isRead).toList();

  List<InAppNotificationItem> get todayItems {
    final now = DateTime.now();
    return _items.where((item) {
      return item.createdAt.year == now.year &&
          item.createdAt.month == now.month &&
          item.createdAt.day == now.day;
    }).toList();
  }

  List<InAppNotificationItem> get earlierItems {
    final now = DateTime.now();
    return _items.where((item) {
      return !(item.createdAt.year == now.year &&
          item.createdAt.month == now.month &&
          item.createdAt.day == now.day);
    }).toList();
  }

  Future<void> loadNotifications() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _items = decoded
            .map((e) => InAppNotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        // Seed initial notifications so the Notification Center is functional out-of-the-box
        _items = [
          InAppNotificationItem(
            id: 'init_welcome',
            title: 'Welcome to MEDGUARD!',
            body: 'Your intelligent health and emergency companion is ready to protect you.',
            type: NotificationType.general,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            isRead: false,
          ),
          InAppNotificationItem(
            id: 'init_med_tip',
            title: 'Medicine Tracking Active',
            body: 'Schedule your prescription reminders to receive exact alarm notifications.',
            type: NotificationType.medicine,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: false,
            targetRoute: '/medicines',
          ),
          InAppNotificationItem(
            id: 'init_health_tip',
            title: 'Daily Health Tip',
            body: 'Stay hydrated and check your BMI regularly for optimal wellness.',
            type: NotificationType.healthTip,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
            targetRoute: '/water-intake',
          ),
        ];
        await _save();
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[IN_APP_NOTIFICATIONS] Load error: $e');
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? targetRoute,
  }) async {
    final newItem = InAppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      targetRoute: targetRoute,
    );
    _items.insert(0, newItem);
    await _save();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1 && !_items[index].isRead) {
      _items[index].isRead = true;
      await _save();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (final item in _items) {
      item.isRead = true;
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[IN_APP_NOTIFICATIONS] Save error: $e');
    }
  }
}
