import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../core/utils/hydration_advisor.dart';
import '../../models/user_profile.dart';
import '../../models/water_intake.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/water_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class WaterIntakePage extends StatefulWidget {
  const WaterIntakePage({super.key});

  @override
  State<WaterIntakePage> createState() => _WaterIntakePageState();
}

class _WaterIntakePageState extends State<WaterIntakePage> {
  final WaterRepository _waterRepository = WaterRepository();
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  DailyWaterIntake? _intake;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isAddingWater = false;

  ActivityLevel _activityLevel = ActivityLevel.moderate;
  int? _clinicianFluidLimit;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final data = await _waterRepository.getTodayWaterIntake(userId: userId);
    final profile = await _profileRepository.getProfile(userId: userId);
    if (mounted) {
      setState(() {
        _intake = data;
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  void _addWater(int amountMl) async {
    if (_isAddingWater) return;
    _isAddingWater = true;
    final userId = await _authRepository.getCurrentUserId();
    final updated = await _waterRepository.addWater(amountMl, userId: userId);
    if (mounted) {
      setState(() {
        _intake = updated;
        _isAddingWater = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$amountMl ml water logged successfully.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _undoWater() async {
    final userId = await _authRepository.getCurrentUserId();
    final updated = await _waterRepository.undoLastWaterLog(userId: userId);
    if (mounted) {
      setState(() {
        _intake = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Last water intake entry undone.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmAndResetWater() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Reset Today\'s Water'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset today\'s water intake records? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetWater();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _resetWater() async {
    final userId = await _authRepository.getCurrentUserId();
    final reset = await _waterRepository.resetWater(userId: userId);
    if (mounted) {
      setState(() {
        _intake = reset;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Today\'s water intake reset to 0 ml.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCustomDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Water Volume'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter amount in ml (e.g. 350)',
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0 && val <= 2000) {
                Navigator.pop(context);
                _addWater(val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid volume between 10 and 2000 ml'),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog() {
    final controller = TextEditingController(text: '${_intake?.targetMl ?? 2000}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Daily Fluid Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 2500',
                suffixText: 'ml',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recommended range: 1400 ml to 3800 ml.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 500 && val <= 6000) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final userId = await _authRepository.getCurrentUserId();
                final updated = await _waterRepository.updateTarget(val, userId: userId);
                if (mounted) {
                  setState(() => _intake = updated);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Daily target updated to $val ml ✓')),
                  );
                }
              }
            },
            child: const Text('Save Target'),
          ),
        ],
      ),
    );
  }

  void _showClinicianLimitDialog() {
    final controller = TextEditingController(
      text: _clinicianFluidLimit != null ? '$_clinicianFluidLimit' : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medical_services_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Clinician Fluid Limit', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If your doctor or cardiologist has placed you on an explicit daily fluid restriction (e.g. for heart failure or renal conditions), enter it here. This will override all general guidance.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prescribed Fluid Limit',
                hintText: 'e.g. 1500',
                suffixText: 'ml/day',
              ),
            ),
          ],
        ),
        actions: [
          if (_clinicianFluidLimit != null)
            TextButton(
              onPressed: () {
                setState(() => _clinicianFluidLimit = null);
                Navigator.pop(context);
              },
              child: const Text('Clear Limit', style: TextStyle(color: AppColors.emergency)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                setState(() => _clinicianFluidLimit = val);
                Navigator.pop(context);
                final userId = await _authRepository.getCurrentUserId();
                final updated = await _waterRepository.updateTarget(val, userId: userId);
                if (mounted) setState(() => _intake = updated);
              }
            },
            child: const Text('Apply Limit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingMl = _intake != null
        ? (_intake!.targetMl - _intake!.currentMl).clamp(0, _intake!.targetMl)
        : 0;

    const presetVolumes = [200, 250, 300, 500];

    // Compute personalized hydration guidance
    final userWeight = double.tryParse(_userProfile?.weight ?? '') ?? 68.0;
    final userAge = _userProfile?.age ?? 25;
    final guidance = HydrationAdvisor.calculateGuidance(
      weightKg: userWeight,
      age: userAge,
      activity: _activityLevel,
      clinicianFluidLimitMl: _clinicianFluidLimit,
    );

    return Scaffold(
      appBar: const AppHeader(
        title: 'Hydration & Health Dashboard',
        subtitle: 'Personalized fluid tracking & BMI overview',
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading hydration dashboard...')
            : _intake == null
                ? const Center(child: Text('Unable to load hydration data.'))
                : RefreshIndicator(
                    onRefresh: () async => _loadData(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // 1. Personalized BMI Card
                          _buildBmiCard(),
                          const SizedBox(height: 16),

                          // 2. Personalized Hydration Guidance Card
                          _buildGuidanceCard(guidance),
                          const SizedBox(height: 16),

                          // 3. Circular Daily Progress Card
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24.0,
                                horizontal: 16.0,
                              ),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 170,
                                        height: 170,
                                        child: CircularProgressIndicator(
                                          value: _intake!.progressRatio,
                                          strokeWidth: 14,
                                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          const Icon(
                                            Icons.water_drop_rounded,
                                            size: 36,
                                            color: AppColors.accent,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_intake!.currentMl}',
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'of ${_intake!.targetMl} ml',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${(_intake!.progressRatio * 100).round()}% Completed',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: _showEditGoalDialog,
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit Goal'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Hydration Stats Card
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatTile('Daily Goal', '${_intake!.targetMl} ml'),
                                  _buildStatTile('Consumed', '${_intake!.currentMl} ml'),
                                  _buildStatTile('Remaining', '$remainingMl ml'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 5. Intake Presets Section
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Quick Add Water:',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: presetVolumes.map((vol) {
                              return ActionChip(
                                avatar: const Icon(Icons.local_drink_rounded, size: 16, color: AppColors.accent),
                                label: Text(
                                  '+$vol ml',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                                onPressed: () => _addWater(vol),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // 6. Action Controls: Custom, Undo, and Reset
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showCustomDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Custom'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_intake?.logs.isNotEmpty ?? false) ? _undoWater : null,
                                  icon: const Icon(Icons.undo, size: 16),
                                  label: const Text('Undo Last'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _confirmAndResetWater,
                                  icon: const Icon(Icons.restart_alt, color: AppColors.emergency, size: 16),
                                  label: const Text('Reset', style: TextStyle(color: AppColors.emergency)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.emergency),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 7. Today's Intake History Section
                          _buildHistorySection(),
                          const SizedBox(height: 20),

                          // 8. Informational Medical Disclaimer
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    HydrationAdvisor.disclaimerText,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBmiCard() {
    final height = double.tryParse(_userProfile?.height ?? '') ?? 170.0;
    final weight = double.tryParse(_userProfile?.weight ?? '') ?? 68.0;
    final age = _userProfile?.age ?? 25;
    final bmiRes = BmiCalculator.evaluate(heightCm: height, weightKg: weight, age: age);

    Color badgeColor = AppColors.success;
    if (bmiRes.category.contains('Underweight')) {
      badgeColor = Colors.orange;
    } else if (bmiRes.category.contains('Overweight')) {
      badgeColor = Colors.deepOrange;
    } else if (bmiRes.category.contains('Obese') || bmiRes.category.contains('Obesity')) {
      badgeColor = AppColors.emergency;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Personal BMI Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bmiRes.category,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${bmiRes.bmi}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                const Text('kg/m²', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const Spacer(),
                Text(
                  'Height: ${height.round()} cm • Weight: ${weight.round()} kg',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'BMI is a screening metric based on height & weight, not a medical diagnosis.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCard(HydrationGuidance guidance) {
    return Card(
      color: AppColors.accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    const Icon(Icons.tips_and_updates_outlined, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      guidance.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _showClinicianLimitDialog,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(
                    _clinicianFluidLimit != null ? 'Edit Limit' : 'Set Doctor Limit',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              guidance.explanation,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Activity Level: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ChoiceChip(
                  label: const Text('Sedentary', style: TextStyle(fontSize: 10)),
                  selected: _activityLevel == ActivityLevel.sedentary,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) => setState(() => _activityLevel = ActivityLevel.sedentary),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Moderate', style: TextStyle(fontSize: 10)),
                  selected: _activityLevel == ActivityLevel.moderate,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) => setState(() => _activityLevel = ActivityLevel.moderate),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Active', style: TextStyle(fontSize: 10)),
                  selected: _activityLevel == ActivityLevel.active,
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) => setState(() => _activityLevel = ActivityLevel.active),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final userId = await _authRepository.getCurrentUserId();
                  final updated = await _waterRepository.updateTarget(
                    guidance.recommendedFluidMl,
                    userId: userId,
                  );
                  if (mounted) {
                    setState(() => _intake = updated);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Target set to ${guidance.recommendedFluidMl} ml ✓'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 14),
                label: Text('Use ${guidance.recommendedFluidMl} ml as Goal', style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final logs = _intake?.logs ?? [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Icon(Icons.history_rounded, color: AppTheme.primaryTeal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Today\'s Intake History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${logs.length} ${logs.length == 1 ? "entry" : "entries"}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const Divider(height: 20),
            if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No water intake recorded today.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 40),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final timeStr = DateFormat('hh:mm a').format(log.timestamp);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(
                      '${log.amountMl} ml',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
