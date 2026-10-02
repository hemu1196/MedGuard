import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../core/config/ai_config.dart';
import '../models/chat_message.dart';

class GeminiService {
  static const String systemInstruction =
      'You are MedGuard AI, a professional medical & health guidance assistant. '
      'Provide general educational health guidance. '
      'Do not diagnose with certainty. '
      'Do not prescribe medication or invent dosage. '
      'If asked about medication choices or prescriptions, state: "I can provide general information, but medication choice and dosage should follow your doctor\'s or pharmacist\'s advice." '
      'Encourage professional medical evaluation when appropriate. '
      'For emergencies, advise the user to contact local emergency services immediately.';

  // Candidate models to cycle through for maximum resilience across regions and API versions
  static const List<String> _candidateModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

  /// Sends a prompt to Google Gemini API using multi-model SDK strategy with REST HTTP fallback.
  Future<String> generateResponse({
    required String prompt,
    List<ChatMessage> conversationHistory = const [],
  }) async {
    final apiKey = await AiConfig.getGeminiApiKey();
    final proxyUrl = await AiConfig.getProxyUrl();

    if (apiKey.isEmpty && proxyUrl.isEmpty) {
      throw GeminiConfigException(
        'Gemini API key is not configured. Please tap the key icon at the top right to configure your API key.',
      );
    }

    // 1. Try Secure Proxy URL if configured (ideal for Web production architecture)
    if (proxyUrl.isNotEmpty) {
      try {
        return await _sendProxyRequest(proxyUrl, apiKey, prompt, conversationHistory);
      } catch (e) {
        debugPrint('[GEMINI PROXY ERROR] $e. Falling back to direct API...');
      }
    }

    // 2. Strategy A: Official google_generative_ai SDK across candidate models
    for (final modelName in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(systemInstruction),
        );

        final historyContent = <Content>[];
        for (final msg in conversationHistory) {
          if (msg.isUser) {
            historyContent.add(Content.text(msg.text));
          } else if (msg.text.isNotEmpty && !msg.isError) {
            historyContent.add(Content.model([TextPart(msg.text)]));
          }
        }

        final chat = model.startChat(history: historyContent);
        final response = await chat
            .sendMessage(Content.text(prompt))
            .timeout(const Duration(seconds: 12));

        final responseText = response.text?.trim() ?? '';
        if (responseText.isNotEmpty) {
          return responseText;
        }
      } catch (e) {
        debugPrint('[GEMINI SDK MODEL FAILED: $modelName] $e');
        _evaluateAndReThrowSpecificErrors(e);
      }
    }

    // 3. Strategy B: Direct REST HTTP API across candidate models
    for (final modelName in _candidateModels) {
      try {
        final responseText = await _fallbackRestApi(apiKey, modelName, prompt, conversationHistory);
        if (responseText.isNotEmpty) {
          return responseText;
        }
      } catch (e) {
        debugPrint('[GEMINI REST MODEL FAILED: $modelName] $e');
        _evaluateAndReThrowSpecificErrors(e);
      }
    }

    throw GeminiServerException(
      'Google AI service is currently unresponsive across candidate models. Please try again in a few moments.',
    );
  }

  Future<String> _sendProxyRequest(
    String proxyUrl,
    String apiKey,
    String prompt,
    List<ChatMessage> history,
  ) async {
    final body = json.encode({
      'prompt': prompt,
      'apiKey': apiKey,
      'history': history.map((m) => {'isUser': m.isUser, 'text': m.text}).toList(),
    });

    final response = await http
        .post(
          Uri.parse(proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['text'] ?? data['response'] ?? '';
    } else {
      throw GeminiServerException('Proxy returned status ${response.statusCode}');
    }
  }

  Future<String> _fallbackRestApi(
    String apiKey,
    String modelName,
    String prompt,
    List<ChatMessage> history,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final contentsList = <Map<String, dynamic>>[];

    for (final msg in history) {
      if (msg.text.trim().isNotEmpty && !msg.isError) {
        contentsList.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text}
          ]
        });
      }
    }

    contentsList.add({
      'role': 'user',
      'parts': [
        {'text': '$systemInstruction\n\nUser Question: $prompt'}
      ]
    });

    final body = json.encode({
      'contents': contentsList,
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      return text.toString().trim();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeminiAuthException(
        'Invalid API key or authorization error. Please check your Gemini API key in settings.',
      );
    } else if (response.statusCode == 429) {
      throw GeminiRateLimitException(
        'AI service rate limit exceeded. Please wait a moment and try again.',
      );
    } else {
      throw GeminiServerException(
        'Google AI service error (${response.statusCode}). Please try again later.',
      );
    }
  }

  void _evaluateAndReThrowSpecificErrors(Object e) {
    if (e is GeminiException) throw e;

    final errStr = e.toString().toLowerCase();

    if (errStr.contains('api_key') ||
        errStr.contains('unauthorized') ||
        errStr.contains('403') ||
        errStr.contains('401') ||
        errStr.contains('api_key_invalid')) {
      throw GeminiAuthException(
        'Invalid API key or authorization error. Please check your Gemini API key in settings.',
      );
    }

    if (errStr.contains('quota') ||
        errStr.contains('429') ||
        errStr.contains('resource_exhausted')) {
      throw GeminiRateLimitException(
        'AI service rate limit exceeded. Please wait a moment and try again.',
      );
    }

    if (errStr.contains('socketexception') ||
        errStr.contains('clientexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network_error')) {
      throw GeminiNetworkException(
        'Unable to connect to the AI service. Please check your internet connection and try again.',
      );
    }

    if (e is TimeoutException || errStr.contains('timeout')) {
      throw GeminiTimeoutException(
        'Request timed out while waiting for AI response. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> analyzePrescriptionImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final apiKey = await AiConfig.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw GeminiConfigException('Gemini API key is not configured.');
    }

    for (final modelName in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
        );

        const prompt =
            'Analyze this prescription document or medicine label image. '
            'Extract details as valid JSON ONLY:\n'
            '{\n'
            '  "title": "Prescription title or category",\n'
            '  "doctorName": "Doctor or Clinic name if visible",\n'
            '  "notes": "Instructions or notes",\n'
            '  "medicines": [\n'
            '    {\n'
            '      "name": "Medicine name and strength",\n'
            '      "dosage": "Dosage (e.g. 1 capsule)",\n'
            '      "frequency": "Frequency (e.g. Daily)",\n'
            '      "reminderTimes": ["08:00 AM"]\n'
            '    }\n'
            '  ]\n'
            '}\n'
            'If non-prescription image, return {"error": "Unable to read this prescription. Please try another image."}.';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ])
        ];

        final response = await model.generateContent(content).timeout(const Duration(seconds: 15));
        final text = response.text?.trim() ?? '';

        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonStr = text.substring(jsonStart, jsonEnd + 1);
          final decoded = json.decode(jsonStr);
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('[GEMINI OCR ERROR: $modelName] $e');
      }
    }

    return {'error': 'Unable to read this prescription. Please try another image.'};
  }
}

// Differentiated Exception Classes
abstract class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}

class GeminiConfigException extends GeminiException {
  GeminiConfigException(super.message);
}

class GeminiAuthException extends GeminiException {
  GeminiAuthException(super.message);
}

class GeminiNetworkException extends GeminiException {
  GeminiNetworkException(super.message);
}

class GeminiRateLimitException extends GeminiException {
  GeminiRateLimitException(super.message);
}

class GeminiTimeoutException extends GeminiException {
  GeminiTimeoutException(super.message);
}

class GeminiServerException extends GeminiException {
  GeminiServerException(super.message);
}
