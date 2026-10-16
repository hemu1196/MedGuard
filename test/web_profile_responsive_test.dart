import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/utils/bmi_calculator.dart';
import 'package:med_ai/screens/main_navigation_frame.dart';
import 'package:med_ai/screens/profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Hemachandra',
      'user_email': 'hem469469@gmail.com',
      'user_height': '175',
      'user_weight': '70',
      'user_blood_group': 'O+',
      'user_gender': 'Male',
      'emergency_name': 'Hema',
      'emergency_relation': 'Dad',
      'emergency_phone': '+91 8309305811',
      'auth_user_id': 'user_test_123',
      'medguard_auth_token':
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJ1c2VyX3Rlc3RfMTIzIiwiZXhwIjoyMDAwMDAwMDAwfQ.mock_signature',
      'medguard_user_data':
          '{"_id":"user_test_123","email":"hem469469@gmail.com","name":"Hemachandra"}',
      'auth_user_session':
          '{"_id":"user_test_123","email":"hem469469@gmail.com","name":"Hemachandra"}',
    });
  });

  group('MEDGUARD Web Profile Responsive & Sidebar Fix Tests', () {
    testWidgets('TC-UI01: Desktop Web at 1920px — exactly one sidebar is rendered', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Exactly ONE NavigationRail should be present in the widget tree
      expect(find.byType(NavigationRail), findsOneWidget);

      // Verify no duplicate MEDGUARD AI sidebar brandings exist
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI02: Web at 1440px — no RenderFlex overflow occurs', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Your Health Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI03: Web at 1280px — profile hero fits cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Your Health Profile'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI04: Web at 1024px — responsive layout adapts without overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Your Health Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI05: Tablet at 768px — renders mobile layout without sidebar', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tablet (< 900px) uses NavigationBar, no NavigationRail
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI06: Mobile at 390px — no sidebar duplication', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI07: Mobile at 360px — no clipped metrics', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Blood'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI08 & TC-UI09: Long username and long email wrap/truncate cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'Dr. Hemachandra Varma Raghavaraju Longname Extravaganza',
        'user_email': 'hemachandra.raghavaraju.developer@medguard-enterprise.healthcare.com',
        'user_height': '175',
        'user_weight': '70',
        'auth_user_id': 'user_test_123',
        'medguard_auth_token':
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJ1c2VyX3Rlc3RfMTIzIiwiZXhwIjoyMDAwMDAwMDAwfQ.mock_signature',
        'medguard_user_data':
            '{"_id":"user_test_123","email":"hemachandra.raghavaraju.developer@medguard-enterprise.healthcare.com","name":"Dr. Hemachandra"}',
      });

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI10: No profile image displays initial letter avatar', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'Hemachandra',
        'user_email': 'hem469469@gmail.com',
        'user_avatar': '',
        'auth_user_id': 'user_test_123',
        'medguard_auth_token':
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJ1c2VyX3Rlc3RfMTIzIiwiZXhwIjoyMDAwMDAwMDAwfQ.mock_signature',
        'medguard_user_data':
            '{"_id":"user_test_123","email":"hem469469@gmail.com","name":"Hemachandra"}',
      });

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationFrame(initialIndex: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('H'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI12: BMI 24.6 produces Normal range category and matching guidance', (tester) async {
      // 175cm and 75.3kg -> BMI 24.6
      final res = BmiCalculator.evaluate(heightCm: 175, weightKg: 75.3, age: 28);
      expect(res.bmi, equals(24.6));
      expect(res.category, equals('Normal range'));
      expect(res.guidance, contains('within the standard adult range'));
      expect(res.guidance, isNot(contains('below the standard adult range')));
    });

    testWidgets('TC-UI13: BMI below 18.5 produces Underweight category and matching guidance', (tester) async {
      final res = BmiCalculator.evaluate(heightCm: 168, weightKg: 50, age: 28);
      expect(res.bmi, equals(17.7));
      expect(res.category, equals('Underweight'));
      expect(res.guidance, contains('below the standard adult range'));
    });

    testWidgets('TC-UI14: Profile page displays consistent BMI insight on desktop', (tester) async {
      // Setup user with normal BMI (175cm, 75.3kg -> 24.6)
      SharedPreferences.setMockInitialValues({
        'user_name': 'Hemachandra',
        'user_email': 'hem469469@gmail.com',
        'user_height': '175',
        'user_weight': '75.3',
        'user_blood_group': 'O+',
        'user_gender': 'Male',
        'emergency_name': 'Hema',
        'emergency_relation': 'Dad',
        'emergency_phone': '+91 8309305811',
      });

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Category should be Normal range
      expect(find.text('Normal range'), findsOneWidget);

      // Guidance should contain standard adult range
      expect(find.textContaining('within the standard adult range'), findsOneWidget);

      // Should NOT contain the old contradictory underweight insight
      expect(find.textContaining('below the standard adult range'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI16: Notification bell remains functional on desktop profile', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-UI17: Other modules display only one sidebar in MainNavigationFrame', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: MainNavigationFrame(initialIndex: i),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('TC-UI18: No Flutter RenderFlex overflow exception under any breakpoint', (tester) async {
      final widths = [1920, 1600, 1440, 1280, 1100, 1024, 950, 900, 768, 600, 390, 360];

      final oldHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('FLUTTER_ERROR_DETAILS:\n${details.toString()}');
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      for (final width in widths) {
        tester.view.physicalSize = Size(width.toDouble(), 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ProfilePage()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final ex = tester.takeException();
        expect(
          ex,
          isNull,
          reason: 'Failed at width: $width px: $ex',
        );
      }
      tester.view.resetPhysicalSize();
    });
  });
}
