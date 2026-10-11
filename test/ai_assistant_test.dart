import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/core/config/ai_config.dart';
import 'package:med_ai/core/errors/app_exception.dart';
import 'package:med_ai/models/chat_message.dart';
import 'package:med_ai/services/ai_health_service.dart';
import 'package:med_ai/services/gemini_service.dart';
import 'package:med_ai/services/local_health_fallback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiConfig Unit Tests', () {
    test('Default API key detection returns fallback or empty', () async {
      final key = await AiConfig.getApiKey();
      final source = await AiConfig.getApiKeySource();
      expect(key, isNotNull);
      expect(source, isNotEmpty);
    });

    test('Storing key in SharedPreferences works correctly', () async {
      await AiConfig.setApiKey('AIzaSyTestKey123456');
      final updatedKey = await AiConfig.getApiKey();
      final updatedSource = await AiConfig.getApiKeySource();

      expect(updatedKey, equals('AIzaSyTestKey123456'));
      expect(updatedSource, contains('SharedPreferences Key'));
    });
  });

  group('ChatMessage Unit Tests', () {
    test('ChatMessage initializes with default timestamp', () {
      final msg = ChatMessage(text: 'I have a headache', isUser: true);
      expect(msg.text, equals('I have a headache'));
      expect(msg.isUser, isTrue);
      expect(msg.isError, isFalse);
      expect(msg.timestamp, isNotNull);
    });

    test('ChatMessage can represent an error state', () {
      final msg = ChatMessage(
        text: '',
        isUser: false,
        isError: true,
        errorMessage: 'Invalid API key',
        lastQuery: 'I have a headache',
      );
      expect(msg.isError, isTrue);
      expect(msg.errorMessage, equals('Invalid API key'));
      expect(msg.lastQuery, equals('I have a headache'));
    });
  });

  group('AiHealthService Unit Tests', () {
    final aiService = AiHealthService();

    test('Empty user query throws AppException', () async {
      expect(
        () => aiService.askAssistant('   '),
        throwsA(isA<AppException>()),
      );
    });

    test('GeminiService throws GeminiConfigException when key is missing', () async {
      final gemini = GeminiService();
      await AiConfig.setApiKey('');
      expect(
        () => gemini.generateResponse(prompt: 'Test prompt'),
        throwsA(isA<GeminiConfigException>()),
      );
    });

    test('HealthUrgency labels map correctly', () {
      final greenResp = AiHealthResponse(
        urgency: HealthUrgency.green,
        understanding: 'Headache',
        followUpQuestions: ['How long?'],
        considerations: ['Rest'],
        whatYouCanDoNow: ['Drink water'],
        warningSigns: ['High fever'],
        whenToSeekMedicalHelp: 'If persistent',
      );
      expect(greenResp.urgencyLabel, equals('GENERAL SELF-CARE'));

      final redResp = AiHealthResponse(
        urgency: HealthUrgency.red,
        understanding: 'Severe headache and blurred vision',
        followUpQuestions: ['Call 911?'],
        considerations: ['Emergency'],
        whatYouCanDoNow: ['Call emergency'],
        warningSigns: ['Loss of consciousness'],
        whenToSeekMedicalHelp: 'Immediately',
      );
      expect(redResp.urgencyLabel, equals('EMERGENCY CARE REQUIRED IMMEDIATELY'));
    });
  });

  group('LocalHealthFallbackService Clinical & Feature Tests', () {
    test('BMI query returns dedicated Body Mass Index categorization', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('What is my BMI?');
      expect(res.category, equals('Body Mass Index (BMI)'));
      expect(res.text, contains('kg/m²'));
      expect(res.text, isNot(contains('Rest in a comfortable environment and maintain regular fluid intake')));
    });

    test('Paracetamol query returns safe analgesic guidelines and 4000mg limit', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('Can I take paracetamol for fever?');
      expect(res.category, equals('Medication: Paracetamol'));
      expect(res.text, contains('4,000 mg'));
      expect(res.text, contains('liver'));
    });

    test('Medicine reminders query returns MedGuard feature guidance', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('How do medicine reminders work in MedGuard?');
      expect(res.category, equals('MedGuard Feature: Medicine Reminders'));
      expect(res.text, contains('Taken'));
      expect(res.text, contains('stock'));
    });

    test('Emergency SOS query returns MedGuard SOS protocol', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('How does emergency SOS work?');
      expect(res.category, equals('MedGuard Feature: Emergency SOS'));
      expect(res.text, contains('GPS'));
      expect(res.text, contains('108'));
    });

    test('Blood pressure query returns AHA hypertension categories', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('What are blood pressure ranges?');
      expect(res.category, equals('Cardiovascular: Blood Pressure'));
      expect(res.text, contains('120'));
      expect(res.text, contains('140'));
    });

    test('Burn first aid query provides cool water instructions and forbids ice/butter', () {
      final fallback = LocalHealthFallbackService();
      final res = fallback.generateFallback('First aid for minor burns');
      expect(res.category, equals('First Aid: Burns & Scalds'));
      expect(res.text, contains('cool running tap water'));
      expect(res.text, contains('Never apply ice'));
    });
  });
}
