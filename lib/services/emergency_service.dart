import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../repositories/emergency_contact_repository.dart';
import 'location_service.dart';
import 'profile_service.dart';

class EmergencySosResult {
  final bool success;
  final String status;
  final String message;
  final String? recipientPhone;
  final String? recipientName;
  final LocationData? location;
  final bool launchedUrl;

  EmergencySosResult({
    required this.success,
    required this.status,
    required this.message,
    this.recipientPhone,
    this.recipientName,
    this.location,
    this.launchedUrl = false,
  });
}

class EmergencyService {
  final EmergencyContactRepository _contactRepository = EmergencyContactRepository();
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final ApiClient _apiClient = ApiClient();

  static const String _sosLogsKey = 'medguard_emergency_sos_logs';

  Future<List<EmergencyContact>> getAllEmergencyContacts({required String userId}) async {
    return await _contactRepository.getEmergencyContacts(userId: userId);
  }

  Future<EmergencySosResult> triggerSos({
    required String userId,
    LocationData? locationOverride,
    String triggerType = 'manual',
  }) async {
    final contacts = await getAllEmergencyContacts(userId: userId);

    if (contacts.isEmpty) {
      return EmergencySosResult(
        success: false,
        status: 'no_contacts',
        message: 'No emergency contact configured.',
      );
    }

    LocationData? location = locationOverride;
    if (location == null) {
      try {
        location = await _locationService.requestLocation();
      } catch (e) {
        debugPrint('[EMERGENCY SERVICE] Location fetch error: $e');
      }
    }

    final primaryContact = contacts.first;
    final cleanPhone = primaryContact.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final fullPhone = primaryContact.displayPhone;
    final UserProfile? profile = await _profileService.getProfile();
    final userName = (profile != null && profile.name.isNotEmpty) ? profile.name : 'MEDGUARD User';

    // 1. Log SOS Event on MongoDB Atlas via ApiClient
    try {
      await _apiClient.post('/emergency/sos/trigger', body: {
        'triggerType': triggerType,
        'latitude': location?.latitude ?? 0.0,
        'longitude': location?.longitude ?? 0.0,
        'address': location?.address ?? (location == null ? 'Location unavailable' : ''),
      });
    } catch (apiErr) {
      debugPrint('[EMERGENCY SERVICE] Backend SOS log error: $apiErr');
    }

    String locationString;
    if (location != null) {
      locationString = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    } else {
      locationString = 'Location unavailable (GPS disabled or permission denied).';
    }

    final sosMessage = '''
EMERGENCY ALERT

Hi ${primaryContact.name},

This is an emergency alert from $userName via MEDGUARD.
I need immediate medical assistance!

My live location:
$locationString

Please check my location and contact me immediately.'''.trim();

    bool launched = false;
    final encodedBody = Uri.encodeComponent(sosMessage);
    final Uri smsUri = Uri.parse('sms:$cleanPhone?body=$encodedBody');

    try {
      if (await canLaunchUrl(smsUri)) {
        launched = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        launched = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[EMERGENCY SERVICE] Could not launch SMS URI ($smsUri): $e');
    }

    await logSosEvent(
      userId: userId,
      contactName: primaryContact.name,
      contactPhone: fullPhone,
      location: location,
      sosMessage: sosMessage,
      status: launched ? 'opened_composer' : 'prepared',
    );

    return EmergencySosResult(
      success: true,
      status: launched ? 'opened_composer' : 'prepared',
      message: sosMessage,
      recipientPhone: fullPhone,
      recipientName: primaryContact.name,
      location: location,
      launchedUrl: launched,
    );
  }

  Future<void> logSosEvent({
    required String userId,
    required String contactName,
    required String contactPhone,
    required LocationData? location,
    required String sosMessage,
    required String status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList(_sosLogsKey) ?? [];

      final logEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'contactName': contactName,
        'contactPhone': contactPhone,
        'latitude': location?.latitude,
        'longitude': location?.longitude,
        'message': sosMessage,
        'status': status,
      };

      existingLogs.insert(0, json.encode(logEntry));
      if (existingLogs.length > 50) {
        existingLogs.removeRange(50, existingLogs.length);
      }

      await prefs.setStringList(_sosLogsKey, existingLogs);
    } catch (e) {
      debugPrint('[EMERGENCY SERVICE] Failed to log SOS event locally: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSosLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLogs = prefs.getStringList(_sosLogsKey) ?? [];
      return rawLogs.map((item) => json.decode(item) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }
}
