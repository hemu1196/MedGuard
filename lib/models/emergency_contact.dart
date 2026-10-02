import 'dart:convert';

class EmergencyContact {
  final String id;
  final String name;
  final String countryCode;
  final String phone;
  final String relationship;
  final String customRelationship;

  EmergencyContact({
    String? id,
    required this.name,
    this.countryCode = '+91',
    required this.phone,
    this.relationship = 'Friend',
    this.customRelationship = '',
  }) : id = id ?? (phone.replaceAll(RegExp(r'[^\d]'), '').isNotEmpty 
            ? phone.replaceAll(RegExp(r'[^\d]'), '') 
            : DateTime.now().millisecondsSinceEpoch.toString());

  String get displayPhone {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('+')) {
      return phone;
    }
    final code = countryCode.trim().isNotEmpty ? countryCode.trim() : '+91';
    return '$code $cleanPhone';
  }

  String get fullPhoneNumber => displayPhone;

  bool get isValidPhoneNumber {
    if (RegExp(r'[a-zA-Z]').hasMatch(phone)) return false;
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    return clean.length >= 7 && clean.length <= 15;
  }

  String get dialablePhone {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('+')) {
      return '+$cleanPhone';
    }
    final codeDigits = countryCode.replaceAll(RegExp(r'[^\d]'), '');
    if (codeDigits.isNotEmpty && !cleanPhone.startsWith(codeDigits)) {
      return '+$codeDigits$cleanPhone';
    }
    return cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';
  }

  String get displayRelationship {
    if (relationship == 'Other' && customRelationship.trim().isNotEmpty) {
      return customRelationship.trim();
    }
    return relationship;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'countryCode': countryCode,
      'phone': phone,
      'relationship': relationship,
      'customRelationship': customRelationship,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    final rawPhone = map['phone'] ?? '';
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    return EmergencyContact(
      id: map['id'] ?? (cleanPhone.isNotEmpty ? cleanPhone : ''),
      name: map['name'] ?? '',
      countryCode: map['countryCode'] ?? '+91',
      phone: rawPhone,
      relationship: map['relationship'] ?? 'Friend',
      customRelationship: map['customRelationship'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory EmergencyContact.fromJson(String source) =>
      EmergencyContact.fromMap(json.decode(source));
}
