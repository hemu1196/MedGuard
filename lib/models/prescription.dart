import 'dart:convert';
import 'medicine.dart';

class Prescription {
  final String id;
  final String title;
  final String doctorName;
  final DateTime date;
  final List<Medicine> medicines;
  final String notes;
  final String? imagePath;

  Prescription({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.date,
    required this.medicines,
    this.notes = '',
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'doctorName': doctorName,
      'date': date.toIso8601String(),
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'notes': notes,
      'imagePath': imagePath,
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      doctorName: map['doctorName'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      medicines: map['medicines'] != null
          ? (map['medicines'] as List)
                .map((m) => Medicine.fromMap(m as Map<String, dynamic>))
                .toList()
          : [],
      notes: map['notes'] ?? '',
      imagePath: map['imagePath'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Prescription.fromJson(String source) =>
      Prescription.fromMap(json.decode(source));
}
