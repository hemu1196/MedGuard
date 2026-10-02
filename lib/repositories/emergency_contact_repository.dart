import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class EmergencyContactRepository {
  static const String _contactsKey = 'user_emergency_contacts';
  final ProfileService _profileService = ProfileService();

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Exposes a real-time Firestore stream for emergency contacts.
  Stream<List<EmergencyContact>> watchEmergencyContacts(String userId) async* {
    if (userId.isEmpty) return;

    // Initial emit from local cache for instant UI feedback
    final localContacts = await getEmergencyContacts(userId: userId);
    yield localContacts;

    if (_firestore == null) return;

    try {
      yield* _firestore!
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => EmergencyContact.fromMap(doc.data()))
            .toList();
      }).handleError((error) {
        debugPrint('[EMERGENCY CONTACT REPO] Stream error (permission-denied / network): $error');
        return localContacts;
      });
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] Firestore watch failed: $e');
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts({required String userId}) async {
    if (userId.isEmpty) return [];

    List<EmergencyContact> contacts = [];

    if (_firestore != null) {
      try {
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('emergency_contacts')
            .get()
            .timeout(const Duration(seconds: 4));

        if (snapshot.docs.isNotEmpty) {
          contacts = snapshot.docs
              .map((doc) => EmergencyContact.fromMap(doc.data()))
              .toList();

          final prefs = await SharedPreferences.getInstance();
          final rawList = contacts.map((c) => c.toJson()).toList();
          await prefs.setStringList('${_contactsKey}_$userId', rawList);
        }
      } catch (e) {
        debugPrint('[EMERGENCY CONTACT REPO] Firestore fetch note: $e');
      }
    }

    if (contacts.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('${_contactsKey}_$userId') ?? prefs.getStringList(_contactsKey) ?? [];
      contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();
    }

    // Auto-sync from Profile if repository is empty but profile has emergency contact
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
      } catch (e) {
        debugPrint('[EMERGENCY CONTACT REPO] Profile sync note: $e');
      }
    }

    return contacts;
  }

  Future<bool> saveEmergencyContact(String userId, EmergencyContact contact) async {
    if (userId.isEmpty) return false;

    final cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d]'), '');
    final docId = contact.id.isNotEmpty
        ? contact.id
        : (cleanPhone.isNotEmpty ? cleanPhone : DateTime.now().millisecondsSinceEpoch.toString());

    final updatedContact = EmergencyContact(
      id: docId,
      name: contact.name.trim(),
      countryCode: contact.countryCode.trim(),
      phone: contact.phone.trim(),
      relationship: contact.relationship,
      customRelationship: contact.customRelationship.trim(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_contactsKey}_$userId';
      final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
      final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();

      final index = contacts.indexWhere((c) => c.id == docId || c.phone == updatedContact.phone);
      if (index >= 0) {
        contacts[index] = updatedContact;
      } else {
        contacts.add(updatedContact);
      }
      await prefs.setStringList(key, contacts.map((c) => c.toJson()).toList());
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] Local save error: $e');
    }

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('emergency_contacts')
            .doc(docId)
            .set(updatedContact.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[EMERGENCY CONTACT REPO] Cloud save note: $e');
      }
    }

    // Keep Profile emergency fields synced
    try {
      final profile = await _profileService.getProfile();
      if (profile != null) {
        final updatedProfile = profile.copyWith(
          emergencyContactName: updatedContact.name,
          emergencyPhone: updatedContact.phone,
          emergencyCountryCode: updatedContact.countryCode,
          emergencyRelationship: updatedContact.displayRelationship,
        );
        await _profileService.saveProfile(updatedProfile);
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] Profile reverse sync note: $e');
    }

    return true;
  }

  Future<bool> deleteEmergencyContact(String userId, String idOrPhone) async {
    if (userId.isEmpty) return false;

    final clean = idOrPhone.replaceAll(RegExp(r'[^\d]'), '');
    List<EmergencyContact> remainingContacts = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_contactsKey}_$userId';
      final rawList = prefs.getStringList(key) ?? prefs.getStringList(_contactsKey) ?? [];
      final contacts = rawList.map((str) => EmergencyContact.fromJson(str)).toList();
      contacts.removeWhere((c) => c.id == idOrPhone || c.phone == idOrPhone || (clean.isNotEmpty && c.id == clean));
      remainingContacts = contacts;
      await prefs.setStringList(key, contacts.map((c) => c.toJson()).toList());
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] Local delete error: $e');
    }

    if (_firestore != null) {
      try {
        final docId = clean.isNotEmpty ? clean : idOrPhone;
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('emergency_contacts')
            .doc(docId)
            .delete()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[EMERGENCY CONTACT REPO] Cloud delete note: $e');
      }
    }

    // Keep Profile emergency fields synced with remaining contacts or clear if empty
    try {
      final profile = await _profileService.getProfile();
      if (profile != null) {
        final updatedProfile = profile.copyWith(
          emergencyContactName: remainingContacts.isNotEmpty ? remainingContacts.first.name : '',
          emergencyPhone: remainingContacts.isNotEmpty ? remainingContacts.first.phone : '',
          emergencyCountryCode: remainingContacts.isNotEmpty ? remainingContacts.first.countryCode : '+91',
          emergencyRelationship: remainingContacts.isNotEmpty ? remainingContacts.first.displayRelationship : 'Friend',
        );
        await _profileService.saveProfile(updatedProfile);
      }
    } catch (e) {
      debugPrint('[EMERGENCY CONTACT REPO] Profile reverse sync delete note: $e');
    }

    return true;
  }
}
