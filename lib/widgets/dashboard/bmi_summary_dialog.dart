import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../models/user_profile.dart';

class BmiSummaryDialog extends StatelessWidget {
  final UserProfile? userProfile;

  const BmiSummaryDialog({
    super.key,
    this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    final heightCm = double.tryParse(userProfile?.height ?? '') ?? 0.0;
    final weightKg = double.tryParse(userProfile?.weight ?? '') ?? 0.0;
    final bmi = userProfile?.bmi ?? 0.0;
    final result = BmiCalculator.evaluate(heightCm: heightCm, weightKg: weightKg);

    Color categoryColor;
    if (bmi < 18.5) {
      categoryColor = Colors.orange;
    } else if (bmi <= 24.9) {
      categoryColor = AppTheme.accentGreen;
    } else if (bmi <= 29.9) {
      categoryColor = Colors.amber.shade800;
    } else {
      categoryColor = AppTheme.accentRed;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_weight_outlined, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Text('BMI Health Summary'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calculated BMI',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bmi > 0 ? result.category : 'Not Calculated',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Measurements Row
            Row(
              children: [
                Expanded(
                  child: _buildMeasureTile(
                    'Height',
                    heightCm > 0 ? '${heightCm.toInt()} cm' : 'Not set',
                    Icons.height,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMeasureTile(
                    'Weight',
                    weightKg > 0 ? '${weightKg.toStringAsFixed(1)} kg' : 'Not set',
                    Icons.scale_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'General Guidance:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              result.guidance,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Non-diagnostic Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BMI is a screening measure and does not diagnose health conditions.',
                      style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildMeasureTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
