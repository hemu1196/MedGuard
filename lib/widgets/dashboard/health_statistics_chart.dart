import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/health_record.dart';

class HealthStatisticsChart extends StatelessWidget {
  final Map<HealthRecordType, int> categoryBreakdown;
  final int totalRecords;

  const HealthStatisticsChart({
    super.key,
    required this.categoryBreakdown,
    required this.totalRecords,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (totalRecords == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.textDisabled, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Record statistics will appear here when you add documents.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Record Distribution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onSurface),
              ),
              Text(
                '$totalRecords Total',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...categoryBreakdown.entries.map((entry) {
            final label = _getTypeName(entry.key);
            final count = entry.value;
            final pct = totalRecords > 0 ? (count / totalRecords) : 0.0;
            final color = _getTypeColor(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      Text('$count (${(pct * 100).round()}%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withValues(alpha: 0.12),
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getTypeName(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return 'Prescriptions';
      case HealthRecordType.labReport:
        return 'Lab Reports';
      case HealthRecordType.consultation:
        return 'Consultations';
      case HealthRecordType.vaccination:
        return 'Vaccinations';
      case HealthRecordType.imaging:
        return 'Scans / Imaging';
      default:
        return 'Other Records';
    }
  }

  Color _getTypeColor(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return AppColors.secondary;
      case HealthRecordType.labReport:
        return AppTheme.accentGreen;
      case HealthRecordType.consultation:
        return const Color(0xFF8B5CF6);
      case HealthRecordType.vaccination:
        return const Color(0xFFF97316);
      default:
        return AppTheme.primaryTeal;
    }
  }
}
