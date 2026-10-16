import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../app/theme.dart';
import '../../core/utils/image_helper.dart';
import '../../models/health_record.dart';
import '../../services/pdf_export_service.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/health_record_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class HealthVaultPage extends StatefulWidget {
  const HealthVaultPage({super.key});

  @override
  State<HealthVaultPage> createState() => _HealthVaultPageState();
}

class _HealthVaultPageState extends State<HealthVaultPage> {
  final HealthRecordRepository _vaultRepository = HealthRecordRepository();
  final AuthRepository _authRepository = AuthRepository();

  String? _currentUserId;
  String _searchQuery = '';
  HealthRecordType? _selectedCategoryFilter;

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'type': null, 'label': 'All', 'color': AppColors.primary},
    {
      'type': HealthRecordType.labReport,
      'label': 'Blood Reports',
      'color': AppColors.secondary,
    },
    {
      'type': HealthRecordType.imaging,
      'label': 'X-Rays & Scans',
      'color': const Color(0xFF4F46E5),
    },
    {
      'type': HealthRecordType.prescription,
      'label': 'Prescriptions',
      'color': AppColors.primary,
    },
    {
      'type': HealthRecordType.vaccination,
      'label': 'Vaccinations',
      'color': AppColors.success,
    },
    {
      'type': HealthRecordType.consultation,
      'label': 'Doctor Notes',
      'color': AppColors.accent,
    },
    {
      'type': HealthRecordType.medicalReport,
      'label': 'Medical Documents',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'type': HealthRecordType.other,
      'label': 'Other',
      'color': AppColors.textSecondary,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  void _initUser() async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      debugPrint('[HEALTH VAULT] User auth error: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HealthRecord> _filterRecords(List<HealthRecord> records) {
    return records.where((r) {
      final matchesCategory =
          _selectedCategoryFilter == null ||
          r.recordType == _selectedCategoryFilter;
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          query.isEmpty ||
          r.title.toLowerCase().contains(query) ||
          r.doctorName.toLowerCase().contains(query) ||
          r.hospitalName.toLowerCase().contains(query) ||
          r.typeDisplayName.toLowerCase().contains(query) ||
          r.tags.any((t) => t.toLowerCase().contains(query));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _deleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Health Record?'),
        content: const Text(
          'Are you sure you want to delete this record from your Health Vault? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
      await _vaultRepository.deleteRecord(id, userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health record deleted.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    }
  }

  void _openAddEditRecordModal({HealthRecord? recordToEdit, HealthRecordType? initialType}) {
    final titleController = TextEditingController(text: recordToEdit?.title ?? '');
    final doctorController = TextEditingController(text: recordToEdit?.doctorName ?? '');
    final hospitalController = TextEditingController(text: recordToEdit?.hospitalName ?? '');
    final notesController = TextEditingController(text: recordToEdit?.description ?? '');

    HealthRecordType selectedType = recordToEdit?.recordType ?? initialType ?? HealthRecordType.labReport;
    DateTime documentDate = recordToEdit?.documentDate ?? DateTime.now();
    String? attachedFilePath = recordToEdit?.fileUrl;
    Uint8List? attachedFileBytes;
    String? attachedFileName;
    String? dialogErrorText;
    bool isSaving = false;

    final picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false, // Form MUST remain open until Save or Cancel
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isEditing = recordToEdit != null;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Health Record' : 'Add New Record'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogErrorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.emergency),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dialogErrorText!,
                              style: const TextStyle(
                                color: AppColors.emergency,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Title Field
                  TextField(
                    controller: titleController,
                    autofocus: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Record Title *',
                      hintText: 'e.g. Blood Test, Chest X-Ray, Dr Note',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Record Type Dropdown
                  DropdownButtonFormField<HealthRecordType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Record Type *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: HealthRecordType.labReport,
                        child: Text('Blood Report'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.imaging,
                        child: Text('X-Ray'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.prescription,
                        child: Text('Prescription'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.vaccination,
                        child: Text('Vaccination'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.consultation,
                        child: Text('Doctor Note'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.medicalReport,
                        child: Text('Medical Document'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.other,
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Document Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: documentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => documentDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(documentDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Doctor Name
                  TextField(
                    controller: doctorController,
                    decoration: const InputDecoration(
                      labelText: 'Doctor Name',
                      hintText: 'e.g. Dr. John Smith',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hospital / Facility
                  TextField(
                    controller: hospitalController,
                    decoration: const InputDecoration(
                      labelText: 'Hospital / Facility',
                      hintText: 'e.g. General Hospital',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description / Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description / Notes',
                      hintText: 'Add important notes or instructions',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attachments Section (Camera, Gallery, File)
                  const Text(
                    'Attachment:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final file = await picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 85,
                              );
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  attachedFilePath = file.path;
                                  attachedFileBytes = bytes;
                                  attachedFileName = file.name;
                                });
                              }
                            } catch (e) {
                              debugPrint('[ATTACHMENT CAMERA ERROR] $e');
                            }
                          },
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Camera', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final file = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setDialogState(() {
                                  attachedFilePath = file.path;
                                  attachedFileBytes = bytes;
                                  attachedFileName = file.name;
                                });
                              }
                            } catch (e) {
                              debugPrint('[ATTACHMENT GALLERY ERROR] $e');
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'png',
                                  'jpg',
                                  'jpeg',
                                  'webp',
                                  'doc',
                                  'docx',
                                  'txt',
                                ],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.first;
                                Uint8List? bytes = file.bytes;
                                if (bytes == null && file.path != null) {
                                  bytes = await ImageHelper.loadBytes(file.path);
                                }
                                setDialogState(() {
                                  attachedFilePath = file.path ?? file.name;
                                  attachedFileBytes = bytes;
                                  attachedFileName = file.name;
                                });
                              }
                            } catch (e) {
                              debugPrint('[ATTACHMENT FILE ERROR] $e');
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text('File/PDF', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (attachedFilePath != null && attachedFilePath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: AppTheme.primaryTeal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              attachedFileName ?? attachedFilePath!.split('/').last,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setDialogState(() {
                              attachedFilePath = null;
                              attachedFileBytes = null;
                              attachedFileName = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          setDialogState(() {
                            dialogErrorText = 'Please enter a Record Title.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          dialogErrorText = null;
                        });

                        try {
                          final userId =
                              _currentUserId ?? await _authRepository.getCurrentUserId();

                          final record = HealthRecord(
                            id: recordToEdit?.id ??
                                'rec_${DateTime.now().millisecondsSinceEpoch}',
                            userId: userId,
                            recordType: selectedType,
                            title: title,
                            description: notesController.text.trim(),
                            createdAt: recordToEdit?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                            documentDate: documentDate,
                            doctorName: doctorController.text.trim(),
                            hospitalName: hospitalController.text.trim(),
                            fileUrl: attachedFilePath,
                          );

                          await _vaultRepository.saveRecord(
                            record,
                            fileBytes: attachedFileBytes,
                            fileName: attachedFileName,
                            throwOnError: true,
                          );

                          if (mounted && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'Health record updated successfully.'
                                      : 'Health record added successfully.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            setState(() {});
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                              dialogErrorText = 'Upload/save failed: ${e.toString().replaceAll("Exception:", "").trim()}';
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Save Record'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Uint8List> _resolveRecordPdfBytes(HealthRecord record) async {
    if (record.hasFileAttachment) {
      try {
        final rawBytes = await _vaultRepository.getRecordBytes(record);
        if (rawBytes.isNotEmpty) {
          // If file starts with %PDF-, it's already a valid PDF
          if (rawBytes.length > 4 &&
              rawBytes[0] == 0x25 && // %
              rawBytes[1] == 0x50 && // P
              rawBytes[2] == 0x44 && // D
              rawBytes[3] == 0x46) { // F
            return rawBytes;
          }
          // Otherwise convert image bytes into formatted A4 PDF
          return await PdfExportService().convertImageToPdf(
            imageBytes: rawBytes,
            title: record.title,
            recordDate: DateFormat('MMM dd, yyyy').format(record.documentDate),
            patientName: record.doctorName.isNotEmpty ? 'Prescribed by Dr. ${record.doctorName}' : null,
          );
        }
      } catch (e) {
        debugPrint('[VAULT] _resolveRecordPdfBytes backend fetch note: $e');
        if (record.fileUrl != null && record.fileUrl!.isNotEmpty) {
          final localBytes = await ImageHelper.loadBytes(record.fileUrl);
          if (localBytes != null && localBytes.isNotEmpty) {
            if (localBytes.length > 4 &&
                localBytes[0] == 0x25 &&
                localBytes[1] == 0x50 &&
                localBytes[2] == 0x44 &&
                localBytes[3] == 0x46) {
              return localBytes;
            }
            return await PdfExportService().convertImageToPdf(
              imageBytes: localBytes,
              title: record.title,
              recordDate: DateFormat('MMM dd, yyyy').format(record.documentDate),
              patientName: record.doctorName.isNotEmpty ? 'Prescribed by Dr. ${record.doctorName}' : null,
            );
          }
        }
      }
    }
    // Summary PDF if no raw file attachment
    return await PdfExportService().generateHealthRecordSummaryPdf(record: record);
  }

  bool _isPdfBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < 4) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  Future<void> _downloadOriginalFile(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading original attachment...'),
          duration: Duration(seconds: 1),
        ),
      );
      final rawBytes = await _vaultRepository.getRecordBytes(record);
      final isPdf = _isPdfBytes(rawBytes) || record.isPdf;
      final ext = isPdf ? 'pdf' : 'jpg';
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}_original.$ext';
      final mimeType = isPdf ? 'application/pdf' : 'image/jpeg';
      await PdfExportService().downloadOriginalFile(
        bytes: rawBytes,
        filename: safeName,
        mimeType: mimeType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to download original file: $e'),
          ),
        );
      }
    }
  }

  Future<void> _shareOriginalFile(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing original attachment for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );
      final rawBytes = await _vaultRepository.getRecordBytes(record);
      final isPdf = _isPdfBytes(rawBytes) || record.isPdf;
      final ext = isPdf ? 'pdf' : 'jpg';
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}_original.$ext';
      final mimeType = isPdf ? 'application/pdf' : 'image/jpeg';
      await PdfExportService().shareOriginalFile(
        bytes: rawBytes,
        filename: safeName,
        mimeType: mimeType,
        subject: 'MEDGUARD Original Document - ${record.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to share original file: $e'),
          ),
        );
      }
    }
  }

  Future<void> _downloadSummaryPdf(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating clinical summary PDF...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await PdfExportService().generateHealthRecordSummaryPdf(record: record);
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}_summary.pdf';
      await PdfExportService().downloadPdf(bytes: pdfBytes, filename: safeName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to download summary PDF: $e'),
          ),
        );
      }
    }
  }

  Future<void> _shareSummaryPdf(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating clinical summary PDF for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await PdfExportService().generateHealthRecordSummaryPdf(record: record);
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}_summary.pdf';
      await PdfExportService().sharePdf(
        bytes: pdfBytes,
        filename: safeName,
        subject: 'MEDGUARD Clinical Summary - ${record.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to share summary PDF: $e'),
          ),
        );
      }
    }
  }

  Future<void> _downloadRecordPdf(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing document for download...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await _resolveRecordPdfBytes(record);
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}.pdf';
      await PdfExportService().downloadPdf(bytes: pdfBytes, filename: safeName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to download document: $e'),
          ),
        );
      }
    }
  }

  Future<void> _shareRecordPdf(HealthRecord record) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing document for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await _resolveRecordPdfBytes(record);
      final safeName = '${record.title.replaceAll(RegExp(r"[^\w\s-]"), "").replaceAll(" ", "_")}.pdf';
      await PdfExportService().sharePdf(
        bytes: pdfBytes,
        filename: safeName,
        subject: 'MEDGUARD Health Vault - ${record.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to share document: $e'),
          ),
        );
      }
    }
  }

  void _viewDocumentFile(HealthRecord record, {int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _HealthDocumentViewerDialog(
        record: record,
        vaultRepository: _vaultRepository,
        initialTab: initialTab,
        onDownloadOriginal: () => _downloadOriginalFile(record),
        onShareOriginal: () => _shareOriginalFile(record),
        onDownloadSummary: () => _downloadSummaryPdf(record),
        onShareSummary: () => _shareSummaryPdf(record),
        onDownloadPdf: () => _downloadRecordPdf(record),
      ),
    );
  }

  void _openRecordDetails(HealthRecord record) {
    final color = _getRecordColor(record.recordType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.typeDisplayName,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(record.documentDate),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                record.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (record.doctorName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Doctor: ${record.doctorName}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
              if (record.hospitalName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Facility: ${record.hospitalName}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const Divider(height: 24),
              if (record.description.isNotEmpty) ...[
                const Text(
                  'Summary / Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(record.description),
                const SizedBox(height: 16),
              ],
              if (record.hasFileAttachment) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _viewDocumentFile(record, initialTab: 0);
                        },
                        icon: const Icon(Icons.attachment_rounded, size: 16),
                        label: const Text('View Original'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _viewDocumentFile(record, initialTab: 1);
                        },
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('View Summary'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _downloadOriginalFile(record);
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download Original'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _shareOriginalFile(record);
                        },
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share Original'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _viewDocumentFile(record, initialTab: 1);
                        },
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('View Summary PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _downloadSummaryPdf(record);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Summary PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openAddEditRecordModal(recordToEdit: record);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteRecord(record.id);
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.emergency,
                        size: 16,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: AppColors.emergency),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.emergency),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Health Vault',
        subtitle: 'Personal medical records & documents',
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'health_vault_page_fab',
        onPressed: () => _openAddEditRecordModal(),
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
        backgroundColor: AppTheme.primaryTeal,
      ),
      body: SafeArea(
        child: _currentUserId == null
            ? const LoadingView(message: 'Loading Health Vault...')
            : StreamBuilder<List<HealthRecord>>(
                stream: _vaultRepository.getRecordsStream(userId: _currentUserId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const LoadingView(
                      message: 'Fetching medical records...',
                    );
                  }

                  final allRecords = snapshot.data ?? [];
                  final filteredRecords = _filterRecords(allRecords);

                  return Column(
                    children: [
                      // Search & Filter Header
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search records, doctors, hospitals...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final cat = _categories[index];
                                  final isSelected =
                                      _selectedCategoryFilter == cat['type'];
                                  return FilterChip(
                                    label: Text(cat['label']),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategoryFilter =
                                            selected ? cat['type'] : null;
                                      });
                                    },
                                    selectedColor:
                                        (cat['color'] as Color).withValues(
                                      alpha: 0.2,
                                    ),
                                    checkmarkColor: cat['color'],
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? cat['color']
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vault Records List
                      Expanded(
                        child: filteredRecords.isEmpty
                            ? EmptyStateView(
                                icon: Icons.folder_open_outlined,
                                title: _searchQuery.isNotEmpty ||
                                        _selectedCategoryFilter != null
                                    ? 'No Matching Records'
                                    : 'No health records yet.',
                                message: _searchQuery.isNotEmpty ||
                                        _selectedCategoryFilter != null
                                    ? 'Try changing your search keywords or category filters.'
                                    : 'Upload prescriptions, lab reports, X-rays, and medical documents to keep them safe & accessible.',
                                actionText: '+ Add New Record',
                                onAction: () => _openAddEditRecordModal(),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  setState(() {});
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredRecords.length,
                                  itemBuilder: (context, index) {
                                    final record = filteredRecords[index];
                                    return _buildRecordCard(record);
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildRecordCard(HealthRecord record) {
    final color = _getRecordColor(record.recordType);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Category Icon, Title, and Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getRecordIcon(record.recordType),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                record.typeDisplayName,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, yyyy').format(record.documentDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Metadata Row: Doctor, Facility, File Type & Size
              if (record.doctorName.isNotEmpty ||
                  record.hospitalName.isNotEmpty ||
                  record.hasFileAttachment) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (record.doctorName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Dr. ${record.doctorName}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    if (record.hospitalName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_hospital_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            record.hospitalName,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    if (record.hasFileAttachment)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              record.isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                              size: 13,
                              color: record.isPdf ? Colors.red.shade700 : Colors.teal.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              record.fileFormatDisplayName +
                                  (record.fileSizeFormatted.isNotEmpty ? ' • ${record.fileSizeFormatted}' : ''),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: record.isPdf ? Colors.red.shade800 : Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              // Description / Notes Snippet
              if (record.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Prominent Action Buttons Bar (View, Download PDF, Share, Edit, Delete)
              Row(
                children: [
                  // 1. View Button
                  ElevatedButton.icon(
                    onPressed: () => _viewDocumentFile(record),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Download PDF Button
                  OutlinedButton.icon(
                    onPressed: () => _downloadRecordPdf(record),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download PDF', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Spacer(),

                  // 3. Share Button
                  IconButton(
                    tooltip: 'Share PDF',
                    icon: const Icon(Icons.share_outlined, size: 20, color: AppTheme.primaryTeal),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shareRecordPdf(record),
                  ),

                  // 4. Edit Button
                  IconButton(
                    tooltip: 'Edit Record',
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openAddEditRecordModal(recordToEdit: record),
                  ),

                  // 5. Delete Button
                  IconButton(
                    tooltip: 'Delete Record',
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.emergency),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteRecord(record.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRecordColor(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return AppColors.primary;
      case HealthRecordType.labReport:
        return AppColors.secondary;
      case HealthRecordType.medicalReport:
        return const Color(0xFF8B5CF6);
      case HealthRecordType.imaging:
        return const Color(0xFF4F46E5);
      case HealthRecordType.dischargeSummary:
        return const Color(0xFFD97706);
      case HealthRecordType.consultation:
        return AppColors.accent;
      case HealthRecordType.vaccination:
        return AppColors.success;
      case HealthRecordType.allergy:
        return AppColors.emergency;
      case HealthRecordType.other:
        return AppColors.textSecondary;
    }
  }

  IconData _getRecordIcon(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return Icons.medication_rounded;
      case HealthRecordType.labReport:
        return Icons.science_rounded;
      case HealthRecordType.medicalReport:
        return Icons.description_rounded;
      case HealthRecordType.imaging:
        return Icons.image_rounded;
      case HealthRecordType.dischargeSummary:
        return Icons.local_hospital_rounded;
      case HealthRecordType.consultation:
        return Icons.people_alt_rounded;
      case HealthRecordType.vaccination:
        return Icons.vaccines_rounded;
      case HealthRecordType.allergy:
        return Icons.warning_rounded;
      case HealthRecordType.other:
        return Icons.folder_rounded;
    }
  }
}

class _HealthDocumentViewerDialog extends StatefulWidget {
  final HealthRecord record;
  final HealthRecordRepository vaultRepository;
  final int initialTab;
  final VoidCallback onDownloadOriginal;
  final VoidCallback onShareOriginal;
  final VoidCallback onDownloadSummary;
  final VoidCallback onShareSummary;
  final VoidCallback onDownloadPdf;

  const _HealthDocumentViewerDialog({
    required this.record,
    required this.vaultRepository,
    this.initialTab = 0,
    required this.onDownloadOriginal,
    required this.onShareOriginal,
    required this.onDownloadSummary,
    required this.onShareSummary,
    required this.onDownloadPdf,
  });

  @override
  State<_HealthDocumentViewerDialog> createState() => _HealthDocumentViewerDialogState();
}

class _HealthDocumentViewerDialogState extends State<_HealthDocumentViewerDialog> {
  late int _selectedTab;
  Uint8List? _documentBytes;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.record.hasFileAttachment ? widget.initialTab : 1;
    if (widget.record.hasFileAttachment) {
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.vaultRepository.getRecordBytes(widget.record);
      if (mounted) {
        setState(() {
          _documentBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[VIEWER] Load error: $e');
      if (widget.record.fileUrl != null && widget.record.fileUrl!.isNotEmpty) {
        final fallbackBytes = await ImageHelper.loadBytes(widget.record.fileUrl);
        if (mounted) {
          setState(() {
            _documentBytes = fallbackBytes;
            _isLoading = false;
            if (fallbackBytes == null) {
              _errorMessage = 'Could not load document: ${e.toString().replaceAll("Exception:", "").trim()}';
            }
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load document: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  bool _isPdfBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < 4) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isPdf = _isPdfBytes(_documentBytes) || record.isPdf;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${record.typeDisplayName} • ${DateFormat("MMM dd, yyyy").format(record.documentDate)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Selector Bar
            if (record.hasFileAttachment) ...[
              Container(
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPdf ? Icons.picture_as_pdf : Icons.image,
                                size: 16,
                                color: _selectedTab == 0 ? AppTheme.primaryTeal : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Original ${isPdf ? "PDF" : "Image"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedTab == 0 ? AppTheme.primaryTeal : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 16,
                                color: _selectedTab == 1 ? AppTheme.primaryTeal : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Clinical Summary PDF',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedTab == 1 ? AppTheme.primaryTeal : AppColors.textSecondary,
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
            ],

            // Content Area
            Expanded(
              child: _selectedTab == 0 && record.hasFileAttachment
                  ? _buildAttachmentView(isPdf)
                  : _buildSummaryPdfView(),
            ),

            // Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (_selectedTab == 0 && record.hasFileAttachment) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onShareOriginal();
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share Original'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDownloadOriginal();
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download Original'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onShareSummary();
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share Summary PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDownloadSummary();
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download Summary PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPdfView() {
    return PdfPreview(
      build: (format) async {
        return await PdfExportService().generateHealthRecordSummaryPdf(
          record: widget.record,
        );
      },
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      maxPageWidth: 700,
    );
  }

  Widget _buildAttachmentView(bool isPdf) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryTeal),
            SizedBox(height: 12),
            Text(
              'Loading secure document from vault...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.emergency),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.emergency),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadBytes,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_documentBytes == null || _documentBytes!.isEmpty) {
      return const Center(
        child: Text('Document data is not available.'),
      );
    }

    if (isPdf) {
      return PdfPreview(
        build: (format) => _documentBytes!,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 700,
      );
    }

    return InteractiveViewer(
      panEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.memory(
            _documentBytes!,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

