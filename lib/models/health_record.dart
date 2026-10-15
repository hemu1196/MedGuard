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
  final String? fileName;
  final String? mimeType;
  final int fileSizeBytes;
  final String? storageKey;
  final String storageType;
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
    this.fileName,
    this.mimeType,
    this.fileSizeBytes = 0,
    this.storageKey,
    this.storageType = 'gridfs',
    this.thumbnailUrl,
    this.extractedData = const {},
    this.metadata = const {},
    this.status = 'active',
  });

  bool get hasFileAttachment =>
      (storageKey != null && storageKey!.isNotEmpty) ||
      (fileUrl != null && fileUrl!.isNotEmpty) ||
      (fileName != null && fileName!.isNotEmpty && fileSizeBytes > 0);

  bool get isPdf {
    if (mimeType != null && mimeType!.toLowerCase().contains('pdf')) return true;
    if (fileName != null && fileName!.toLowerCase().endsWith('.pdf')) return true;
    if (fileUrl != null && fileUrl!.toLowerCase().contains('.pdf')) return true;
    return false;
  }

  bool get isImage {
    if (mimeType != null && mimeType!.toLowerCase().startsWith('image/')) return true;
    final fn = (fileName ?? fileUrl ?? '').toLowerCase();
    return fn.endsWith('.jpg') || fn.endsWith('.jpeg') || fn.endsWith('.png') || fn.endsWith('.webp') || fn.endsWith('.gif') || fn.endsWith('.bmp');
  }

  String get fileFormatDisplayName {
    if (isPdf) return 'PDF Document';
    if (isImage) {
      if (fileName != null && fileName!.toLowerCase().endsWith('.png')) return 'Image (PNG)';
      return 'Image (JPEG)';
    }
    if (hasFileAttachment) return 'Document';
    return 'Clinical Record';
  }

  String get fileSizeFormatted {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? storageKey,
    String? storageType,
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
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      storageKey: storageKey ?? this.storageKey,
      storageType: storageType ?? this.storageType,
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
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'storageKey': storageKey,
      'storageType': storageType,
      'thumbnailUrl': thumbnailUrl,
      'extractedData': extractedData,
      'metadata': metadata,
      'status': status,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    HealthRecordType parseCategory(String? cat) {
      if (cat == null) return HealthRecordType.other;
      switch (cat.toLowerCase()) {
        case 'lab':
        case 'labreport':
          return HealthRecordType.labReport;
        case 'prescription':
          return HealthRecordType.prescription;
        case 'scan':
        case 'imaging':
          return HealthRecordType.imaging;
        case 'vaccination':
          return HealthRecordType.vaccination;
        case 'consultation':
          return HealthRecordType.consultation;
        case 'medicalreport':
        case 'medical_report':
          return HealthRecordType.medicalReport;
        case 'dischargesummary':
        case 'discharge_summary':
          return HealthRecordType.dischargeSummary;
        case 'allergy':
          return HealthRecordType.allergy;
        default:
          return HealthRecordType.values.firstWhere(
            (e) => e.name == cat,
            orElse: () => HealthRecordType.other,
          );
      }
    }

    final id = (map['_id'] ?? map['id'] ?? '').toString();
    final fileName = (map['fileName'] ?? map['originalFileName'] ?? '').toString();
    final storageKey = map['storageKey']?.toString();

    String? resolvedFileUrl;
    if (map['fileUrl'] != null && map['fileUrl'].toString().isNotEmpty) {
      resolvedFileUrl = map['fileUrl'].toString();
    } else if (storageKey != null && storageKey.isNotEmpty && id.isNotEmpty) {
      resolvedFileUrl = '/api/health-records/$id/download';
    } else if (map['filePath'] != null && map['filePath'].toString().isNotEmpty) {
      resolvedFileUrl = map['filePath'].toString();
    }

    return HealthRecord(
      id: id,
      userId: (map['userId'] ?? 'demo_user').toString(),
      recordType: parseCategory(map['category'] ?? map['recordType'] ?? map['documentType']),
      title: (map['title'] ?? map['fileName'] ?? '').toString(),
      description: (map['notes'] ?? map['description'] ?? '').toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      documentDate: DateTime.tryParse(map['documentDate']?.toString() ?? map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      providerName: (map['providerName'] ?? '').toString(),
      hospitalName: (map['hospitalName'] ?? '').toString(),
      doctorName: (map['doctorName'] ?? '').toString(),
      tags: List<String>.from(map['tags'] ?? []),
      fileUrl: resolvedFileUrl,
      fileName: fileName.isNotEmpty ? fileName : null,
      mimeType: map['mimeType']?.toString(),
      fileSizeBytes: (map['fileSizeBytes'] ?? map['fileSize'] ?? 0) is int
          ? (map['fileSizeBytes'] ?? map['fileSize'] ?? 0) as int
          : int.tryParse(map['fileSizeBytes']?.toString() ?? '') ?? 0,
      storageKey: storageKey,
      storageType: (map['storageType'] ?? 'gridfs').toString(),
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      extractedData: Map<String, dynamic>.from(map['extractedData'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      status: (map['status'] ?? 'active').toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory HealthRecord.fromJson(String source) => HealthRecord.fromMap(json.decode(source));
}
