import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/appointment.dart';
import '../models/medicine.dart';

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

  static const String _scheduledMedicineIdsPrefix = 'medguard_scheduled_ids_med_';
  static const String _scheduledApptIdsPrefix = 'medguard_scheduled_ids_appt_';

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Timezone database with real device IANA timezone
    try {
      tz.initializeTimeZones();
      String timeZoneName = 'UTC';
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        timeZoneName = tzInfo.identifier;
      } catch (tzErr) {
        debugPrint('[NOTIFICATION SERVICE] FlutterTimezone detection note: $tzErr');
      }

      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[NOTIFICATION SERVICE] Local timezone set to: $timeZoneName');
      } else {
        _setFallbackLocationByOffset();
      }
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Timezone init fallback: $e');
      _setFallbackLocationByOffset();
    }

    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create dedicated Android notification channels
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // Channel 1: High Priority Medicine Alarms
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

        // Channel 2: High Priority Appointment Reminders
        const appointmentChannel = AndroidNotificationChannel(
          'appointment_alarms',
          'Appointment Reminders',
          description:
              'High-priority alerts for upcoming doctor visits and clinical consultations',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        await androidImpl.createNotificationChannel(appointmentChannel);

        // Channel 3: General Alerts
        const generalChannel = AndroidNotificationChannel(
          'medguard_general',
          'General Notifications',
          description: 'MedGuard System and Health Announcements',
          importance: Importance.defaultImportance,
        );
        await androidImpl.createNotificationChannel(generalChannel);
      }
    }

    _initialized = true;
  }

  void _setFallbackLocationByOffset() {
    final offset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offset.inMilliseconds) {
        tz.setLocalLocation(loc);
        debugPrint('[NOTIFICATION SERVICE] Matched timezone by offset: ${loc.name}');
        return;
      }
    }
    tz.setLocalLocation(tz.local);
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
      try {
        await androidImpl.requestExactAlarmsPermission();
      } catch (exactErr) {
        debugPrint('[NOTIFICATION SERVICE] Exact alarm permission request note: $exactErr');
      }
      return granted ?? false;
    }
    return true;
  }

  int generateMedicineNotifId(String medicineId, String timeStr) {
    final combined = '$medicineId|$timeStr';
    return (combined.hashCode.abs()) % 100000;
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

    final notifId = generateMedicineNotifId(medicineId, timeStr);
    final payload = 'med_reminder|$medicineId|$medicineName|$dosage|$timeStr';

    // Store mapped ID for reliable cancellation
    await _recordScheduledId(_scheduledMedicineIdsPrefix, medicineId, notifId);

    if (kIsWeb) {
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

    const notifTitle = 'MEDGUARD — Medicine Reminder';
    final notifBody = "It's time for your scheduled medicine: $medicineName ($dosage).";

    try {
      await _notificationsPlugin.zonedSchedule(
        notifId,
        notifTitle,
        notifBody,
        scheduledTzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      // In-app fallback trigger when app is actively open
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
      debugPrint('[NOTIFICATION SERVICE] zonedSchedule fallback to inexact: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          notifTitle,
          notifBody,
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

  /// Helper to compute next TZDateTime matching target time string
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

  /// Cancels all scheduled reminder alarms for a given medicine
  Future<void> cancelMedicineReminders(String medicineId) async {
    final scheduledIds = await _getRecordedIds(_scheduledMedicineIdsPrefix, medicineId);
    for (final id in scheduledIds) {
      _webTimers[id]?.cancel();
      if (!kIsWeb) {
        await _notificationsPlugin.cancel(id);
      }
    }
    await _clearRecordedIds(_scheduledMedicineIdsPrefix, medicineId);
    debugPrint('[NOTIFICATION SERVICE] Cancelled all reminders for medicine: $medicineId (${scheduledIds.length} alarms)');
  }

  /// Cancels a specific time reminder for a medicine
  Future<void> cancelSingleMedicineTimeReminder(String medicineId, String timeStr) async {
    final notifId = generateMedicineNotifId(medicineId, timeStr);
    _webTimers[notifId]?.cancel();
    if (!kIsWeb) {
      await _notificationsPlugin.cancel(notifId);
    }
  }

  /// Schedules native OS notifications for an appointment
  Future<void> scheduleAppointmentNotifications({
    required String appointmentId,
    required String doctorName,
    required String hospitalOrClinic,
    required DateTime appointmentDate,
    required List<int> reminderOffsets,
  }) async {
    await init();

    final timeStr = DateFormat('hh:mm a').format(appointmentDate);
    final dateStr = DateFormat('MMM dd').format(appointmentDate);
    final placeStr = hospitalOrClinic.isNotEmpty ? ' at $hospitalOrClinic' : '';

    // First cancel any old reminders for this appointment
    await cancelAppointmentNotifications(appointmentId);

    for (final offset in reminderOffsets) {
      final scheduledTime = appointmentDate.subtract(Duration(minutes: offset));
      if (scheduledTime.isAfter(DateTime.now())) {
        final notifId = ((appointmentId.hashCode.abs() * 31 + offset) & 0x7FFFFFFF) % 100000;
        await _recordScheduledId(_scheduledApptIdsPrefix, appointmentId, notifId);

        String timingText = 'approaching';
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

        const title = 'MEDGUARD — Appointment Reminder';
        final body =
            'Your appointment with Dr. $doctorName$placeStr is scheduled for $dateStr at $timeStr ($timingText).';

        if (kIsWeb) continue;

        final scheduledTz = tz.TZDateTime.from(scheduledTime, tz.local);
        const androidDetails = AndroidNotificationDetails(
          'appointment_alarms',
          'Appointment Reminders',
          channelDescription:
              'High-priority alerts for upcoming doctor visits and clinical consultations',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
        const details = NotificationDetails(android: androidDetails);

        try {
          await _notificationsPlugin.zonedSchedule(
            notifId,
            title,
            body,
            scheduledTz,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'appointment|$appointmentId|$doctorName|$timeStr',
          );
          debugPrint(
            '[NOTIFICATION SERVICE] Scheduled appointment reminder (ID: $notifId) for $scheduledTime',
          );
        } catch (e) {
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
              payload: 'appointment|$appointmentId|$doctorName|$timeStr',
            );
          } catch (_) {}
        }
      }
    }
  }

  /// Cancels all scheduled reminder alarms for an appointment
  Future<void> cancelAppointmentNotifications(String appointmentId) async {
    final scheduledIds = await _getRecordedIds(_scheduledApptIdsPrefix, appointmentId);
    for (final id in scheduledIds) {
      _webTimers[id]?.cancel();
      if (!kIsWeb) {
        await _notificationsPlugin.cancel(id);
      }
    }
    await _clearRecordedIds(_scheduledApptIdsPrefix, appointmentId);
    debugPrint('[NOTIFICATION SERVICE] Cancelled appointment reminders for: $appointmentId');
  }

  /// Reconciles local notification schedules against user's active medicines and appointments
  Future<void> reconcileSchedules({
    required List<Medicine> medicines,
    required List<Appointment> appointments,
  }) async {
    await init();
    debugPrint('[NOTIFICATION SERVICE] Reconciling schedules: ${medicines.length} medicines, ${appointments.length} appointments');

    // 1. Reschedule all active medicines
    for (final med in medicines) {
      for (final time in med.reminderTimes) {
        await scheduleExactMedicineReminder(
          medicineId: med.id,
          medicineName: med.name,
          dosage: med.dosage,
          timeStr: time,
        );
      }
    }

    // 2. Reschedule all upcoming appointments
    for (final appt in appointments) {
      if (appt.status.toLowerCase() == 'upcoming' && appt.reminderEnabled) {
        await scheduleAppointmentNotifications(
          appointmentId: appt.id,
          doctorName: appt.doctorName,
          hospitalOrClinic: appt.hospitalOrClinic,
          appointmentDate: appt.appointmentDate,
          reminderOffsets: appt.selectedRemindersMinutes,
        );
      } else {
        await cancelAppointmentNotifications(appt.id);
      }
    }
  }

  // --- Internal SharedPreferences ID Tracker Helpers ---

  Future<void> _recordScheduledId(String prefix, String entityId, int notifId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$prefix$entityId';
      final existing = prefs.getStringList(key) ?? [];
      final idStr = notifId.toString();
      if (!existing.contains(idStr)) {
        existing.add(idStr);
        await prefs.setStringList(key, existing);
      }
    } catch (_) {}
  }

  Future<List<int>> _getRecordedIds(String prefix, String entityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$prefix$entityId';
      final raw = prefs.getStringList(key) ?? [];
      return raw.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _clearRecordedIds(String prefix, String entityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$prefix$entityId';
      await prefs.remove(key);
    } catch (_) {}
  }
}
