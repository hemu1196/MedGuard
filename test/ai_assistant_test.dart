import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_ai/core/config/ai_config.dart';
import 'package:med_ai/core/errors/app_exception.dart';
import 'package:med_ai/models/chat_message.dart';
import 'package:med_ai/services/ai_health_service.dart';
import 'package:med_ai/services/gemini_service.dart';

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
}
