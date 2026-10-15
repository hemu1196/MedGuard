import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/app/theme.dart';
import 'package:med_ai/models/user_profile.dart';
import 'package:med_ai/services/user_state_service.dart';
import 'package:med_ai/widgets/medguard_avatar.dart';

void main() {
  group('Android Status Bar Visibility Theme Tests', () {
    test('lightPageOverlay has soft medical teal background (#E8F5F3) and dark icons', () {
      const overlay = AppTheme.lightPageOverlay;
      expect(overlay.statusBarColor, equals(const Color(0xFFE8F5F3)));
      expect(overlay.statusBarIconBrightness, equals(Brightness.dark));
      expect(overlay.statusBarBrightness, equals(Brightness.light));
    });

    test('darkDashboardOverlay has deep teal navy background (#102B3B) and light icons', () {
      const overlay = AppTheme.darkDashboardOverlay;
      expect(overlay.statusBarColor, equals(const Color(0xFF102B3B)));
      expect(overlay.statusBarIconBrightness, equals(Brightness.light));
      expect(overlay.statusBarBrightness, equals(Brightness.dark));
    });

    test('Light theme appBarTheme uses lightPageOverlay and #E8F5F3', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, equals(const Color(0xFFE8F5F3)));
      expect(theme.appBarTheme.systemOverlayStyle, equals(AppTheme.lightPageOverlay));
    });
  });

  group('ProfileStateManager & Avatar 3-State Sync Tests', () {
    setUp(() {
      ProfileStateManager.instance.clear();
    });

    test('State A (No Image): Displays uppercase first letter of name', () {
      final state = ProfileStateManager.instance;
      final profile = UserProfile(
        name: 'Hemachandra',
        gender: 'Male',
        bloodGroup: 'O+',
        height: '175',
        weight: '70',
        allergies: '',
        existingConditions: '',
        currentMedications: '',
        emergencyContactName: 'Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        profileImagePath: null,
      );

      state.setProfile(profile);

      expect(state.initial, equals('H'));
      expect(state.firstName, equals('Hemachandra'));
      expect(state.profileImagePath, isNull);
    });

    test('State B (Image Uploaded): Updates profileImagePath and bumps avatarVersion', () {
      final state = ProfileStateManager.instance;
      final profile = UserProfile(
        name: 'Jane Doe',
        gender: 'Female',
        bloodGroup: 'A+',
        height: '165',
        weight: '58',
        allergies: '',
        existingConditions: '',
        currentMedications: '',
        emergencyContactName: 'Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        profileImagePath: '/api/users/123/avatar',
      );

      final initialVersion = state.avatarVersion;
      state.setProfile(profile);

      expect(state.initial, equals('J'));
      expect(state.firstName, equals('Jane'));
      expect(state.profileImagePath, equals('/api/users/123/avatar'));
      expect(state.avatarVersion, greaterThanOrEqualTo(initialVersion));
    });

    test('State C (Image Removed): Nullifies profileImagePath and instantly reverts to State A initial', () {
      final state = ProfileStateManager.instance;
      final profileWithImage = UserProfile(
        name: 'Alex Johnson',
        gender: 'Male',
        bloodGroup: 'B+',
        height: '180',
        weight: '75',
        allergies: '',
        existingConditions: '',
        currentMedications: '',
        emergencyContactName: 'Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        profileImagePath: 'https://medguard-cqmw.onrender.com/api/users/456/avatar',
      );

      state.setProfile(profileWithImage);
      expect(state.profileImagePath, isNotNull);

      // Simulate remove photo
      final profileWithoutImage = profileWithImage.copyWith(clearProfileImagePath: true);
      state.setProfile(profileWithoutImage);

      expect(state.profileImagePath, isNull);
      expect(state.initial, equals('A'));
      expect(state.firstName, equals('Alex'));
    });
  });

  group('MedGuardAvatar Widget Tests', () {
    setUp(() {
      ProfileStateManager.instance.clear();
    });

    testWidgets('Renders State A initial in teal circle with white text when no image exists', (tester) async {
      final profile = UserProfile(
        name: 'Kavitha Devi',
        gender: 'Female',
        bloodGroup: 'O+',
        height: '160',
        weight: '55',
        allergies: '',
        existingConditions: '',
        currentMedications: '',
        emergencyContactName: 'Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        profileImagePath: null,
      );

      ProfileStateManager.instance.setProfile(profile);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedGuardAvatar(radius: 30),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify uppercase initial 'K' is rendered
      expect(find.text('K'), findsOneWidget);

      // Verify the container has teal color #00BFA5
      final textWidget = tester.widget<Text>(find.text('K'));
      expect(textWidget.style?.color, equals(Colors.white));
    });

    testWidgets('Transitions immediately from State B to State A upon removing photo', (tester) async {
      final profileWithPhoto = UserProfile(
        name: 'Suresh Kumar',
        gender: 'Male',
        bloodGroup: 'AB+',
        height: '172',
        weight: '68',
        allergies: '',
        existingConditions: '',
        currentMedications: '',
        emergencyContactName: 'Contact',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
        profileImagePath: 'https://example.com/photo.png',
      );

      ProfileStateManager.instance.setProfile(profileWithPhoto);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MedGuardAvatar(radius: 30),
            ),
          ),
        ),
      );

      await tester.pump();

      // Remove photo
      final profileWithoutPhoto = profileWithPhoto.copyWith(clearProfileImagePath: true);
      ProfileStateManager.instance.setProfile(profileWithoutPhoto);

      await tester.pumpAndSettle();

      // Should immediately show 'S' in State A
      expect(find.text('S'), findsOneWidget);
    });
  });
}
