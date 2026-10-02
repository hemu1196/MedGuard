import '../repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository = AuthRepository();

  Future<bool> isLoggedIn() async {
    return await _authRepository.isAuthenticated();
  }

  Future<String?> getUserEmail() async {
    return await _authRepository.getCurrentUserId();
  }

  Future<bool> login(String email, String password) async {
    return await _authRepository.login(email, password);
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }
}

