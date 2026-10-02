import 'dart:convert';
import '../services/ai_health_service.dart';

enum AIResponseSource {
  gemini,
  localFallback,
}

class AIResponse {
  final String text;
  final AIResponseSource source;
  final bool isFallback;
  final String category;
  final bool isEmergency;
  final DateTime timestamp;
  final HealthUrgency urgency;
  final String understanding;
  final List<String> followUpQuestions;
  final List<String> considerations;
  final List<String> whatYouCanDoNow;
  final List<String> warningSigns;
  final String whenToSeekMedicalHelp;
  final String disclaimer;
  final String? errorInfo;

  AIResponse({
    required this.text,
    required this.source,
    required this.isFallback,
    required this.category,
    required this.isEmergency,
    DateTime? timestamp,
    required this.urgency,
    required this.understanding,
    required this.followUpQuestions,
    required this.considerations,
    required this.whatYouCanDoNow,
    required this.warningSigns,
    required this.whenToSeekMedicalHelp,
    required this.disclaimer,
    this.errorInfo,
  }) : timestamp = timestamp ?? DateTime.now();

  String get sourceBadgeLabel {
    switch (source) {
      case AIResponseSource.gemini:
        return 'Powered by Gemini AI';
      case AIResponseSource.localFallback:
        return 'Using Offline Health Guidance';
    }
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

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'source': source.name,
      'isFallback': isFallback,
      'category': category,
      'isEmergency': isEmergency,
      'timestamp': timestamp.toIso8601String(),
      'urgency': urgency.name,
      'understanding': understanding,
      'followUpQuestions': followUpQuestions,
      'considerations': considerations,
      'whatYouCanDoNow': whatYouCanDoNow,
      'warningSigns': warningSigns,
      'whenToSeekMedicalHelp': whenToSeekMedicalHelp,
      'disclaimer': disclaimer,
      'errorInfo': errorInfo,
    };
  }

  factory AIResponse.fromMap(Map<String, dynamic> map) {
    HealthUrgency u = HealthUrgency.green;
    final uStr = (map['urgency'] ?? 'green').toString().toLowerCase();
    for (final val in HealthUrgency.values) {
      if (val.name.toLowerCase() == uStr) {
        u = val;
        break;
      }
    }

    AIResponseSource src = AIResponseSource.localFallback;
    final sStr = (map['source'] ?? 'localFallback').toString().toLowerCase();
    if (sStr.contains('gemini')) {
      src = AIResponseSource.gemini;
    }

    return AIResponse(
      text: map['text'] ?? '',
      source: src,
      isFallback: map['isFallback'] == true || map['isFallback'] == 1,
      category: map['category'] ?? 'General',
      isEmergency: map['isEmergency'] == true || map['isEmergency'] == 1,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      urgency: u,
      understanding: map['understanding'] ?? '',
      followUpQuestions: List<String>.from(map['followUpQuestions'] ?? []),
      considerations: List<String>.from(map['considerations'] ?? []),
      whatYouCanDoNow: List<String>.from(map['whatYouCanDoNow'] ?? []),
      warningSigns: List<String>.from(map['warningSigns'] ?? []),
      whenToSeekMedicalHelp: map['whenToSeekMedicalHelp'] ?? '',
      disclaimer: map['disclaimer'] ??
          'This information is general guidance and does not replace professional medical evaluation.',
      errorInfo: map['errorInfo'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AIResponse.fromJson(String source) =>
      AIResponse.fromMap(json.decode(source));
}
