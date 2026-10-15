import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../models/ai_response.dart';
import '../models/chat_message.dart';
import 'ai_health_service.dart';
import 'health_safety_filter.dart';
import 'local_health_fallback_service.dart';

class MedGuardAIService {
  final AiHealthService _aiHealthService = AiHealthService();
  final LocalHealthFallbackService _fallbackService = LocalHealthFallbackService();
  final ApiClient _apiClient = ApiClient();

  Future<AIResponse> getGuidance({
    required String userQuery,
    List<ChatMessage> conversationHistory = const [],
    bool forceGemini = false,
  }) async {
    final cleanQuery = userQuery.trim();
    if (cleanQuery.isEmpty) {
      final rawFallback = _fallbackService.generateFallback('General Health');
      return HealthSafetyFilter.filter(userQuery: 'General Health', response: rawFallback);
    }

    // 1. Primary Route: Authenticated Cloud Backend AI Endpoint (Render)
    if (!forceGemini) {
      try {
        final token = await _apiClient.getToken();
        if (token != null && token.isNotEmpty) {
          final historyPayload = conversationHistory
              .where((m) => m.text.trim().isNotEmpty && !m.isError)
              .map((m) => {'isUser': m.isUser, 'text': m.text})
              .toList();

          final res = await _apiClient.post(
            '/ai/chat',
            body: {
              'message': cleanQuery,
              'history': historyPayload,
            },
          ).timeout(const Duration(seconds: 12));

          if (res['success'] == true && res['reply'] != null) {
            final replyText = res['reply'].toString().trim();
            final isEmergency = res['isEmergency'] == true;
            final intent = (res['intent'] ?? (isEmergency ? 'emergency' : 'general')).toString();

            RecommendedCare? recommendedCare;
            if (res['recommendedCare'] != null) {
              recommendedCare = RecommendedCare.fromMap(
                Map<String, dynamic>.from(res['recommendedCare']),
              );
            }

            final followUpQuestions = List<String>.from(res['followUpQuestions'] ?? []);
            final warningSigns = List<String>.from(res['warningSigns'] ?? []);

            HealthUrgency urgency = HealthUrgency.green;
            if (isEmergency || intent == 'emergency') {
              urgency = HealthUrgency.red;
            } else if (recommendedCare != null) {
              final u = recommendedCare.urgency.toLowerCase();
              if (u == 'urgent' || u == 'high') {
                urgency = HealthUrgency.orange;
              } else if (u == 'prompt' || u == 'medium') {
                urgency = HealthUrgency.yellow;
              }
            }

            final cloudResponse = AIResponse(
              text: replyText,
              source: AIResponseSource.gemini,
              isFallback: false,
              category: isEmergency
                  ? 'Emergency Guidance'
                  : (intent == 'greeting'
                      ? 'Greeting'
                      : (intent == 'app_help'
                          ? 'App Guidance'
                          : (intent == 'education'
                              ? 'Medical Education'
                              : (intent == 'medicine'
                                  ? 'Medication Information'
                                  : 'Symptom Guidance')))),
              isEmergency: isEmergency,
              urgency: urgency,
              understanding: cleanQuery,
              followUpQuestions: followUpQuestions,
              considerations: const [],
              whatYouCanDoNow: const [],
              warningSigns: warningSigns,
              whenToSeekMedicalHelp: isEmergency
                  ? 'Call emergency medical services immediately (108 / 112).'
                  : (recommendedCare != null
                      ? 'Consult a ${recommendedCare.clinicianType} for clinical evaluation.'
                      : ''),
              disclaimer: intent == 'greeting'
                  ? ''
                  : 'This guidance is educational and does not constitute a clinical medical diagnosis.',
              intent: intent,
              recommendedCare: recommendedCare,
            );

            return HealthSafetyFilter.filter(userQuery: cleanQuery, response: cloudResponse);
          }
        }
      } catch (e) {
        debugPrint('[MEDGUARD AI SERVICE] Cloud backend AI request unauthenticated or timed out ($e). Falling back to direct/local pipeline...');
      }
    }

    // 2. Direct SDK / REST Pipeline
    try {
      final AiHealthResponse geminiRes = await _aiHealthService
          .askAssistant(cleanQuery, conversationHistory: conversationHistory)
          .timeout(const Duration(seconds: 8));

      final aiResponse = AIResponse(
        text: geminiRes.rawText.isNotEmpty ? geminiRes.rawText : _formatGeminiText(geminiRes),
        source: AIResponseSource.gemini,
        isFallback: false,
        category: geminiRes.intent == 'greeting'
            ? 'Greeting'
            : (geminiRes.intent == 'app_help'
                ? 'App Guidance'
                : (geminiRes.intent == 'education'
                    ? 'Medical Education'
                    : (geminiRes.intent == 'medicine'
                        ? 'Medication Information'
                        : 'Gemini AI Guidance'))),
        isEmergency: geminiRes.urgency == HealthUrgency.red || geminiRes.intent == 'emergency',
        urgency: geminiRes.urgency,
        understanding: geminiRes.understanding,
        followUpQuestions: geminiRes.followUpQuestions,
        considerations: geminiRes.considerations,
        whatYouCanDoNow: geminiRes.whatYouCanDoNow,
        warningSigns: geminiRes.warningSigns,
        whenToSeekMedicalHelp: geminiRes.whenToSeekMedicalHelp,
        disclaimer: geminiRes.intent == 'greeting' ? '' : geminiRes.disclaimer,
        intent: geminiRes.intent,
        recommendedCare: geminiRes.recommendedCare,
      );

      return HealthSafetyFilter.filter(userQuery: cleanQuery, response: aiResponse);
    } catch (e) {
      debugPrint('[MEDGUARD AI SERVICE] Gemini request failed or timed out ($e). Falling back to offline health guidance.');

      final rawFallback = _fallbackService.generateFallback(cleanQuery);

      final fallbackResponse = AIResponse(
        text: rawFallback.text,
        source: AIResponseSource.localFallback,
        isFallback: true,
        category: rawFallback.category,
        isEmergency: rawFallback.isEmergency,
        urgency: rawFallback.urgency,
        understanding: rawFallback.understanding,
        followUpQuestions: rawFallback.followUpQuestions,
        considerations: rawFallback.considerations,
        whatYouCanDoNow: rawFallback.whatYouCanDoNow,
        warningSigns: rawFallback.warningSigns,
        whenToSeekMedicalHelp: rawFallback.whenToSeekMedicalHelp,
        disclaimer: rawFallback.disclaimer,
        errorInfo: e.toString(),
        intent: rawFallback.intent,
        recommendedCare: rawFallback.recommendedCare,
      );

      return HealthSafetyFilter.filter(userQuery: cleanQuery, response: fallbackResponse);
    }
  }

  String _formatGeminiText(AiHealthResponse r) {
    final sb = StringBuffer();
    sb.writeln('Summary: ${r.understanding}\n');
    if (r.considerations.isNotEmpty) {
      sb.writeln('Considerations:');
      for (final c in r.considerations) {
        sb.writeln('• $c');
      }
      sb.writeln();
    }
    if (r.whatYouCanDoNow.isNotEmpty) {
      sb.writeln('What You Can Do Now:');
      for (final a in r.whatYouCanDoNow) {
        sb.writeln('• $a');
      }
      sb.writeln();
    }
    if (r.whenToSeekMedicalHelp.isNotEmpty) {
      sb.writeln('When to Seek Help:\n${r.whenToSeekMedicalHelp}');
    }
    return sb.toString();
  }
}
