import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/appointment.dart';
import '../models/medicine.dart';
import '../repositories/medicine_repository.dart';
import 'in_app_notification_service.dart';

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

class AppointmentAlertEvent {
  final String appointmentId;
  final String doctorName;
  final String hospitalOrClinic;
  final String scheduledTime;
  final DateTime timestamp;

  AppointmentAlertEvent({
    required this.appointmentId,
    required this.doctorName,
    required this.hospitalOrClinic,
    required this.scheduledTime,
    DateTime? timestamp,
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

  final StreamController<AppointmentAlertEvent> _appointmentAlertController =
      StreamController<AppointmentAlertEvent>.broadcast();

  Stream<MedicineAlertEvent> get onMedicineAlert => _alertController.stream;
  Stream<AppointmentAlertEvent> get onAppointmentAlert =>
      _appointmentAlertController.stream;

  bool _initialized = false;
  final Map<int, Timer> _webTimers = {};

  static const String _scheduledMedicineIdsPrefix = 'medguard_scheduled_ids_med_';
  static const String _scheduledApptIdsPrefix = 'medguard_scheduled_ids_appt_';

  // Stable Versioned Notification Channels (Android 8.0+ / API 26+)
  static const String medicineChannelId = 'medguard_medicine_alerts_v2';
  static const String medicineChannelName = 'MEDGUARD Medicine Reminders';
  static const String medicineChannelDesc =
      'High-priority audible and vibration alarms for scheduled medications';

  static const String appointmentChannelId = 'medguard_appointment_alerts_v2';
  static const String appointmentChannelName = 'MEDGUARD Appointment Alerts';
  static const String appointmentChannelDesc =
      'High-priority alerts for upcoming doctor visits and clinical consultations';

  // Base IDs for non-colliding notification ranges
  static const int _medicineIdBase = 100000;
  static const int _appointmentIdBase = 500000;
  static const int _idRange = 400000;

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
      // Use monochrome drawable icon in res/drawable/ic_notification.xml
      const androidSettings =
          AndroidInitializationSettings('ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      try {
        final initOk = await _notificationsPlugin.initialize(
          settings,
          onDidReceiveNotificationResponse: _handleNotificationResponse,
        );
        debugPrint('[NOTIFICATION SERVICE] Native notification plugin init status: $initOk');

        // Create dedicated Android notification channels with MAX importance
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          // Channel 1: High Priority Medicine Alarms (V2)
          const medicineChannel = AndroidNotificationChannel(
            medicineChannelId,
            medicineChannelName,
            description: medicineChannelDesc,
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
            enableLights: true,
          );
          await androidImpl.createNotificationChannel(medicineChannel);

          // Channel 2: High Priority Appointment Reminders (V2)
          const appointmentChannel = AndroidNotificationChannel(
            appointmentChannelId,
            appointmentChannelName,
            description: appointmentChannelDesc,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            showBadge: true,
            enableLights: true,
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

        // Check if application was launched via tapping a notification while terminated
        try {
          final launchDetails =
              await _notificationsPlugin.getNotificationAppLaunchDetails();
          if (launchDetails != null &&
              launchDetails.didNotificationLaunchApp &&
              launchDetails.notificationResponse != null) {
            Future.microtask(() =>
                _handleNotificationResponse(launchDetails.notificationResponse!));
          }
        } catch (launchErr) {
          debugPrint('[NOTIFICATION SERVICE] Launch details check note: $launchErr');
        }
      } catch (pluginErr) {
        debugPrint('[NOTIFICATION SERVICE] Native notifications init note: $pluginErr');
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

      // Direct action button triggers from OS tray
      if (response.actionId == 'action_taken') {
        MedicineRepository().logMedicationDose(
          medicineId: medicineId,
          scheduledTime: scheduledTime,
          status: 'taken',
        );
      } else if (response.actionId == 'action_skip') {
        MedicineRepository().logMedicationDose(
          medicineId: medicineId,
          scheduledTime: scheduledTime,
          status: 'skipped',
        );
      } else if (response.actionId == 'action_snooze') {
        scheduleExactMedicineReminder(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          timeStr: scheduledTime,
          snoozeMinutes: 10,
        );
      }

      _alertController.add(
        MedicineAlertEvent(
          medicineId: medicineId,
          medicineName: medicineName,
          dosage: dosage,
          scheduledTime: scheduledTime,
        ),
      );
    } else if (parts.length >= 3 && parts[0] == 'appointment') {
      final appointmentId = parts[1];
      final doctorName = parts[2];
      final timeStr = parts.length > 3 ? parts[3] : '';

      _appointmentAlertController.add(
        AppointmentAlertEvent(
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalOrClinic: '',
          scheduledTime: timeStr,
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

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return true;
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return (await androidImpl.areNotificationsEnabled()) ?? false;
    }
    return true;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return true;
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return (await androidImpl.canScheduleExactNotifications()) ?? false;
    }
    return true;
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return [];
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Error fetching pending notifications: $e');
      return [];
    }
  }

  int generateMedicineNotifId(String medicineId, String timeStr) {
    final combined = '$medicineId|$timeStr';
    return _medicineIdBase + ((combined.hashCode.abs()) % _idRange);
  }

  int generateAppointmentNotifId(String appointmentId, int offset) {
    final hash = (appointmentId.hashCode.abs() * 31 + offset) & 0x7FFFFFFF;
    return _appointmentIdBase + (hash % _idRange);
  }

  /// Parses 12-hour (1:03 PM, 01:03 PM, 1:03\u202fPM) or 24-hour (13:03) time strings
  /// returning (hour, minute) in 24-hour format.
  static (int, int) parseTimeParts(String timeStr) {
    final normalized =
        timeStr.replaceAll(RegExp(r'[\s\u00A0\u202F\u2007\u200B]+'), ' ').trim();
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?(?:\s*([APap][Mm]))?')
            .firstMatch(normalized);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3)?.toUpperCase();
      if (ampm == 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }
      return (hour, minute);
    }
    return (8, 0);
  }

  /// Computes the exact next future occurrence as a TZDateTime.
  tz.TZDateTime computeNextScheduledTzTime({
    required String timeStr,
    DateTime? startDate,
    int? snoozeMinutes,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    if (snoozeMinutes != null && snoozeMinutes > 0) {
      return now.add(Duration(minutes: snoozeMinutes));
    }

    final (targetHour, targetMinute) = parseTimeParts(timeStr);

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
    }

    // Crucial: Never schedule in the past silently. If target time already passed today, advance to next day.
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Schedules an exact-time medicine reminder with high-priority sound,
  /// vibration, and action payload.
  Future<bool> scheduleExactMedicineReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String timeStr,
    String frequency = 'Daily',
    DateTime? startDate,
    int? snoozeMinutes,
  }) async {
    await init();

    final scheduledTzTime = computeNextScheduledTzTime(
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
      medicineChannelId,
      medicineChannelName,
      channelDescription: medicineChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      icon: 'ic_notification',
      color: Color(0xFF0D9488),
      enableVibration: true,
      playSound: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'MEDGUARD Medicine Reminder',
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

    // Select repeat match based on frequency
    DateTimeComponents? matchComponents;
    if (snoozeMinutes != null && snoozeMinutes > 0) {
      matchComponents = null; // One-time snooze
    } else if (frequency.toLowerCase() == 'weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (frequency.toLowerCase() == 'once') {
      matchComponents = null;
    } else {
      // Default daily recurrence
      matchComponents = DateTimeComponents.time;
    }

    bool scheduled = false;
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
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      scheduled = true;
      debugPrint(
        '[NOTIFICATION SERVICE] Exactly scheduled reminder for "$medicineName" at ${scheduledTzTime.toLocal()} (ID: $notifId, Mode: exactAllowWhileIdle, Match: $matchComponents)',
      );
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] zonedSchedule exact mode note: $e. Falling back to inexact...');
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
          matchDateTimeComponents: matchComponents,
          payload: payload,
        );
        scheduled = true;
        debugPrint(
          '[NOTIFICATION SERVICE] Inexact scheduled reminder for "$medicineName" at ${scheduledTzTime.toLocal()} (ID: $notifId)',
        );
      } catch (err) {
        debugPrint('[NOTIFICATION SERVICE] Inexact schedule failed: $err');
      }
    }

    // In-app backup trigger when app remains active
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

    // Verify presence in Android's pending notification request queue
    if (!kIsWeb) {
      final pending = await getPendingNotifications();
      final isFound = pending.any((p) => p.id == notifId);
      debugPrint('[NOTIFICATION SERVICE] Pending alarm verification: ${isFound ? "VERIFIED IN QUEUE" : "NOT FOUND"} (ID: $notifId, Total pending: ${pending.length})');
    }

    return scheduled;
  }

  /// Cancels all scheduled reminder alarms for a given medicine
  Future<void> cancelMedicineReminders(String medicineId) async {
    final scheduledIds = await _getRecordedIds(_scheduledMedicineIdsPrefix, medicineId);
    for (final id in scheduledIds) {
      _webTimers[id]?.cancel();
      if (!kIsWeb) {
        try {
          await _notificationsPlugin.cancel(id);
        } catch (_) {}
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
      try {
        await _notificationsPlugin.cancel(notifId);
      } catch (_) {}
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
        final notifId = generateAppointmentNotifId(appointmentId, offset);
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

        if (kIsWeb) {
          final diff = scheduledTime.difference(DateTime.now());
          if (!diff.isNegative) {
            _webTimers[notifId]?.cancel();
            _webTimers[notifId] = Timer(diff, () {
              InAppNotificationService().addNotification(
                title: title,
                body: body,
                type: NotificationType.appointment,
                targetRoute: '/appointments',
              );
            });
          }
          continue;
        }

        final scheduledTz = tz.TZDateTime.from(scheduledTime, tz.local);
        const androidDetails = AndroidNotificationDetails(
          appointmentChannelId,
          appointmentChannelName,
          channelDescription: appointmentChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_notification',
          color: Color(0xFF0D9488),
          playSound: true,
          enableVibration: true,
          channelShowBadge: true,
          visibility: NotificationVisibility.public,
        );
        const details = NotificationDetails(android: androidDetails);
        final payload = 'appointment|$appointmentId|$doctorName|$timeStr';

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
            payload: payload,
          );
          debugPrint(
            '[NOTIFICATION SERVICE] Scheduled appointment reminder (ID: $notifId) for $scheduledTime (Mode: exactAllowWhileIdle)',
          );
        } catch (e) {
          debugPrint('[NOTIFICATION SERVICE] Exact appointment schedule note: $e. Falling back to inexact...');
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
              payload: payload,
            );
            debugPrint(
              '[NOTIFICATION SERVICE] Inexact appointment reminder scheduled (ID: $notifId) for $scheduledTime',
            );
          } catch (_) {}
        }

        final pending = await getPendingNotifications();
        final isFound = pending.any((p) => p.id == notifId);
        debugPrint('[NOTIFICATION SERVICE] Pending appt verification: ${isFound ? "VERIFIED IN QUEUE" : "NOT FOUND"} (ID: $notifId)');
      }
    }
  }

  /// Cancels all scheduled reminder alarms for an appointment
  Future<void> cancelAppointmentNotifications(String appointmentId) async {
    final scheduledIds = await _getRecordedIds(_scheduledApptIdsPrefix, appointmentId);
    for (final id in scheduledIds) {
      _webTimers[id]?.cancel();
      if (!kIsWeb) {
        try {
          await _notificationsPlugin.cancel(id);
        } catch (_) {}
      }
    }
    await _clearRecordedIds(_scheduledApptIdsPrefix, appointmentId);
    debugPrint('[NOTIFICATION SERVICE] Cancelled appointment reminders for: $appointmentId');
  }

  /// Cancels all scheduled reminder alarms across all medicines and appointments
  Future<void> cancelAllScheduledReminders() async {
    for (final timer in _webTimers.values) {
      timer.cancel();
    }
    _webTimers.clear();

    if (!kIsWeb) {
      try {
        await _notificationsPlugin.cancelAll();
      } catch (e) {
        debugPrint('[NOTIFICATION SERVICE] cancelAll note: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith(_scheduledMedicineIdsPrefix) ||
          k.startsWith(_scheduledApptIdsPrefix));
      for (final key in keys.toList()) {
        await prefs.remove(key);
      }
    } catch (_) {}

    debugPrint('[NOTIFICATION SERVICE] Cancelled all scheduled reminders.');
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
          frequency: med.frequency,
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

  // --- Diagnostic Methods (Phase 2 & Phase 3) ---

  /// Phase 2 Diagnostic: Immediate system notification posting
  Future<bool> showImmediateDiagnosticNotification({
    String title = 'MEDGUARD — Android Notification Test',
    String body = 'Android system notifications are configured.',
  }) async {
    await init();
    if (kIsWeb) {
      debugPrint('[NOTIFICATION DIAGNOSTIC] Web immediate notification stub');
      return true;
    }

    const androidDetails = AndroidNotificationDetails(
      medicineChannelId,
      medicineChannelName,
      channelDescription: medicineChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      icon: 'ic_notification',
      color: Color(0xFF0D9488),
      enableVibration: true,
      playSound: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'MEDGUARD Diagnostic Alert',
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
      await _notificationsPlugin.show(
        999999,
        title,
        body,
        details,
        payload: 'diagnostic_immediate',
      );
      debugPrint('[NOTIFICATION DIAGNOSTIC] Immediate system notification posted successfully (ID: 999999)');
      return true;
    } catch (e) {
      debugPrint('[NOTIFICATION DIAGNOSTIC] Immediate notification posting error: $e');
      return false;
    }
  }

  /// Phase 3 Diagnostic: Native scheduled system notification (2 minutes ahead)
  Future<bool> scheduleDiagnosticNotification({
    int minutesAhead = 2,
    String title = 'MEDGUARD — Scheduled Diagnostic Test',
    String? body,
  }) async {
    await init();
    final fireTime = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesAhead));
    final notifBody = body ??
        'Diagnostic reminder scheduled $minutesAhead min ago arrived successfully in system shade.';

    if (kIsWeb) {
      debugPrint('[NOTIFICATION DIAGNOSTIC] Web scheduled notification stub');
      return true;
    }

    const androidDetails = AndroidNotificationDetails(
      medicineChannelId,
      medicineChannelName,
      channelDescription: medicineChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      icon: 'ic_notification',
      color: Color(0xFF0D9488),
      enableVibration: true,
      playSound: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'MEDGUARD Scheduled Diagnostic',
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
        999998,
        title,
        notifBody,
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'diagnostic_scheduled',
      );
      debugPrint('[NOTIFICATION DIAGNOSTIC] Scheduled diagnostic alarm for $fireTime (ID: 999998, exactAllowWhileIdle)');
      return true;
    } catch (e) {
      debugPrint('[NOTIFICATION DIAGNOSTIC] Exact mode failed ($e), falling back to inexact...');
      try {
        await _notificationsPlugin.zonedSchedule(
          999998,
          title,
          notifBody,
          fireTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'diagnostic_scheduled',
        );
        debugPrint('[NOTIFICATION DIAGNOSTIC] Scheduled diagnostic alarm (inexact) for $fireTime (ID: 999998)');
        return true;
      } catch (err) {
        debugPrint('[NOTIFICATION DIAGNOSTIC] Scheduled diagnostic failed: $err');
        return false;
      }
    }
  }
}
