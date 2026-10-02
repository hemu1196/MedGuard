import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_member.dart';

class FamilyRepository {
  static const String _familyStorageKey = 'user_family_members_list';

  Future<List<FamilyMember>> getFamilyMembers({
    String userId = 'demo_user',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_familyStorageKey) ?? [];
    final allMembers = rawList
        .map((str) => FamilyMember.fromJson(str))
        .toList();
    return allMembers.where((m) => m.userId == userId).toList();
  }

  Future<FamilyMember?> getFamilyMemberById(
    String id, {
    String userId = 'demo_user',
  }) async {
    final members = await getFamilyMembers(userId: userId);
    try {
      return members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveFamilyMember(FamilyMember member) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_familyStorageKey) ?? [];
    final allMembers = rawList
        .map((str) => FamilyMember.fromJson(str))
        .toList();

    final index = allMembers.indexWhere((m) => m.id == member.id);
    if (index >= 0) {
      allMembers[index] = member;
    } else {
      allMembers.add(member);
    }

    final updatedRawList = allMembers.map((m) => m.toJson()).toList();
    return await prefs.setStringList(_familyStorageKey, updatedRawList);
  }

  Future<bool> deleteFamilyMember(
    String id, {
    String userId = 'demo_user',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_familyStorageKey) ?? [];
    final allMembers = rawList
        .map((str) => FamilyMember.fromJson(str))
        .toList();

    allMembers.removeWhere((m) => m.id == id && m.userId == userId);

    final updatedRawList = allMembers.map((m) => m.toJson()).toList();
    return await prefs.setStringList(_familyStorageKey, updatedRawList);
  }
}
