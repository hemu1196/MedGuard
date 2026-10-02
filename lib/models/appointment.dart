import 'dart:convert';

class Appointment {
  final String id;
  final String userId;
  final String doctorName;
  final String specialization;
  final String hospitalOrClinic;
  final DateTime appointmentDate;
  final String phoneNumber;
  final String address;
  final String notes;
  final bool reminderEnabled;
  final int reminderTimeMinutesBefore; // 0, 30, 60, 180, 1440
  final List<int> selectedRemindersMinutes; // e.g. [1440, 60, 30, 0]
  final String status; // Upcoming, Completed, Cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.specialization,
    this.hospitalOrClinic = '',
    required this.appointmentDate,
    this.phoneNumber = '',
    this.address = '',
    this.notes = '',
    this.reminderEnabled = true,
    this.reminderTimeMinutesBefore = 60,
    List<int>? selectedRemindersMinutes,
    this.status = 'Upcoming',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : selectedRemindersMinutes = selectedRemindersMinutes ?? [reminderTimeMinutesBefore],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  List<int> get reminderOffsets {
    if (selectedRemindersMinutes.isNotEmpty) {
      return selectedRemindersMinutes;
    }
    return [reminderTimeMinutesBefore];
  }

  DateTime get reminderDateTime {
    return appointmentDate.subtract(
      Duration(minutes: reminderTimeMinutesBefore),
    );
  }

  int get notificationId => id.hashCode.abs() % 100000;

  int notificationIdFor(int offsetMinutes) {
    return (id.hashCode.abs() + offsetMinutes) % 100000;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'doctorName': doctorName,
      'specialization': specialization,
      'hospitalOrClinic': hospitalOrClinic,
      'appointmentDate': appointmentDate.toIso8601String(),
      'phoneNumber': phoneNumber,
      'address': address,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'reminderTimeMinutesBefore': reminderTimeMinutesBefore,
      'selectedRemindersMinutes': selectedRemindersMinutes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final rawReminders = map['selectedRemindersMinutes'];
    List<int> remindersList = [];
    if (rawReminders is List) {
      remindersList = rawReminders.map((e) => (e as num).toInt()).toList();
    }

    final singleReminder = map['reminderTimeMinutesBefore'] is num
        ? (map['reminderTimeMinutesBefore'] as num).toInt()
        : 60;

    if (remindersList.isEmpty) {
      remindersList = [singleReminder];
    }

    return Appointment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      specialization: map['specialization'] ?? '',
      hospitalOrClinic: map['hospitalOrClinic'] ?? '',
      appointmentDate:
          DateTime.tryParse(map['appointmentDate'] ?? '') ?? DateTime.now(),
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      notes: map['notes'] ?? '',
      reminderEnabled: map['reminderEnabled'] ?? true,
      reminderTimeMinutesBefore: singleReminder,
      selectedRemindersMinutes: remindersList,
      status: map['status'] ?? 'Upcoming',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Appointment.fromJson(String source) =>
      Appointment.fromMap(json.decode(source));
}
