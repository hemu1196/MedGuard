import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';

class PrescriptionService {
  static const String _prescriptionsKey = 'user_prescriptions_list';

  Future<List<Prescription>> getPrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prescriptionsKey) ?? [];
    return list.map((item) => Prescription.fromJson(item)).toList();
  }

  Future<bool> savePrescription(Prescription prescription) async {
    final list = await getPrescriptions();
    final index = list.indexWhere((p) => p.id == prescription.id);
    if (index >= 0) {
      list[index] = prescription;
    } else {
      list.add(prescription);
    }
    return await _saveAll(list);
  }

  Future<bool> deletePrescription(String id) async {
    final list = await getPrescriptions();
    list.removeWhere((p) => p.id == id);
    return await _saveAll(list);
  }

  Future<bool> _saveAll(List<Prescription> list) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = list.map((p) => p.toJson()).toList();
    return await prefs.setStringList(_prescriptionsKey, stringList);
  }
}
