import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/appointment.dart';
import '../../services/pdf_export_service.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/notification_service.dart';
import '../../services/in_app_notification_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final AuthRepository _authRepository = AuthRepository();
  final NotificationService _notificationService = NotificationService();

  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String _selectedTab = 'Upcoming';

  final List<String> _specializations = [
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'Gastroenterologist',
    'General Physician',
    'Neurologist',
    'Gynecologist',
    'Oncologist',
    'Ophthalmologist',
    'Orthopedic',
    'Pediatrician',
    'Psychiatrist',
    'Pulmonologist',
    'Urologist',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  void _loadAppointments() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final list = await _appointmentRepository.getAppointments(userId: userId);
    if (mounted) {
      setState(() {
        _appointments = list;
        _isLoading = false;
      });
    }
  }

  List<Appointment> get _filteredAppointments {
    return _appointments.where((a) {
      return a.status.toLowerCase() == _selectedTab.toLowerCase();
    }).toList();
  }

  void _scheduleSystemNotification(Appointment appt) {
    InAppNotificationService().addNotification(
      title: 'Appointment: Dr. ${appt.doctorName}',
      body: 'Scheduled for ${DateFormat("MMM dd, yyyy 'at' hh:mm a").format(appt.appointmentDate)} at ${appt.hospitalOrClinic}.',
      type: NotificationType.appointment,
      targetRoute: '/appointments',
    );
    if (kIsWeb) return;
    _notificationService.scheduleAppointmentNotifications(
      baseNotificationId: appt.notificationId,
      doctorName: appt.doctorName,
      hospitalOrClinic: appt.hospitalOrClinic,
      appointmentDate: appt.appointmentDate,
      reminderOffsets: appt.reminderOffsets,
    );
  }

  void _cancelSystemNotification(Appointment appt) {
    InAppNotificationService().addNotification(
      title: 'Appointment Cancelled',
      body: 'Your appointment with Dr. ${appt.doctorName} was cancelled.',
      type: NotificationType.appointment,
      targetRoute: '/appointments',
    );
    if (kIsWeb) return;
    _notificationService.cancelAppointmentNotifications(
      baseNotificationId: appt.notificationId,
      reminderOffsets: appt.reminderOffsets,
    );
  }

  Future<void> _callDoctor(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid doctor or clinic phone number available.'),
          backgroundColor: AppColors.emergency,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer: $e'),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    }
  }

  Future<void> _downloadAppointmentPdf(Appointment appt) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating appointment summary PDF...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await PdfExportService().generateAppointmentPdf(
        appointment: appt,
        patientName: 'Authorized User',
      );
      final filename = 'Appointment_Dr_${appt.doctorName.replaceAll(" ", "_")}.pdf';
      await PdfExportService().downloadPdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to generate appointment PDF: $e'),
          ),
        );
      }
    }
  }

  Future<void> _shareAppointmentPdf(Appointment appt) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing appointment PDF for sharing...'),
          duration: Duration(seconds: 1),
        ),
      );
      final pdfBytes = await PdfExportService().generateAppointmentPdf(
        appointment: appt,
        patientName: 'Authorized User',
      );
      final filename = 'Appointment_Dr_${appt.doctorName.replaceAll(" ", "_")}.pdf';
      await PdfExportService().sharePdf(
        bytes: pdfBytes,
        filename: filename,
        subject: 'MEDGUARD Appointment Summary - Dr. ${appt.doctorName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emergency,
            content: Text('Failed to share appointment PDF: $e'),
          ),
        );
      }
    }
  }

  void _showAppointmentSuccessModal(Appointment appt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              'Appointment Saved Successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Dr. ${appt.doctorName} • ${DateFormat("dd MMM yyyy, hh:mm a").format(appt.appointmentDate)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadAppointmentPdf(appt);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareAppointmentPdf(appt);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddEditDialog([Appointment? existing]) {
    final nameCtrl = TextEditingController(text: existing?.doctorName ?? '');
    String selectedSpec = existing?.specialization ?? 'General Physician';
    final customSpecCtrl = TextEditingController(
      text:
          (existing != null &&
              !_specializations.contains(existing.specialization))
          ? existing.specialization
          : '',
    );
    final facilityCtrl = TextEditingController(
      text: existing?.hospitalOrClinic ?? '',
    );
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    DateTime selectedDate =
        existing?.appointmentDate ??
        DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay.fromDateTime(existing.appointmentDate)
        : const TimeOfDay(hour: 10, minute: 30);

    bool reminderEnabled = existing?.reminderEnabled ?? true;
    List<int> selectedReminders = List<int>.from(
      existing?.selectedRemindersMinutes ?? [60],
    );

    String? nameError;
    String? facilityError;
    String? phoneError;
    String? dateError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Schedule Doctor Appointment'
                  : 'Edit Appointment',
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Doctor Name *',
                        hintText: 'e.g. Dr. Arun Kumar',
                        errorText: nameError,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _specializations.contains(selectedSpec)
                          ? selectedSpec
                          : 'Other',
                      decoration: const InputDecoration(
                        labelText: 'Specialization *',
                        prefixIcon: Icon(Icons.medical_services_outlined),
                      ),
                      items: _specializations
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedSpec = val);
                        }
                      },
                    ),
                    if (selectedSpec == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customSpecCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Specify Specialization *',
                          hintText: 'e.g. Immunologist',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: facilityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Hospital / Clinic *',
                        hintText: 'e.g. Apollo Hospital',
                        errorText: facilityError,
                        prefixIcon: const Icon(Icons.local_hospital_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );
                                  dateError = null;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Appointment Date *',
                                errorText: dateError,
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedTime = picked;
                                  selectedDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time *',
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                selectedTime.format(context),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Clinic Phone (Optional)',
                        hintText: 'e.g. +91 9123456789',
                        errorText: phoneError,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'e.g. Bring previous blood work reports',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Enable Reminder Alerts'),
                              subtitle: const Text(
                                'Schedule local system notifications',
                              ),
                              value: reminderEnabled,
                              onChanged: (val) {
                                setDialogState(() => reminderEnabled = val);
                              },
                              activeThumbColor: AppColors.primary,
                            ),
                            if (reminderEnabled) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Select Reminder Timings:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildReminderChip(
                                    label: '1 day before',
                                    minutes: 1440,
                                    selectedReminders: selectedReminders,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedReminders.add(1440);
                                        } else {
                                          selectedReminders.remove(1440);
                                        }
                                      });
                                    },
                                  ),
                                  _buildReminderChip(
                                    label: '1 hour before',
                                    minutes: 60,
                                    selectedReminders: selectedReminders,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedReminders.add(60);
                                        } else {
                                          selectedReminders.remove(60);
                                        }
                                      });
                                    },
                                  ),
                                  _buildReminderChip(
                                    label: '30 mins before',
                                    minutes: 30,
                                    selectedReminders: selectedReminders,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedReminders.add(30);
                                        } else {
                                          selectedReminders.remove(30);
                                        }
                                      });
                                    },
                                  ),
                                  _buildReminderChip(
                                    label: 'At time of visit',
                                    minutes: 0,
                                    selectedReminders: selectedReminders,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedReminders.add(0);
                                        } else {
                                          selectedReminders.remove(0);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final facility = facilityCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final spec = selectedSpec == 'Other'
                            ? customSpecCtrl.text.trim()
                            : selectedSpec;

                        bool isValid = true;
                        setDialogState(() {
                          nameError = null;
                          facilityError = null;
                          phoneError = null;
                          dateError = null;
                        });

                        if (name.isEmpty || name.length < 2) {
                          setDialogState(
                            () => nameError = 'Please enter a valid doctor name',
                          );
                          isValid = false;
                        }
                        if (facility.isEmpty) {
                          setDialogState(
                            () => facilityError =
                                'Please enter hospital or clinic name',
                          );
                          isValid = false;
                        }
                        if (phone.isNotEmpty &&
                            (!RegExp(r'^[0-9+\s-]{7,15}$').hasMatch(phone))) {
                          setDialogState(
                            () => phoneError = 'Please enter a valid phone number',
                          );
                          isValid = false;
                        }

                        final fullApptDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        if (existing == null &&
                            fullApptDate.isBefore(
                              DateTime.now().subtract(const Duration(minutes: 5)),
                            )) {
                          setDialogState(
                            () => dateError = 'Appointment cannot be in the past',
                          );
                          isValid = false;
                        }

                        if (!isValid) return;

                        setDialogState(() => isSaving = true);

                        final userId = await _authRepository.getCurrentUserId();
                        final finalReminders = selectedReminders.isEmpty
                            ? [60]
                            : selectedReminders;

                        final appt = Appointment(
                          id:
                              existing?.id ??
                              'appt_${DateTime.now().millisecondsSinceEpoch}',
                          userId: userId,
                          doctorName: name,
                          specialization: spec.isNotEmpty
                              ? spec
                              : 'General Physician',
                          hospitalOrClinic: facility,
                          appointmentDate: fullApptDate,
                          phoneNumber: phone,
                          address: addressCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          reminderEnabled: reminderEnabled,
                          reminderTimeMinutesBefore: finalReminders.first,
                          selectedRemindersMinutes: finalReminders,
                          status: existing?.status ?? 'Upcoming',
                          createdAt: existing?.createdAt ?? DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        await _appointmentRepository.saveAppointment(userId, appt);

                        if (existing != null) {
                          _cancelSystemNotification(existing);
                        }
                        if (appt.reminderEnabled && appt.status == 'Upcoming') {
                          _scheduleSystemNotification(appt);
                        }

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          _loadAppointments();
                          if (existing == null) {
                            _showAppointmentSuccessModal(appt);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Appointment updated successfully ✓'),
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Appointment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReminderChip({
    required String label,
    required int minutes,
    required List<int> selectedReminders,
    required ValueChanged<bool> onChanged,
  }) {
    final isSelected = selectedReminders.contains(minutes);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: onChanged,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  void _updateStatus(Appointment appt, String newStatus) async {
    if (newStatus == 'Cancelled') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Appointment?'),
          content: Text(
            'Are you sure you want to cancel your appointment with Dr. ${appt.doctorName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Appointment'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel Appointment'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    } else if (newStatus == 'Completed') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark Appointment as Completed?'),
          content: Text('Mark visit with Dr. ${appt.doctorName} as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Yet'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final userId = await _authRepository.getCurrentUserId();
    await _appointmentRepository.updateStatus(
      userId,
      appt.id,
      newStatus,
    );
    if (newStatus == 'Completed' || newStatus == 'Cancelled') {
      _cancelSystemNotification(appt);
    } else if (newStatus == 'Upcoming' && appt.reminderEnabled) {
      _scheduleSystemNotification(appt);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $newStatus ✓'),
          backgroundColor: newStatus == 'Completed'
              ? AppColors.success
              : (newStatus == 'Cancelled' ? AppColors.emergency : AppColors.primary),
        ),
      );
    }
    _loadAppointments();
  }

  void _deleteAppointment(Appointment appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: Text(
          'Are you sure you want to delete appointment with Dr. ${appt.doctorName}? Scheduled notifications will be cancelled.',
        ),
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
      final userId = await _authRepository.getCurrentUserId();
      await _appointmentRepository.deleteAppointment(userId, appt.id);
      _cancelSystemNotification(appt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment deleted successfully ✓'),
          ),
        );
      }
      _loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Doctor Appointments',
        subtitle: 'Schedule & track doctor visit reminders',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
            ),
            onPressed: () => _openAddEditDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Tabs (Upcoming, Completed, Cancelled)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: ['Upcoming', 'Completed', 'Cancelled'].map((tab) {
                  final isSelected =
                      _selectedTab.toLowerCase() == tab.toLowerCase();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Center(child: Text(tab)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedTab = tab);
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),

            // Web Banner Notice
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.amber.shade50,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.brown),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'System push notifications require mobile device permissions. In-app reminders active.',
                        style: TextStyle(fontSize: 11, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),

            // Appointments List
            Expanded(
              child: _isLoading
                  ? const LoadingView(message: 'Loading Doctor Appointments...')
                  : _filteredAppointments.isEmpty
                  ? EmptyStateView(
                      title: 'No $_selectedTab Appointments',
                      message:
                          'Schedule your doctor consultations and follow-ups with local reminder notifications.',
                      icon: Icons.event_available_outlined,
                      actionText: 'Schedule Appointment',
                      onAction: () => _openAddEditDialog(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appt = _filteredAppointments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.medical_services_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dr. ${appt.doctorName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              appt.specialization,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _openAddEditDialog(appt),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: AppColors.emergency,
                                          ),
                                          onPressed: () =>
                                              _deleteAppointment(appt),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),

                                if (appt.hospitalOrClinic.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_hospital_outlined,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        appt.hospitalOrClinic,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat(
                                        'EEEE, MMM dd, yyyy • hh:mm a',
                                      ).format(appt.appointmentDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),

                                if (appt.reminderEnabled) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.alarm,
                                        size: 14,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Reminders: ${_formatRemindersList(appt.reminderOffsets)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                if (appt.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes: ${appt.notes}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (appt.status.toLowerCase() == 'upcoming') ...[
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _updateStatus(appt, 'Cancelled'),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 14,
                                          color: AppColors.emergency,
                                        ),
                                        label: const Text(
                                          'Cancel Visit',
                                          style: TextStyle(
                                            color: AppColors.emergency,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.emergency,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _updateStatus(appt, 'Completed'),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Mark Complete',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                        ),
                                      ),
                                    ] else if (appt.status.toLowerCase() == 'completed') ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                            SizedBox(width: 4),
                                            Text(
                                              'Completed',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (appt.status.toLowerCase() == 'cancelled') ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.emergency.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cancel, size: 14, color: AppColors.emergency),
                                            SizedBox(width: 4),
                                            Text(
                                              'Cancelled',
                                              style: TextStyle(
                                                color: AppColors.emergency,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => _updateStatus(appt, 'Upcoming'),
                                        child: const Text('Re-open', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                      tooltip: 'Download Summary PDF',
                                      onPressed: () => _downloadAppointmentPdf(appt),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      tooltip: 'Share Summary PDF',
                                      onPressed: () => _shareAppointmentPdf(appt),
                                    ),
                                    if (appt.phoneNumber.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.call,
                                          color: AppColors.success,
                                          size: 20,
                                        ),
                                        tooltip: 'Call Doctor / Clinic (${appt.phoneNumber})',
                                        onPressed: () => _callDoctor(appt.phoneNumber),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemindersList(List<int> offsets) {
    if (offsets.isEmpty) return 'None';
    final labels = offsets.map((m) {
      if (m == 1440) return '1 day before';
      if (m == 180) return '3 hrs before';
      if (m == 60) return '1 hr before';
      if (m == 30) return '30 mins before';
      if (m == 0) return 'At visit time';
      return '$m mins before';
    }).toList();
    return labels.join(', ');
  }
}
