import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
    'I have a headache',
    'I have fever',
    'I feel dizzy',
    'I have stomach pain',
    'What medicine should I take?',
    'I have headache and vomiting',
    'I suddenly have severe headache and blurred vision',
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

  Widget _buildStructuredAiResponseCard(AIResponse resp, String? lastQuery) {
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
              // Source Badge & Title Header
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
                      'MedGuard AI Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isGemini ? AppTheme.primaryTeal : AppTheme.textDark,
                      ),
                    ),
                  ),
                  // Source Badge
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
              const Divider(height: 20),

              // UNDERSTANDING
              const Text(
                'UNDERSTANDING',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resp.understanding,
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
              ),
              const SizedBox(height: 16),

              // FOLLOW-UP QUESTIONS
              if (resp.followUpQuestions.isNotEmpty) ...[
                const Text(
                  'FOLLOW-UP QUESTIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                ...resp.followUpQuestions.map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: InkWell(
                      onTap: _isThinking ? null : () => _sendMessage(q),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.help_outline, size: 16, color: AppTheme.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // CONSIDERATIONS
              if (resp.considerations.isNotEmpty) ...[
                const Text(
                  'POSSIBLE CONSIDERATIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // WHAT YOU CAN DO NOW
              if (resp.whatYouCanDoNow.isNotEmpty) ...[
                const Text(
                  'WHAT YOU CAN DO NOW',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // WARNING SIGNS
              if (resp.warningSigns.isNotEmpty) ...[
                const Text(
                  'WARNING SIGNS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                const SizedBox(height: 16),
              ],

              // WHEN TO SEEK HELP
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
              const SizedBox(height: 16),

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
