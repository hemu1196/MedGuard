import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ai_response.dart';
import '../models/chat_message.dart';
import 'ai_health_service.dart';
import 'health_safety_filter.dart';
import 'local_health_fallback_service.dart';

class MedGuardAIService {
  final AiHealthService _aiHealthService = AiHealthService();
  final LocalHealthFallbackService _fallbackService = LocalHealthFallbackService();

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

    try {
      final AiHealthResponse geminiRes = await _aiHealthService
          .askAssistant(cleanQuery, conversationHistory: conversationHistory)
          .timeout(const Duration(seconds: 8));

      final aiResponse = AIResponse(
        text: geminiRes.rawText.isNotEmpty ? geminiRes.rawText : _formatGeminiText(geminiRes),
        source: AIResponseSource.gemini,
        isFallback: false,
        category: 'Gemini AI Guidance',
        isEmergency: geminiRes.urgency == HealthUrgency.red,
        urgency: geminiRes.urgency,
        understanding: geminiRes.understanding,
        followUpQuestions: geminiRes.followUpQuestions,
        considerations: geminiRes.considerations,
        whatYouCanDoNow: geminiRes.whatYouCanDoNow,
        warningSigns: geminiRes.warningSigns,
        whenToSeekMedicalHelp: geminiRes.whenToSeekMedicalHelp,
        disclaimer: geminiRes.disclaimer,
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
