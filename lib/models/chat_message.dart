import 'ai_response.dart';
import '../services/ai_health_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final AiHealthResponse? aiResponse;
  final AIResponse? structuredResponse;
  final String? errorMessage;
  final bool isError;
  final String? lastQuery;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.aiResponse,
    this.structuredResponse,
    this.errorMessage,
    this.isError = false,
    this.lastQuery,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser ? 1 : 0,
      'isError': isError ? 1 : 0,
      'errorMessage': errorMessage,
      'lastQuery': lastQuery,
      'timestamp': timestamp.toIso8601String(),
      'aiResponse': aiResponse?.toMap(),
      'structuredResponse': structuredResponse?.toMap(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    AIResponse? structResp;
    if (map['structuredResponse'] != null) {
      structResp = AIResponse.fromMap(
        Map<String, dynamic>.from(map['structuredResponse']),
      );
    }

    AiHealthResponse? legacyResp;
    if (map['aiResponse'] != null) {
      legacyResp = AiHealthResponse.fromMap(
        Map<String, dynamic>.from(map['aiResponse']),
      );
    }

    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] == 1 || map['isUser'] == true,
      isError: map['isError'] == 1 || map['isError'] == true,
      errorMessage: map['errorMessage'],
      lastQuery: map['lastQuery'],
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      aiResponse: legacyResp,
      structuredResponse: structResp,
    );
  }
}
