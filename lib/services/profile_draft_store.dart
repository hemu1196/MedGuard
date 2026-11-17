import 'dart:convert';
import '../models/user_profile.dart';
import 'private_local_store.dart';

class ProfileDraftStore {
  static String _key(String userId) => 'onboarding_draft_$userId';
  static Future<void> save(String userId, UserProfile profile) async {
    if (userId.isEmpty) return;
    await PrivateLocalStore.write(
      _key(userId),
      jsonEncode({'userId': userId, 'profile': profile.toJson()}),
    );
  }

  static Future<UserProfile?> read(String userId) async {
    final raw = await PrivateLocalStore.read(_key(userId));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data['userId'] == userId
          ? UserProfile.fromJson(data['profile'])
          : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String userId) =>
      PrivateLocalStore.remove(_key(userId));
}
