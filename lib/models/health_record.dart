import 'dart:convert';

enum HealthRecordType {
  prescription,
  labReport,
  medicalReport,
  imaging,
  dischargeSummary,
  consultation,
  vaccination,
  allergy,
  other,
}

class HealthRecord {
  final String id;
  final String userId;
  final HealthRecordType recordType;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime documentDate;
  final String providerName;
  final String hospitalName;
  final String doctorName;
  final List<String> tags;
  final String? fileUrl;
  final String? thumbnailUrl;
  final Map<String, dynamic> extractedData;
  final Map<String, dynamic> metadata;
  final String status;

  HealthRecord({
    required this.id,
    required this.userId,
    required this.recordType,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    required this.documentDate,
    this.providerName = '',
    this.hospitalName = '',
    this.doctorName = '',
    this.tags = const [],
    this.fileUrl,
    this.thumbnailUrl,
    this.extractedData = const {},
    this.metadata = const {},
    this.status = 'active',
  });

  HealthRecord copyWith({
    String? id,
    String? userId,
    HealthRecordType? recordType,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? documentDate,
    String? providerName,
    String? hospitalName,
    String? doctorName,
    List<String>? tags,
    String? fileUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? extractedData,
    Map<String, dynamic>? metadata,
    String? status,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordType: recordType ?? this.recordType,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentDate: documentDate ?? this.documentDate,
      providerName: providerName ?? this.providerName,
      hospitalName: hospitalName ?? this.hospitalName,
      doctorName: doctorName ?? this.doctorName,
      tags: tags ?? this.tags,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      extractedData: extractedData ?? this.extractedData,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
    );
  }

  String get typeDisplayName {
    switch (recordType) {
      case HealthRecordType.prescription:
        return 'Prescription';
      case HealthRecordType.labReport:
        return 'Lab Report';
      case HealthRecordType.medicalReport:
        return 'Medical Report';
      case HealthRecordType.imaging:
        return 'Imaging / Scan';
      case HealthRecordType.dischargeSummary:
        return 'Discharge Summary';
      case HealthRecordType.consultation:
        return 'Doctor Consultation';
      case HealthRecordType.vaccination:
        return 'Vaccination Record';
      case HealthRecordType.allergy:
        return 'Allergy Record';
      case HealthRecordType.other:
        return 'Other Record';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'recordType': recordType.name,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'documentDate': documentDate.toIso8601String(),
      'providerName': providerName,
      'hospitalName': hospitalName,
      'doctorName': doctorName,
      'tags': tags,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'extractedData': extractedData,
      'metadata': metadata,
      'status': status,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? 'demo_user',
      recordType: HealthRecordType.values.firstWhere(
        (e) => e.name == map['recordType'],
        orElse: () => HealthRecordType.other,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      documentDate:
          DateTime.tryParse(map['documentDate'] ?? '') ?? DateTime.now(),
      providerName: map['providerName'] ?? '',
      hospitalName: map['hospitalName'] ?? '',
      doctorName: map['doctorName'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      fileUrl: map['fileUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      extractedData: Map<String, dynamic>.from(map['extractedData'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      status: map['status'] ?? 'active',
    );
  }

  String toJson() => json.encode(toMap());

  factory HealthRecord.fromJson(String source) =>
      HealthRecord.fromMap(json.decode(source));
}
