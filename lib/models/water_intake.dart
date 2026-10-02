import 'dart:convert';

class WaterIntake {
  final String id;
  final String userId;
  final int amountMl;
  final DateTime timestamp;

  WaterIntake({
    required this.id,
    required this.userId,
    required this.amountMl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amountMl': amountMl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WaterIntake.fromMap(Map<String, dynamic> map) {
    return WaterIntake(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      amountMl: map['amountMl'] ?? 0,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory WaterIntake.fromJson(String source) =>
      WaterIntake.fromMap(json.decode(source));
}

class DailyWaterIntake {
  final String userId;
  final int currentMl;
  final int targetMl;
  final List<WaterIntake> logs;

  DailyWaterIntake({
    required this.userId,
    required this.currentMl,
    this.targetMl = 2000,
    this.logs = const [],
  });

  double get progressRatio =>
      targetMl > 0 ? (currentMl / targetMl).clamp(0.0, 1.0) : 0.0;
}
