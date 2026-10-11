import 'dart:convert';

enum HealthcareCategory {
  hospital,
  emergencyDepartment,
  clinic,
  primaryHealthCentre,
  pharmacy,
  otherHealthcareFacility;

  String get displayName {
    switch (this) {
      case HealthcareCategory.hospital:
        return 'Hospital';
      case HealthcareCategory.emergencyDepartment:
        return 'Emergency Department';
      case HealthcareCategory.clinic:
        return 'Clinic';
      case HealthcareCategory.primaryHealthCentre:
        return 'Primary Health Centre';
      case HealthcareCategory.pharmacy:
        return 'Pharmacy';
      case HealthcareCategory.otherHealthcareFacility:
        return 'Healthcare Facility';
    }
  }

  static HealthcareCategory fromString(String? val) {
    if (val == null) return HealthcareCategory.hospital;
    final lower = val.toLowerCase().trim();
    if (lower.contains('emergency') || lower.contains('trauma') || lower.contains('casualty')) {
      return HealthcareCategory.emergencyDepartment;
    }
    if (lower.contains('pharmacy') || lower.contains('chemist') || lower.contains('drugstore')) {
      return HealthcareCategory.pharmacy;
    }
    if (lower.contains('primary') || lower.contains('health centre') || lower.contains('phc') || lower.contains('dispensary')) {
      return HealthcareCategory.primaryHealthCentre;
    }
    if (lower.contains('clinic') || lower.contains('doctor') || lower.contains('polyclinic')) {
      return HealthcareCategory.clinic;
    }
    if (lower.contains('hospital')) {
      return HealthcareCategory.hospital;
    }
    return HealthcareCategory.otherHealthcareFacility;
  }
}

class Hospital {
  final String id;
  final String source;
  final String sourcePlaceId;
  final String name;
  final HealthcareCategory category;
  final double latitude;
  final double longitude;
  final String address;
  final String phoneNumber;
  final String website;
  final String openingHours;
  final bool emergencyServiceVerified;
  final String emergencyVerificationSource;
  final double distanceMeters;
  final DateTime lastFetchedAt;
  final bool isDemoData;

  Hospital({
    required this.id,
    this.source = 'openstreetmap',
    this.sourcePlaceId = '',
    required this.name,
    this.category = HealthcareCategory.hospital,
    required this.latitude,
    required this.longitude,
    required this.address,
    String? phoneNumber,
    this.website = '',
    this.openingHours = '',
    bool? emergencyServiceVerified,
    this.emergencyVerificationSource = 'unverified',
    double? distanceMeters,
    double? distanceKm,
    String? phone,
    bool? hasEmergencyServices,
    DateTime? lastFetchedAt,
    this.isDemoData = false,
  })  : phoneNumber = ((phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : (phone ?? '')),
        distanceMeters = distanceMeters ?? ((distanceKm ?? 0.0) * 1000.0),
        emergencyServiceVerified = (emergencyServiceVerified ?? false) || (hasEmergencyServices ?? false),
        lastFetchedAt = lastFetchedAt ?? DateTime.now();

  /// Backward-compatible aliases
  String get phone => phoneNumber;
  bool get hasEmergencyServices => emergencyServiceVerified;
  double get distanceKm => double.parse((distanceMeters / 1000.0).toStringAsFixed(1));

  /// Verified phone validation
  bool get hasValidPhone {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return clean.length >= 6;
  }

  /// Clean dialable phone number for url_launcher
  String? get dialablePhone {
    if (!hasValidPhone) return null;
    final trimmed = phoneNumber.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.replaceAll(RegExp(r'[^\d]'), '')}';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isNotEmpty ? digits : null;
  }

  /// Display phone number
  String get displayPhone {
    if (!hasValidPhone) return 'Phone number unavailable';
    return phoneNumber.trim();
  }

  /// Opening hours display string
  String get openingHoursDisplay {
    if (openingHours.trim().isNotEmpty) {
      return openingHours.trim();
    }
    return 'Hours not verified';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source,
      'sourcePlaceId': sourcePlaceId,
      'name': name,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phoneNumber': phoneNumber,
      'website': website,
      'openingHours': openingHours,
      'emergencyServiceVerified': emergencyServiceVerified,
      'emergencyVerificationSource': emergencyVerificationSource,
      'distanceMeters': distanceMeters,
      'lastFetchedAt': lastFetchedAt.toIso8601String(),
      'isDemoData': isDemoData,
    };
  }

  factory Hospital.fromMap(Map<String, dynamic> map) {
    return Hospital(
      id: map['id']?.toString() ?? '',
      source: map['source']?.toString() ?? 'openstreetmap',
      sourcePlaceId: map['sourcePlaceId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Healthcare Facility',
      category: HealthcareCategory.fromString(map['category']?.toString()),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address']?.toString() ?? 'Address unavailable',
      phoneNumber: map['phoneNumber']?.toString() ?? map['phone']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      openingHours: map['openingHours']?.toString() ?? '',
      emergencyServiceVerified: map['emergencyServiceVerified'] == true || map['hasEmergencyServices'] == true,
      emergencyVerificationSource: map['emergencyVerificationSource']?.toString() ?? 'unverified',
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      lastFetchedAt: map['lastFetchedAt'] != null ? DateTime.tryParse(map['lastFetchedAt']) : null,
      isDemoData: map['isDemoData'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Hospital.fromJson(String source) => Hospital.fromMap(json.decode(source));
}
