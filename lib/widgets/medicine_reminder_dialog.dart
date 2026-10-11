import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../repositories/medicine_repository.dart';
import '../services/notification_service.dart';

class MedicineReminderDialog extends StatefulWidget {
  final MedicineAlertEvent alertEvent;

  const MedicineReminderDialog({
    super.key,
    required this.alertEvent,
  });

  static Future<void> show(BuildContext context, MedicineAlertEvent event) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicineReminderDialog(alertEvent: event),
    );
  }

  @override
  State<MedicineReminderDialog> createState() => _MedicineReminderDialogState();
}

class _MedicineReminderDialogState extends State<MedicineReminderDialog> {
  final MedicineRepository _medicineRepository = MedicineRepository();
  bool _isProcessing = false;
  int _selectedSnoozeMinutes = 10;
  bool _showSnoozeOptions = false;

  Future<void> _handleTaken() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _medicineRepository.logMedicationDose(
        medicineId: widget.alertEvent.medicineId,
        scheduledTime: widget.alertEvent.scheduledTime,
        status: 'taken',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              '✅ ${widget.alertEvent.medicineName} marked as TAKEN. Stock updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to record dose: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await _medicineRepository.logMedicationDose(
        medicineId: widget.alertEvent.medicineId,
        scheduledTime: widget.alertEvent.scheduledTime,
        status: 'skipped',
        missedReason: 'User skipped in reminder popup',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Dose skipped for ${widget.alertEvent.medicineName}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleSnooze(int minutes) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await NotificationService().scheduleExactMedicineReminder(
      medicineId: widget.alertEvent.medicineId,
      medicineName: widget.alertEvent.medicineName,
      dosage: widget.alertEvent.dosage,
      timeStr: widget.alertEvent.scheduledTime,
      snoozeMinutes: minutes,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(
            '⏰ Snoozed for $minutes minutes. Reminder scheduled.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.alertEvent;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.medication_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'MEDICATION DUE NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.medicineName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Dosage: ${event.dosage}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Scheduled for: ${event.scheduledTime}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (_showSnoozeOptions) ...[
              const Divider(height: 24),
              const Text(
                'Select Snooze Duration:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15].map((m) {
                  final isSelected = _selectedSnoozeMinutes == m;
                  return ChoiceChip(
                    label: Text('$m min'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedSnoozeMinutes = m);
                        _handleSnooze(m);
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        if (!_showSnoozeOptions) ...[
          OutlinedButton(
            onPressed: _isProcessing ? null : _handleSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('SKIP'),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _showSnoozeOptions = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('SNOOZE'),
          ),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleTaken,
            icon: _isProcessing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('TAKEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: () => setState(() => _showSnoozeOptions = false),
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }
}
