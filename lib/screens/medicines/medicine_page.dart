import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/medicine.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/medicine_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class MedicinePage extends StatefulWidget {
  const MedicinePage({super.key});

  @override
  State<MedicinePage> createState() => _MedicinePageState();
}

class _MedicinePageState extends State<MedicinePage> {
  final MedicineRepository _medicineRepository = MedicineRepository();
  final AuthRepository _authRepository = AuthRepository();
  String? _currentUserId;

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

  void _openAddEditDialog([Medicine? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final dosageController = TextEditingController(text: existing?.dosage ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final stockController = TextEditingController(
      text: '${existing?.quantityAvailable ?? 30}',
    );
    final dailyConsumptionController = TextEditingController(
      text: '${existing?.dailyConsumption ?? 2}',
    );
    String selectedFrequency = existing?.frequency ?? 'Daily';
    List<String> reminderTimes = List<String>.from(
      existing?.reminderTimes ?? ['08:30 AM'],
    );

    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Add Medicine Reminder' : 'Edit Medicine',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
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
                              errorText!,
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
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Amoxicillin, Paracetamol',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage *',
                      hintText: 'e.g. 500mg, 1 tablet',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Current Stock *',
                            hintText: 'e.g. 30 tablets',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: dailyConsumptionController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Daily Intake *',
                            hintText: 'e.g. 2 per day',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: ['Once', 'Daily', 'Weekly', 'Specific Days']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedFrequency = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reminder Times:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...reminderTimes.map(
                        (t) => Chip(
                          label: Text(t),
                          onDeleted: reminderTimes.length > 1
                              ? () {
                                  setDialogState(() => reminderTimes.remove(t));
                                }
                              : null,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('Add Time'),
                        onPressed: () async {
                          final timeOfDay = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (timeOfDay != null && context.mounted) {
                            final formatted = timeOfDay.format(context);
                            if (!reminderTimes.contains(formatted)) {
                              setDialogState(() {
                                reminderTimes.add(formatted);
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'e.g. Take post meals',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final dosage = dosageController.text.trim();
                  if (name.isEmpty || dosage.isEmpty) {
                    setDialogState(() {
                      errorText = 'Please enter both Medicine Name and Dosage';
                    });
                    return;
                  }

                  final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
                  final newMed = Medicine(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    userId: userId,
                    sourceHealthRecordId: existing?.sourceHealthRecordId,
                    name: name,
                    dosage: dosage,
                    frequency: selectedFrequency,
                    reminderTimes: reminderTimes,
                    notes: notesController.text.trim(),
                    quantityAvailable: int.tryParse(stockController.text.trim()) ?? 30,
                    dailyConsumption: int.tryParse(dailyConsumptionController.text.trim()) ?? 2,
                  );

                  await _medicineRepository.saveMedicine(newMed);

                  // Trigger local notification registration for each reminder time
                  for (final time in reminderTimes) {
                    await NotificationService().scheduleMedicineReminder(
                      medicineName: name,
                      time: time,
                    );
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medication added successfully.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    setState(() {});
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteMedicine(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine?'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
      await _medicineRepository.deleteMedicine(id, userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Medicine Reminders & Stock',
        subtitle: 'Schedule dosages & predict refill needs',
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'medicine_page_fab',
        onPressed: () => _openAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        backgroundColor: AppTheme.primaryTeal,
      ),
      body: SafeArea(
        child: _currentUserId == null
            ? const LoadingView(message: 'Initializing authenticated session...')
            : StreamBuilder<List<Medicine>>(
                stream: _medicineRepository.watchMedicines(_currentUserId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const LoadingView(message: 'Loading medicine schedule...');
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.emergency),
                          const SizedBox(height: 12),
                          Text('Failed to load medicines: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final medicines = snapshot.data ?? [];

                  if (medicines.isEmpty) {
                    return EmptyStateView(
                      title: 'No Medicine Reminders',
                      message:
                          'Keep track of your daily medications and schedule timely notifications.',
                      icon: Icons.medication_outlined,
                      actionText: 'Add First Medicine',
                      onAction: () => _openAddEditDialog(),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: medicines.length,
                    itemBuilder: (context, index) {
                      final med = medicines[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.medication_rounded,
                                          color: AppTheme.primaryTeal,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Dosage: ${med.dosage} (${med.frequency})',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _openAddEditDialog(med),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: AppTheme.accentRed,
                                        ),
                                        onPressed: () => _deleteMedicine(med.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Stock: ${med.quantityAvailable} units (Refill in ~${med.estimatedDaysRemaining} days)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: med.isLowStock
                                              ? AppColors.emergency
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (med.isLowStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.emergency.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '⚠️ LOW STOCK',
                                        style: TextStyle(
                                          color: AppColors.emergency,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: med.reminderTimes
                                    .map(
                                      (t) => Chip(
                                        avatar: const Icon(Icons.access_time, size: 14),
                                        label: Text(t, style: const TextStyle(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
