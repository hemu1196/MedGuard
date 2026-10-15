import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/config/ai_config.dart';
import '../../core/database/database_helper.dart';
import '../../models/ai_response.dart';
import '../../models/chat_message.dart';
import '../../models/health_record.dart';
import '../../repositories/health_record_repository.dart';
import '../../services/ai_health_service.dart';
import '../../services/medguard_ai_service.dart';
import '../../widgets/app_header.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MedGuardAIService _medGuardAIService = MedGuardAIService();
  final HealthRecordRepository _vaultRepository = HealthRecordRepository();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isThinking = false;

  final List<ChatMessage> _messages = [];

  final List<String> _quickPrompts = [
    'What is BMI?',
    'What is paracetamol?',
    'How do medicine reminders work?',
    'Emergency SOS guide',
    'I have a headache',
    'I have fever',
    'Blood pressure ranges',
    'Blood sugar ranges',
    'First aid for minor burns',
    'I feel dizzy',
    'I have stomach pain',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final savedMaps = await DatabaseHelper.instance.getChatHistory('default_user');
      if (savedMaps.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          for (final map in savedMaps) {
            _messages.add(ChatMessage.fromMap(map));
          }
        });
        _scrollToBottom();
        return;
      }
    } catch (e) {
      debugPrint('[AI CHAT persistence load error] $e');
    }

    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Hello! I am MedGuard AI, your intelligent health companion. Describe your symptoms or ask a medical question below.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _persistChatHistory() async {
    try {
      await DatabaseHelper.instance.saveChatHistory('default_user', _messages);
    } catch (e) {
      debugPrint('[AI CHAT persistence save error] $e');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isThinking) return;

    if (!_isListening) {
      try {
        final status = await Permission.microphone.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission is required for voice input.'),
              ),
            );
          }
          return;
        }

        bool available = await _speech.initialize(
          onStatus: (status) => debugPrint('[SPEECH] status: $status'),
          onError: (error) => debugPrint('[SPEECH] error: $error'),
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (result) {
              setState(() {
                _inputController.text = result.recognizedWords;
              });
            },
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Speech recognition unavailable on this device.'),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[SPEECH] Init error: $e');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isThinking) return;

    _inputController.clear();
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isError) {
        _messages.removeLast();
      }
      if (_messages.isEmpty || !_messages.last.isUser || _messages.last.text != cleanQuery) {
        _messages.add(ChatMessage(text: cleanQuery, isUser: true));
      }
      _isThinking = true;
    });

    _persistChatHistory();
    _scrollToBottom();

    try {
      final historyForPrompt = List<ChatMessage>.from(_messages.where((m) => !m.isError));
      final response = await _medGuardAIService.getGuidance(
        userQuery: cleanQuery,
        conversationHistory: historyForPrompt,
      );

      if (!mounted) return;

      setState(() {
        _isThinking = false;
        _messages.add(
          ChatMessage(
            text: '',
            isUser: false,
            structuredResponse: response,
            lastQuery: cleanQuery,
          ),
        );
      });
      _persistChatHistory();
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AI ASSISTANT PAGE] Unexpected error: $e');
      setState(() {
        _isThinking = false;
      });
    }

    _scrollToBottom();
  }

  void _retryQuery(String query) {
    _sendMessage(query);
  }

  void _clearChat() async {
    if (_isThinking) return;
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text:
              'Hello! I am MedGuard AI, your intelligent health companion. Describe your symptoms or ask a medical question below.',
          isUser: false,
        ),
      );
    });
    await DatabaseHelper.instance.clearChatHistory('default_user');
  }

  void _saveSummaryToVault(AIResponse response) async {
    final now = DateTime.now();
    final record = HealthRecord(
      id: 'ai_summary_${now.millisecondsSinceEpoch}',
      userId: 'default_user',
      title: 'AI Summary: ${response.understanding}',
      recordType: HealthRecordType.consultation,
      createdAt: now,
      updatedAt: now,
      documentDate: now,
      doctorName: 'MedGuard AI Assistant',
      hospitalName: 'MedGuard AI System',
      description: 'Symptom Understanding: ${response.understanding}\n\n'
          'Urgency Level: ${response.urgencyLabel}\n\n'
          'Considerations: ${response.considerations.join(', ')}\n\n'
          'Self-Care Advice: ${response.whatYouCanDoNow.join(', ')}\n\n'
          'When to seek help: ${response.whenToSeekMedicalHelp}',
      tags: ['AI Assistant', response.urgencyLabel],
    );

    await _vaultRepository.saveRecord(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Health Summary saved successfully to Health Vault!'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    }
  }

  void _showApiKeyDialog() async {
    final currentKey = await AiConfig.getApiKey();
    final keyController = TextEditingController(text: currentKey);
    final keySource = await AiConfig.getApiKeySource();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Gemini API Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Source: $keySource',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your API key from Google AI Studio. Offline health guidance activates automatically when unconfigured.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = keyController.text.trim();
              await AiConfig.setApiKey(newKey);
              if (!mounted) return;
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gemini API Key saved successfully.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'MedGuard AI Assistant',
        subtitle: 'Intelligent Health & Symptom Guidance',
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Configure API Key',
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
            tooltip: 'Clear Chat History',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Prompts Row
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.primaryTeal.withValues(
                      alpha: 0.08,
                    ),
                    side: BorderSide(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                    ),
                    onPressed: _isThinking ? null : () => _sendMessage(prompt),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Chat Messages List
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isThinking) {
                        return _buildThinkingIndicator();
                      }
                      final msg = _messages[index];
                      if (msg.isUser) {
                        return _buildUserBubble(msg.text);
                      } else if (msg.isError) {
                        return _buildAiErrorCard(msg);
                      } else if (msg.structuredResponse != null) {
                        return _buildStructuredAiResponseCard(msg.structuredResponse!, msg.lastQuery);
                      } else if (msg.aiResponse != null) {
                        return _buildLegacyAiResponseCard(msg.aiResponse!);
                      } else {
                        return _buildSystemBubble(msg.text);
                      }
                    },
                  ),
                ),
              ),
            ),

            // Input Field
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          enabled: !_isThinking,
                          onSubmitted: _isThinking ? null : _sendMessage,
                          decoration: InputDecoration(
                            hintText: _isThinking
                                ? 'MedGuard AI is responding...'
                                : 'Describe your symptoms or ask a question...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening ? AppColors.emergency : AppTheme.primaryTeal,
                        ),
                        onPressed: _isThinking ? null : _toggleListening,
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: _isThinking
                            ? null
                            : () => _sendMessage(_inputController.text),
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppTheme.primaryTeal,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSystemBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryTeal,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'MedGuard AI is analyzing your inquiry...',
              style: TextStyle(
                color: AppTheme.primaryTeal,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiErrorCard(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 24),
      child: Card(
        color: const Color(0xFFFEF2F2),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.accentRed,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI Assistant Response Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.accentRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                msg.errorMessage ??
                    'AI Assistant is currently unavailable. Please try again later.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
              ),
              const SizedBox(height: 12),
              const Text(
                'Disclaimer: Medical advice requires professional clinical evaluation. For emergencies, please call 108/911 immediately.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showApiKeyDialog,
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: const Text('API Key'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (msg.lastQuery != null)
                    ElevatedButton.icon(
                      onPressed: () => _retryQuery(msg.lastQuery!),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot place call to $phoneNumber automatically.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[PHONE CALL ERROR] $e');
    }
  }

  Widget _buildStructuredAiResponseCard(AIResponse resp, String? lastQuery) {
    if (resp.isGreeting) {
      return _buildGreetingResponseCard(resp, lastQuery);
    }
    if (resp.isEmergencyCase) {
      return _buildEmergencyResponseCard(resp, lastQuery);
    }
    if (resp.isAppHelp || resp.isEducation) {
      return _buildEducationalResponseCard(resp, lastQuery);
    }
    return _buildSymptomGuidanceCard(resp, lastQuery);
  }

  Widget _buildGreetingResponseCard(AIResponse resp, String? lastQuery) {
    final isGemini = resp.source == AIResponseSource.gemini;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MedGuard AI Assistant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Your Intelligent Health Companion',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGemini
                          ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGemini
                            ? AppTheme.primaryTeal.withValues(alpha: 0.3)
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Text(
                      resp.sourceBadgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isGemini ? AppTheme.primaryTeal : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Greeting Message
              Text(
                resp.text.isNotEmpty ? resp.text : resp.understanding,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textDark,
                ),
              ),

              // Follow-up Suggestions
              if (resp.followUpQuestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'HOW CAN I HELP YOU TODAY?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resp.followUpQuestions.map((q) {
                    return ActionChip(
                      avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.primaryTeal),
                      label: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.06),
                      side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onPressed: _isThinking ? null : () => _sendMessage(q),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 12),
              // Copy Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: resp.text.isNotEmpty ? resp.text : resp.understanding));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard ✓'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                  label: const Text('Copy', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyResponseCard(AIResponse resp, String? lastQuery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        color: const Color(0xFFFEF2F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.accentRed, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Red Emergency Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EMERGENCY CARE REQUIRED IMMEDIATELY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Understanding / Symptoms description
              Text(
                resp.understanding.isNotEmpty ? resp.understanding : resp.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentRed,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Severe emergency symptoms reported. Please seek immediate clinical emergency evaluation. Do not attempt to drive yourself.',
                style: TextStyle(fontSize: 13, color: AppTheme.textDark, height: 1.4),
              ),

              // Red-Flag Warnings
              if (resp.warningSigns.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'CRITICAL WARNING SIGNS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.accentRed,
                  ),
                ),
                const SizedBox(height: 4),
                ...resp.warningSigns.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.accentRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.accentRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              const SizedBox(height: 16),
              // Prominent Emergency Buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _makePhoneCall('108'),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call 108 Ambulance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _makePhoneCall('112'),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call 112 Emergency'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.emergency),
                    icon: const Icon(Icons.sos_rounded, size: 18),
                    label: const Text('Trigger Emergency SOS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.hospitals),
                    icon: const Icon(Icons.local_hospital_rounded, size: 18),
                    label: const Text('Nearest ER Hospitals'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(),
              const Text(
                'Emergency Protocol: MedGuard is an assistive guidance platform and does not replace official emergency services. In severe respiratory, cardiac, or traumatic distress, call 108 or 112 without delay.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEducationalResponseCard(AIResponse resp, String? lastQuery) {
    final isGemini = resp.source == AIResponseSource.gemini;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isGemini ? Icons.smart_toy_outlined : Icons.offline_bolt_outlined,
                    color: isGemini ? AppTheme.primaryTeal : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resp.category.isNotEmpty ? resp.category : 'Health Information',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGemini
                          ? AppTheme.primaryTeal.withValues(alpha: 0.1)
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGemini
                            ? AppTheme.primaryTeal.withValues(alpha: 0.3)
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Text(
                      resp.sourceBadgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isGemini ? AppTheme.primaryTeal : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Text or Understanding
              Text(
                resp.text.isNotEmpty ? resp.text : resp.understanding,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textDark),
              ),

              // Considerations
              if (resp.considerations.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'KEY DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                ...resp.considerations.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 13, height: 1.4))),
                      ],
                    ),
                  ),
                ),
              ],

              // What You Can Do Now
              if (resp.whatYouCanDoNow.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'RECOMMENDED STEPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 6),
                ...resp.whatYouCanDoNow.map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.primaryTeal),
                        const SizedBox(width: 6),
                        Expanded(child: Text(a, style: const TextStyle(fontSize: 13, height: 1.4))),
                      ],
                    ),
                  ),
                ),
              ],

              // Suggested Follow-up Questions in Wrap
              _buildFollowUpQuestionsWrap(resp.followUpQuestions),

              const SizedBox(height: 12),
              // Action Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.textDark),
                    label: const Text('Copy Guidance', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: resp.text.isNotEmpty ? resp.text : resp.understanding));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Guidance copied to clipboard ✓')),
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 15, color: AppTheme.primaryBlue),
                    label: const Text('Save to Health Vault', style: TextStyle(fontSize: 11)),
                    onPressed: () => _saveSummaryToVault(resp),
                  ),
                  if (resp.isFallback && lastQuery != null)
                    ActionChip(
                      avatar: const Icon(Icons.refresh_rounded, size: 15, color: AppTheme.primaryTeal),
                      label: const Text('Try AI again', style: TextStyle(fontSize: 11)),
                      onPressed: () => _retryQuery(lastQuery),
                    ),
                ],
              ),

              if (resp.disclaimer.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  resp.disclaimer,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomGuidanceCard(AIResponse resp, String? lastQuery) {
    Color urgencyBg;
    Color urgencyBorder;
    Color urgencyTextColor;
    IconData urgencyIcon;

    switch (resp.urgency) {
      case HealthUrgency.green:
        urgencyBg = Colors.green.shade50;
        urgencyBorder = Colors.green.shade300;
        urgencyTextColor = Colors.green.shade800;
        urgencyIcon = Icons.check_circle_outline;
        break;
      case HealthUrgency.yellow:
        urgencyBg = Colors.amber.shade50;
        urgencyBorder = Colors.amber.shade300;
        urgencyTextColor = Colors.amber.shade900;
        urgencyIcon = Icons.info_outline;
        break;
      case HealthUrgency.orange:
        urgencyBg = Colors.orange.shade50;
        urgencyBorder = Colors.orange.shade400;
        urgencyTextColor = Colors.orange.shade900;
        urgencyIcon = Icons.warning_amber_rounded;
        break;
      case HealthUrgency.red:
        urgencyBg = const Color(0xFFFEF2F2);
        urgencyBorder = AppTheme.accentRed;
        urgencyTextColor = AppTheme.accentRed;
        urgencyIcon = Icons.emergency;
        break;
    }

    final isGemini = resp.source == AIResponseSource.gemini;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isGemini ? Icons.smart_toy_outlined : Icons.offline_bolt_outlined,
                    color: isGemini ? AppTheme.primaryTeal : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MedGuard Symptom Guidance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isGemini ? AppTheme.primaryTeal : AppTheme.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGemini
                          ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isGemini
                            ? AppTheme.primaryTeal.withValues(alpha: 0.4)
                            : Colors.amber.shade400,
                      ),
                    ),
                    child: Text(
                      resp.sourceBadgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isGemini ? AppTheme.primaryTeal : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Urgency Classification Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: urgencyBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: urgencyBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(urgencyIcon, color: urgencyTextColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resp.urgencyLabel,
                        style: TextStyle(
                          color: urgencyTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // UNDERSTANDING
              const Text(
                'UNDERSTANDING',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resp.understanding,
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
              ),

              // MANDATORY RECOMMENDED CARE / DOCTOR TYPE CARD
              _buildRecommendedCareCard(resp),

              // FOLLOW-UP QUESTIONS in responsive Wrap
              _buildFollowUpQuestionsWrap(resp.followUpQuestions),

              // CONSIDERATIONS
              if (resp.considerations.isNotEmpty) ...[
                const Text(
                  'POSSIBLE CONSIDERATIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                ...resp.considerations.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                        Expanded(
                          child: Text(item, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // WHAT YOU CAN DO NOW
              if (resp.whatYouCanDoNow.isNotEmpty) ...[
                const Text(
                  'WHAT YOU CAN DO NOW',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppTheme.primaryTeal,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                ...resp.whatYouCanDoNow.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // WARNING SIGNS
              if (resp.warningSigns.isNotEmpty) ...[
                const Text(
                  'WARNING SIGNS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppTheme.accentRed,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                ...resp.warningSigns.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppTheme.accentRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.accentRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // WHEN TO SEEK HELP
              if (resp.whenToSeekMedicalHelp.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_hospital_outlined,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resp.whenToSeekMedicalHelp,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Quick Actions Bar
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.local_hospital, size: 16, color: AppTheme.primaryTeal),
                    label: const Text('Nearby Hospital', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.hospitals),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.sos_rounded, size: 16, color: AppTheme.accentRed),
                    label: const Text('Emergency SOS', style: TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: AppTheme.accentRed),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.emergency),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textDark),
                    label: const Text('Copy Guidance', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final fullText = resp.text.isNotEmpty
                          ? resp.text
                          : '${resp.understanding}\n\n${resp.considerations.join('\n')}\n\n${resp.whatYouCanDoNow.join('\n')}\n\n${resp.whenToSeekMedicalHelp}';
                      Clipboard.setData(ClipboardData(text: fullText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Guidance copied to clipboard ✓'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 16, color: AppTheme.primaryBlue),
                    label: const Text('Save to Health Vault', style: TextStyle(fontSize: 11)),
                    onPressed: () => _saveSummaryToVault(resp),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.alarm_add, size: 16, color: Colors.purple),
                    label: const Text('Add Medicine Reminder', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.medicines),
                  ),
                  if (resp.isFallback && lastQuery != null)
                    ActionChip(
                      avatar: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primaryTeal),
                      label: const Text('Try AI again', style: TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.08),
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      onPressed: () => _retryQuery(lastQuery),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Medical Disclaimer
              if (resp.disclaimer.isNotEmpty)
                Text(
                  resp.disclaimer,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedCareCard(AIResponse resp) {
    final care = resp.recommendedCare ??
        RecommendedCare(
          clinicianType: 'General Physician / Primary-Care Doctor',
          urgency: 'routine',
          urgencyLabel: 'Medical Consultation',
          reason: 'A qualified clinician can physically examine your symptoms and provide personalized diagnosis.',
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services_rounded, color: AppTheme.primaryTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECOMMENDED CARE / DOCTOR TYPE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      care.clinicianType,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.4)),
                ),
                child: Text(
                  care.urgencyLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          if (care.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              care.reason,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.hospitals),
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('Find Nearby Clinics & Hospitals'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryTeal,
                side: const BorderSide(color: AppTheme.primaryTeal),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpQuestionsWrap(List<String> questions) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Text(
          'FOLLOW-UP QUESTIONS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: AppTheme.primaryBlue,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: questions.map((q) {
            return ActionChip(
              avatar: const Icon(Icons.help_outline_rounded, size: 14, color: AppTheme.primaryBlue),
              label: Text(
                q,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
              side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onPressed: _isThinking ? null : () => _sendMessage(q),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildLegacyAiResponseCard(AiHealthResponse resp) {
    final struct = AIResponse(
      text: resp.rawText,
      source: AIResponseSource.gemini,
      isFallback: false,
      category: 'Legacy Response',
      isEmergency: resp.urgency == HealthUrgency.red,
      urgency: resp.urgency,
      understanding: resp.understanding,
      followUpQuestions: resp.followUpQuestions,
      considerations: resp.considerations,
      whatYouCanDoNow: resp.whatYouCanDoNow,
      warningSigns: resp.warningSigns,
      whenToSeekMedicalHelp: resp.whenToSeekMedicalHelp,
      disclaimer: resp.disclaimer,
    );
    return _buildStructuredAiResponseCard(struct, null);
  }
}
