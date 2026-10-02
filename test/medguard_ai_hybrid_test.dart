import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/models/ai_response.dart';
import 'package:med_ai/services/ai_health_service.dart';
import 'package:med_ai/services/health_safety_filter.dart';
import 'package:med_ai/services/local_health_fallback_service.dart';
import 'package:med_ai/services/medguard_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalHealthFallbackService Unit Tests', () {
    final fallbackService = LocalHealthFallbackService();

    test('Identifies headache category correctly', () {
      final res = fallbackService.generateFallback('I have a sharp headache');
      expect(res.category, equals('Headache'));
      expect(res.isFallback, isTrue);
      expect(res.source, equals(AIResponseSource.localFallback));
      expect(res.whatYouCanDoNow.isNotEmpty, isTrue);
      expect(res.followUpQuestions.isNotEmpty, isTrue);
    });

    test('Identifies fever category correctly', () {
      final res = fallbackService.generateFallback('I have a high fever');
      expect(res.category, equals('Fever'));
      expect(res.urgency, equals(HealthUrgency.yellow));
    });

    test('Identifies combined headache and vomiting category', () {
      final res = fallbackService.generateFallback('I have a severe headache and vomiting');
      expect(res.category, equals('Headache + Vomiting'));
      expect(res.urgency, equals(HealthUrgency.orange));
    });

    test('Identifies emergency chest pain and sets RED urgency', () {
      final res = fallbackService.generateFallback('I have chest pain and difficulty breathing');
      expect(res.isEmergency, isTrue);
      expect(res.urgency, equals(HealthUrgency.red));
    });

    test('Identifies medication questions and includes safety advice', () {
      final res = fallbackService.generateFallback('What medicine should I take for fever?');
      expect(res.category, equals('Medication Safety'));
      expect(res.considerations.any((c) => c.contains('pharmacist') || c.contains('doctor\'s')), isTrue);
    });
  });

  group('HealthSafetyFilter Unit Tests', () {
    test('Forces RED urgency and emergency guidance on chest pain red flag', () {
      final baseResponse = AIResponse(
        text: 'Sample text',
        source: AIResponseSource.localFallback,
        isFallback: true,
        category: 'General',
        isEmergency: false,
        urgency: HealthUrgency.green,
        understanding: 'General issue',
        followUpQuestions: [],
        considerations: [],
        whatYouCanDoNow: [],
        warningSigns: [],
        whenToSeekMedicalHelp: 'Consult doctor',
        disclaimer: 'General disclaimer',
      );

      final filtered = HealthSafetyFilter.filter(
        userQuery: 'I have severe chest pain',
        response: baseResponse,
      );

      expect(filtered.isEmergency, isTrue);
      expect(filtered.urgency, equals(HealthUrgency.red));
      expect(filtered.warningSigns.any((w) => w.contains('EMERGENCY')), isTrue);
    });

    test('Enforces medication safeguard on medicine query', () {
      final baseResponse = AIResponse(
        text: 'Sample text',
        source: AIResponseSource.localFallback,
        isFallback: true,
        category: 'General',
        isEmergency: false,
        urgency: HealthUrgency.green,
        understanding: 'General issue',
        followUpQuestions: [],
        considerations: ['Rest well'],
        whatYouCanDoNow: [],
        warningSigns: [],
        whenToSeekMedicalHelp: 'Consult doctor',
        disclaimer: 'General disclaimer',
      );

      final filtered = HealthSafetyFilter.filter(
        userQuery: 'What pill or antibiotic should I take?',
        response: baseResponse,
      );

      expect(filtered.considerations.any((c) => c.contains('pharmacist') || c.contains('doctor\'s or pharmacist\'s advice')), isTrue);
    });
  });

  group('MedGuardAIService Hybrid Integration Tests', () {
    final aiService = MedGuardAIService();

    test('Returns safe fallback response when Gemini fails or is unconfigured', () async {
      final response = await aiService.getGuidance(userQuery: 'I have stomach pain');
      expect(response.text.isNotEmpty, isTrue);
      expect(response.source, equals(AIResponseSource.localFallback));
      expect(response.isFallback, isTrue);
      expect(response.sourceBadgeLabel, equals('Using Offline Health Guidance'));
      expect(response.disclaimer.isNotEmpty, isTrue);
    });

    test('Handles emergency symptoms safely', () async {
      final response = await aiService.getGuidance(userQuery: 'I suddenly have shortness of breath and chest pain');
      expect(response.isEmergency, isTrue);
      expect(response.urgency, equals(HealthUrgency.red));
    });
  });
}
