import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

class ProfileStateManager extends ChangeNotifier {
  static final ProfileStateManager instance = ProfileStateManager._internal();
  factory ProfileStateManager() => instance;
  ProfileStateManager._internal();

  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthRepository _authRepository = AuthRepository();

  UserProfile? _currentProfile;
  String? _userId;
  bool _isLoading = false;
  int _avatarVersion = DateTime.now().millisecondsSinceEpoch;

  UserProfile? get currentProfile => _currentProfile;
  int get avatarVersion => _avatarVersion;
  bool get isLoading => _isLoading;

  String get initial {
    final name = _currentProfile?.name.trim() ?? '';
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'U';
  }

  String get firstName {
    final name = _currentProfile?.name.trim() ?? '';
    if (name.isNotEmpty) {
      return name.split(' ').first;
    }
    return 'User';
  }

  String? get profileImagePath => _currentProfile?.profileImagePath;

  Future<UserProfile?> loadProfile({bool force = false}) async {
    if (_currentProfile != null && !force) {
      return _currentProfile;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _userId = await _authRepository.getCurrentUserId();
      if (_userId != null && _userId!.isNotEmpty) {
        _currentProfile = await _profileRepository.getProfile(userId: _userId!);
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('[PROFILE STATE MANAGER] loadProfile note: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _currentProfile;
  }

  void setProfile(UserProfile profile) {
    _currentProfile = profile;
    _avatarVersion = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  Future<bool> saveProfile(UserProfile profile) async {
    _userId ??= await _authRepository.getCurrentUserId();
    final uid = _userId!;
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _profileRepository.saveProfile(profile, userId: uid);
      if (success) {
        _currentProfile = profile;
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      }
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserProfile> uploadAvatar({
    required Uint8List bytes,
    required String filename,
    String? filePath,
  }) async {
    _userId ??= await _authRepository.getCurrentUserId();
    final uid = _userId!;
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _profileRepository.uploadAvatar(
        userId: uid,
        bytes: bytes,
        filename: filename,
        filePath: filePath,
      );
      _currentProfile = updated;
      _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserProfile> removeAvatar() async {
    _userId ??= await _authRepository.getCurrentUserId();
    final uid = _userId!;
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _profileRepository.removeAvatar(userId: uid);
      _currentProfile = updated;
      _avatarVersion = DateTime.now().millisecondsSinceEpoch;
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentProfile = null;
    _userId = null;
    _avatarVersion = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }
}
