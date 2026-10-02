import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/health_record.dart';
import '../../models/medicine.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/health_record_repository.dart';
import '../../repositories/medicine_repository.dart';
import '../../services/gemini_service.dart';
import '../../widgets/app_header.dart';

class PrescriptionScannerPage extends StatefulWidget {
  const PrescriptionScannerPage({super.key});

  @override
  State<PrescriptionScannerPage> createState() =>
      _PrescriptionScannerPageState();
}

enum ScannerStep { selectSource, preview, extractedResult, error }

class _PrescriptionScannerPageState extends State<PrescriptionScannerPage> {
  ScannerStep _step = ScannerStep.selectSource;
  String _selectedSource = '';
  bool _isProcessing = false;
  String? _errorMessage;

  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;

  // Real user Controllers (starting completely EMPTY, no dummy defaults)
  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _prescriptionDate = DateTime.now();
  final List<Medicine> _extractedMedicines = [];

  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  final HealthRecordRepository _vaultRepository = HealthRecordRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final AuthRepository _authRepository = AuthRepository();

  bool _addToMedicineManagement = true;

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected.')),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImageFile = file;
        _selectedImageBytes = bytes;
        _selectedSource = source == ImageSource.camera ? 'Camera' : 'Gallery / File';
        _step = ScannerStep.preview;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[PRESCRIPTION SCANNER] Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _processImage() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final mimeType = _selectedImageFile?.mimeType ?? 'image/jpeg';
      final result = await _geminiService.analyzePrescriptionImage(
        _selectedImageBytes!,
        mimeType,
      );

      if (!mounted) return;

      if (result.containsKey('error')) {
        setState(() {
          _isProcessing = false;
          _errorMessage = result['error'] ?? 'Unable to read this prescription. Please try another image.';
          _step = ScannerStep.error;
        });
        return;
      }

      final rawMedicines = result['medicines'] as List? ?? [];
      final List<Medicine> parsedMeds = [];

      for (var i = 0; i < rawMedicines.length; i++) {
        final item = Map<String, dynamic>.from(rawMedicines[i] as Map);
        final name = (item['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          parsedMeds.add(
            Medicine(
              id: 'ext_${DateTime.now().millisecondsSinceEpoch}_$i',
              name: name,
              dosage: (item['dosage'] ?? 'As directed').toString(),
              frequency: (item['frequency'] ?? 'Daily').toString(),
              reminderTimes: List<String>.from(item['reminderTimes'] ?? ['08:00 AM']),
            ),
          );
        }
      }

      if (parsedMeds.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Unable to read this prescription. Please try another image.';
          _step = ScannerStep.error;
        });
        return;
      }

      final extTitle = (result['title'] ?? '').toString().trim();
      final extDoctor = (result['doctorName'] ?? '').toString().trim();
      final extNotes = (result['notes'] ?? '').toString().trim();

      setState(() {
        _isProcessing = false;
        _titleController.text = extTitle.isNotEmpty
            ? extTitle
            : 'Prescription - ${DateFormat('MMM dd, yyyy').format(_prescriptionDate)}';
        _doctorController.text = extDoctor;
        _notesController.text = extNotes;
        _extractedMedicines.clear();
        _extractedMedicines.addAll(parsedMeds);
        _step = ScannerStep.extractedResult;
      });
    } catch (e) {
      debugPrint('[PRESCRIPTION SCANNER] OCR Error: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Unable to read this prescription. Please try another image.';
        _step = ScannerStep.error;
      });
    }
  }

  void _addCustomMedicineDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController(text: '1 tablet');
    final freqCtrl = TextEditingController(text: 'Daily');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Extracted Medicine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Medicine Name *', hintText: 'e.g. Paracetamol'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dosageCtrl,
              decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 500mg'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: freqCtrl,
              decoration: const InputDecoration(labelText: 'Frequency', hintText: 'e.g. Daily'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _extractedMedicines.add(
                    Medicine(
                      id: 'ext_manual_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      dosage: dosageCtrl.text.trim(),
                      frequency: freqCtrl.text.trim(),
                      reminderTimes: ['08:00 AM'],
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveToVault() async {
    final rawTitle = _titleController.text.trim();
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : 'Prescription - ${DateFormat('MMM dd, yyyy').format(_prescriptionDate)}';
    final doctor = _doctorController.text.trim();

    if (_extractedMedicines.isEmpty && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter valid prescription details.')),
      );
      return;
    }

    final userId = await _authRepository.getCurrentUserId();
    final recordId = 'rx_${DateTime.now().millisecondsSinceEpoch}';

    final healthRecord = HealthRecord(
      id: recordId,
      userId: userId,
      recordType: HealthRecordType.prescription,
      title: title,
      description: _notesController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentDate: _prescriptionDate,
      doctorName: doctor,
      extractedData: {
        'medicines': _extractedMedicines.map((m) => m.toMap()).toList(),
      },
    );

    // 1. Save actual user prescription to Health Vault
    await _vaultRepository.saveRecord(healthRecord);

    // 2. If selected, add extracted medicines to Medicine Management
    if (_addToMedicineManagement) {
      for (final med in _extractedMedicines) {
        final derivedMed = Medicine(
          id: 'med_${DateTime.now().millisecondsSinceEpoch}_${med.name.hashCode}',
          userId: userId,
          sourceHealthRecordId: recordId,
          name: med.name,
          dosage: med.dosage,
          frequency: med.frequency,
          reminderTimes: med.reminderTimes,
          notes: doctor.isNotEmpty ? 'Prescribed by $doctor' : 'Scanned Prescription',
        );
        await _medicineRepository.saveMedicine(derivedMed);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription saved to Health Vault.'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pushReplacementNamed(AppRoutes.vault);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Prescription Scanner',
        subtitle: 'Scan doctor notes & extract medicines',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildCurrentStepView(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_step) {
      case ScannerStep.selectSource:
        return Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 64,
                color: AppTheme.primaryTeal,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload or Snap Prescription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No prescription scanned yet. Select an image or document to scan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 36),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan with Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Upload from Gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Choose File'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

      case ScannerStep.preview:
        return Column(
          children: [
            const Text(
              'Prescription Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _selectedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Image selected via $_selectedSource',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _step = ScannerStep.selectSource;
                      _selectedImageBytes = null;
                      _selectedImageFile = null;
                    }),
                    child: const Text('Retake / Choose Another'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Use Image & Scan'),
                  ),
                ),
              ],
            ),
          ],
        );

      case ScannerStep.extractedResult:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Extracted Information (Editable)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Prescription Title',
                hintText: 'e.g. Annual Checkup Prescription',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctorController,
              decoration: const InputDecoration(
                labelText: 'Doctor Name',
                hintText: 'e.g. Dr. John Smith',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _prescriptionDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _prescriptionDate = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Prescription Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_prescriptionDate),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Extracted Medicines:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: _addCustomMedicineDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Medicine'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_extractedMedicines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'No medicines extracted. Tap "Add Medicine" to add items manually.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                ),
              )
            else
              ..._extractedMedicines.asMap().entries.map(
                (entry) {
                  final idx = entry.key;
                  final m = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.medication,
                        color: AppTheme.primaryTeal,
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${m.dosage} - ${m.frequency}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _extractedMedicines.removeAt(idx);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Instructions',
                hintText: 'e.g. Take post meals',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _addToMedicineManagement,
              onChanged: (val) {
                setState(() => _addToMedicineManagement = val ?? true);
              },
              activeColor: AppTheme.primaryTeal,
              title: const Text(
                'Add Extracted Medicines to Medicine Schedule',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Derives active reminders linked to this prescription in Health Vault',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveToVault,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save to Health Vault'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case ScannerStep.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, size: 60, color: AppTheme.accentRed),
                const SizedBox(height: 16),
                const Text(
                  'OCR Analysis Failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentRed),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unable to read this prescription. Please try another image.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _step = ScannerStep.selectSource;
                    _selectedImageBytes = null;
                    _selectedImageFile = null;
                    _errorMessage = null;
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Another Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

