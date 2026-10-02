import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../models/emergency_contact.dart';
import '../repositories/auth_repository.dart';
import '../repositories/emergency_contact_repository.dart';

Future<EmergencyContact?> showEmergencyContactDialog(
  BuildContext context, {
  EmergencyContact? existing,
  VoidCallback? onSaved,
}) async {
  final AuthRepository authRepository = AuthRepository();
  final EmergencyContactRepository contactRepository = EmergencyContactRepository();

  final nameController = TextEditingController(text: existing?.name ?? '');
  final phoneController = TextEditingController(
    text: existing?.phone.replaceAll(RegExp(r'[^\d]'), '') ?? '',
  );
  String selectedCountryCode = existing?.countryCode.isNotEmpty == true
      ? existing!.countryCode
      : '+91';

  final List<String> relationshipOptions = ['Dad', 'Mother', 'Friend', 'Other'];
  String selectedRelationship = (existing != null &&
          relationshipOptions.contains(existing.relationship))
      ? existing.relationship
      : 'Friend';

  final customRelationshipController = TextEditingController(
    text: existing?.customRelationship ??
        (existing != null && !relationshipOptions.contains(existing.relationship)
            ? existing.relationship
            : ''),
  );

  String? nameError;
  String? phoneError;
  String? dialogError;
  bool isSaving = false;

  return showDialog<EmergencyContact>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          title: Text(
            existing == null ? 'Add Emergency Contact' : 'Edit Emergency Contact',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.emergency),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
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
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Contact Name *',
                      hintText: 'e.g. Rohith',
                      errorText: nameError,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCountryCode,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: '+91', child: Text('+91')),
                            DropdownMenuItem(value: '+1', child: Text('+1')),
                            DropdownMenuItem(value: '+44', child: Text('+44')),
                            DropdownMenuItem(value: '+61', child: Text('+61')),
                            DropdownMenuItem(value: '+81', child: Text('+81')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCountryCode = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Phone Number (Digits only) *',
                            hintText: 'e.g. 7207210627',
                            errorText: phoneError,
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRelationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship *',
                      prefixIcon: Icon(Icons.family_restroom_outlined),
                    ),
                    items: relationshipOptions
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRelationship = val);
                      }
                    },
                  ),
                  if (selectedRelationship == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customRelationshipController,
                      decoration: const InputDecoration(
                        labelText: 'Specify Relationship *',
                        hintText: 'e.g. Brother, Spouse, Doctor',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: dialogContext,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Emergency Contact'),
                            content: Text(
                              'Are you sure you want to delete ${existing.name} (${existing.displayPhone}) from your emergency contacts?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(c).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emergency,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(c).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          setDialogState(() => isSaving = true);
                          final userId = await authRepository.getCurrentUserId();
                          await contactRepository.deleteEmergencyContact(userId, existing.id);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(null);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Emergency contact deleted successfully ✓'),
                                ),
                              );
                              if (onSaved != null) onSaved();
                            }
                          }
                        }
                      },
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.emergency),
                label: const Text('Delete', style: TextStyle(color: AppColors.emergency)),
              ),
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final rawPhone = phoneController.text.trim();
                      final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
                      final customRel = customRelationshipController.text.trim();

                      setDialogState(() {
                        nameError = null;
                        phoneError = null;
                        dialogError = null;
                      });

                      bool isValid = true;
                      if (name.isEmpty || name.length < 2) {
                        setDialogState(() => nameError = 'Please enter a valid contact name.');
                        isValid = false;
                      }

                      if (cleanPhone.isEmpty || cleanPhone.length < 7 || cleanPhone.length > 15) {
                        setDialogState(() => phoneError = 'Please enter a valid 7 to 15-digit phone number.');
                        isValid = false;
                      }

                      if (selectedRelationship == 'Other' && customRel.isEmpty) {
                        setDialogState(() => dialogError = 'Please specify the relationship.');
                        isValid = false;
                      }

                      if (!isValid) return;

                      setDialogState(() => isSaving = true);

                      final userId = await authRepository.getCurrentUserId();
                      final contact = EmergencyContact(
                        id: existing?.id,
                        name: name,
                        countryCode: selectedCountryCode,
                        phone: cleanPhone,
                        relationship: selectedRelationship,
                        customRelationship: customRel,
                      );

                      final saved = await contactRepository.saveEmergencyContact(userId, contact);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(contact);
                        if (saved && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'Emergency contact added successfully ✓'
                                    : 'Emergency contact updated successfully ✓',
                              ),
                            ),
                          );
                          if (onSaved != null) onSaved();
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(existing == null ? 'Save Contact' : 'Update Contact'),
            ),
          ],
        );
      },
    ),
  );
}
