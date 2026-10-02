import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment.dart';

class AppointmentRepository {
  static const String _storageKey = 'user_doctor_appointments_list';

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Exposes a real-time stream for user appointments
  Stream<List<Appointment>> watchAppointments(String userId) {
    if (_firestore == null || userId.isEmpty) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('users')
        .doc(userId)
        .collection('appointments')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<Appointment>> getAppointments({required String userId}) async {
    if (userId.isEmpty) return [];

    if (_firestore != null) {
      try {
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .get()
            .timeout(const Duration(seconds: 4));

        if (snapshot.docs.isNotEmpty) {
          final appointments = snapshot.docs
              .map((doc) => Appointment.fromMap(doc.data()))
              .toList();

          final prefs = await SharedPreferences.getInstance();
          final rawList = appointments.map((a) => a.toJson()).toList();
          await prefs.setStringList('${_storageKey}_$userId', rawList);

          return appointments;
        }
      } catch (e) {
        debugPrint('[APPOINTMENT REPO] Firestore fetch note: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '${_storageKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_storageKey) ?? [];
    final all = rawList.map((str) => Appointment.fromJson(str)).toList();
    return all.where((a) => a.userId == userId || a.userId.isEmpty).toList();
  }

  Future<bool> saveAppointment(String userId, Appointment appointment) async {
    final updatedAppt = Appointment(
      id: appointment.id,
      userId: userId,
      doctorName: appointment.doctorName,
      specialization: appointment.specialization,
      hospitalOrClinic: appointment.hospitalOrClinic,
      appointmentDate: appointment.appointmentDate,
      phoneNumber: appointment.phoneNumber,
      address: appointment.address,
      notes: appointment.notes,
      reminderEnabled: appointment.reminderEnabled,
      reminderTimeMinutesBefore: appointment.reminderTimeMinutesBefore,
      selectedRemindersMinutes: appointment.selectedRemindersMinutes,
      status: appointment.status,
      createdAt: appointment.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_storageKey}_$userId';
      final rawList = prefs.getStringList(key) ?? [];
      final all = rawList.map((str) => Appointment.fromJson(str)).toList();

      final index = all.indexWhere((a) => a.id == updatedAppt.id);
      if (index >= 0) {
        all[index] = updatedAppt;
      } else {
        all.add(updatedAppt);
      }

      final updatedRaw = all.map((a) => a.toJson()).toList();
      await prefs.setStringList(key, updatedRaw);
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] Local save error: $e');
    }

    if (_firestore != null && userId.isNotEmpty) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(updatedAppt.id)
            .set(updatedAppt.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[APPOINTMENT REPO] Cloud save note: $e');
      }
    }

    return true;
  }

  Future<bool> updateStatus(
    String userId,
    String id,
    String status,
  ) async {
    final appointments = await getAppointments(userId: userId);
    final index = appointments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final old = appointments[index];
      final updated = Appointment(
        id: old.id,
        userId: userId,
        doctorName: old.doctorName,
        specialization: old.specialization,
        hospitalOrClinic: old.hospitalOrClinic,
        appointmentDate: old.appointmentDate,
        phoneNumber: old.phoneNumber,
        address: old.address,
        notes: old.notes,
        reminderEnabled: old.reminderEnabled,
        reminderTimeMinutesBefore: old.reminderTimeMinutesBefore,
        selectedRemindersMinutes: old.selectedRemindersMinutes,
        status: status,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      return await saveAppointment(userId, updated);
    }
    return false;
  }

  Future<bool> deleteAppointment(
    String userId,
    String id,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_storageKey}_$userId';
      final rawList = prefs.getStringList(key) ?? [];
      final all = rawList.map((str) => Appointment.fromJson(str)).toList();

      all.removeWhere((a) => a.id == id);

      final updatedRaw = all.map((a) => a.toJson()).toList();
      await prefs.setStringList(key, updatedRaw);
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] Local delete error: $e');
    }

    if (_firestore != null && userId.isNotEmpty) {
      try {
        await _firestore!
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[APPOINTMENT REPO] Cloud delete note: $e');
      }
    }

    return true;
  }
}
