class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthenticationException extends AppException {
  AuthenticationException(super.message, {super.code = 'AUTH_ERROR'});
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code = 'DATABASE_ERROR'});
}

class StorageException extends AppException {
  StorageException(super.message, {super.code = 'STORAGE_ERROR'});
}

class NetworkException extends AppException {
  NetworkException([super.message = 'Network connection unavailable'])
      : super(code: 'NETWORK_ERROR');
}

class LocationException extends AppException {
  LocationException([super.message = 'Location service unavailable or permission denied'])
      : super(code: 'LOCATION_ERROR');
}

class PermissionException extends AppException {
  PermissionException([super.message = 'Permission denied'])
      : super(code: 'PERMISSION_DENIED');
}

class ApiException extends AppException {
  ApiException(super.message, {super.code = 'API_ERROR'});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code = 'VALIDATION_ERROR'});
}
