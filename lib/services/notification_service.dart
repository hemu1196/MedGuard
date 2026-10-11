import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicineAlertEvent {
  final String medicineId;
  final String medicineName;
  final String dosage;
  final String scheduledTime;
  final DateTime timestamp;
  final int? snoozeMinutes;

  MedicineAlertEvent({
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.scheduledTime,
    DateTime? timestamp,
    this.snoozeMinutes,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<MedicineAlertEvent> _alertController =
      StreamController<MedicineAlertEvent>.broadcast();

  Stream<MedicineAlertEvent> get onMedicineAlert => _alertController.stream;

  bool _initialized = false;
  final Map<int, Timer> _webTimers = {};

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezone database
    try {
      tz.initializeTimeZones();
      // Default to local device timezone; fallback gracefully if not found
      final String currentTimeZone = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(currentTimeZone)) {
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
      } else {
        // Fallback to UTC or general offset
        tz.setLocalLocation(tz.local);
      }
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Timezone init fallback: $e');
    }

    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create dedicated high-priority medicine alert channel for Android
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        const medicineChannel = AndroidNotificationChannel(
          'medicine_alarms',
          'Medicine Alarms & Reminders',
          description:
              'High-priority audible and vibration alerts for scheduled medications',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidImpl.createNotificationChannel(medicineChannel);
      }
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length >= 4 && parts[0] == 'med_reminder') {
      final medicineId = parts[1];
      final medicineName = parts[2];
      final dosage = parts[3];
      final scheduledTime = parts.length > 4 ? parts[4] : '';

      _alertController.add(
        MedicineAlertEvent(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          scheduledTime: scheduledTime,
        ),
      );
    }
  }

  Future<bool> requestPermission() async {
    await init();
    if (kIsWeb) return true;

    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      // Request exact alarm permission if available (Android 12+)
      await androidImpl.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedules an exact-time medicine reminder with high-priority sound,
  /// vibration, and action payload.
  Future<bool> scheduleExactMedicineReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String timeStr,
    DateTime? startDate,
    int? snoozeMinutes,
  }) async {
    await init();

    final scheduledTzTime = _computeNextScheduledTzTime(
      timeStr: timeStr,
      startDate: startDate,
      snoozeMinutes: snoozeMinutes,
    );

    final notifId = (medicineId.hashCode.abs() + timeStr.hashCode.abs()) % 100000;
    final payload = 'med_reminder|$medicineId|$medicineName|$dosage|$timeStr';

    if (kIsWeb) {
      // Web scheduling: In-tab timer fallback to fire foreground modal
      final now = DateTime.now();
      final scheduledDateTime = scheduledTzTime.toLocal();
      final diff = scheduledDateTime.difference(now);

      if (diff.isNegative) return false;

      _webTimers[notifId]?.cancel();
      _webTimers[notifId] = Timer(diff, () {
        _alertController.add(
          MedicineAlertEvent(
            medicineId: medicineId,
            medicineName: medicineName,
            dosage: dosage,
            scheduledTime: timeStr,
            snoozeMinutes: snoozeMinutes,
          ),
        );
      });
      debugPrint('[NOTIFICATION SERVICE WEB] Scheduled reminder for $timeStr (in ${diff.inSeconds}s)');
      return true;
    }

    const androidDetails = AndroidNotificationDetails(
      'medicine_alarms',
      'Medicine Alarms & Reminders',
      channelDescription:
          'High-priority audible and vibration alerts for scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_taken',
          'TAKEN',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_snooze',
          'SNOOZE 10M',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_skip',
          'SKIP',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        notifId,
        'MEDGUARD Medicine Alert: $medicineName',
        'Time to take your scheduled dose: $dosage ($timeStr)',
        scheduledTzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      // Also set an in-app timer so that if the app is foregrounded, the popup opens seamlessly
      final diff = scheduledTzTime.toLocal().difference(DateTime.now());
      if (!diff.isNegative) {
        _webTimers[notifId]?.cancel();
        _webTimers[notifId] = Timer(diff, () {
          _alertController.add(
            MedicineAlertEvent(
              medicineId: medicineId,
              medicineName: medicineName,
              dosage: dosage,
              scheduledTime: timeStr,
              snoozeMinutes: snoozeMinutes,
            ),
          );
        });
      }

      debugPrint(
        '[NOTIFICATION SERVICE] Exactly scheduled reminder for "$medicineName" at ${scheduledTzTime.toLocal()} (ID: $notifId)',
      );
      return true;
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] zonedSchedule fallback to immediate: $e');
      // If exact alarm is blocked by OS permission, fallback to inexact schedule
      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          'MEDGUARD Medicine Alert: $medicineName',
          'Time to take your scheduled dose: $dosage ($timeStr)',
          scheduledTzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        return true;
      } catch (err) {
        debugPrint('[NOTIFICATION SERVICE] Inexact schedule failed: $err');
        return false;
      }
    }
  }

  /// Helper to compute next TZDateTime matching the target time string
  tz.TZDateTime _computeNextScheduledTzTime({
    required String timeStr,
    DateTime? startDate,
    int? snoozeMinutes,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    if (snoozeMinutes != null && snoozeMinutes > 0) {
      return now.add(Duration(minutes: snoozeMinutes));
    }

    int targetHour = 8;
    int targetMinute = 0;

    final trimmed = timeStr.trim();
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      targetHour = int.tryParse(parts[0]) ?? 8;
      final minutePart = parts[1].split(' ')[0];
      targetMinute = int.tryParse(minutePart) ?? 0;

      // Handle 12-hour AM/PM format
      final upper = trimmed.toUpperCase();
      if (upper.contains('PM') && targetHour < 12) {
        targetHour += 12;
      } else if (upper.contains('AM') && targetHour == 12) {
        targetHour = 0;
      }
    }

    tz.TZDateTime scheduledDate;
    if (startDate != null && startDate.isAfter(DateTime.now())) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        startDate.year,
        startDate.month,
        startDate.day,
        targetHour,
        targetMinute,
      );
    } else {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      // If scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }

    return scheduledDate;
  }

  /// Triggers a test reminder after a short 3-second delay so the user
  /// can verify sound, system notification, and foreground popup on their device.
  Future<void> testReminderNow({
    required String medicineId,
    required String medicineName,
    required String dosage,
  }) async {
    await init();
    final testTimeStr = DateFormat('hh:mm a').format(DateTime.now());

    if (!kIsWeb) {
      const androidDetails = AndroidNotificationDetails(
        'medicine_alarms',
        'Medicine Alarms & Reminders',
        channelDescription:
            'High-priority audible and vibration alerts for scheduled medications',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        99999,
        '🔔 TEST MEDGUARD Alert: $medicineName',
        'Time to take your scheduled dose: $dosage ($testTimeStr)',
        details,
        payload: 'med_reminder|$medicineId|$medicineName|$dosage|$testTimeStr',
      );
    }

    // Broadcast foreground alert popup
    Timer(const Duration(milliseconds: 500), () {
      _alertController.add(
        MedicineAlertEvent(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          scheduledTime: testTimeStr,
        ),
      );
    });
  }

  Future<void> cancelMedicineReminders(String medicineId) async {
    final notifIdBase = medicineId.hashCode.abs() % 100000;
    _webTimers[notifIdBase]?.cancel();
    if (!kIsWeb) {
      await _notificationsPlugin.cancel(notifIdBase);
    }
  }

  Future<void> cancelNotification(int id) async {
    _webTimers[id]?.cancel();
    if (!kIsWeb) {
      await _notificationsPlugin.cancel(id);
    }
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

      final scheduledTime = appointmentDate.subtract(Duration(minutes: offset));
      if (scheduledTime.isAfter(DateTime.now())) {
        final scheduledTz = tz.TZDateTime.from(scheduledTime, tz.local);
        const androidDetails = AndroidNotificationDetails(
          'medguard_general',
          'General Notifications',
          channelDescription: 'MedGuard General Alerts',
          importance: Importance.high,
          priority: Priority.high,
        );
        const details = NotificationDetails(android: androidDetails);

        try {
          await _notificationsPlugin.zonedSchedule(
            notifId,
            title,
            body,
            scheduledTz,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }
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
