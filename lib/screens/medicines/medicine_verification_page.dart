import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/medicine_verification_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class MedicineVerificationPage extends StatefulWidget {
  const MedicineVerificationPage({super.key});

  @override
  State<MedicineVerificationPage> createState() =>
      _MedicineVerificationPageState();
}

class _MedicineVerificationPageState extends State<MedicineVerificationPage> {
  final MedicineVerificationService _verificationService =
      MedicineVerificationService();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  MedicineVerificationResult? _result;
  bool _isChecking = false;

  @override
  void dispose() {
    _batchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _runVerification() async {
    final batch = _batchController.text.trim();
    if (batch.isEmpty) return;

    setState(() {
      _isChecking = true;
      _result = null;
    });

    final res = await _verificationService.verifyMedicine(
      barcodeOrBatch: batch,
      medicineName: _nameController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _result = res;
        _isChecking = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Verified':
        return AppColors.success;
      case 'Unable to Verify':
        return AppColors.warning;
      case 'Invalid / Unknown':
      default:
        return AppColors.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Medicine Verification',
        subtitle: 'Batch number & counterfeit checker',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Authenticity Safety Rule: Medicines are only marked Genuine when confirmed by an official national pharma registry API.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Inputs Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medicine & Batch Lookup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Name (Optional)',
                          hintText: 'e.g. Paracetamol 650mg',
                          prefixIcon: Icon(Icons.medication),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _batchController,
                        decoration: const InputDecoration(
                          labelText: 'Batch Number / Barcode *',
                          hintText: 'e.g. BATCH-987654',
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isChecking ? null : _runVerification,
                          icon: const Icon(Icons.search),
                          label: const Text('Verify Medicine Batch'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Result Section
              if (_isChecking)
                const LoadingView(message: 'Querying Medicine Registry...')
              else if (_result != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _result!.medicineName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  _result!.status,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _result!.status,
                                style: TextStyle(
                                  color: _getStatusColor(_result!.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Batch Number: ${_result!.batchNumber}'),
                        Text('Manufacturer: ${_result!.manufacturer}'),
                        const Divider(height: 24),
                        Text(
                          _result!.message,
                          style: TextStyle(
                            color: _getStatusColor(_result!.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _result!.disclaimer,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
