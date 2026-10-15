import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/controllers/dashboard_controller.dart';
import 'package:med_ai/models/appointment.dart';
import 'package:med_ai/models/hospital.dart';
import 'package:med_ai/models/user_profile.dart';
import 'package:med_ai/models/water_intake.dart';
import 'package:med_ai/widgets/dashboard/ask_ai_banner_card.dart';
import 'package:med_ai/widgets/dashboard/dark_scenic_hero_header.dart';
import 'package:med_ai/widgets/dashboard/health_insights_section.dart';
import 'package:med_ai/widgets/dashboard/nearby_hospital_preview_card.dart';
import 'package:med_ai/widgets/dashboard/upcoming_appointment_preview_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dark-Accent Dashboard Widgets Tests', () {
    testWidgets('DarkScenicHeroHeader renders title, SOS, and 8 Quick Actions', (tester) async {
      final controller = DashboardController();
      controller.userProfile = UserProfile(
        name: 'Muvva Kumar',
        dateOfBirth: DateTime(1995, 5, 20),
        gender: 'Male',
        bloodGroup: 'O+',
        height: '175',
        weight: '70',
        allergies: 'None',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContactName: 'Dad',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DarkScenicHeroHeader(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Top Bar
      expect(find.text('MEDGUARD'), findsOneWidget);
      expect(find.text('Your Health & Emergency Companion'), findsOneWidget);

      // Greeting
      expect(find.text('Muvva'), findsOneWidget);
      expect(find.text('Stay healthy, stay safe!'), findsOneWidget);

      // Emergency SOS
      expect(find.text('EMERGENCY SOS'), findsOneWidget);
      expect(find.text('Tap to get immediate help'), findsOneWidget);

      // 8 Quick Actions
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Medicines'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
      expect(find.text('Appts'), findsOneWidget);
      expect(find.text('Hospitals'), findsOneWidget);
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Ambulance'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('HealthInsightsSection renders BMI, Water, and Records', (tester) async {
      final controller = DashboardController();
      controller.userProfile = UserProfile(
        name: 'Muvva Kumar',
        dateOfBirth: DateTime(1995, 5, 20),
        gender: 'Male',
        bloodGroup: 'O+',
        height: '175',
        weight: '70',
        allergies: 'None',
        existingConditions: 'None',
        currentMedications: 'None',
        emergencyContactName: 'Dad',
        emergencyCountryCode: '+91',
        emergencyPhone: '9876543210',
      );
      controller.dailyWaterIntake = DailyWaterIntake(
        userId: 'test_user',
        currentMl: 1200,
        targetMl: 2500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthInsightsSection(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Health Insights'), findsOneWidget);
      expect(find.text('BMI'), findsOneWidget);
      expect(find.text('22.9'), findsOneWidget); // 70 / (1.75 * 1.75) = 22.86 -> 22.9
      expect(find.text('Normal'), findsOneWidget);

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('1.2L / 2.5L'), findsOneWidget);
      expect(find.text('48% Goal'), findsOneWidget);

      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
    });

    testWidgets('UpcomingAppointmentPreviewCard renders doctor and date correctly', (tester) async {
      final appt = Appointment(
        id: 'appt_101',
        userId: 'test_user',
        doctorName: 'Dr. Sharma',
        specialization: 'General Physician',
        hospitalOrClinic: 'City Hospital',
        appointmentDate: DateTime(2026, 10, 18, 10, 0),
        phoneNumber: '9876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpcomingAppointmentPreviewCard(
              appointment: appt,
              isLoading: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upcoming Appointment'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('General Physician'), findsOneWidget);
      expect(find.text('Oct 18, 2026'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
    });

    testWidgets('UpcomingAppointmentPreviewCard empty state displays properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpcomingAppointmentPreviewCard(
              appointment: null,
              isLoading: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upcoming Appointment'), findsOneWidget);
      expect(find.text('No upcoming appointments'), findsOneWidget);
      expect(find.text('+ Book'), findsOneWidget);
    });

    testWidgets('NearbyHospitalPreviewCard renders hospital details and status', (tester) async {
      final hospital = Hospital(
        id: 'hosp_1',
        name: 'Saranya Ayurveda Hospital',
        latitude: 12.9716,
        longitude: 77.5946,
        address: 'Kanyakumari Highway',
        distanceKm: 3.8,
        openingHours: '24/7',
        emergencyServiceVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyHospitalPreviewCard(
              hospitals: [hospital],
              isLoading: false,
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nearby Hospitals'), findsOneWidget);
      expect(find.text('See All'), findsOneWidget);
      expect(find.text('Saranya Ayurveda Hospital'), findsOneWidget);
      expect(find.text('3.8 km away • Kanyakumari Highway'), findsOneWidget);
      expect(find.text('Open 24/7'), findsOneWidget);
    });

    testWidgets('AskAiBannerCard renders banner, prompt chips, and Start Chatting', (tester) async {
      bool navigated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AskAiBannerCard(
              onNavigateTab: (idx) {
                if (idx == 1) navigated = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ASK MEDGUARD AI'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Your Personal Health Assistance & Guidance Companion'), findsOneWidget);
      expect(find.text('🩺 Check Symptoms'), findsOneWidget);
      expect(find.text('💊 Medication Advice'), findsOneWidget);
      expect(find.text('📋 Explain Lab Report'), findsOneWidget);
      expect(find.text('🍎 Healthy Lifestyle'), findsOneWidget);
      expect(find.text('Start Chatting'), findsOneWidget);

      await tester.tap(find.text('Start Chatting'));
      await tester.pump();
      expect(navigated, isTrue);
    });
  });
}
