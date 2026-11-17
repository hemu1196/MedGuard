import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:med_ai/core/api/api_client.dart';
import 'package:med_ai/screens/launch/access_center_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Medical ID preview publishes selected fields and renders the returned real QR link',
    (tester) async {
      tester.view.physicalSize = const Size(1000,1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      SharedPreferences.setMockInitialValues({});
      final token =
          'header.${base64UrlEncode(utf8.encode(jsonEncode({'exp': 2000000000})))}.signature';
      await ApiClient().saveAuthSession(token, {
        '_id': 'fixture-owner',
        'fullName': 'Test patient',
      });
      var created = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: AccessCenterPage(mode: 'medical-id')),
          );
          for(var frame=0;frame<20;frame++){await tester.pump(const Duration(milliseconds:50));}
          expect(find.text('Test patient'), findsOneWidget);
          await tester.tap(find.text('Create Medical ID QR'));
          for(var frame=0;frame<20;frame++){await tester.pump(const Duration(milliseconds:50));}
          await tester.tap(find.text('Confirm'));
          for(var frame=0;frame<20;frame++){await tester.pump(const Duration(milliseconds:50));}
          expect(tester.takeException(), isNull);
          expect(created, isTrue);
          expect(find.byType(QrImageView), findsOneWidget);
          expect(find.text('${ApiClient().baseUrl}/launch/public/${'x' * 43}'), findsOneWidget);
      await tester.tap(find.text('Done'));
          for(var frame=0;frame<20;frame++){await tester.pump(const Duration(milliseconds:50));}
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.method == 'GET' && request.url.path.endsWith('/users/me')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'user': {
                  'fullName': 'Test patient',
                  'bloodGroup': 'Unknown',
                  'allergies': [],
                },
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/launch/grants')) {
            final body = jsonDecode(request.body);
            expect(body['consent'], isTrue);
            expect(body['fields'], contains('fullName'));
            expect(body['fields'], isNot(contains('password')));
            created = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'grant': {'_id': 'fixture-grant', 'kind': 'medical-id'},
                'token': 'x' * 43,
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'grants': []}),
            200,
          );
        }),
      );
    },
  );
}
