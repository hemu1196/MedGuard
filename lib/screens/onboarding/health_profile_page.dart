import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../models/emergency_contact.dart';
import '../../models/user_profile.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/emergency_contact_repository.dart';
import '../../repositories/profile_repository.dart';

class HealthProfilePage extends StatefulWidget {
  const HealthProfilePage({super.key});

  @override
  State<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends State<HealthProfilePage> {
  int _currentStep = 0;
  final _profileRepository = ProfileRepository();
  final _authRepository = AuthRepository();
  final _emergencyContactRepository = EmergencyContactRepository();

  // Step 1 Controllers & State
  final _nameController = TextEditingController();
  DateTime? _selectedDob;
  String _selectedGender = 'Male';
  String? _existingImagePath;

  // Step 2 Controllers & State
  String _selectedBloodGroup = 'O+';
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();

  // Step 3 Controllers & State
  final _emergencyNameController = TextEditingController();
  String _selectedCountryCode = '+91';
  final _emergencyPhoneController = TextEditingController();
  String _selectedRelationship = 'Dad';

  bool _isSaving = false;

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
  ];
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'USA'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'UK'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'UAE'},
  ];
  final List<String> _relationships = [
    'Dad',
    'Mother',
    'Brother',
    'Sister',
    'Spouse',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      final existing = await _profileRepository.getProfile(userId: userId);
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('user_profile_image_$userId');

      if (existing != null && mounted) {
        setState(() {
          _nameController.text = existing.name;
          _selectedDob = existing.dateOfBirth;
          _selectedGender = _genders.contains(existing.gender) ? existing.gender : 'Male';
          _selectedBloodGroup = _bloodGroups.contains(existing.bloodGroup) ? existing.bloodGroup : 'O+';
          _heightController.text = existing.height;
          _weightController.text = existing.weight;
          _allergiesController.text = existing.allergies;
          _conditionsController.text = existing.existingConditions;
          _medicationsController.text = existing.currentMedications;
          _emergencyNameController.text = existing.emergencyContactName;
          _selectedCountryCode = existing.emergencyCountryCode.isNotEmpty ? existing.emergencyCountryCode : '+91';
          _emergencyPhoneController.text = existing.emergencyPhone;
          _selectedRelationship = _relationships.contains(existing.emergencyRelationship)
              ? existing.emergencyRelationship
              : 'Dad';
          _existingImagePath = savedPath ?? existing.profileImagePath;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE] Load existing profile note: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  void _saveProfile() async {
    if (_isSaving) return;

    debugPrint('PROFILE: starting validation');

    // 1. Name Validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      setState(() => _currentStep = 0);
      return;
    }

    // 2. Height Validation
    final heightText = _heightController.text.trim();
    final heightVal = double.tryParse(heightText);
    if (heightText.isNotEmpty && (heightVal == null || heightVal <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive height in cm (e.g. 174)')),
      );
      setState(() => _currentStep = 1);
      return;
    }

    // 3. Weight Validation
    final weightText = _weightController.text.trim();
    final weightVal = double.tryParse(weightText);
    if (weightText.isNotEmpty && (weightVal == null || weightVal <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive weight in kg (e.g. 68)')),
      );
      setState(() => _currentStep = 1);
      return;
    }

    // 4. Emergency Phone Validation
    final phoneText = _emergencyPhoneController.text.trim();
    if (phoneText.isNotEmpty && !RegExp(r'^\d{7,15}$').hasMatch(phoneText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number. Digits only expected (e.g. 9876543210)')),
      );
      setState(() => _currentStep = 2);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = await _authRepository.getCurrentUserId();

      final profile = UserProfile(
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDob,
        gender: _selectedGender,
        bloodGroup: _selectedBloodGroup,
        height: heightText,
        weight: weightText,
        allergies: _allergiesController.text.trim(),
        existingConditions: _conditionsController.text.trim(),
        currentMedications: _medicationsController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyCountryCode: _selectedCountryCode,
        emergencyPhone: phoneText,
        emergencyRelationship: _selectedRelationship,
        profileImagePath: _existingImagePath,
      );

      debugPrint('PROFILE: saving profile');
      final saved = await _profileRepository.createProfile(
        uid: userId,
        profile: profile,
      );

      if (!saved) {
        throw Exception('Failed to persist profile data');
      }
      debugPrint('PROFILE: profile save completed');

      // Also save emergency contact to repository if phone is provided
      if (phoneText.isNotEmpty) {
        debugPrint('PROFILE: saving emergency contact');
        final contact = EmergencyContact(
          name: _emergencyNameController.text.trim().isNotEmpty
              ? _emergencyNameController.text.trim()
              : 'Emergency Contact',
          countryCode: _selectedCountryCode,
          phone: phoneText,
          relationship: _selectedRelationship,
        );
        await _emergencyContactRepository.saveEmergencyContact(userId, contact);
        debugPrint('PROFILE: emergency contact save completed');
      }

      if (!mounted) return;

      debugPrint('PROFILE: navigating to home');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('PROFILE COMPLETION ERROR: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save your profile: ${e.toString()}'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildBmiOverviewCard() {
    final h = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final w = double.tryParse(_weightController.text.trim()) ?? 0.0;

    if (h <= 0 || w <= 0) return const SizedBox.shrink();

    final userAge = _selectedDob != null ? _calculateAge(_selectedDob!) : 25;
    final bmiResult = BmiCalculator.evaluate(heightCm: h, weightKg: w, age: userAge);

    Color badgeColor;
    if (bmiResult.bmi < 18.5) {
      badgeColor = Colors.orange;
    } else if (bmiResult.bmi <= 24.9) {
      badgeColor = AppTheme.accentGreen;
    } else if (bmiResult.bmi <= 29.9) {
      badgeColor = Colors.amber.shade800;
    } else {
      badgeColor = AppTheme.accentRed;
    }

    return Card(
      color: badgeColor.withValues(alpha: 0.08),
      elevation: 0,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_weight_rounded, color: badgeColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'BMI OVERVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bmiResult.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${bmiResult.bmi}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'kg/m²',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bmiResult.guidance,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bmiResult.note,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Health Profile')),
      body: SafeArea(
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (!_isSaving) {
              setState(() => _currentStep = step);
            }
          },
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              _saveProfile();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0 && !_isSaving) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _isSaving ? null : details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    child: _isSaving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : Text(isLastStep ? 'Complete Profile' : 'Next Step'),
                  ),
                ],
              ),
            );
          },
          steps: [
            // Step 1: Personal Info
            Step(
              title: const Text('Personal'),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDateOfBirth,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth *',
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDob != null
                                ? DateFormat('MMM dd, yyyy').format(_selectedDob!)
                                : 'Select Date of Birth',
                          ),
                          if (_selectedDob != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Age: ${_calculateAge(_selectedDob!)} yrs',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryTeal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    items: _genders
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    },
                  ),
                ],
              ),
            ),

            // Step 2: Health Info + BMI
            Step(
              title: const Text('Health'),
              isActive: _currentStep >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    items: _bloodGroups
                        .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBloodGroup = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Height (cm)',
                            prefixIcon: Icon(Icons.height),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  _buildBmiOverviewCard(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Known Allergies',
                      hintText: 'e.g. Penicillin, Peanuts (None if N/A)',
                      prefixIcon: Icon(Icons.warning_amber),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _conditionsController,
                    decoration: const InputDecoration(
                      labelText: 'Existing Conditions',
                      hintText: 'e.g. Asthma, Hypertension (None if N/A)',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _medicationsController,
                    decoration: const InputDecoration(
                      labelText: 'Current Medications',
                      hintText: 'e.g. Inhaler, Vitamin D (None if N/A)',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                  ),
                ],
              ),
            ),

            // Step 3: Emergency Contact
            Step(
              title: const Text('Emergency'),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _emergencyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Name',
                      prefixIcon: Icon(Icons.person_pin),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRelationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                    items: _relationships
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRelationship = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCountryCode,
                          decoration: const InputDecoration(labelText: 'Code'),
                          items: _countryCodes
                              .map((c) => DropdownMenuItem(
                                    value: c['code'],
                                    child: Text('${c['flag']} ${c['code']}'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCountryCode = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emergencyPhoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (10 Digits)',
                            hintText: 'e.g. 9123456789',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Step 4: Review
            Step(
              title: const Text('Review'),
              isActive: _currentStep >= 3,
              content: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Health Profile Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildReviewRow(
                        'Name',
                        _nameController.text.trim(),
                        Icons.person,
                      ),
                      _buildReviewRow(
                        'Age / DOB',
                        _selectedDob != null
                            ? '${_calculateAge(_selectedDob!)} yrs (${DateFormat('MMM dd, yyyy').format(_selectedDob!)})'
                            : 'Not set',
                        Icons.cake,
                      ),
                      _buildReviewRow('Gender', _selectedGender, Icons.wc),
                      _buildReviewRow(
                        'Blood Group',
                        _selectedBloodGroup,
                        Icons.bloodtype,
                      ),
                      _buildReviewRow(
                        'Height / Weight',
                        '${_heightController.text.trim()} cm / ${_weightController.text.trim()} kg',
                        Icons.straighten,
                      ),
                      _buildReviewRow(
                        'Allergies',
                        _allergiesController.text.trim().isEmpty
                            ? 'None'
                            : _allergiesController.text.trim(),
                        Icons.warning,
                      ),
                      _buildReviewRow(
                        'Emergency Contact',
                        '${_emergencyNameController.text.trim()} ($_selectedRelationship, $_selectedCountryCode ${_emergencyPhoneController.text.trim()})',
                        Icons.contact_phone,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _isSaving ? null : () => setState(() => _currentStep = 0),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, IconData icon) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
