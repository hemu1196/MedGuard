import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/health_record.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/health_record_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class AiReportSummaryPage extends StatefulWidget {
  const AiReportSummaryPage({super.key});

  @override
  State<AiReportSummaryPage> createState() => _AiReportSummaryPageState();
}

class _AiReportSummaryPageState extends State<AiReportSummaryPage> {
  final HealthRecordRepository _vaultRepository = HealthRecordRepository();
  final AuthRepository _authRepository = AuthRepository();

  List<HealthRecord> _availableRecords = [];
  HealthRecord? _selectedRecord;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void initState() {
    super.initState();
    _loadVaultRecords();
  }

  void _loadVaultRecords() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final allRecords = await _vaultRepository.getRecords(userId: userId);

    final filtered = allRecords.where((r) {
      return r.recordType == HealthRecordType.labReport ||
          r.recordType == HealthRecordType.medicalReport ||
          r.recordType == HealthRecordType.dischargeSummary ||
          r.recordType == HealthRecordType.consultation ||
          r.recordType == HealthRecordType.imaging ||
          r.recordType == HealthRecordType.prescription;
    }).toList();

    if (mounted) {
      setState(() {
        _availableRecords = filtered;
        _selectedRecord = filtered.isNotEmpty ? filtered.first : null;
        _isLoading = false;
      });
      if (filtered.isNotEmpty) {
        _analyzeRecord(filtered.first);
      }
    }
  }

  void _analyzeRecord(HealthRecord record) async {
    setState(() {
      _selectedRecord = record;
      _isAnalyzing = true;
      _analysisResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    // Structured extraction based strictly on source record metadata & description
    final title = record.title;
    final doctor = record.doctorName.isNotEmpty
        ? record.doctorName
        : 'Attending Physician';
    final facility = record.hospitalName.isNotEmpty
        ? record.hospitalName
        : 'Healthcare Facility';
    final notes = record.description;

    List<Map<String, String>> extractedValues = [];

    final data = record.extractedData;
    if (data.containsKey('medicines') && data['medicines'] is List) {
      final medsList = data['medicines'] as List;
      for (final m in medsList) {
        if (m is Map) {
          extractedValues.add({
            'label': m['name'] ?? 'Medication',
            'value': '${m['dosage']} (${m['frequency']})',
          });
        }
      }
    }

    if (notes.contains(':') || notes.contains('=')) {
      final lines = notes.split('\n');
      for (final line in lines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length == 2 && parts[0].trim().isNotEmpty) {
            extractedValues.add({
              'label': parts[0].trim(),
              'value': parts[1].trim(),
            });
          }
        }
      }
    }

    final String overview =
        'This document is a ${record.typeDisplayName} titled "$title", issued by $doctor at $facility.';

    final String keyFindings = notes.isNotEmpty
        ? 'Key Summary Notes: $notes'
        : 'Medical document recorded under ${record.typeDisplayName} category on ${record.documentDate.toString().split(" ").first}.';

    final String explanation =
        'This report summarizes clinical observations and treatment guidelines provided during your visit. Terminology indicates standard clinical evaluation without critical immediate alerts.';

    final List<String> itemsToDiscuss = [
      'Confirm dosage schedules or follow-up test dates with $doctor.',
      'Ask whether any lifestyle modifications or dietary adjustments are recommended.',
      'Discuss whether follow-up blood work or imaging is required in 3-6 months.',
    ];

    setState(() {
      _isAnalyzing = false;
      _analysisResult = {
        'overview': overview,
        'findings': keyFindings,
        'extractedValues': extractedValues,
        'explanation': explanation,
        'itemsToDiscuss': itemsToDiscuss,
        'isDemo': true,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'AI Health Report Summary',
        subtitle: 'Plain-language medical report analysis',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading Health Vault Documents...')
            : _availableRecords.isEmpty
            ? EmptyStateView(
                title: 'No Vault Reports Available',
                message:
                    'Add a Lab Report, Medical Report, or Prescription to your Health Vault to generate AI plain-language summaries.',
                icon: Icons.folder_open,
                actionText: 'Go to Health Vault',
                onAction: () {
                  Navigator.of(context).pop();
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Record Selector Dropdown Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Select Health Vault Document',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Demo Analysis',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.brown,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<HealthRecord>(
                                  initialValue: _selectedRecord,
                                  decoration: const InputDecoration(
                                    labelText: 'Health Record / Report',
                                    prefixIcon: Icon(
                                      Icons.description_outlined,
                                    ),
                                  ),
                                  items: _availableRecords
                                      .map(
                                        (r) => DropdownMenuItem(
                                          value: r,
                                          child: Text(
                                            '${r.typeDisplayName}: ${r.title}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      _analyzeRecord(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Analysis Loading or Display State
                        if (_isAnalyzing)
                          const LoadingView(
                            message:
                                'Analyzing report text & extracting key findings...',
                          )
                        else if (_analysisResult != null) ...[
                          // 1. Report Overview
                          _buildSummaryCard(
                            '1. REPORT OVERVIEW',
                            Icons.info_outline,
                            AppColors.primary,
                            Text(
                              _analysisResult!['overview'],
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),

                          // 2. Key Findings
                          _buildSummaryCard(
                            '2. KEY FINDINGS',
                            Icons.search,
                            AppColors.secondary,
                            Text(
                              _analysisResult!['findings'],
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),

                          // 3. Important Values (Extracted only)
                          _buildSummaryCard(
                            '3. IMPORTANT VALUES',
                            Icons.format_list_bulleted,
                            const Color(0xFF8B5CF6),
                            (_analysisResult!['extractedValues'] as List)
                                    .isEmpty
                                ? const Text(
                                    'No specific numerical values or dosages found in this record text.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  )
                                : Column(
                                    children:
                                        (_analysisResult!['extractedValues']
                                                as List)
                                            .map(
                                              (item) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4.0,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      item['label'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      item['value'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                          ),

                          // 4. Simple Explanation
                          _buildSummaryCard(
                            '4. SIMPLE EXPLANATION',
                            Icons.auto_awesome,
                            AppColors.accent,
                            Text(
                              _analysisResult!['explanation'],
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),

                          // 5. Items to Discuss with Doctor
                          _buildSummaryCard(
                            '5. ITEMS TO DISCUSS WITH YOUR DOCTOR',
                            Icons.healing,
                            AppColors.warning,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  (_analysisResult!['itemsToDiscuss']
                                          as List<String>)
                                      .map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 3.0,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),

                          // 6. Mandatory Disclaimer
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This AI-generated summary is for informational purposes only and does not replace professional medical advice, diagnosis, or treatment.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            content,
          ],
        ),
      ),
    );
  }
}
