import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/routes.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../core/utils/phone_helper.dart';
import '../../models/user_profile.dart';
import '../../models/water_intake.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/emergency_contact_repository.dart';
import '../../repositories/health_record_repository.dart';
import '../../repositories/medicine_repository.dart';
import '../../repositories/water_repository.dart';
import '../../services/in_app_notification_service.dart';
import '../../services/user_state_service.dart';
import '../../widgets/loading_view.dart';

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
  final EmergencyContactRepository _contactRepository =
      EmergencyContactRepository();

  UserProfile? _userProfile;
  String _userEmail = '';
  String? _profileImagePath;
  DailyWaterIntake? _todayWaterIntake;
  int _activeMedsCount = 0;
  int _healthRecordsCount = 0;
  String? _emergencyContactName;
  String? _emergencyContactRelation;
  String? _emergencyContactPhone;
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
      String? emName;
      String? emRel;
      String? emPhone;

      try {
        water = await _waterRepository.getTodayWaterIntake(userId: userId);
        final meds = await _medicineRepository.getMedicines(userId: userId);
        medsCount = meds.where((m) => m.quantityAvailable > 0).length;
        final recs = await _recordRepository.getRecords(userId: userId);
        recordsCount = recs.length;

        final contacts =
            await _contactRepository.getEmergencyContacts(userId: userId);
        if (contacts.isNotEmpty) {
          final c = contacts.first;
          emName = c.name;
          emRel = c.displayRelationship;
          emPhone = c.displayPhone;
        } else if (p != null && p.emergencyContactName.isNotEmpty) {
          emName = p.emergencyContactName;
          emRel = p.emergencyRelationship.isNotEmpty ? p.emergencyRelationship : 'Family';
          emPhone = p.emergencyPhone;
        }
      } catch (e) {
        debugPrint('[PROFILE] Load health stats note: $e');
      }

      if (mounted) {
        setState(() {
          _userProfile = p;
          _userEmail = email.isNotEmpty ? email : (p?.name != null ? email : '');
          _profileImagePath = p?.profileImagePath;
          _todayWaterIntake = water;
          _activeMedsCount = medsCount;
          _healthRecordsCount = recordsCount;
          _emergencyContactName = emName ?? 'Hema';
          _emergencyContactRelation = emRel ?? 'Dad';
          _emergencyContactPhone = emPhone ?? '+91 8309305811';
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

  int _calculateProfileCompleteness() {
    int score = 0;
    if (_userProfile?.name != null && _userProfile!.name.trim().isNotEmpty) {
      score += 15;
    }
    if (_userEmail.trim().isNotEmpty) {
      score += 15;
    }
    if (_userProfile?.bloodGroup != null &&
        _userProfile!.bloodGroup.isNotEmpty) {
      score += 15;
    }
    if (_userProfile?.gender != null && _userProfile!.gender.isNotEmpty) {
      score += 15;
    }
    if (_userProfile?.height != null && _userProfile!.height.isNotEmpty) {
      score += 15;
    }
    if (_userProfile?.weight != null && _userProfile!.weight.isNotEmpty) {
      score += 10;
    }
    if (_emergencyContactPhone != null &&
        _emergencyContactPhone!.trim().isNotEmpty) {
      score += 15;
    }
    return score.clamp(0, 100);
  }

  void _pickProfileImage() {
    final hasExistingPhoto =
        (ProfileStateManager.instance.profileImagePath != null &&
                ProfileStateManager.instance.profileImagePath!
                    .trim()
                    .isNotEmpty) ||
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
              leading:
                  const Icon(Icons.camera_alt, color: Color(0xFF009E8F)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF009E8F)),
              title: const Text('Choose from Gallery / Files'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            if (hasExistingPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626)),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(
                      color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              backgroundColor: const Color(0xFFDC2626),
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
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 85);
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
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _editProfile() async {
    final updated =
        await Navigator.of(context).pushNamed(AppRoutes.profileSetup);
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
              backgroundColor: const Color(0xFFDC2626),
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
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  Widget _buildAvatarWidget({double radius = 48}) {
    final avatarPath = _profileImagePath ?? _userProfile?.profileImagePath;
    final initial = (_userProfile?.name.isNotEmpty == true)
        ? _userProfile!.name[0].toUpperCase()
        : 'H';

    Widget avatarContent;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('data:image') || avatarPath.length > 300) {
        try {
          final cleanBase64 = avatarPath.contains(',')
              ? avatarPath.split(',').last
              : avatarPath;
          final bytes = base64Decode(cleanBase64.trim());
          avatarContent = Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {
          avatarContent = _buildInitialAvatar(initial, radius);
        }
      } else if (!kIsWeb && File(avatarPath).existsSync()) {
        avatarContent = Image.file(File(avatarPath), fit: BoxFit.cover);
      } else {
        avatarContent = _buildInitialAvatar(initial, radius);
      }
    } else {
      avatarContent = _buildInitialAvatar(initial, radius);
    }

    return Stack(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF009E8F).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(child: avatarContent),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF087F7A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialAvatar(String initial, double radius) {
    return Container(
      color: const Color(0xFF009E8F),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(message: 'Loading health profile...'),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final h = double.tryParse(_userProfile?.height ?? '') ?? 168.0;
    final w = double.tryParse(_userProfile?.weight ?? '') ?? 50.0;
    final userAge = _userProfile?.age ?? 28;
    final bmiResult =
        BmiCalculator.evaluate(heightCm: h, weightKg: w, age: userAge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: isDesktop
            ? _buildDesktopLayout(bmiResult, h, w)
            : _buildMobileLayout(bmiResult, h, w),
      ),
    );
  }

  // =========================================================================
  // MOBILE PROFILE LAYOUT (Matches Image 1)
  // =========================================================================
  Widget _buildMobileLayout(
      BmiResult bmiResult, double heightCm, double weightKg) {
    final name = _userProfile?.name.isNotEmpty == true
        ? _userProfile!.name
        : 'Hemachandra';
    final email = _userEmail.isNotEmpty ? _userEmail : 'hem469469@gmail.com';
    final blood = _userProfile?.bloodGroup.isNotEmpty == true
        ? _userProfile!.bloodGroup
        : 'O+';
    final gender =
        _userProfile?.gender.isNotEmpty == true ? _userProfile!.gender : 'Male';
    final heightStr = '${heightCm.toInt()} cm';
    final weightStr = '${weightKg.toInt()} kg';
    final waterMl = _todayWaterIntake?.currentMl ?? 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _loadProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar (Back button, Profile & Health, Edit button)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Color(0xFF12254A)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Profile & Health',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF12254A),
                          ),
                        ),
                        Text(
                          'Personal medical profile',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF009E8F),
                        side: const BorderSide(color: Color(0xFF009E8F)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Edit',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Scenic Header Hero with Avatar
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Scenic Mountain Background
                  Container(
                    height: 140,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/scenic_mountain_bg.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Avatar & Info Overlay
                  Container(
                    margin: const EdgeInsets.only(top: 85),
                    child: Column(
                      children: [
                        _buildAvatarWidget(radius: 46),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF12254A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FAF8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified_rounded,
                                  color: Color(0xFF009E8F), size: 13),
                              SizedBox(width: 5),
                              Text(
                                'Active User',
                                style: TextStyle(
                                  color: Color(0xFF009E8F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4 Compact Metrics Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetricCol(
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFFEF4444),
                      value: blood,
                      label: 'Blood',
                    ),
                    _buildMetricDivider(),
                    _buildMetricCol(
                      icon: Icons.male_rounded,
                      iconColor: const Color(0xFF009E8F),
                      value: gender,
                      label: 'Gender',
                    ),
                    _buildMetricDivider(),
                    _buildMetricCol(
                      icon: Icons.swap_vert_rounded,
                      iconColor: const Color(0xFF087F7A),
                      value: heightStr,
                      label: 'Height',
                    ),
                    _buildMetricDivider(),
                    _buildMetricCol(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: const Color(0xFF009E8F),
                      value: weightStr,
                      label: 'Weight',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Health Overview Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Health Overview',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12254A),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Circular BMI Card
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.healthRisk);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Circular Gauge
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: (bmiResult.bmi / 40).clamp(0.1, 1.0),
                              strokeWidth: 8,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: bmiResult.bmi < 18.5
                                  ? const Color(0xFFF59E0B)
                                  : (bmiResult.bmi <= 24.9
                                      ? const Color(0xFF009E8F)
                                      : const Color(0xFFEF4444)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bmiResult.bmi.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF12254A),
                                ),
                              ),
                              const Text(
                                'BMI',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Status & Advice
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 13, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  Text(
                                    bmiResult.category,
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your BMI is below the standard range. Focus on a balanced diet and consult a healthcare professional.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4 Wellness Grid Cards (2x2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildWellnessMiniCard(
                        title: 'Eat Healthy',
                        subtitle: 'Balanced nutrition every day',
                        icon: Icons.restaurant_rounded,
                        iconColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFDCFCE7),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.dietFitness),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWellnessMiniCard(
                        title: 'Stay Hydrated',
                        subtitle: '$waterMl / 2000 ml',
                        icon: Icons.water_drop_rounded,
                        iconColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.waterIntake),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildWellnessMiniCard(
                        title: 'Medication',
                        subtitle: '$_activeMedsCount reminders',
                        icon: Icons.medication_rounded,
                        iconColor: const Color(0xFFE11D48),
                        bgColor: const Color(0xFFFFE4E6),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.medicines),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWellnessMiniCard(
                        title: 'Activity',
                        subtitle: 'No data today',
                        icon: Icons.directions_run_rounded,
                        iconColor: const Color(0xFF059669),
                        bgColor: const Color(0xFFD1FAE5),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Medical Information Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Medical Information',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF12254A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.vault);
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: Color(0xFF009E8F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4 Horizontal Medical Info Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMedInfoChip(
                        icon: Icons.medical_services_outlined,
                        iconColor: const Color(0xFF009E8F),
                        title: 'Allergies',
                        subtitle: _userProfile?.allergies.isNotEmpty == true
                            ? _userProfile!.allergies
                            : 'None',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMedInfoChip(
                        icon: Icons.assignment_outlined,
                        iconColor: const Color(0xFF087F7A),
                        title: 'Conditions',
                        subtitle: _userProfile?.existingConditions.isNotEmpty == true
                            ? _userProfile!.existingConditions
                            : 'None',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMedInfoChip(
                        icon: Icons.medication_outlined,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Medications',
                        subtitle: _activeMedsCount > 0
                            ? '$_activeMedsCount active'
                            : 'None',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMedInfoChip(
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Records',
                        subtitle: '$_healthRecordsCount document',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.vault),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Emergency Contact Card (Bottom)
              GestureDetector(
                onTap: () {
                  PhoneHelper.callNumber(context, _emergencyContactPhone!);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_in_talk_rounded,
                            color: Color(0xFFEF4444), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Contact',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_emergencyContactName ($_emergencyContactRelation)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF12254A),
                              ),
                            ),
                            Text(
                              _emergencyContactPhone!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFEF4444), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Settings & Logout Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.settings),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DESKTOP PROFILE LAYOUT (Matches Image 2)
  // =========================================================================
  Widget _buildDesktopLayout(
      BmiResult bmiResult, double heightCm, double weightKg) {
    final name = _userProfile?.name.isNotEmpty == true
        ? _userProfile!.name
        : 'Hemachandra';
    final email = _userEmail.isNotEmpty ? _userEmail : 'hem469469@gmail.com';
    final blood = _userProfile?.bloodGroup.isNotEmpty == true
        ? _userProfile!.bloodGroup
        : 'O+';
    final gender =
        _userProfile?.gender.isNotEmpty == true ? _userProfile!.gender : 'Male';
    final completeness = _calculateProfileCompleteness();
    final waterMl = _todayWaterIntake?.currentMl ?? 0;

    return Row(
      children: [
        // Left Sidebar
        _buildDesktopSidebar(),

        // Main Profile Dashboard
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Your Health Profile',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF12254A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your personal health, all in one place',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification Bell
                        ListenableBuilder(
                          listenable: InAppNotificationService(),
                          builder: (context, _) {
                            final unread =
                                InAppNotificationService().unreadCount;
                            return Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Color(0xFF12254A)),
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, AppRoutes.notifications);
                                  },
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8FAF8),
                            foregroundColor: const Color(0xFF009E8F),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF009E8F)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onPressed: _editProfile,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit profile',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Wide Profile Hero Banner Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0F7F5), Color(0xFFF1FAF9), Colors.white],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      _buildAvatarWidget(radius: 46),
                      const SizedBox(width: 20),

                      // Name, email, member since
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF12254A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 13, color: Color(0xFF009E8F)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Member since 2025',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile Completeness Ring
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: CircularProgressIndicator(
                                    value: completeness / 100,
                                    strokeWidth: 6,
                                    color: const Color(0xFF009E8F),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                Text(
                                  '$completeness%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF12254A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Profile complete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF12254A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Keep going! Add more details to get the most from MedGuard AI.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 4 Quick Stats
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricCol(
                                icon: Icons.water_drop_rounded,
                                iconColor: const Color(0xFFEF4444),
                                value: blood,
                                label: 'Blood Group',
                              ),
                              _buildMetricCol(
                                icon: Icons.male_rounded,
                                iconColor: const Color(0xFF009E8F),
                                value: gender,
                                label: 'Gender',
                              ),
                              _buildMetricCol(
                                icon: Icons.swap_vert_rounded,
                                iconColor: const Color(0xFF087F7A),
                                value: '${heightCm.toInt()} cm',
                                label: 'Height',
                              ),
                              _buildMetricCol(
                                icon: Icons.shopping_bag_outlined,
                                iconColor: const Color(0xFF009E8F),
                                value: '${weightKg.toInt()} kg',
                                label: 'Weight',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Two Columns (Left: Health at a glance BMI, Right: Daily wellness)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: BMI
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8FAF8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.favorite_rounded,
                                      color: Color(0xFF009E8F), size: 18),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Health at a glance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF12254A),
                                  ),
                                ),
                                const Spacer(),
                                const Text('BMI',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 4),
                                const Icon(Icons.info_outline,
                                    size: 15, color: Color(0xFF64748B)),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // BMI Value + Badge
                            const Text('BMI',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(
                                  bmiResult.bmi.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF12254A),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('kg/m²',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B))),
                                const SizedBox(width: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          size: 13, color: Color(0xFFD97706)),
                                      const SizedBox(width: 4),
                                      Text(
                                        bmiResult.category,
                                        style: const TextStyle(
                                          color: Color(0xFFD97706),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Segmented Bar
                            _buildBmiSegmentedBar(bmiResult.bmi),
                            const SizedBox(height: 20),

                            // Insight Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFB),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFCCFBF1)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      color: Color(0xFF009E8F), size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Insight',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF009E8F),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Your BMI is below the standard adult range. Focus on balanced, nutrient-dense meals and consider discussing your weight with a qualified healthcare professional.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Column: Daily Wellness
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.wb_sunny_outlined,
                                      color: Color(0xFF0284C7), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Daily wellness',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF12254A),
                                      ),
                                    ),
                                    Text(
                                      'Small steps make a big difference',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Water Intake Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0F2FE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.water_drop_rounded,
                                      color: Color(0xFF0284C7), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Water Intake',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF12254A),
                                        ),
                                      ),
                                      Text(
                                        '$waterMl / 2000 ml',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${((waterMl / 2000) * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (waterMl / 2000).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Medication Reminders Row
                            InkWell(
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.medicines),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF3E8FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.medication_rounded,
                                          color: Color(0xFF9333EA), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Medication Reminders',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF12254A),
                                            ),
                                          ),
                                          Text(
                                            '$_activeMedsCount today',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Activity Row
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.directions_run_rounded,
                                        color: Color(0xFF16A34A),
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Activity',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF12254A),
                                          ),
                                        ),
                                        Text(
                                          'No activity data recorded today.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bottom Row (4 Cards across)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emergency Contact
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_in_talk_rounded,
                                    color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('Emergency Contact',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF12254A))),
                                ),
                                InkWell(
                                  onTap: _editProfile,
                                  child: const Icon(Icons.edit_outlined,
                                      size: 14, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('Name',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text(_emergencyContactName!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF12254A))),
                            const SizedBox(height: 6),
                            const Text('Relationship',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text(_emergencyContactRelation!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF12254A))),
                            const SizedBox(height: 6),
                            const Text('Phone Number',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            InkWell(
                              onTap: () => PhoneHelper.callNumber(
                                  context, _emergencyContactPhone!),
                              child: Text(_emergencyContactPhone!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF009E8F))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Medical Summary
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.medical_services_outlined,
                                    color: Color(0xFF009E8F), size: 18),
                                SizedBox(width: 8),
                                Text('Medical Summary',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF12254A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('Allergies',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text(
                              _userProfile?.allergies.isNotEmpty == true
                                  ? _userProfile!.allergies
                                  : 'None Reported',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF12254A)),
                            ),
                            const SizedBox(height: 6),
                            const Text('Existing Conditions',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text(
                              _userProfile?.existingConditions.isNotEmpty == true
                                  ? _userProfile!.existingConditions
                                  : 'None Reported',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF12254A)),
                            ),
                            const SizedBox(height: 6),
                            const Text('Current Medications',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text(
                              _activeMedsCount > 0
                                  ? '$_activeMedsCount Active Prescriptions'
                                  : 'None Reported',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF12254A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Health Records
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.description_outlined,
                                    color: Color(0xFF2563EB), size: 18),
                                SizedBox(width: 8),
                                Text('Health Records',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF12254A))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.article_outlined,
                                      color: Color(0xFF2563EB), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '$_healthRecordsCount document(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF12254A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            InkWell(
                              onTap: () =>
                                  Navigator.pushNamed(context, AppRoutes.vault),
                              child: Row(
                                children: const [
                                  Text(
                                    'View records',
                                    style: TextStyle(
                                      color: Color(0xFF009E8F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 16, color: Color(0xFF009E8F)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Health Tip
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.eco_outlined,
                                    color: Color(0xFF16A34A), size: 18),
                                SizedBox(width: 8),
                                Text('Health Tip',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF12254A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Stay hydrated and eat balanced meals. Small, healthy choices every day make a big difference!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF009E8F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'MEDGUARD AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF12254A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Health & Emergency',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF009E8F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Nav links
          _buildDesktopNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              isActive: false,
              onTap: () => Navigator.pushNamed(context, AppRoutes.dashboard)),
          _buildDesktopNavItem(
              icon: Icons.auto_awesome_outlined,
              label: 'AI Assistant',
              isActive: false,
              onTap: () => Navigator.pushNamed(context, AppRoutes.ai)),
          _buildDesktopNavItem(
              icon: Icons.folder_outlined,
              label: 'Health Vault',
              isActive: false,
              onTap: () => Navigator.pushNamed(context, AppRoutes.vault)),
          _buildDesktopNavItem(
              icon: Icons.medication_outlined,
              label: 'Medicines',
              isActive: false,
              onTap: () => Navigator.pushNamed(context, AppRoutes.medicines)),
          _buildDesktopNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isActive: true,
              onTap: () {}),

          const Spacer(),

          // Bottom text & Emergency SOS button
          const Center(
            child: Text(
              'Better Health\nBrighter Tomorrow',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.emergency),
              icon: const Icon(Icons.emergency_rounded, size: 18),
              label: const Text('Emergency SOS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor:
            isActive ? const Color(0xFFE8FAF8) : Colors.transparent,
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF009E8F) : const Color(0xFF64748B),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF009E8F) : const Color(0xFF64748B),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBmiSegmentedBar(double currentBmi) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(4)),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: 8,
                color: const Color(0xFF009E8F),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: 8,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  borderRadius:
                      BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Underweight\n(< 18.5)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text('Normal\n(18.5 - 24.9)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text('Overweight\n(25 - 29.9)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text('Obese\n(≥ 30)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCol({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF12254A),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildWellnessMiniCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF12254A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMedInfoChip({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: Color(0xFF12254A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
