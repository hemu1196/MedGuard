import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/core/api/api_client.dart';
import 'package:med_ai/core/errors/app_exception.dart';
import 'package:med_ai/models/user_profile.dart';
import 'package:med_ai/repositories/auth_repository.dart';
import 'package:med_ai/repositories/profile_repository.dart';
import 'package:med_ai/services/private_local_store.dart';
import 'package:med_ai/services/profile_draft_store.dart';
import 'package:med_ai/screens/onboarding/health_profile_page.dart';
import 'package:med_ai/services/medguard_ai_service.dart';
import 'package:med_ai/core/config/ai_config.dart';

String token(String identity) =>
    'header.${base64UrlEncode(utf8.encode(jsonEncode({'sub': identity, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.testSignature';
Map<String, dynamic> user(String id, {bool complete = false}) => {
  '_id': id,
  'email': 'fixture@example.test',
  'fullName': 'Synthetic patient',
  'profileCompleted': complete,
  'dateOfBirth': '2000-01-01',
  'gender': 'Male',
  'bloodGroup': 'O+',
  'heightCm': 175,
  'weightKg': 70,
};
http.Response response(Map<String, dynamic> value, [int status = 200]) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json'},
    );
UserProfile draft() => UserProfile(
  name: 'Synthetic patient',
  dateOfBirth: DateTime(2000),
  gender: 'Male',
  bloodGroup: 'O+',
  height: '175',
  weight: '70',
  allergies: 'Fixture allergy',
  existingConditions: '',
  currentMedications: '',
  emergencyContactName: 'Fixture contact',
  emergencyCountryCode: '+91',
  emergencyPhone: '9999999999',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('malformed and missing-expiry JWTs fail closed', () {
    for (final value in [
      'a.invalid.c',
      'a.${base64UrlEncode(utf8.encode('{}'))}.c',
      'a.b.c',
      '',
    ]) {
      expect(ApiClient().isTokenExpired(value), isTrue);
    }
  });
  test(
    '401 invalidates persisted credentials without losing same-account draft',
    () async {
      final api = ApiClient();
      await api.saveAuthSession(token('a'), user('a'));
      await ProfileDraftStore.save('a', draft());
      await http.runWithClient(
        () async {
          await expectLater(
            api.get('/users/me'),
            throwsA(isA<AuthenticationException>()),
          );
        },
        () => MockClient(
          (_) async => response({'message': 'Session revoked'}, 401),
        ),
      );
      expect(await api.getToken(), isNull);
      expect(await PrivateLocalStore.read('medguard_auth_token'), isNull);
      expect(await api.getStoredUser(), isNull);
      expect((await ProfileDraftStore.read('a'))?.allergies, 'Fixture allergy');
      await api.saveAuthSession(token('a-new'), user('a'));
      expect(await ProfileDraftStore.read('a'), isNotNull);
      await api.saveAuthSession(token('b'), user('b'));
      expect(await ProfileDraftStore.read('a'), isNull);
    },
  );
  test('late rejection cannot clear a newer successful login', () async {
    final api = ApiClient(),
        started = Completer<void>(),
        late = Completer<http.Response>();
    await api.saveAuthSession(token('old'), user('a'));
    await http.runWithClient(
      () async {
        final pending = api.get('/users/me');
        final assertion = expectLater(
          pending,
          throwsA(isA<AuthenticationException>()),
        );
        await started.future;
        final fresh = token('new');
        await api.saveAuthSession(fresh, user('a'));
        late.complete(response({'message': 'expired'}, 401));
        await assertion;
        expect(await api.getToken(), fresh);
      },
      () => MockClient((_) async {
        started.complete();
        return late.future;
      }),
    );
  });
  test(
    'profile authentication rejection never falls back to cached profile',
    () async {
      final api = ApiClient();
      await api.saveAuthSession(token('a'), user('a'));
      await PrivateLocalStore.write('user_profile_a', draft().toJson());
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            ProfileRepository().getProfile(userId: 'a'),
            throwsA(isA<AuthenticationException>()),
          );
        },
        () => MockClient((_) async {
          requests++;
          return response({'message': 'revoked'}, 401);
        }),
      );
      expect(requests, 1);
    },
  );
  test(
    'register, authenticated profile save, restart validation, logout and login use one account',
    () async {
      final api = ApiClient(), auth = AuthRepository();
      var saved = false, registrations = 0;
      final issued = token('registered');
      await http.runWithClient(
        () async {
          final session = await auth.signUp(
            name: 'Synthetic patient',
            email: 'fixture@example.test',
            password: 'Synthetic-password-123',
          );
          expect(session.userId, 'a');
          expect(
            await ProfileRepository().saveProfile(draft(), userId: 'a'),
            isTrue,
          );
          expect(saved, isTrue);
          api.resetForTesting();
          expect(await auth.isAuthenticated(), isTrue);
          expect((await api.getStoredUser())?['profileCompleted'], isTrue);
          await auth.signOut();
          expect(await api.getToken(), isNull);
          expect(await auth.isAuthenticated(), isFalse);
          final again = await auth.signIn(
            'fixture@example.test',
            'Synthetic-password-123',
          );
          expect(again.profileCompleted, isTrue);
          expect(registrations, 1);
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/auth/register')) {
            expect(r.headers['Authorization'], isNull);
            registrations++;
            return response({
              'success': true,
              'token': issued,
              'user': user('a'),
            }, 201);
          }
          if (r.url.path.endsWith('/auth/login')) {
            expect(r.headers['Authorization'], isNull);
            return response({
              'success': true,
              'token': token('login'),
              'user': user('a', complete: saved),
            });
          }
          if (r.url.path.endsWith('/auth/profile')) {
            expect(r.headers['Authorization'], 'Bearer $issued');
            expect(jsonDecode(r.body)['heightCm'], 175);
            saved = true;
            return response({
              'success': true,
              'user': user('a', complete: true),
            });
          }
          if (r.url.path.endsWith('/auth/verify')) {
            expect(r.headers['Authorization'], 'Bearer $issued');
            return response({
              'success': true,
              'user': user('a', complete: saved),
            });
          }
          if (r.url.path.endsWith('/auth/logout')) {
            return response({'success': true});
          }
          return response({'message': 'unexpected route'}, 404);
        }),
      );
    },
  );
  test(
    'revoked restored session is rejected and explicit logout clears drafts',
    () async {
      final api = ApiClient();
      await api.saveAuthSession(token('a'), user('a'));
      await ProfileDraftStore.save('a', draft());
      await http.runWithClient(() async {
        expect(await AuthRepository().isAuthenticated(), isFalse);
      }, () => MockClient((_) async => response({'message': 'revoked'}, 401)));
      expect(await api.getToken(), isNull);
      await api.clearAuthSession();
      expect(await ProfileDraftStore.read('a'), isNull);
    },
  );
  test(
    'AI guidance refuses provider transmission without explicit consent',
    () async {
      var calls = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            MedGuardAIService().getGuidance(userQuery: 'Synthetic question'),
            throwsStateError,
          );
        },
        () => MockClient((_) async {
          calls++;
          return response({});
        }),
      );
      expect(calls, 0);
    },
  );
  test(
    'optional legacy AI key migrates to protected storage and clears on logout',
    () async {
      SharedPreferences.setMockInitialValues({
        'user_configured_gemini_api_key': 'synthetic-custom-key',
      });
      expect(await AiConfig.getApiKey(), 'synthetic-custom-key');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'user_configured_gemini_api_key',
        ),
        isNull,
      );
      await ApiClient().clearAuthSession();
      expect(await AiConfig.getApiKey(), isEmpty);
    },
  );
  test(
    'an old-account profile draft cannot be sent using a new account session',
    () async {
      final api = ApiClient();
      await api.saveAuthSession(token('a'), user('a'));
      await api.saveAuthSession(token('b'), user('b'));
      var calls = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            ProfileRepository().saveProfile(draft(), userId: 'a'),
            throwsA(isA<AuthenticationException>()),
          );
        },
        () => MockClient((_) async {
          calls++;
          return response({});
        }),
      );
      expect(calls, 0);
    },
  );
  for (final scenario in [(true, 1000.0), (false, 1000.0), (true, 360.0)]) {
    final accepted = scenario.$1;
    final width = scenario.$2;
    testWidgets(
      'onboarding at $width px ${accepted ? 'waits for server acknowledgement before dashboard' : 'retains draft on rejected submission'}',
      (tester) async {
        tester.view.physicalSize = Size(width, width < 600 ? 800 : 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final api = ApiClient();
        final widgetToken = token('widget');
        await api.saveAuthSession(widgetToken, user('a'));
        await ProfileDraftStore.save('a', draft());
        final ack = Completer<http.Response>();
        var saves = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: const HealthProfilePage(),
                routes: {
                  '/dashboard': (_) =>
                      const Scaffold(body: Text('Verified dashboard')),
                  '/login': (_) => const Scaffold(body: Text('Reauthenticate')),
                },
              ),
            );
            for (var i = 0; i < 15; i++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
            for (var step = 0; step < 3; step++) {
              await tester.ensureVisible(find.text('Next Step'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Next Step'));
              await tester.pumpAndSettle();
            }
            await tester.ensureVisible(find.text('Complete Profile'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Complete Profile'));
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text('Verified dashboard'), findsNothing);
            expect(saves, 1);
            expect(await ProfileDraftStore.read('a'), isNotNull);
            ack.complete(
              accepted
                  ? response({
                      'success': true,
                      'user': user('a', complete: true),
                    })
                  : response({'message': 'Session revoked'}, 401),
            );
            for (var i = 0; i < 30; i++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
            if (accepted) {
              expect(find.text('Verified dashboard'), findsOneWidget);
              expect(await ProfileDraftStore.read('a'), isNull);
            } else {
              expect(find.text('Verified dashboard'), findsNothing);
              expect((await ProfileDraftStore.read('a'))?.height, '175');
              expect(await api.getToken(), isNull);
            }
          },
          () => MockClient((r) async {
            if (r.method == 'PUT' && r.url.path.endsWith('/auth/profile')) {
              saves++;
              expect(r.headers['Authorization'], 'Bearer $widgetToken');
              return ack.future;
            }
            if (r.method == 'GET' && r.url.path.endsWith('/users/me')) {
              return response({
                'success': true,
                'user': user('a', complete: true),
              });
            }
            return response({'message': 'unexpected route'}, 404);
          }),
        );
      },
    );
  }
}
