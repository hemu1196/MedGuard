import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/utils/hydration_advisor.dart';
import 'package:med_ai/models/appointment.dart';
import 'package:med_ai/models/health_record.dart';
import 'package:med_ai/services/pdf_export_service.dart';
import 'package:med_ai/widgets/sos_countdown_dialog.dart';

void main() {
  group('Feature 6: HydrationAdvisor Evidence-Based Fluids & Clinician Override', () {
    test('Calculates baseline fluid target correctly for 70kg, 30yo sedentary adult', () {
      final guidance = HydrationAdvisor.calculateGuidance(
        weightKg: 70.0,
        age: 30,
        activity: ActivityLevel.sedentary,
      );

      // 70 * 35 = 2450 - 200 (sedentary) = 2250 total; 80% is 1800 ml beverage
      expect(guidance.isClinicianRestricted, isFalse);
      expect(guidance.recommendedFluidMl, greaterThan(1500));
      expect(guidance.totalWaterMl, greaterThan(2000));
    });

    test('Adjusts fluid target upward for Moderate and Active activity levels', () {
      final moderate = HydrationAdvisor.calculateGuidance(
        weightKg: 70.0,
        age: 30,
        activity: ActivityLevel.moderate,
      );
      final active = HydrationAdvisor.calculateGuidance(
        weightKg: 70.0,
        age: 30,
        activity: ActivityLevel.active,
      );

      expect(active.totalWaterMl, greaterThan(moderate.totalWaterMl));
      expect(active.recommendedFluidMl, greaterThanOrEqualTo(moderate.recommendedFluidMl));
    });

    test('Clinician prescribed fluid limit STRICTLY overrides general formula', () {
      // Patient with congestive heart failure or renal restriction: 1500 ml limit
      final guidance = HydrationAdvisor.calculateGuidance(
        weightKg: 85.0,
        age: 62,
        activity: ActivityLevel.active,
        clinicianFluidLimitMl: 1500,
      );

      expect(guidance.isClinicianRestricted, isTrue);
      expect(guidance.recommendedFluidMl, equals(1500));
      expect(guidance.title.contains('Clinician Prescribed'), isTrue);
      expect(guidance.explanation.contains('strict clinical precedence'), isTrue);
    });
  });

  group('Feature 2 & 3: PDF Generation via PdfExportService', () {
    test('Generates valid non-empty PDF bytes for Personal Appointment Record', () async {
      final appt = Appointment(
        id: 'appt_test_101',
        userId: 'user_456',
        doctorName: 'Dr. Sarah Jenkins',
        specialization: 'Cardiology',
        hospitalOrClinic: 'Metro Heart Institute',
        appointmentDate: DateTime(2026, 10, 15, 14, 30),
        phoneNumber: '+919876543210',
        address: 'Suite 402, Medical Arts Building',
        notes: 'Annual cardiac consultation and ECG review.',
      );

      final pdfBytes = await PdfExportService().generateAppointmentPdf(
        appointment: appt,
        patientName: 'Jane Doe',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Check PDF header signature: %PDF-
      expect(pdfBytes.length, greaterThan(100));
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('Generates valid non-empty PDF bytes for Health Vault Record Summary', () async {
      final now = DateTime.now();
      final record = HealthRecord(
        id: 'rec_test_202',
        userId: 'user_456',
        title: 'Complete Blood Count (CBC)',
        recordType: HealthRecordType.labReport,
        documentDate: DateTime(2026, 9, 20),
        createdAt: now,
        updatedAt: now,
        doctorName: 'Dr. Robert Chen',
        hospitalName: 'Apollo Diagnostics',
        description: 'Hemoglobin 14.2 g/dL, WBC 6,800 /mcL, Platelets 250,000 /mcL. All markers within normal limits.',
        fileUrl: '',
      );

      final pdfBytes = await PdfExportService().generateHealthRecordSummaryPdf(
        record: record,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Check PDF header signature: %PDF-
      expect(pdfBytes[0], equals(0x25));
      expect(pdfBytes[1], equals(0x50));
      expect(pdfBytes[2], equals(0x44));
      expect(pdfBytes[3], equals(0x46));
    });
  });

  group('Feature 7: Voice SOS 5-Second Cancel Countdown Widget', () {
    testWidgets('Renders countdown dialog with title, keyword chip, and cancel button', (tester) async {
      bool completed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosCountdownDialog(
              totalSeconds: 5,
              triggerWord: 'HELP ME',
              onCountdownComplete: () => completed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('VOICE SOS DETECTED'), findsOneWidget);
      expect(find.text('Keyword Heard: "HELP ME"'), findsOneWidget);
      expect(find.text('CANCEL SOS'), findsOneWidget);
      expect(find.text('SEND IMMEDIATELY'), findsOneWidget);
      expect(completed, isFalse);
      expect(cancelled, isFalse);
    });

    testWidgets('Tapping CANCEL SOS stops countdown and invokes onCancel', (tester) async {
      bool completed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosCountdownDialog(
              totalSeconds: 5,
              triggerWord: 'EMERGENCY',
              onCountdownComplete: () => completed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('CANCEL SOS'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(completed, isFalse);
    });

    testWidgets('Tapping SEND IMMEDIATELY invokes onCountdownComplete without waiting', (tester) async {
      bool completed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosCountdownDialog(
              totalSeconds: 5,
              triggerWord: 'SOS',
              onCountdownComplete: () => completed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('SEND IMMEDIATELY'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(cancelled, isFalse);
    });
  });
}
