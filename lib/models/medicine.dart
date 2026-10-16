import 'dart:convert';

class Medicine {
  final String id;
  final String userId;
  final String? sourceHealthRecordId; // Traces back to Prescription HealthRecord
  final String name;
  final String dosage;
  final String frequency; // Once, Daily, Weekly, Specific Days
  final List<String> reminderTimes; // e.g. ["08:30", "20:00"]
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

  Medicine copyWith({
    String? id,
    String? userId,
    String? sourceHealthRecordId,
    String? name,
    String? dosage,
    String? frequency,
    List<String>? reminderTimes,
    String? notes,
    int? quantityAvailable,
    int? dosageQuantity,
    int? dailyConsumption,
    int? refillThreshold,
  }) {
    return Medicine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourceHealthRecordId: sourceHealthRecordId ?? this.sourceHealthRecordId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      notes: notes ?? this.notes,
      quantityAvailable: quantityAvailable ?? this.quantityAvailable,
      dosageQuantity: dosageQuantity ?? this.dosageQuantity,
      dailyConsumption: dailyConsumption ?? this.dailyConsumption,
      refillThreshold: refillThreshold ?? this.refillThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': id,
      'userId': userId,
      'sourceHealthRecordId': sourceHealthRecordId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'reminderTimes': reminderTimes,
      'times': reminderTimes,
      'notes': notes,
      'quantityAvailable': quantityAvailable,
      'remainingStock': quantityAvailable,
      'totalStock': quantityAvailable,
      'dosageQuantity': dosageQuantity,
      'dailyConsumption': dailyConsumption,
      'refillThreshold': refillThreshold,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    List<String> times = [];
    if (map['reminderTimes'] != null) {
      times = List<String>.from(map['reminderTimes']);
    } else if (map['times'] != null) {
      times = List<String>.from(map['times']);
    }

    final stock = map['quantityAvailable'] ?? map['remainingStock'] ?? map['totalStock'] ?? 30;

    return Medicine(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      userId: (map['userId'] ?? 'demo_user').toString(),
      sourceHealthRecordId: map['sourceHealthRecordId'],
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? 'Daily',
      reminderTimes: times,
      notes: map['notes'] ?? map['instructions'] ?? '',
      quantityAvailable: (stock is num) ? stock.toInt() : 30,
      dosageQuantity: map['dosageQuantity'] ?? 1,
      dailyConsumption: map['dailyConsumption'] ?? (times.isNotEmpty ? times.length : 1),
      refillThreshold: map['refillThreshold'] ?? 5,
    );
  }

  String toJson() => json.encode(toMap());

  factory Medicine.fromJson(String source) => Medicine.fromMap(json.decode(source));
}
