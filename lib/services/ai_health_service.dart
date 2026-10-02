import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../models/chat_message.dart';
import 'gemini_service.dart';

enum HealthUrgency {
  green,  // General self-care
  yellow, // Doctor consultation recommended
  orange, // Urgent medical review
  red,    // Emergency
}

class AiHealthResponse {
  final HealthUrgency urgency;
  final String understanding;
  final List<String> followUpQuestions;
  final List<String> considerations;
  final List<String> whatYouCanDoNow;
  final List<String> warningSigns;
  final String whenToSeekMedicalHelp;
  final String rawText;
  final String disclaimer;

  AiHealthResponse({
    required this.urgency,
    required this.understanding,
    required this.followUpQuestions,
    required this.considerations,
    required this.whatYouCanDoNow,
    required this.warningSigns,
    required this.whenToSeekMedicalHelp,
    this.rawText = '',
    this.disclaimer =
        'This information is general guidance and does not replace professional medical evaluation. Always consult a healthcare provider for medical diagnosis and prescriptions.',
  });

  Map<String, dynamic> toMap() {
    return {
      'urgency': urgency.name,
      'understanding': understanding,
      'followUpQuestions': followUpQuestions,
      'considerations': considerations,
      'whatYouCanDoNow': whatYouCanDoNow,
      'warningSigns': warningSigns,
      'whenToSeekMedicalHelp': whenToSeekMedicalHelp,
      'rawText': rawText,
      'disclaimer': disclaimer,
    };
  }

  factory AiHealthResponse.fromMap(Map<String, dynamic> map) {
    HealthUrgency u = HealthUrgency.green;
    final uStr = (map['urgency'] ?? 'green').toString().toLowerCase();
    for (final val in HealthUrgency.values) {
      if (val.name.toLowerCase() == uStr) {
        u = val;
        break;
      }
    }
    return AiHealthResponse(
      urgency: u,
      understanding: map['understanding'] ?? '',
      followUpQuestions: List<String>.from(map['followUpQuestions'] ?? []),
      considerations: List<String>.from(map['considerations'] ?? []),
      whatYouCanDoNow: List<String>.from(map['whatYouCanDoNow'] ?? []),
      warningSigns: List<String>.from(map['warningSigns'] ?? []),
      whenToSeekMedicalHelp: map['whenToSeekMedicalHelp'] ?? '',
      rawText: map['rawText'] ?? '',
      disclaimer: map['disclaimer'] ??
          'This information is general guidance and does not replace professional medical evaluation.',
    );
  }

  String get urgencyLabel {
    switch (urgency) {
      case HealthUrgency.green:
        return 'GENERAL SELF-CARE';
      case HealthUrgency.yellow:
        return 'DOCTOR CONSULTATION RECOMMENDED';
      case HealthUrgency.orange:
        return 'URGENT MEDICAL REVIEW';
      case HealthUrgency.red:
        return 'EMERGENCY CARE REQUIRED IMMEDIATELY';
    }
  }
}

class AiHealthService {
  final GeminiService _geminiService = GeminiService();

  Future<AiHealthResponse> askAssistant(
    String userQuery, {
    List<ChatMessage> conversationHistory = const [],
  }) async {
    final cleanQuery = userQuery.trim();
    if (cleanQuery.isEmpty) {
      throw AppException('Please enter a valid health query or symptom description.');
    }

    final formattedPrompt = _buildStructuredPrompt(cleanQuery);

    final responseText = await _geminiService.generateResponse(
      prompt: formattedPrompt,
      conversationHistory: conversationHistory,
    );

    if (responseText.isEmpty) {
      throw GeminiServerException('Empty response received from Google AI service.');
    }

    // 1. Attempt parsing structured JSON output
    try {
      final jsonStart = responseText.indexOf('{');
      final jsonEnd = responseText.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonStr = responseText.substring(jsonStart, jsonEnd + 1);
        final parsed = json.decode(jsonStr);

        final rawUrgency = (parsed['urgency'] ?? 'GREEN').toString().toUpperCase();
        HealthUrgency urgency = _mapStringToUrgency(rawUrgency);

        // Override urgency if query contains explicit red-flag symptoms
        urgency = _evaluateRedFlagsInQuery(cleanQuery, urgency);

        final considerations = List<String>.from(parsed['considerations'] ?? []);

        // Medication request safeguard check
        _applyMedicationSafeguardIfNeeded(cleanQuery, considerations);

        return AiHealthResponse(
          urgency: urgency,
          understanding: parsed['understanding'] ?? cleanQuery,
          followUpQuestions: List<String>.from(parsed['followUpQuestions'] ?? []),
          considerations: considerations,
          whatYouCanDoNow: List<String>.from(parsed['whatYouCanDoNow'] ?? []),
          warningSigns: List<String>.from(parsed['warningSigns'] ?? []),
          whenToSeekMedicalHelp: parsed['whenToSeekMedicalHelp'] ??
              'Consult a doctor if symptoms persist or cause severe discomfort.',
          rawText: responseText,
          disclaimer: parsed['disclaimer'] ??
              'This information is general guidance and does not replace professional medical evaluation.',
        );
      }
    } catch (e) {
      debugPrint('[AI HEALTH SERVICE] Text response non-JSON fallback: $e');
    }

    // 2. Fallback parser for plain text / markdown responses
    return _parseTextToResponse(cleanQuery, responseText);
  }

  String _buildStructuredPrompt(String query) {
    return 'Analyze the following user health inquiry and output a structured response.\n'
        'User Question: "$query"\n\n'
        'JSON Schema Output Required:\n'
        '{\n'
        '  "urgency": "GREEN" | "YELLOW" | "ORANGE" | "RED",\n'
        '  "understanding": "Brief summary of reported symptoms/question",\n'
        '  "followUpQuestions": ["2-3 specific follow-up questions to understand context"],\n'
        '  "considerations": ["General non-diagnostic considerations"],\n'
        '  "whatYouCanDoNow": ["General non-diagnostic self-care steps"],\n'
        '  "warningSigns": ["Red-flag warning symptoms"],\n'
        '  "whenToSeekMedicalHelp": "Clear guidance on when to consult a doctor or seek emergency care",\n'
        '  "disclaimer": "General medical guidance disclaimer"\n'
        '}';
  }

  HealthUrgency _mapStringToUrgency(String urgencyStr) {
    switch (urgencyStr) {
      case 'RED':
        return HealthUrgency.red;
      case 'ORANGE':
        return HealthUrgency.orange;
      case 'YELLOW':
        return HealthUrgency.yellow;
      case 'GREEN':
      default:
        return HealthUrgency.green;
    }
  }

  HealthUrgency _evaluateRedFlagsInQuery(String query, HealthUrgency currentUrgency) {
    final lower = query.toLowerCase();

    // Red Flag Emergency Indicators
    if (lower.contains('sudden') && lower.contains('blurred vision') ||
        lower.contains('severe headache and blurred vision') ||
        lower.contains('chest pain') ||
        lower.contains('shortness of breath') ||
        lower.contains('numbness') ||
        lower.contains('paralysis') ||
        lower.contains('coughing blood') ||
        lower.contains('unconscious') ||
        lower.contains('stroke') ||
        lower.contains('heart attack')) {
      return HealthUrgency.red;
    }

    // Urgent Review Indicators
    if (lower.contains('headache and vomiting') ||
        lower.contains('fever and vomiting') ||
        lower.contains('high fever') ||
        lower.contains('severe stomach pain') ||
        lower.contains('persistent vomiting')) {
      if (currentUrgency == HealthUrgency.green || currentUrgency == HealthUrgency.yellow) {
        return HealthUrgency.orange;
      }
    }

    // Moderate Doctor Consultation Indicators
    if (lower.contains('headache') ||
        lower.contains('fever') ||
        lower.contains('dizzy') ||
        lower.contains('stomach pain') ||
        lower.contains('nausea')) {
      if (currentUrgency == HealthUrgency.green) {
        return HealthUrgency.yellow;
      }
    }

    return currentUrgency;
  }

  void _applyMedicationSafeguardIfNeeded(String query, List<String> considerations) {
    final lower = query.toLowerCase();
    if (lower.contains('what medicine') ||
        lower.contains('which medicine') ||
        lower.contains('prescribe') ||
        lower.contains('what pill') ||
        lower.contains('what drug') ||
        lower.contains('dosage')) {
      const safeguardText =
          'I can provide general information, but medication choice and dosage should follow your doctor\'s or pharmacist\'s advice.';
      if (!considerations.any((c) => c.contains('pharmacist') || c.contains('doctor\'s or pharmacist\'s advice'))) {
        considerations.insert(0, safeguardText);
      }
    }
  }

  AiHealthResponse _parseTextToResponse(String query, String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    String understanding = query;
    final followUpQuestions = <String>[];
    final considerations = <String>[];
    final whatYouCanDoNow = <String>[];
    final warningSigns = <String>[];
    String whenToSeekHelp = 'Consult a healthcare professional if symptoms persist or worsen.';

    if (lines.isNotEmpty) {
      understanding = lines.first.replaceAll(RegExp(r'^[*#-]\s*'), '').trim();
    }

    for (final line in lines.skip(1)) {
      final clean = line.replaceAll(RegExp(r'^[*#-]\s*'), '').trim();
      if (clean.length < 5) continue;

      final lower = clean.toLowerCase();

      if (clean.endsWith('?') || lower.contains('how long') || lower.contains('do you have')) {
        if (followUpQuestions.length < 3) followUpQuestions.add(clean);
      } else if (lower.contains('warning') || lower.contains('red flag') || lower.contains('seek emergency')) {
        warningSigns.add(clean);
      } else if (lower.contains('doctor') || lower.contains('medical help') || lower.contains('hospital')) {
        whenToSeekHelp = clean;
      } else if (lower.contains('rest') || lower.contains('drink') || lower.contains('stay') || lower.contains('apply') || lower.contains('hydrate')) {
        if (whatYouCanDoNow.length < 4) whatYouCanDoNow.add(clean);
      } else {
        if (considerations.length < 4) considerations.add(clean);
      }
    }

    // Default Follow-Up Questions if none extracted
    if (followUpQuestions.isEmpty) {
      final lowerQ = query.toLowerCase();
      if (lowerQ.contains('headache')) {
        followUpQuestions.addAll([
          'How long have you been experiencing this headache?',
          'Is the pain sharp, throbbing, or a dull ache?',
          'Do you have any sensitivity to light or sound?'
        ]);
      } else if (lowerQ.contains('fever')) {
        followUpQuestions.addAll([
          'What is your current body temperature reading?',
          'How many days have you had the fever?',
          'Are you experiencing chills or body aches?'
        ]);
      } else if (lowerQ.contains('dizzy') || lowerQ.contains('dizziness')) {
        followUpQuestions.addAll([
          'Does the dizziness occur when standing up suddenly?',
          'Are you experiencing any lightheadedness or nausea?',
          'Have you had enough water and meals today?'
        ]);
      } else if (lowerQ.contains('stomach')) {
        followUpQuestions.addAll([
          'Where exactly in your stomach is the pain located?',
          'Is the pain constant or coming in waves?',
          'Have you experienced any nausea or change in appetite?'
        ]);
      } else {
        followUpQuestions.addAll([
          'How long have these symptoms been present?',
          'Are your symptoms mild, moderate, or severe?',
          'Does anything make the symptoms better or worse?'
        ]);
      }
    }

    HealthUrgency urgency = _evaluateRedFlagsInQuery(query, HealthUrgency.green);
    _applyMedicationSafeguardIfNeeded(query, considerations);

    return AiHealthResponse(
      urgency: urgency,
      understanding: understanding.isNotEmpty ? understanding : query,
      followUpQuestions: followUpQuestions,
      considerations: considerations.isNotEmpty
          ? considerations
          : [
              'I can provide general information, but medication choice and dosage should follow your doctor\'s or pharmacist\'s advice.',
              'Monitor how your body feels over the next 24 hours.'
            ],
      whatYouCanDoNow: whatYouCanDoNow.isNotEmpty
          ? whatYouCanDoNow
          : ['Rest in a quiet, comfortable environment.', 'Maintain adequate hydration with water.'],
      warningSigns: warningSigns.isNotEmpty
          ? warningSigns
          : ['High fever, severe pain, or shortness of breath.', 'Confusion, blurred vision, or dizziness.'],
      whenToSeekMedicalHelp: whenToSeekHelp,
      rawText: text,
    );
  }
}
