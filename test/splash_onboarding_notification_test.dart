import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/services/onboarding_service.dart';
import 'package:med_ai/services/in_app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isOnboardingCompleted defaults to false for new install', () async {
      final isCompleted = await OnboardingService.isOnboardingCompleted();
      expect(isCompleted, isFalse);
    });

    test('setOnboardingCompleted sets flag to true', () async {
      await OnboardingService.setOnboardingCompleted();
      final isCompleted = await OnboardingService.isOnboardingCompleted();
      expect(isCompleted, isTrue);
    });

    test('resetOnboarding resets flag back to false', () async {
      await OnboardingService.setOnboardingCompleted();
      expect(await OnboardingService.isOnboardingCompleted(), isTrue);

      await OnboardingService.resetOnboarding();
      expect(await OnboardingService.isOnboardingCompleted(), isFalse);
    });
  });

  group('InAppNotificationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads notifications and tracks unread counts correctly', () async {
      final service = InAppNotificationService();
      await service.loadNotifications();

      // Clear existing seeds for deterministic testing
      await service.clearAll();
      expect(service.items.length, 0);
      expect(service.unreadCount, 0);

      // Add Medicine notification
      await service.addNotification(
        title: 'Medication Alert: Paracetamol',
        body: 'Scheduled dose at 08:00 AM',
        type: NotificationType.medicine,
        targetRoute: '/medicines',
      );

      expect(service.items.length, 1);
      expect(service.unreadCount, 1);
      expect(service.items.first.title, 'Medication Alert: Paracetamol');
      expect(service.items.first.isRead, isFalse);

      // Add Appointment notification
      await service.addNotification(
        title: 'Appointment Confirmed: Dr. Sharma',
        body: 'Cardiology consultation on Friday at 10:00 AM',
        type: NotificationType.appointment,
        targetRoute: '/appointments',
      );

      expect(service.items.length, 2);
      expect(service.unreadCount, 2);

      // Mark first notification as read
      final firstId = service.items.first.id;
      await service.markAsRead(firstId);
      expect(service.unreadCount, 1);

      // Mark all as read
      await service.markAllAsRead();
      expect(service.unreadCount, 0);

      // Delete one notification
      await service.deleteNotification(firstId);
      expect(service.items.length, 1);

      // Clear all
      await service.clearAll();
      expect(service.items.length, 0);
      expect(service.unreadCount, 0);
    });

    test('InAppNotificationItem JSON serialization and deserialization', () {
      final now = DateTime.now();
      final item = InAppNotificationItem(
        id: 'test_123',
        title: 'Critical Emergency Alert',
        body: 'SOS triggered for emergency contact',
        createdAt: now,
        type: NotificationType.emergency,
        isRead: false,
        targetRoute: '/emergency_sos',
      );

      final json = item.toJson();
      expect(json['id'], 'test_123');
      expect(json['title'], 'Critical Emergency Alert');
      expect(json['type'], 'emergency');
      expect(json['isRead'], false);

      final restored = InAppNotificationItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.type, item.type);
      expect(restored.isRead, isFalse);
      expect(restored.body, item.body);
    });
  });

  group('Phone Normalization Tests', () {
    test('Phone clean and validation handles formatted strings', () {
      const sample1 = '+91 8309305811';
      final cleaned1 = sample1.replaceAll(RegExp(r'\s+'), '');
      expect(cleaned1, '+918309305811');

      const sample2 = '(555) 123-4567';
      final cleaned2 = sample2.replaceAll(RegExp(r'[\s()-]'), '');
      expect(cleaned2, '5551234567');
    });
  });
}
