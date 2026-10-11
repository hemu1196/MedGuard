import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../models/appointment.dart';

class AppointmentRepository {
  static const String _storageKey = 'user_doctor_appointments_list';
  final ApiClient _apiClient = ApiClient();

  Stream<List<Appointment>> watchAppointments(String userId) async* {
    final localList = await getAppointments(userId: userId);
    yield localList;

    try {
      final remoteList = await getAppointmentsFromApi();
      if (remoteList.isNotEmpty) {
        yield remoteList;
      }
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] watchAppointments API error: $e');
    }
  }

  Future<List<Appointment>> getAppointmentsFromApi() async {
    try {
      final res = await _apiClient.get('/appointments');
      if (res['success'] == true && res['appointments'] != null) {
        final list = (res['appointments'] as List)
            .map((a) => Appointment.fromMap(Map<String, dynamic>.from(a)))
            .toList();
        await _saveToLocalCache(list);
        return list;
      }
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] getAppointmentsFromApi error: $e');
    }
    return [];
  }

  Future<List<Appointment>> getAppointments({required String userId}) async {
    final remoteList = await getAppointmentsFromApi();
    if (remoteList.isNotEmpty) {
      return remoteList;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '${_storageKey}_$userId';
    final rawList = prefs.getStringList(key) ?? prefs.getStringList(_storageKey) ?? [];
    final all = rawList.map((str) => Appointment.fromJson(str)).toList();
    return all.where((a) => a.userId == userId || a.userId.isEmpty || userId.isEmpty).toList();
  }

  Future<bool> saveAppointment(String userId, Appointment appointment) async {
    try {
      final formattedTime =
          '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}';
      final body = {
        'doctorName': appointment.doctorName,
        'specialty': appointment.specialization,
        'hospitalName': appointment.hospitalOrClinic,
        'appointmentDate': appointment.appointmentDate.toIso8601String(),
        'appointmentTime': formattedTime,
        'reason': appointment.notes,
        'notes': appointment.notes,
        'status': appointment.status.toLowerCase(),
      };

      Map<String, dynamic> res;
      if (appointment.id.length == 24) {
        res = await _apiClient.put('/appointments/${appointment.id}', body: body);
      } else {
        res = await _apiClient.post('/appointments', body: body);
      }

      if (res['success'] == true && res['appointment'] != null) {
        final savedAppt = Appointment.fromMap(Map<String, dynamic>.from(res['appointment']));
        await _updateSingleLocalAppt(userId, savedAppt);
        return true;
      }
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] saveAppointment API error: $e');
    }

    return await _updateSingleLocalAppt(userId, appointment);
  }

  Future<bool> updateStatus(
    String userId,
    String id,
    String status,
  ) async {
    final normalized = status.toLowerCase();
    bool updatedInCloud = false;

    try {
      if (id.length == 24) {
        final res = await _apiClient.patch(
          '/appointments/$id/status',
          body: {'status': normalized},
        );
        if (res['success'] == true && res['appointment'] != null) {
          final savedAppt = Appointment.fromMap(Map<String, dynamic>.from(res['appointment']));
          await _updateSingleLocalAppt(userId, savedAppt);
          updatedInCloud = true;
        }
      }
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] updateStatus API error: $e');
    }

    if (!updatedInCloud) {
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
          pdfPath: old.pdfPath,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        await _updateSingleLocalAppt(userId, updated);
      }
    }

    return true;
  }

  Future<bool> deleteAppointment(
    String userId,
    String id,
  ) async {
    try {
      if (id.length == 24) {
        await _apiClient.delete('/appointments/$id');
      }
    } catch (e) {
      debugPrint('[APPOINTMENT REPO] deleteAppointment API error: $e');
    }

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

    return true;
  }

  Future<bool> _updateSingleLocalAppt(String userId, Appointment appt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_storageKey}_$userId';
      final rawList = prefs.getStringList(key) ?? [];
      final all = rawList.map((str) => Appointment.fromJson(str)).toList();

      final index = all.indexWhere((a) => a.id == appt.id);
      if (index >= 0) {
        all[index] = appt;
      } else {
        all.add(appt);
      }

      final updatedRaw = all.map((a) => a.toJson()).toList();
      await prefs.setStringList(key, updatedRaw);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToLocalCache(List<Appointment> appts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedRaw = appts.map((a) => a.toJson()).toList();
      await prefs.setStringList(_storageKey, updatedRaw);
    } catch (_) {}
  }
}
