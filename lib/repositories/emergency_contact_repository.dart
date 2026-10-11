import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/emergency_contact.dart';

class EmergencyContactRepository {
  static final EmergencyContactRepository _instance = EmergencyContactRepository._internal();
  factory EmergencyContactRepository() => _instance;
  EmergencyContactRepository._internal();

  static const String _contactsKey = 'user_emergency_contacts';
  final ApiClient _apiClient = ApiClient();
  final StreamController<List<EmergencyContact>> _contactsStreamController =
      StreamController<List<EmergencyContact>>.broadcast();

  Stream<List<EmergencyContact>> watchEmergencyContacts(String userId) async* {
    final localContacts = await getEmergencyContacts(userId: userId);
    yield localContacts;

    try {
      final remoteList = await getContactsFromApi(userId: userId);
      if (remoteList.isNotEmpty) {
        yield remoteList;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] watchEmergencyContacts API error: $e');
    }

    yield* _contactsStreamController.stream;
  }

  Future<List<EmergencyContact>> getContactsFromApi({String? userId}) async {
    try {
      final res = await _apiClient.get('/emergency/contacts');
      if (res['success'] == true && res['contacts'] != null) {
        final list = (res['contacts'] as List)
            .map((c) => EmergencyContact.fromMap(Map<String, dynamic>.from(c)))
            .toList();

        // Sort so primary contact appears first
        list.sort((a, b) {
          if (a.isPrimary != b.isPrimary) {
            return a.isPrimary ? -1 : 1;
          }
          return 0;
        });

        await _saveToLocalCache(list, userId: userId);
        _contactsStreamController.add(list);
        return list;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] getContactsFromApi error: $e');
    }
    return [];
  }

  Future<List<EmergencyContact>> getEmergencyContacts({required String userId}) async {
    final remoteList = await getContactsFromApi(userId: userId);
    if (remoteList.isNotEmpty) {
      return remoteList;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '${_contactsKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
    final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();

    contacts.sort((a, b) {
      if (a.isPrimary != b.isPrimary) {
        return a.isPrimary ? -1 : 1;
      }
      return 0;
    });

    return contacts;
  }

  Future<bool> saveEmergencyContact(String userId, EmergencyContact contact) async {
    try {
      final body = {
        'name': contact.name,
        'relation': contact.displayRelationship,
        'phone': contact.phone,
        'isPrimary': contact.isPrimary,
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
        await getContactsFromApi(userId: userId);
        return true;
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] saveEmergencyContact API error: $e');
    }

    final success = await _updateSingleLocalContact(userId, contact);
    final updatedList = await getEmergencyContacts(userId: userId);
    _contactsStreamController.add(updatedList);
    return success;
  }

  Future<bool> setPrimaryContact(String userId, String contactId) async {
    try {
      if (contactId.length == 24) {
        final res = await _apiClient.patch('/emergency/contacts/$contactId/primary');
        if (res['success'] == true) {
          await getContactsFromApi(userId: userId);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] setPrimaryContact API error: $e');
    }

    // Local fallback update
    final prefs = await SharedPreferences.getInstance();
    final key = '${_contactsKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
    final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();

    for (var i = 0; i < contacts.length; i++) {
      final c = contacts[i];
      final isTarget = c.id == contactId || c.phone == contactId;
      contacts[i] = EmergencyContact(
        id: c.id,
        name: c.name,
        countryCode: c.countryCode,
        phone: c.phone,
        relationship: c.relationship,
        customRelationship: c.customRelationship,
        isPrimary: isTarget,
      );
    }

    await prefs.setStringList(key, contacts.map((c) => c.toJson()).toList());
    _contactsStreamController.add(contacts);
    return true;
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

    _contactsStreamController.add(contacts);
    // Refresh from API to ensure complete sync
    await getContactsFromApi(userId: userId);
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

  Future<void> _saveToLocalCache(List<EmergencyContact> contacts, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedRaw = contacts.map((c) => c.toJson()).toList();
      await prefs.setStringList(_contactsKey, updatedRaw);
      if (userId != null && userId.isNotEmpty) {
        await prefs.setStringList('${_contactsKey}_$userId', updatedRaw);
      }
    } catch (_) {}
  }
}
