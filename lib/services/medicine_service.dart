import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

class MedicineService {
  static const String _medicinesKey = 'user_medicines_list';

  Future<List<Medicine>> getMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_medicinesKey) ?? [];
    return list.map((item) => Medicine.fromJson(item)).toList();
  }

  Future<bool> saveMedicine(Medicine medicine) async {
    final medicines = await getMedicines();
    final index = medicines.indexWhere((m) => m.id == medicine.id);
    if (index >= 0) {
      medicines[index] = medicine;
    } else {
      medicines.add(medicine);
    }
    return await _saveAll(medicines);
  }

  Future<bool> deleteMedicine(String id) async {
    final medicines = await getMedicines();
    medicines.removeWhere((m) => m.id == id);
    return await _saveAll(medicines);
  }

  Future<bool> _saveAll(List<Medicine> medicines) async {
    final prefs = await SharedPreferences.getInstance();
    final list = medicines.map((m) => m.toJson()).toList();
    return await prefs.setStringList(_medicinesKey, list);
  }
}
