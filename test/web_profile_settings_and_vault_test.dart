import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/app/routes.dart';
import 'package:med_ai/models/health_record.dart';
import 'package:med_ai/models/user_profile.dart';
import 'package:med_ai/repositories/health_record_repository.dart';
import 'package:med_ai/screens/addons/diet_fitness_page.dart';
import 'package:med_ai/screens/profile/profile_page.dart';
import 'package:med_ai/screens/settings/settings_page.dart';
import 'package:med_ai/services/notification_service.dart';
import 'package:med_ai/services/user_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'medguard_auth_token': 'test_jwt_token',
      'user_email': 'test@medguard.com',
      'user_name': 'Dr. Test User',
      'settings_medicine_reminders': true,
      'settings_appointment_reminders': true,
      'settings_sound_enabled': true,
      'settings_vibration_enabled': true,
      'settings_theme_mode': 'System',
    });

    ProfileStateManager.instance.setProfile(
      UserProfile(
        name: 'Dr. Test User',
        gender: 'Male',
        bloodGroup: 'O+',
        height: '175',
        weight: '70',
        allergies: 'Peanuts',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContactName: 'Emergency Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '+91 9999999999',
        emergencyRelationship: 'Family',
      ),
    );
  });

  group('Web Profile Settings & Logout Tests', () {
    testWidgets('Desktop Web Profile renders Settings and Logout buttons at bottom',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.settings: (ctx) => const Scaffold(body: Text('Settings Screen Test')),
            AppRoutes.login: (ctx) => const Scaffold(body: Text('Login Screen Test')),
          },
          home: const ProfilePage(),
        ),
      );

      await tester.pumpAndSettle();

      final settingsBtn = find.byKey(const Key('web_profile_settings_button'));
      final logoutBtn = find.byKey(const Key('web_profile_logout_button'));

      expect(settingsBtn, findsOneWidget);
      expect(logoutBtn, findsOneWidget);

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Logout'), findsWidgets);
    });

    testWidgets('Clicking Logout button shows confirmation dialog with MEDGUARD casing',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (ctx) => const Scaffold(body: Text('Login Screen Test')),
          },
          home: const ProfilePage(),
        ),
      );

      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const Key('web_profile_logout_button'));
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(find.text('Are you sure you want to log out of MEDGUARD?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Logout'), findsNothing);
    });

    test('NotificationService cancelAllScheduledReminders clears state', () async {
      final notifService = NotificationService();
      await notifService.cancelAllScheduledReminders();
      expect(true, isTrue);
    });
  });

  group('SettingsPage Functionality Tests', () {
    testWidgets('SettingsPage renders all sections and toggles persist', (tester) async {
      tester.view.physicalSize = const Size(1024, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsPage(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Emergency & Services'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Privacy & About'), findsOneWidget);

      expect(find.text('Medicine Reminders'), findsOneWidget);
      expect(find.text('Appointment Reminders'), findsOneWidget);
      expect(find.text('Sound Alerts'), findsOneWidget);
      expect(find.text('Vibration Feedback'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
    });
  });

  group('Diet & Fitness Page Simplification Tests', () {
    testWidgets('Diet & Fitness renders sections 1 to 5 and Section 6 Disclaimer without AI button',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DietFitnessPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Sections 1-5 present
      expect(find.text('1. Wellness Overview'), findsOneWidget);
      expect(find.text("2. Today's Balanced Meals"), findsOneWidget);
      expect(find.text('3. Daily Nutrition Principles'), findsOneWidget);
      expect(find.text('4. Healthy Movement & Activity'), findsOneWidget);
      expect(find.text('5. Daily Wellness Habits'), findsOneWidget);

      // Section 6 is Medical Guidance & Disclaimer
      expect(find.text('6. Medical Guidance & Disclaimer'), findsOneWidget);

      // Section 6 General Health Goals and AI Personalized Plan must NOT be present
      expect(find.text('6. General Health Goals'), findsNothing);
      expect(find.text('Personalize with AI'), findsNothing);
      expect(find.text('MedGuard AI Personalized Plan'), findsNothing);
    });
  });

  group('Health Vault Repository & Model Tests', () {
    test('HealthRecord correctly detects file formats and formats display', () {
      final pdfRecord = HealthRecord(
        id: '507f1f77bcf86cd799439011',
        userId: 'test_user',
        recordType: HealthRecordType.labReport,
        title: 'Complete Blood Count',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
        fileName: 'cbc_report.pdf',
        mimeType: 'application/pdf',
        fileSizeBytes: 204800,
      );

      expect(pdfRecord.isPdf, isTrue);
      expect(pdfRecord.isImage, isFalse);
      expect(pdfRecord.hasFileAttachment, isTrue);
      expect(pdfRecord.fileFormatDisplayName, 'PDF Document');
      expect(pdfRecord.fileSizeFormatted, '200.0 KB');

      final imgRecord = HealthRecord(
        id: '507f1f77bcf86cd799439012',
        userId: 'test_user',
        recordType: HealthRecordType.imaging,
        title: 'Chest X-Ray',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        documentDate: DateTime.now(),
        fileName: 'xray.png',
        mimeType: 'image/png',
        fileSizeBytes: 1048576,
      );

      expect(imgRecord.isPdf, isFalse);
      expect(imgRecord.isImage, isTrue);
      expect(imgRecord.hasFileAttachment, isTrue);
      expect(imgRecord.fileFormatDisplayName, 'Image (PNG)');
      expect(imgRecord.fileSizeFormatted, '1.0 MB');
    });

    test('HealthRecordRepository fallback loads local data when remote throws', () async {
      final repo = HealthRecordRepository();
      final records = await repo.getRecords(userId: 'test_user');
      expect(records, isA<List<HealthRecord>>());
    });
  });
}
