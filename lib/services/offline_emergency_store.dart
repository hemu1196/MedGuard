import 'dart:convert';
import '../models/user_profile.dart';
import 'private_local_store.dart';

class OfflineEmergencyStore {
  static String key(String userId) => 'emergency_snapshot_$userId';
  static Future<void> save(String userId, UserProfile profile) async {
    if (userId.isEmpty || userId == 'demo_user') return;
    // Explicitly requested snapshot, with minimal emergency fields only.
    await PrivateLocalStore.write(
      key(userId),
      jsonEncode({
        'userId': userId,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'userName': profile.name,
        'bloodGroup': profile.bloodGroup,
        'allergies': profile.allergies,
        'conditions': profile.existingConditions,
        'medicines': profile.currentMedications,
        'emergencyContactName': profile.emergencyContactName,
        'emergencyPhone':
            '${profile.emergencyCountryCode}${profile.emergencyPhone}',
      }),
    );
  }

  static Future<Map<String, dynamic>?> read(String userId) async {
    if (userId.isEmpty || userId == 'demo_user') return null;
    final value = await PrivateLocalStore.read(key(userId));
    if (value == null) return null;
    final data = Map<String, dynamic>.from(jsonDecode(value));
    return data['userId'] == userId ? data : null;
  }

  static Future<void> remove(String userId) =>
      PrivateLocalStore.remove(key(userId));
}
