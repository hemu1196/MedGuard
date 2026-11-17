import '../services/health_preferences.dart';
import '../core/api/api_client.dart';
import '../models/family_member.dart';

class FamilyRepository {
  final ApiClient _api = ApiClient();
  Future<List<FamilyMember>> getFamilyMembers({
    String userId = 'demo_user',
  }) async {
    final response = await _api.get('/launch/family');
    return (response['members'] as List)
        .map((m) => FamilyMember.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<FamilyMember?> getFamilyMemberById(
    String id, {
    String userId = 'demo_user',
  }) async {
    final members = await getFamilyMembers(userId: userId);
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  Future<bool> saveFamilyMember(FamilyMember member) async {
    final response = await _api.put(
      '/launch/family/${Uri.encodeComponent(member.id)}',
      body: {...member.toMap(), 'guardianAcknowledged': member.age < 18},
    );
    return response['success'] == true;
  }

  Future<bool> deleteFamilyMember(
    String id, {
    String userId = 'demo_user',
  }) async {
    final response = await _api.delete(
      '/launch/family/${Uri.encodeComponent(id)}',
    );
    return response['success'] == true;
  }
  Future<int> importLegacyProfiles(String userId) async {
    final current = await _api.getStoredUser();
    if (current?['_id']?.toString() != userId) throw StateError('Sign in again.');
    final prefs = await HealthPreferences.getInstance();
    final raw = prefs.getStringList('user_family_members_list') ?? [];
    var count = 0;
    for (final item in raw) {
      final member = FamilyMember.fromJson(item);
      if (member.userId == userId) { await saveFamilyMember(member); count++; }
    }
    // Do not remove legacy records: partial imports can be retried safely using the same IDs.
    return count;
  }

}
