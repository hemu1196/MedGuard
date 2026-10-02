import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/utils/image_helper.dart';
import '../../models/health_record.dart';
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
    final userId = await _authRepository.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
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
    String? dialogErrorText;

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
                                setDialogState(() {
                                  attachedFilePath = file.path;
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
                                setDialogState(() {
                                  attachedFilePath = file.path;
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
                              final file = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (file != null) {
                                setDialogState(() {
                                  attachedFilePath = file.path;
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
                              attachedFilePath!.split('/').last,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setDialogState(() => attachedFilePath = null),
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
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setDialogState(() {
                      dialogErrorText = 'Please enter a Record Title.';
                    });
                    return;
                  }

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

                  await _vaultRepository.saveRecord(record);

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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEditing ? 'Save Changes' : 'Save Record'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewDocumentFile(HealthRecord record) {
    final url = record.fileUrl;
    final isAvailable = url != null &&
        url.isNotEmpty &&
        (url.startsWith('http') ||
            url.startsWith('blob:') ||
            url.startsWith('data:') ||
            ImageHelper.isLocalFile(url));

    if (isAvailable) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(record.title),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ImageHelper.buildImage(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(record.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Record Type: ${record.typeDisplayName}'),
              if (record.doctorName.isNotEmpty)
                Text('Doctor: ${record.doctorName}'),
              if (record.hospitalName.isNotEmpty)
                Text('Facility: ${record.hospitalName}'),
              const SizedBox(height: 12),
              Text(
                'Notes: ${record.description.isNotEmpty ? record.description : "No file attachment provided."}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openAddEditRecordModal(recordToEdit: record);
                      },
                      icon: const Icon(Icons.edit_outlined),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _viewDocumentFile(record);
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openRecordDetails(record),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getRecordIcon(record.recordType), color: color),
        ),
        title: Text(
          record.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          [
            if (record.doctorName.isNotEmpty) 'Dr. ${record.doctorName}',
            if (record.hospitalName.isNotEmpty) record.hospitalName,
            DateFormat('MMM dd, yyyy').format(record.documentDate),
          ].join(' • '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'view') {
              _openRecordDetails(record);
            } else if (val == 'edit') {
              _openAddEditRecordModal(recordToEdit: record);
            } else if (val == 'delete') {
              _deleteRecord(record.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit Record')),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: AppColors.emergency),
              ),
            ),
          ],
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

