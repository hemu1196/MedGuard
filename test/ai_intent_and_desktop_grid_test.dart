import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/services/health_safety_filter.dart';
import 'package:med_ai/services/local_health_fallback_service.dart';
import 'package:med_ai/widgets/dashboard/dark_scenic_hero_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Intent Classification & Doctor Recommendations Tests', () {
    final fallback = LocalHealthFallbackService();

    test('Greeting query ("hi", "hello") returns intent: greeting with zero medical boilerplate', () {
      final resHi = fallback.generateFallback('hi');
      expect(resHi.intent, equals('greeting'));
      expect(resHi.isGreeting, isTrue);
      expect(resHi.category, equals('Greeting'));
      expect(resHi.recommendedCare, isNull);
      expect(resHi.considerations, isEmpty);
      expect(resHi.warningSigns, isEmpty);
      expect(resHi.text, contains('Hello! I am MEDGUARD Health Assistant'));
      // UrgencyLabel must NOT be "GENERAL SELF-CARE"
      expect(resHi.urgencyLabel, isNot(equals('GENERAL SELF-CARE')));

      final resHello = fallback.generateFallback('hello Medguard');
      expect(resHello.intent, equals('greeting'));
      expect(resHello.isGreeting, isTrue);

      final resMorning = fallback.generateFallback('good morning');
      expect(resMorning.intent, equals('greeting'));
      expect(resMorning.isGreeting, isTrue);
    });

    test('HealthSafetyFilter does not inject clinical disclaimers or medicine warnings to greeting', () {
      final raw = fallback.generateFallback('hi');
      final filtered = HealthSafetyFilter.filter(userQuery: 'hi', response: raw);

      expect(filtered.intent, equals('greeting'));
      expect(filtered.isGreeting, isTrue);
      expect(filtered.considerations, isEmpty);
      expect(filtered.warningSigns, isEmpty);
      expect(filtered.text, isNot(contains('MEDGUARD CLINICAL DISCLAIMER')));
    });

    test('Educational query ("What is BMI?") returns intent: education', () {
      final res = fallback.generateFallback('What is BMI?');
      expect(res.intent, equals('education'));
      expect(res.isEducation, isTrue);
      expect(res.category, contains('Body Mass Index'));
      expect(res.text, contains('kg/m²'));
    });

    test('Medication query ("paracetamol") returns intent: medicine with Pharmacist/Doctor recommendation', () {
      final res = fallback.generateFallback('Can I take paracetamol?');
      expect(res.intent, equals('medicine'));
      expect(res.isMedicine, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Pharmacist'));
      expect(res.text, contains('4,000 mg'));
    });

    test('Toothache query returns Dentist recommendation', () {
      final res = fallback.generateFallback('I have a severe toothache and gum pain');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Dentist'));
      expect(res.recommendedCare!.reason, contains('dental caries'));
    });

    test('Skin rash query returns Dermatologist recommendation', () {
      final res = fallback.generateFallback('I have an itchy skin rash on my arm');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Dermatologist'));
      expect(res.recommendedCare!.reason, contains('dermatological'));
    });

    test('Knee pain query returns Orthopedic Specialist recommendation', () {
      final res = fallback.generateFallback('I have knee pain and swollen joint');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Orthopedic'));
      expect(res.recommendedCare!.reason, contains('imaging'));
    });

    test('Headache query returns General Physician recommendation', () {
      final res = fallback.generateFallback('I have a persistent headache');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('General Physician'));
    });

    test('Emergency query ("chest pain and shortness of breath") returns intent: emergency', () {
      final res = fallback.generateFallback('I have severe chest pain and shortness of breath');
      expect(res.intent, equals('emergency'));
      expect(res.isEmergencyCase, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Emergency Department'));
      expect(res.recommendedCare!.clinicianType, contains('108'));
    });

    test('Stroke warning query ("I suddenly cannot speak clearly") triggers immediate emergency escalation', () {
      final res = fallback.generateFallback('I suddenly cannot speak clearly');
      expect(res.intent, equals('emergency'));
      expect(res.isEmergencyCase, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Emergency Department'));
      expect(res.recommendedCare!.clinicianType, contains('108'));
    });

    test('Prolonged fever query ("I have a fever for three days") returns prompt clinical evaluation', () {
      final res = fallback.generateFallback('I have a fever for three days');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('General Physician'));
      expect(res.recommendedCare!.urgency, equals('prompt'));
      expect(res.recommendedCare!.reason, contains('3 or more days'));
    });

    test('Water intake feature query ("How does water intake work?") returns intent: app_help', () {
      final res = fallback.generateFallback('How does water intake work?');
      expect(res.intent, equals('app_help'));
      expect(res.isAppHelp, isTrue);
      expect(res.category, contains('Water Tracker'));
      expect(res.text, contains('250 mL'));
    });

    test('Add medicines query ("How do I add medicines in MEDGUARD?") returns intent: app_help', () {
      final res = fallback.generateFallback('How do I add medicines in MEDGUARD?');
      expect(res.intent, equals('app_help'));
      expect(res.isAppHelp, isTrue);
      expect(res.category, contains('Medicine Reminders'));
      expect(res.text, contains('Medicines icon'));
    });

    test('Ear pain query ("Who should I see for persistent ear pain?") returns ENT specialist recommendation', () {
      final res = fallback.generateFallback('Who should I see for persistent ear pain?');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('ENT Specialist'));
      expect(res.recommendedCare!.reason, contains('otoscopic examination'));
    });

    test('Blood group query ("What does my blood group mean?") returns educational explanation', () {
      final res = fallback.generateFallback('What does my blood group mean?');
      expect(res.intent, equals('education'));
      expect(res.isEducation, isTrue);
      expect(res.category, contains('Blood Group'));
      expect(res.text, contains('ABO'));
      expect(res.text, contains('Rh factor'));
    });

    test('Fatigue query ("I\'m feeling tired") returns cautious primary care guidance without overdiagnosis', () {
      final res = fallback.generateFallback('I am feeling tired and exhausted');
      expect(res.intent, equals('symptom'));
      expect(res.isSymptom, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.recommendedCare!.clinicianType, contains('Primary-Care Physician'));
      expect(res.text, contains('sleep'));
      expect(res.text, contains('water'));
    });

    test('Antibiotics for cold query ("Should I take antibiotics for a cold?") warns against viral antibiotic use', () {
      final res = fallback.generateFallback('Should I take antibiotics for a cold?');
      expect(res.intent, equals('medicine'));
      expect(res.isMedicine, isTrue);
      expect(res.recommendedCare, isNotNull);
      expect(res.text, contains('bacteria'));
      expect(res.text, contains('ineffective against viral'));
    });
  });

  group('Web Dashboard Quick Actions Desktop Grid Tests', () {
    testWidgets('Quick Actions Grid applies mainAxisExtent: 130 on desktop viewport (>= 800px)', (tester) async {
      // Set desktop screen size
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        QuickActionData(
          icon: Icons.local_hospital_rounded,
          iconColor: const Color(0xFF00BFA5),
          bgColor: const Color(0xFFE0F2F1),
          label: 'Hospitals',
          subtitle: 'Find Care',
          onTap: () {},
        ),
        QuickActionData(
          icon: Icons.emergency_rounded,
          iconColor: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFFEBEE),
          label: 'Emergency',
          subtitle: 'SOS Alert',
          onTap: () {},
        ),
        QuickActionData(
          icon: Icons.medication_rounded,
          iconColor: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFE3F2FD),
          label: 'Medicines',
          subtitle: 'Reminders',
          onTap: () {},
        ),
        QuickActionData(
          icon: Icons.folder_shared_rounded,
          iconColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFEDE7F6),
          label: 'Health Vault',
          subtitle: 'Records',
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: Builder(
                builder: (context) {
                  return LayoutBuilder(
                    builder: (ctx, constraints) {
                      return GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 130.0,
                        ),
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) => Card(child: Text(items[idx].label)),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);

      final gridWidget = tester.widget<GridView>(gridFinder);
      final delegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, equals(4));
      expect(delegate.mainAxisExtent, equals(130.0));

      // Verify rendered card height is 130px, NOT 300px
      final cardFinder = find.byType(Card).first;
      final cardSize = tester.getSize(cardFinder);
      expect(cardSize.height, equals(130.0));
      expect(cardSize.height, lessThan(160.0));
    });

    test('Responsive breakpoint logic applies 4 cols on desktop, 3 cols on medium tablet, 4 on phone, 2 on narrow display', () {
      int getColumns(double width) {
        return width >= 800
            ? 4
            : (width >= 560 && width < 800
                ? 3
                : (width < 340 ? 2 : 4));
      }

      double getExtent(double width) {
        final isWideDesktop = width >= 800;
        final isTablet = width >= 500 && width < 800;
        return isWideDesktop ? 130.0 : (isTablet ? 114.0 : 96.0);
      }

      // Wide Desktop (1280px)
      expect(getColumns(1280), equals(4));
      expect(getExtent(1280), equals(130.0));

      // Standard Desktop (900px)
      expect(getColumns(900), equals(4));
      expect(getExtent(900), equals(130.0));

      // Medium Tablet / Split Web (700px)
      expect(getColumns(700), equals(3));
      expect(getExtent(700), equals(114.0));

      // Standard Phone (390px iPhone / Android)
      expect(getColumns(390), equals(4));
      expect(getExtent(390), equals(96.0));

      // Ultra-narrow display (320px fold screen)
      expect(getColumns(320), equals(2));
      expect(getExtent(320), equals(96.0));
    });
  });
}
