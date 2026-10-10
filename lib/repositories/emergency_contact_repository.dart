import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class EmergencyContactRepository {
  static const String _contactsKey = 'user_emergency_contacts';
  final ProfileService _profileService = ProfileService();
  final ApiClient _apiClient = ApiClient();

  Stream<List<EmergencyContact>> watchEmergencyContacts(String userId) async* {
    final localContacts = await getEmergencyContacts(userId: userId);
    yield localContacts;

    try {
      final remoteList = await getContactsFromApi();
      if (remoteList.isNotEmpty) {
        yield remoteList;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] watchEmergencyContacts API error: $e');
    }
  }

  Future<List<EmergencyContact>> getContactsFromApi() async {
    try {
      final res = await _apiClient.get('/emergency/contacts');
      if (res['success'] == true && res['contacts'] != null) {
        final list = (res['contacts'] as List)
            .map((c) => EmergencyContact.fromMap(Map<String, dynamic>.from(c)))
            .toList();
        await _saveToLocalCache(list);
        return list;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] getContactsFromApi error: $e');
    }
    return [];
  }

  Future<List<EmergencyContact>> getEmergencyContacts({required String userId}) async {
    final remoteList = await getContactsFromApi();
    if (remoteList.isNotEmpty) {
      return remoteList;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '${_contactsKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
    List<EmergencyContact> contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();

    if (contacts.isEmpty) {
      try {
        final UserProfile? profile = await _profileService.getProfile();
        if (profile != null && profile.emergencyPhone.trim().isNotEmpty) {
          final syncContact = EmergencyContact(
            name: profile.emergencyContactName.isNotEmpty
                ? profile.emergencyContactName
                : 'Emergency Contact',
            countryCode: profile.emergencyCountryCode.isNotEmpty
                ? profile.emergencyCountryCode
                : '+91',
            phone: profile.emergencyPhone.trim(),
            relationship: profile.emergencyRelationship.isNotEmpty
                ? profile.emergencyRelationship
                : 'Friend',
          );
          await saveEmergencyContact(userId, syncContact);
          contacts = [syncContact];
        }
      } catch (_) {}
    }

    return contacts;
  }

  Future<bool> saveEmergencyContact(String userId, EmergencyContact contact) async {
    try {
      final body = {
        'name': contact.name,
        'relation': contact.displayRelationship,
        'phone': contact.phone,
        'isPrimary': true,
      };

      Map<String, dynamic> res;
      if (contact.id.length == 24) {
        res = await _apiClient.put('/emergency/contacts/${contact.id}', body: body);
      } else {
        res = await _apiClient.post('/emergency/contacts', body: body);
      }

      if (res['success'] == true && res['contact'] != null) {
        final savedContact = EmergencyContact.fromMap(Map<String, dynamic>.from(res['contact']));
        await _updateSingleLocalContact(userId, savedContact);
        return true;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] saveEmergencyContact API error: $e');
    }

    return await _updateSingleLocalContact(userId, contact);
  }

  Future<bool> deleteEmergencyContact(String userId, String idOrPhone) async {
    try {
      if (idOrPhone.length == 24) {
        await _apiClient.delete('/emergency/contacts/$idOrPhone');
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] deleteEmergencyContact API error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '${_contactsKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
    final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();
    contacts.removeWhere((c) => c.id == idOrPhone || c.phone == idOrPhone);
    await prefs.setStringList(key, contacts.map((c) => c.toJson()).toList());
    return true;
  }

  Future<bool> _updateSingleLocalContact(String userId, EmergencyContact contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_contactsKey}_$userId';
      final rawList = prefs.getStringList(key) ?? [];
      final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();

      final index = contacts.indexWhere((c) => c.id == contact.id || c.phone == contact.phone);
      if (index >= 0) {
        contacts[index] = contact;
      } else {
        contacts.add(contact);
      }

      await prefs.setStringList(key, contacts.map((c) => c.toJson()).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToLocalCache(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedRaw = contacts.map((c) => c.toJson()).toList();
      await prefs.setStringList(_contactsKey, updatedRaw);
    } catch (_) {}
  }
}
