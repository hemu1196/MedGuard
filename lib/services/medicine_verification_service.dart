class MedicineVerificationResult {
  final String status; // Verified, Unable to Verify, Invalid / Unknown
  final String medicineName;
  final String batchNumber;
  final String manufacturer;
  final String message;
  final String disclaimer;

  MedicineVerificationResult({
    required this.status,
    required this.medicineName,
    required this.batchNumber,
    required this.manufacturer,
    required this.message,
    this.disclaimer =
        'Official Verification API not configured. Results default to unverified status to prevent counterfeit false safety claims.',
  });
}

class MedicineVerificationService {
  Future<MedicineVerificationResult> verifyMedicine({
    required String barcodeOrBatch,
    String? medicineName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final query = barcodeOrBatch.trim().toUpperCase();

    if (query.isEmpty) {
      return MedicineVerificationResult(
        status: 'Invalid / Unknown',
        medicineName: medicineName ?? 'Unknown Product',
        batchNumber: 'N/A',
        manufacturer: 'Unknown',
        message: 'Please provide a valid barcode or batch number.',
      );
    }

    // Default safe response when official national medicine registry API is unconfigured
    return MedicineVerificationResult(
      status: 'Unable to Verify',
      medicineName: medicineName?.isNotEmpty == true
          ? medicineName!
          : 'Batch #$query',
      batchNumber: query,
      manufacturer: 'Registry Unconfigured',
      message:
          'Verification service not configured / Unable to verify batch "$query".',
    );
  }
}
