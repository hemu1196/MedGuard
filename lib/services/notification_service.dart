import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    await init();
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
    return true;
  }

  Future<void> scheduleMedicineReminder({
    required String medicineName,
    required String time,
  }) async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for daily scheduled medicines',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = medicineName.hashCode.abs() % 10000;
    await _notificationsPlugin.show(
      notificationId,
      'Medication Reminder: $medicineName',
      'Time to take your scheduled dose ($time)',
      details,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'medguard_general',
      'General Notifications',
      channelDescription: 'MedGuard General Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }

  Future<void> scheduleAppointmentNotifications({
    required int baseNotificationId,
    required String doctorName,
    required String hospitalOrClinic,
    required DateTime appointmentDate,
    required List<int> reminderOffsets,
  }) async {
    if (kIsWeb) return;
    await init();

    final timeStr = DateFormat('hh:mm a').format(appointmentDate);
    final dateStr = DateFormat('MMM dd').format(appointmentDate);
    final placeStr = hospitalOrClinic.isNotEmpty ? ' at $hospitalOrClinic' : '';

    for (final offset in reminderOffsets) {
      final notifId = (baseNotificationId + offset) % 100000;
      String timingText = 'soon';
      if (offset == 1440) {
        timingText = 'tomorrow';
      } else if (offset == 180) {
        timingText = 'in 3 hours';
      } else if (offset == 60) {
        timingText = 'in 1 hour';
      } else if (offset == 30) {
        timingText = 'in 30 minutes';
      } else if (offset == 0) {
        timingText = 'now';
      }

      final title = 'Doctor Visit Reminder ($timingText)';
      final body =
          'Appointment with Dr. $doctorName$placeStr scheduled for $dateStr at $timeStr.';

      await scheduleNotification(
        id: notifId,
        title: title,
        body: body,
        scheduledTime: appointmentDate.subtract(Duration(minutes: offset)),
      );
    }
  }

  Future<void> cancelAppointmentNotifications({
    required int baseNotificationId,
    required List<int> reminderOffsets,
  }) async {
    if (kIsWeb) return;
    await cancelNotification(baseNotificationId % 100000);
    for (final offset in reminderOffsets) {
      final notifId = (baseNotificationId + offset) % 100000;
      await cancelNotification(notifId);
    }
  }
}
