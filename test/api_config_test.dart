import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/api/api_client.dart';
import 'package:med_ai/core/config/api_config.dart';

void main() {
  group('ApiConfig & ApiClient Architecture Tests', () {
    test('ApiConfig defaults to Render production cloud backend', () {
      expect(ApiConfig.baseUrl, 'https://medguard-cqmw.onrender.com');
      expect(ApiConfig.apiUrl, 'https://medguard-cqmw.onrender.com/api');
      expect(ApiConfig.isProduction, isTrue);
    });

    test('ApiConfig endpoint constructors format paths accurately', () {
      final rootUri = ApiConfig.endpoint('health');
      expect(rootUri.toString(), 'https://medguard-cqmw.onrender.com/health');

      final apiUri = ApiConfig.apiEndpoint('/auth/login');
      expect(apiUri.toString(), 'https://medguard-cqmw.onrender.com/api/auth/login');

      final profileUri = ApiConfig.apiEndpoint('users/me');
      expect(profileUri.toString(), 'https://medguard-cqmw.onrender.com/api/users/me');
    });

    test('ApiClient singleton defaults to ApiConfig.apiUrl', () {
      final client = ApiClient();
      expect(client.baseUrl, 'https://medguard-cqmw.onrender.com/api');
    });

    test('ApiClient setCustomBaseUrl allows local developer override when explicitly provided', () {
      final client = ApiClient();
      client.setCustomBaseUrl('http://192.168.1.100:5001');
      expect(client.baseUrl, 'http://192.168.1.100:5001/api');

      // Reset back to null
      client.setCustomBaseUrl(null);
      expect(client.baseUrl, 'https://medguard-cqmw.onrender.com/api');
    });
  });
}
