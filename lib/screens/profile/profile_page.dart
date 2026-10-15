import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../models/user_profile.dart';
import '../../models/water_intake.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/emergency_contact_repository.dart';
import '../../repositories/health_record_repository.dart';
import '../../repositories/medicine_repository.dart';
import '../../repositories/water_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/emergency_contact_dialog.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/medguard_avatar.dart';
import '../../models/emergency_contact.dart';
import '../../services/user_state_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthRepository _authRepository = AuthRepository();
  final WaterRepository _waterRepository = WaterRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final HealthRecordRepository _recordRepository = HealthRecordRepository();
  final EmergencyContactRepository _contactRepository = EmergencyContactRepository();

  UserProfile? _userProfile;
  String _userEmail = '';
  String? _currentUserId;
  String? _profileImagePath;
  DailyWaterIntake? _todayWaterIntake;
  int _activeMedsCount = 0;
  int _healthRecordsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ProfileStateManager.instance.addListener(_onProfileStateManagerChanged);
    _userProfile = ProfileStateManager.instance.currentProfile;
    _profileImagePath = ProfileStateManager.instance.profileImagePath;
    _loadProfile();
  }

  void _onProfileStateManagerChanged() {
    if (mounted) {
      setState(() {
        _userProfile = ProfileStateManager.instance.currentProfile;
        _profileImagePath = ProfileStateManager.instance.profileImagePath;
      });
    }
  }

  @override
  void dispose() {
    ProfileStateManager.instance.removeListener(_onProfileStateManagerChanged);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      final p = await ProfileStateManager.instance.loadProfile();
      final email = _authRepository.currentUser?.email ?? '';

      DailyWaterIntake? water;
      int medsCount = 0;
      int recordsCount = 0;

      try {
        water = await _waterRepository.getTodayWaterIntake(userId: userId);
        final meds = await _medicineRepository.getMedicines(userId: userId);
        medsCount = meds.where((m) => m.quantityAvailable > 0).length;
        final recs = await _recordRepository.getRecords(userId: userId);
        recordsCount = recs.length;
      } catch (e) {
        debugPrint('[PROFILE] Load health stats note: $e');
      }

      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _userProfile = p;
          _userEmail = email;
          _profileImagePath = p?.profileImagePath;
          _todayWaterIntake = water;
          _activeMedsCount = medsCount;
          _healthRecordsCount = recordsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE] Load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _pickProfileImage() {
    final hasExistingPhoto = (ProfileStateManager.instance.profileImagePath != null &&
            ProfileStateManager.instance.profileImagePath!.trim().isNotEmpty) ||
        (_profileImagePath != null && _profileImagePath!.trim().isNotEmpty);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Profile Photo Options',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryTeal),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryTeal),
              title: const Text('Choose from Gallery / Files'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            if (hasExistingPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  _confirmAndRemovePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Profile Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo? Your avatar will immediately revert to your name initial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ProfileStateManager.instance.removeAvatar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo removed successfully.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove photo: $e'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      }
    }
  }

  void _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        await ProfileStateManager.instance.uploadAvatar(
          bytes: bytes,
          filename: pickedFile.name,
          filePath: pickedFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PROFILE] Pick image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update profile image: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _editProfile() async {
    final updated = await Navigator.of(context).pushNamed(AppRoutes.profileSetup);
    if (updated == true || mounted) {
      await ProfileStateManager.instance.loadProfile(force: true);
      _loadProfile();
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of MedGuard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authRepository.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final h = double.tryParse(_userProfile?.height ?? '') ?? 0.0;
    final w = double.tryParse(_userProfile?.weight ?? '') ?? 0.0;
    final userAge = _userProfile?.age ?? 0;
    final bmiResult = BmiCalculator.evaluate(heightCm: h, weightKg: w, age: userAge);

    return Scaffold(
      appBar: const AppHeader(
        title: 'Profile & Health',
        subtitle: 'Personal medical profile',
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading health profile...')
            : RefreshIndicator(
                onRefresh: () async => _loadProfile(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. PROFILE HEADER CARD
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  MedGuardAvatar(
                                    radius: 46,
                                    showEditBadge: true,
                                    onTap: _pickProfileImage,
                                    onEditTap: _pickProfileImage,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _userProfile?.name.isNotEmpty == true ? _userProfile!.name : 'User Profile',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: onSurface,
                                    ),
                                  ),
                                  if (_userEmail.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _userEmail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    _userProfile?.dateOfBirth != null
                                        ? 'Age: ${_userProfile!.age} yrs (${DateFormat('MMM dd, yyyy').format(_userProfile!.dateOfBirth!)})'
                                        : 'Age: Not specified',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildBadge(
                                        'Blood',
                                        _userProfile?.bloodGroup.isNotEmpty == true ? _userProfile!.bloodGroup : 'N/A',
                                        Icons.bloodtype,
                                      ),
                                      _buildBadge(
                                        'Gender',
                                        _userProfile?.gender.isNotEmpty == true ? _userProfile!.gender : 'N/A',
                                        Icons.wc,
                                      ),
                                      _buildBadge(
                                        'Height',
                                        _userProfile?.height.isNotEmpty == true ? '${_userProfile!.height} cm' : 'N/A',
                                        Icons.height,
                                      ),
                                      _buildBadge(
                                        'Weight',
                                        _userProfile?.weight.isNotEmpty == true ? '${_userProfile!.weight} kg' : 'N/A',
                                        Icons.monitor_weight_outlined,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 2. BODY & HEALTH (BMI SECTION)
                          _buildBodyAndHealthCard(bmiResult, h, w),
                          const SizedBox(height: 20),

                          // 3. HEALTH INSIGHT (BMI RECOMMENDATION)
                          _buildHealthInsightCard(bmiResult),
                          const SizedBox(height: 20),

                          // 4. TRACK YOUR DAY HEALTHY (3 DAILY TIPS)
                          _buildTrackYourDayHealthyCard(),
                          const SizedBox(height: 20),

                          // 5. TODAY'S HEALTH SUMMARY
                          _buildTodaysHealthSummaryCard(),
                          const SizedBox(height: 20),

                          // 6. EMERGENCY CONTACT CARD
                          _buildEmergencyContactCard(),
                          const SizedBox(height: 20),

                          // 7. MEDICAL HISTORY CARD
                          _buildMedicalHistoryCard(),
                          const SizedBox(height: 24),

                          // ACTION BUTTONS
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(AppRoutes.settings);
                                  },
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Settings'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentRed,
                                  ),
                                  onPressed: _logout,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Logout'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBodyAndHealthCard(BmiResult bmiResult, double heightCm, double weightKg) {
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

    final hasValidInputs = heightCm > 0 && weightKg > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fitness_center_rounded, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Body & Health',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _editProfile,
                ),
              ],
            ),
            const Divider(),
            if (hasValidInputs) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body Mass Index (BMI)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
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
                          const SizedBox(width: 6),
                          const Text(
                            'kg/m²',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(
                      bmiResult.category,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bmiResult.note,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted,
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Please enter your height and weight in profile settings to calculate your BMI.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthInsightCard(BmiResult bmiResult) {
    return Card(
      color: AppTheme.primaryTeal.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryTeal),
                SizedBox(width: 8),
                Text(
                  'Health Insight',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bmiResult.guidance,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackYourDayHealthyCard() {
    final todayWater = _todayWaterIntake?.currentMl ?? 0;
    final hydrationMessage = todayWater < 1000
        ? 'Your recorded water intake is low today ($todayWater ml). Remember to drink fluids regularly if appropriate for you.'
        : 'Good progress with today\'s hydration tracking ($todayWater ml recorded today).';

    final activeMeds = _activeMedsCount;
    final activityMedMessage = activeMeds > 0
        ? '💊 Medication: You have $activeMeds medication reminder(s) scheduled today. Check your Medicines screen for upcoming reminders.'
        : '🏃 Stay Active: Include regular movement or physical activity that is appropriate for you.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Track Your Day Healthy',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildTipTile(
              emoji: '🥗',
              title: 'Eat Healthy',
              subtitle: 'Choose balanced meals with vegetables, fruits, whole grains and appropriate protein.',
            ),
            const SizedBox(height: 10),
            _buildTipTile(
              emoji: '💧',
              title: 'Stay Hydrated',
              subtitle: hydrationMessage,
            ),
            const SizedBox(height: 10),
            _buildTipTile(
              emoji: activeMeds > 0 ? '💊' : '🏃',
              title: activeMeds > 0 ? 'Medication Schedule' : 'Stay Active',
              subtitle: activityMedMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipTile({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysHealthSummaryCard() {
    final waterCurrent = _todayWaterIntake?.currentMl ?? 0;
    final waterTarget = _todayWaterIntake?.targetMl ?? 2000;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insert_chart_outlined_rounded, color: AppTheme.primaryTeal),
                SizedBox(width: 8),
                Text(
                  'Today\'s Health Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStatTile(
                    label: 'Water Intake',
                    value: '$waterCurrent / $waterTarget ml',
                    icon: Icons.water_drop_rounded,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryStatTile(
                    label: 'Active Medicines',
                    value: '$_activeMedsCount scheduled',
                    icon: Icons.medication_rounded,
                    color: AppColors.emergency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStatTile(
                    label: 'Health Records',
                    value: '$_healthRecordsCount document(s)',
                    icon: Icons.folder_copy_rounded,
                    color: AppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryStatTile(
                    label: 'Activity Data',
                    value: 'No activity data recorded today.',
                    icon: Icons.directions_run_rounded,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<EmergencyContact>>(
      stream: _contactRepository.watchEmergencyContacts(_currentUserId!),
      builder: (context, snapshot) {
        List<EmergencyContact> contacts = [];
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          contacts = snapshot.data!;
        } else if (_userProfile != null && _userProfile!.emergencyPhone.trim().isNotEmpty) {
          contacts = [
            EmergencyContact(
              name: _userProfile!.emergencyContactName.isNotEmpty
                  ? _userProfile!.emergencyContactName
                  : 'Emergency Contact',
              countryCode: _userProfile!.emergencyCountryCode.isNotEmpty
                  ? _userProfile!.emergencyCountryCode
                  : '+91',
              phone: _userProfile!.emergencyPhone,
              relationship: _userProfile!.emergencyRelationship.isNotEmpty
                  ? _userProfile!.emergencyRelationship
                  : 'Friend',
            )
          ];
        }

        final hasContact = contacts.isNotEmpty;
        final primaryContact = hasContact ? contacts.first : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phone_in_talk_rounded, color: AppTheme.accentRed),
                        SizedBox(width: 8),
                        Text(
                          'Emergency Contact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(hasContact ? Icons.edit : Icons.add, size: 20),
                      onPressed: () async {
                        await showEmergencyContactDialog(
                          context,
                          existing: primaryContact,
                          onSaved: () => _loadProfile(),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                if (hasContact && primaryContact != null) ...[
                  _buildInfoTile(
                    'Name',
                    primaryContact.name.isNotEmpty
                        ? primaryContact.name
                        : 'Emergency Contact',
                    Icons.person,
                  ),
                  _buildInfoTile(
                    'Relationship',
                    primaryContact.displayRelationship,
                    Icons.family_restroom,
                  ),
                  _buildInfoTile(
                    'Phone Number',
                    primaryContact.displayPhone,
                    Icons.phone,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'No emergency contact added',
                          style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await showEmergencyContactDialog(
                              context,
                              onSaved: () => _loadProfile(),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Contact'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicalHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_information_rounded, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Medical History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _editProfile,
                ),
              ],
            ),
            const Divider(),
            _buildInfoTile(
              'Allergies',
              _userProfile?.allergies.isNotEmpty == true ? _userProfile!.allergies : 'None Reported',
              Icons.warning_amber,
            ),
            _buildInfoTile(
              'Existing Conditions',
              _userProfile?.existingConditions.isNotEmpty == true ? _userProfile!.existingConditions : 'None Reported',
              Icons.medical_services_outlined,
            ),
            _buildInfoTile(
              'Current Medications',
              _userProfile?.currentMedications.isNotEmpty == true ? _userProfile!.currentMedications : 'None Reported',
              Icons.medication_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryTeal),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
