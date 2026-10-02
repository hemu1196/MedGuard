import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/water_intake.dart';
import '../../repositories/auth_repository.dart';
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

  DailyWaterIntake? _intake;
  bool _isLoading = true;
  bool _isAddingWater = false;

  @override
  void initState() {
    super.initState();
    _loadIntake();
  }

  void _loadIntake() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final data = await _waterRepository.getTodayWaterIntake(userId: userId);
    if (mounted) {
      setState(() {
        _intake = data;
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
          content: Text('$amountMl ml water added successfully.'),
          duration: const Duration(seconds: 2),
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
          content: Text('Today\'s water intake has been reset.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditGoalDialog() {
    final targetController = TextEditingController(
      text: '${_intake?.targetMl ?? 2000}',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Daily Hydration Goal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Daily Goal (ml) *',
                    hintText: 'e.g. 2000',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recommended daily goal typically ranges between 1500 ml to 3500 ml.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final val = int.tryParse(targetController.text.trim());
                  if (val == null || val <= 0 || val > 10000) {
                    setDialogState(() {
                      errorText =
                          'Please enter a valid positive volume (1-10000 ml)';
                    });
                    return;
                  }
                  Navigator.of(context).pop();
                  final userId = await _authRepository.getCurrentUserId();
                  final updated = await _waterRepository.updateTarget(
                    val,
                    userId: userId,
                  );
                  if (mounted) {
                    setState(() => _intake = updated);
                  }
                },
                child: const Text('Save Goal'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomDialog() {
    final customController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Custom Water Intake'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Volume (ml) *',
                    hintText: 'e.g. 350',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(customController.text.trim());
                  if (val == null || val <= 0 || val > 10000) {
                    setDialogState(() {
                      errorText = 'Please enter a valid positive amount (1-10000 ml)';
                    });
                    return;
                  }
                  Navigator.of(context).pop();
                  _addWater(val);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getHydrationSuggestion(double ratio) {
    final percentage = (ratio * 100).round();
    if (percentage <= 25) {
      return 'Your intake is still low today. Consider drinking water regularly.';
    } else if (percentage <= 60) {
      return 'Good progress. Continue taking water regularly throughout the day.';
    } else if (percentage < 100) {
      return 'You\'re close to today\'s target. Keep maintaining regular hydration.';
    } else {
      return 'You\'ve reached today\'s hydration target.';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final remainingMl = (_intake != null)
        ? (_intake!.targetMl - _intake!.currentMl).clamp(0, 100000)
        : 0;

    final presetVolumes = [200, 300, 400, 500, 600, 700, 800];

    return Scaffold(
      appBar: const AppHeader(
        title: 'Smart Water Intake',
        subtitle: 'Daily hydration progress & target',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading Hydration Data...')
            : _intake == null
                ? const Center(child: Text('Unable to load water intake.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Progress Ring Card
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 160,
                                          height: 160,
                                          child: CircularProgressIndicator(
                                            value: _intake!.progressRatio,
                                            strokeWidth: 14,
                                            backgroundColor: AppColors.accent
                                                .withValues(alpha: 0.15),
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                              AppColors.accent,
                                            ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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

                            // Hydration Summary Stats Card
                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatTile(
                                      'Daily Goal',
                                      '${_intake!.targetMl} ml',
                                    ),
                                    _buildStatTile(
                                      'Consumed',
                                      '${_intake!.currentMl} ml',
                                    ),
                                    _buildStatTile('Remaining', '$remainingMl ml'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Intake Presets Section (200 ml to 800 ml)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Hydration Presets (200 ml – 800 ml)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: presetVolumes.map((vol) {
                                return ActionChip(
                                  avatar: const Icon(
                                    Icons.local_drink_rounded,
                                    size: 16,
                                    color: AppColors.accent,
                                  ),
                                  label: Text(
                                    '+$vol ml',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  backgroundColor: AppColors.accent
                                      .withValues(alpha: 0.12),
                                  onPressed: () => _addWater(vol),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Custom and Reset Controls
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showCustomDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Custom Volume'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _confirmAndResetWater,
                                    icon: const Icon(
                                      Icons.restart_alt,
                                      color: AppColors.emergency,
                                    ),
                                    label: const Text('Reset Today'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.emergency,
                                      ),
                                      foregroundColor: AppColors.emergency,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Dynamic Hydration Guidance
                            Card(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.tips_and_updates_outlined,
                                          color: AppColors.secondary,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Hydration Guidance',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _getHydrationSuggestion(
                                        _intake!.progressRatio,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Today's Intake History Section
                            _buildHistorySection(),
                            const SizedBox(height: 20),

                            // Disclaimer Notice
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hydration needs vary by individual, activity, climate, pregnancy and medical conditions. Consult healthcare professionals if under fluid restrictions.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  final timeStr = _formatTime(log.timestamp);
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

