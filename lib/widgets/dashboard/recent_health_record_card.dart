import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/health_record.dart';

class RecentHealthRecordCard extends StatelessWidget {
  final List<HealthRecord> records;
  final bool isLoading;
  final Function(int)? onNavigateTab;

  const RecentHealthRecordCard({
    super.key,
    required this.records,
    this.isLoading = false,
    this.onNavigateTab,
  });

  IconData _getRecordIcon(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.prescription:
        return Icons.medical_services_outlined;
      case HealthRecordType.labReport:
        return Icons.science_outlined;
      case HealthRecordType.consultation:
        return Icons.record_voice_over_outlined;
      case HealthRecordType.vaccination:
        return Icons.vaccines_outlined;
      case HealthRecordType.imaging:
        return Icons.document_scanner_outlined;
      default:
        return Icons.folder_open_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Health Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                if (onNavigateTab != null) {
                  onNavigateTab!(2);
                }
              },
              child: const Text(
                'See All',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (isLoading)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  size: 36,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(height: 10),
                Text(
                  'No health records yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Securely store lab reports, prescriptions, and medical notes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    if (onNavigateTab != null) {
                      onNavigateTab!(2);
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Health Record'),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.take(3).length,
            itemBuilder: (context, index) {
              final rec = records[index];
              final dateStr = DateFormat('MMM d, yyyy').format(rec.documentDate);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getRecordIcon(rec.recordType),
                        color: AppTheme.primaryTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                rec.typeDisplayName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                              if (rec.doctorName.isNotEmpty) ...[
                                const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                Expanded(
                                  child: Text(
                                    rec.doctorName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
