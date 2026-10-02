import 'dart:convert';

class Medicine {
  final String id;
  final String userId;
  final String?
  sourceHealthRecordId; // Traces back to Prescription HealthRecord
  final String name;
  final String dosage;
  final String frequency; // Once, Daily, Weekly, Specific Days
  final List<String> reminderTimes; // e.g. ["08:30 AM", "08:00 PM"]
  final String notes;

  // Stock Predictor Fields
  final int quantityAvailable;
  final int dosageQuantity;
  final int dailyConsumption;
  final int refillThreshold;

  Medicine({
    required this.id,
    this.userId = 'demo_user',
    this.sourceHealthRecordId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.reminderTimes,
    this.notes = '',
    this.quantityAvailable = 30,
    this.dosageQuantity = 1,
    this.dailyConsumption = 2,
    this.refillThreshold = 5,
  });

  int get estimatedDaysRemaining {
    if (dailyConsumption <= 0) return 99;
    return (quantityAvailable / dailyConsumption).floor();
  }

  bool get isLowStock {
    return estimatedDaysRemaining <= refillThreshold || quantityAvailable <= 5;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sourceHealthRecordId': sourceHealthRecordId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'reminderTimes': reminderTimes,
      'notes': notes,
      'quantityAvailable': quantityAvailable,
      'dosageQuantity': dosageQuantity,
      'dailyConsumption': dailyConsumption,
      'refillThreshold': refillThreshold,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] ?? '',
      userId: map['userId'] ?? 'demo_user',
      sourceHealthRecordId: map['sourceHealthRecordId'],
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? 'Daily',
      reminderTimes: List<String>.from(map['reminderTimes'] ?? []),
      notes: map['notes'] ?? '',
      quantityAvailable: map['quantityAvailable'] ?? 30,
      dosageQuantity: map['dosageQuantity'] ?? 1,
      dailyConsumption: map['dailyConsumption'] ?? 2,
      refillThreshold: map['refillThreshold'] ?? 5,
    );
  }

  String toJson() => json.encode(toMap());

  factory Medicine.fromJson(String source) =>
      Medicine.fromMap(json.decode(source));
}
