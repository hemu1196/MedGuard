import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/family_member.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/family_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class FamilyHealthDashboardPage extends StatefulWidget {
  const FamilyHealthDashboardPage({super.key});

  @override
  State<FamilyHealthDashboardPage> createState() =>
      _FamilyHealthDashboardPageState();
}

class _FamilyHealthDashboardPageState extends State<FamilyHealthDashboardPage> {
  final FamilyRepository _familyRepository = FamilyRepository();
  final AuthRepository _authRepository = AuthRepository();

  List<FamilyMember> _familyMembers = [];
  bool _isLoading = true;

  final List<String> _relationships = [
    'Mother',
    'Father',
    'Spouse',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Grandfather',
    'Grandmother',
    'Guardian',
    'Other',
  ];

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  final List<String> _countryCodes = ['+91', '+1', '+44', '+971'];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  void _loadFamilyMembers() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final list = await _familyRepository.getFamilyMembers(userId: userId);
    if (mounted) {
      setState(() {
        _familyMembers = list;
        _isLoading = false;
      });
    }
  }

  void _openAddEditMemberDialog([FamilyMember? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedRelationship =
        (existing != null && _relationships.contains(existing.relationship))
        ? existing.relationship
        : 'Mother';
    final customRelController = TextEditingController(
      text:
          (existing != null && !_relationships.contains(existing.relationship))
          ? existing.relationship
          : '',
    );

    DateTime selectedDob =
        existing?.dateOfBirth ??
        DateTime.now().subtract(const Duration(days: 365 * 45));

    String selectedGender = existing?.gender ?? 'Female';
    String selectedBloodGroup = existing?.bloodGroup ?? 'O+';
    bool noKnownAllergies = existing?.noKnownAllergies ?? false;
    final allergiesController = TextEditingController(
      text: existing?.allergies ?? '',
    );
    final conditionsController = TextEditingController(
      text: existing?.existingConditions ?? '',
    );
    final medsController = TextEditingController(
      text: existing?.currentMedications ?? '',
    );
    String selectedCountryCode = existing?.emergencyCountryCode ?? '+91';
    final phoneController = TextEditingController(
      text: existing?.emergencyPhone ?? '',
    );
    final notesController = TextEditingController(
      text: existing?.emergencyNotes ?? '',
    );

    String? nameError;
    String? phoneError;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int computedAge = DateTime.now().year - selectedDob.year;
          if (DateTime.now().month < selectedDob.month ||
              (DateTime.now().month == selectedDob.month &&
                  DateTime.now().day < selectedDob.day)) {
            computedAge--;
          }
          if (computedAge < 0) computedAge = 0;

          return AlertDialog(
            title: Text(
              existing == null ? 'Add Family Member' : 'Edit Family Member',
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Lakshmi Devi',
                        errorText: nameError,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Relationship Dropdown
                    DropdownButtonFormField<String>(
                      initialValue:
                          _relationships.contains(selectedRelationship)
                          ? selectedRelationship
                          : 'Other',
                      decoration: const InputDecoration(
                        labelText: 'Relationship *',
                        prefixIcon: Icon(Icons.people_outline),
                      ),
                      items: _relationships
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRelationship = val);
                        }
                      },
                    ),

                    if (selectedRelationship == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customRelController,
                        decoration: const InputDecoration(
                          labelText: 'Specify Relationship *',
                          hintText: 'e.g. Cousin',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Date of Birth Field & Auto-Calculated Age
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDob,
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDob = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth *',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(selectedDob),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Age: $computedAge yrs',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Gender & Blood Group Dropdowns
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender *',
                            ),
                            items: _genders
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedGender = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedBloodGroup,
                            decoration: const InputDecoration(
                              labelText: 'Blood Group *',
                            ),
                            items: _bloodGroups
                                .map(
                                  (bg) => DropdownMenuItem(
                                    value: bg,
                                    child: Text(
                                      bg,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedBloodGroup = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Allergies Section & Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: noKnownAllergies,
                      activeColor: AppColors.primary,
                      title: const Text(
                        'No Known Allergies',
                        style: TextStyle(fontSize: 13),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          noKnownAllergies = val ?? false;
                          if (noKnownAllergies) {
                            allergiesController.clear();
                          }
                        });
                      },
                    ),
                    if (!noKnownAllergies) ...[
                      TextFormField(
                        controller: allergiesController,
                        decoration: const InputDecoration(
                          labelText: 'Allergies (Optional)',
                          hintText: 'e.g. Penicillin, Peanuts',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Existing Conditions & Current Medicines
                    TextFormField(
                      controller: conditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Existing Conditions (Optional)',
                        hintText: 'e.g. Diabetes, Hypertension, None',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: medsController,
                      decoration: const InputDecoration(
                        labelText: 'Current Medicines (Optional)',
                        hintText: 'e.g. Metformin 500mg Twice Daily',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Emergency Phone with Country Code
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCountryCode,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                            ),
                            items: _countryCodes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedCountryCode = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Emergency Phone *',
                              hintText: 'e.g. 9123456789',
                              errorText: phoneError,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Notes (Optional)',
                        hintText: 'e.g. Carries inhaler in purse',
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
                        final rawName = nameController.text.trim();
                        final rawPhone = phoneController.text.trim();

                        setDialogState(() {
                          nameError = null;
                          phoneError = null;
                        });

                        bool isValid = true;

                        if (rawName.length < 2 ||
                            RegExp(r'^[0-9\s]+$').hasMatch(rawName)) {
                          setDialogState(() {
                            nameError = 'Please enter a valid name.';
                          });
                          isValid = false;
                        }

                        if (rawPhone.isEmpty ||
                            !RegExp(r'^[0-9]{7,15}$').hasMatch(rawPhone)) {
                          setDialogState(() {
                            phoneError =
                                'Please enter a valid emergency contact number.';
                          });
                          isValid = false;
                        }

                        if (!isValid) return;

                        setDialogState(() => isSaving = true);

                        final userId = await _authRepository.getCurrentUserId();
                        final relationshipValue =
                            selectedRelationship == 'Other'
                            ? (customRelController.text.trim().isNotEmpty
                                  ? customRelController.text.trim()
                                  : 'Family Member')
                            : selectedRelationship;

                        final member = FamilyMember(
                          id:
                              existing?.id ??
                              'fam_${DateTime.now().millisecondsSinceEpoch}',
                          userId: userId,
                          name: rawName,
                          relationship: relationshipValue,
                          dateOfBirth: selectedDob,
                          gender: selectedGender,
                          bloodGroup: selectedBloodGroup,
                          noKnownAllergies: noKnownAllergies,
                          allergies: noKnownAllergies
                              ? 'None'
                              : allergiesController.text.trim(),
                          existingConditions:
                              conditionsController.text.trim().isNotEmpty
                              ? conditionsController.text.trim()
                              : 'None',
                          currentMedications:
                              medsController.text.trim().isNotEmpty
                              ? medsController.text.trim()
                              : 'None',
                          emergencyCountryCode: selectedCountryCode,
                          emergencyPhone: rawPhone,
                          emergencyNotes: notesController.text.trim(),
                          lastMedicineStatus:
                              existing?.lastMedicineStatus ?? 'Active Schedule',
                          lastHealthUpdate: DateTime.now(),
                        );

                        await _familyRepository.saveFamilyMember(member);

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Family member added successfully.',
                              ),
                            ),
                          );
                          _loadFamilyMembers();
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Member'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteMember(FamilyMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this family member?'),
        content: Text(
          'Are you sure you want to remove ${member.name}? This will permanently delete their locally stored family health details.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userId = await _authRepository.getCurrentUserId();
      await _familyRepository.deleteFamilyMember(member.id, userId: userId);
      _loadFamilyMembers();
    }
  }

  void _viewMemberDetails(FamilyMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${member.relationship} • Age: ${member.age} yrs (${member.gender})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Blood Group',
                member.bloodGroup,
                Icons.bloodtype,
                AppColors.emergency,
              ),
              _buildDetailRow(
                'Allergies',
                member.noKnownAllergies
                    ? 'No Known Allergies'
                    : member.allergies,
                Icons.warning_amber,
                AppColors.warning,
              ),
              _buildDetailRow(
                'Existing Conditions',
                member.existingConditions,
                Icons.medical_services_outlined,
                AppColors.secondary,
              ),
              _buildDetailRow(
                'Current Medications',
                member.currentMedications,
                Icons.medication_outlined,
                AppColors.primary,
              ),
              _buildDetailRow(
                'Emergency Contact',
                '${member.emergencyCountryCode} ${member.emergencyPhone}',
                Icons.phone,
                AppColors.primary,
              ),
              if (member.emergencyNotes.isNotEmpty)
                _buildDetailRow(
                  'Emergency Notes',
                  member.emergencyNotes,
                  Icons.notes,
                  AppColors.textSecondary,
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'None',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Family Health Dashboard',
        subtitle: 'Manage family health profiles & emergency data',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
            onPressed: () => _openAddEditMemberDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading Family Dashboard...')
            : _familyMembers.isEmpty
            ? EmptyStateView(
                title: 'No Family Members Added',
                message:
                    'Keep track of your family’s medications, blood groups, conditions, and emergency details.',
                icon: Icons.family_restroom,
                actionText: 'Add Family Member',
                onAction: () => _openAddEditMemberDialog(),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _familyMembers[index];
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
                                        child: Text(
                                          member.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                member.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  member.relationship,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Age: ${member.age} yrs • Blood Group: ${member.bloodGroup}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
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
                                            _openAddEditMemberDialog(member),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: AppColors.emergency,
                                        ),
                                        onPressed: () => _deleteMember(member),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Conditions',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          member.existingConditions.isNotEmpty
                                              ? member.existingConditions
                                              : 'None',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Medicines',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          member.currentMedications.isNotEmpty
                                              ? member.currentMedications
                                              : 'None',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Emergency Contact: ${member.emergencyCountryCode} ${member.emergencyPhone}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _viewMemberDetails(member),
                                    child: const Text(
                                      'View Details',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
