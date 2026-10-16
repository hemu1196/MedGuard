import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/utils/bmi_calculator.dart';
import '../../models/user_profile.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/gemini_service.dart';
import '../../widgets/app_header.dart';

class DietFitnessPage extends StatefulWidget {
  const DietFitnessPage({super.key});

  @override
  State<DietFitnessPage> createState() => _DietFitnessPageState();
}

class _DietFitnessPageState extends State<DietFitnessPage> {
  final ProfileRepository _profileRepo = ProfileRepository();
  final AuthRepository _authRepo = AuthRepository();
  final GeminiService _geminiService = GeminiService();

  UserProfile? _profile;
  bool _loading = true;
  String _dietFilter = 'All';
  String _selectedGoal = 'Weight Management';
  bool _isGeneratingAi = false;
  String? _customAiPlan;

  final Map<String, bool> _dailyHabits = {
    'Hydration (8+ glasses / 2.2L - 2.5L)': false,
    '2+ servings of fresh greens & vegetables': false,
    '30 minutes intentional physical movement': false,
    '7-8 hours restful restorative sleep': false,
    '5 minutes mindful breathing or relaxation': false,
  };

  final List<String> _healthGoals = [
    'Weight Management',
    'Boost Energy',
    'Heart Health',
    'Better Digestion',
    'Blood Sugar Balance',
    'Muscle Tone',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = await _authRepo.getCurrentUserId();
      if (userId.isNotEmpty) {
        final prof = await _profileRepo.getProfile(userId: userId);
        if (mounted) {
          setState(() {
            _profile = prof;
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[DIET FITNESS] Error loading profile: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  double get _heightCm {
    if (_profile == null || _profile!.height.isEmpty) return 170.0;
    return double.tryParse(_profile!.height) ?? 170.0;
  }

  double get _weightKg {
    if (_profile == null || _profile!.weight.isEmpty) return 68.0;
    return double.tryParse(_profile!.weight) ?? 68.0;
  }

  double get _bmi {
    return BmiCalculator.calculateBMI(
      heightCm: _heightCm,
      weightKg: _weightKg,
    );
  }

  String get _bmiCategory {
    return BmiCalculator.getBMICategory(_bmi);
  }

  Color get _bmiColor {
    if (_bmi <= 0) return AppColors.textSecondary;
    if (_bmi < 18.5) return Colors.blue;
    if (_bmi <= 24.9) return AppColors.success;
    if (_bmi <= 29.9) return Colors.orange;
    return AppColors.emergency;
  }

  int get _estimatedDailyCalories {
    if (_weightKg <= 0) return 2000;
    // Mifflin-St Jeor rough baseline
    final isFemale = _profile?.gender.toLowerCase() == 'female';
    double bmr = (10 * _weightKg) + (6.25 * _heightCm) - (5 * 28) + (isFemale ? -161 : 5);
    return (bmr * 1.35).round();
  }

  String get _allergiesText {
    final a = _profile?.allergies.trim() ?? '';
    if (a.isEmpty || a.toLowerCase() == 'none' || a.toLowerCase() == 'nil') {
      return '';
    }
    return a;
  }

  Future<void> _generateAiPlan() async {
    setState(() {
      _isGeneratingAi = true;
    });

    final prompt = '''
You are MedGuard AI Clinical Nutritionist. Provide a structured, tailored 1-day meal & fitness routine based on:
- User BMI: ${_bmi.toStringAsFixed(1)} ($_bmiCategory)
- Weight: ${_weightKg.round()} kg, Height: ${_heightCm.round()} cm
- Known Allergies: ${_allergiesText.isEmpty ? 'None' : _allergiesText}
- Selected Health Goal: $_selectedGoal
- Preferred Diet Style: $_dietFilter

Format your response clearly with:
1. Target Daily Intake & Calorie Breakdown
2. Tailored Breakfast, Lunch, Snack & Dinner (respecting all allergies strictly)
3. 2 Targeted Exercise Suggestions for $_selectedGoal
4. Medical Safety Reminder

Keep the tone encouraging, professional, and practical.
''';

    try {
      final response = await _geminiService.generateResponse(prompt: prompt);
      if (mounted) {
        setState(() {
          _customAiPlan = response;
          _isGeneratingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI customization notice: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(
        title: 'AI Diet & Fitness',
        subtitle: 'Personalized nutrition & healthy lifestyle guidance',
        showBack: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Wellness Overview
                    _buildSectionHeader(
                      icon: Icons.monitor_heart_outlined,
                      title: '1. Wellness Overview',
                      subtitle: 'Personal metrics synced with your profile',
                    ),
                    const SizedBox(height: 10),
                    _buildWellnessOverviewCard(),
                    const SizedBox(height: 24),

                    // SECTION 2: Today's Balanced Meals
                    _buildSectionHeader(
                      icon: Icons.restaurant_menu_rounded,
                      title: "2. Today's Balanced Meals",
                      subtitle: 'Nutrient-dense options tailored to your body',
                    ),
                    const SizedBox(height: 10),
                    _buildMealFilterChips(),
                    const SizedBox(height: 12),
                    _buildMealList(),
                    const SizedBox(height: 24),

                    // SECTION 3: Daily Nutrition Principles
                    _buildSectionHeader(
                      icon: Icons.pie_chart_outline_rounded,
                      title: '3. Daily Nutrition Principles',
                      subtitle: 'The Healthy Plate Method for balanced health',
                    ),
                    const SizedBox(height: 10),
                    _buildHealthyPlateCard(),
                    const SizedBox(height: 24),

                    // SECTION 4: Healthy Activity Suggestions
                    _buildSectionHeader(
                      icon: Icons.directions_run_rounded,
                      title: '4. Healthy Movement & Activity',
                      subtitle: 'Daily routine for vitality and metabolic health',
                    ),
                    const SizedBox(height: 10),
                    _buildActivityCards(),
                    const SizedBox(height: 24),

                    // SECTION 5: Daily Wellness Habits Checklist
                    _buildSectionHeader(
                      icon: Icons.check_circle_outline_rounded,
                      title: '5. Daily Wellness Habits',
                      subtitle: 'Check off your daily health commitments',
                    ),
                    const SizedBox(height: 10),
                    _buildHabitsChecklistCard(),
                    const SizedBox(height: 24),

                    // SECTION 6: Health Goals Focus
                    _buildSectionHeader(
                      icon: Icons.flag_outlined,
                      title: '6. General Health Goals',
                      subtitle: 'Select your focus area for contextual guidance',
                    ),
                    const SizedBox(height: 10),
                    _buildGoalsSelector(),
                    const SizedBox(height: 24),

                    // AI Tailored Plan (Optional on-demand)
                    _buildAiPlanCard(),
                    const SizedBox(height: 24),

                    // SECTION 7: Professional Guidance & Disclaimer
                    _buildSectionHeader(
                      icon: Icons.verified_user_outlined,
                      title: '7. Medical Guidance & Disclaimer',
                      subtitle: 'Important health safety principles',
                    ),
                    const SizedBox(height: 10),
                    _buildDisclaimerCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 1: Wellness Overview ---
  Widget _buildWellnessOverviewCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_allergiesText.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Allergy Alert: "$_allergiesText" is strictly excluded from all recommendations.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'BMI Status',
                    value: _bmi > 0 ? '${_bmi.toStringAsFixed(1)} - $_bmiCategory' : 'N/A',
                    valueColor: _bmiColor,
                    icon: Icons.speed_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Height & Weight',
                    value: '${_heightCm.round()} cm | ${_weightKg.round()} kg',
                    valueColor: AppColors.textPrimary,
                    icon: Icons.accessibility_new_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Target Daily Calories',
                    value: '~$estimatedDailyCalories kcal',
                    valueColor: AppColors.primary,
                    icon: Icons.local_fire_department_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Hydration Target',
                    value: '2.2L - 2.5L / day',
                    valueColor: const Color(0xFF0284C7),
                    icon: Icons.water_drop_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int get estimatedDailyCalories => _estimatedDailyCalories;

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: valueColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- SECTION 2: Meal Filter & Suggestions ---
  Widget _buildMealFilterChips() {
    final filters = ['All', 'Vegetarian', 'High-Protein', 'Low-Carb'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _dietFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (_) => setState(() => _dietFilter = f),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealList() {
    final meals = [
      {
        'tag': 'BREAKFAST (7:30 - 8:30 AM)',
        'calories': '380 kcal',
        'icon': Icons.wb_sunny_outlined,
        'title': _dietFilter == 'Vegetarian'
            ? 'Steamed Idli with Sambar & Mint Chutney'
            : _dietFilter == 'High-Protein'
                ? '3 Egg White Omelet with Spinach & Whole Grain Toast'
                : 'Rolled Oats Porridge with Chia Seeds & Almonds',
        'description': 'Complex carbohydrates and dietary fiber for sustained morning mental focus.',
        'macros': 'Carbs: 45g | Protein: 16g | Fats: 9g',
        'allergySafe': 'Dairy-free, easily digestible',
      },
      {
        'tag': 'MID-MORNING REFRESH (10:30 AM)',
        'calories': '120 kcal',
        'icon': Icons.free_breakfast_outlined,
        'title': 'Tender Coconut Water & Handful of Walnuts',
        'description': 'Natural electrolytes and omega-3 fatty acids for cellular hydration.',
        'macros': 'Carbs: 12g | Protein: 3g | Fats: 8g',
        'allergySafe': 'Gluten-free, zero processed sugars',
      },
      {
        'tag': 'LUNCH (1:00 - 2:00 PM)',
        'calories': '580 kcal',
        'icon': Icons.lunch_dining_outlined,
        'title': _dietFilter == 'Vegetarian'
            ? 'Brown Rice, Yellow Dal Tadka & Sauteed Beans'
            : _dietFilter == 'Low-Carb'
                ? 'Grilled Herb Chicken / Paneer with Large Cucumber Salad'
                : 'Quinoa Bowl with Spiced Chickpeas & Steamed Greens',
        'description': 'Balanced macronutrient plate with plant protein, micro-minerals, and healthy fats.',
        'macros': 'Carbs: 55g | Protein: 28g | Fats: 14g',
        'allergySafe': 'Naturally lactose-controlled',
      },
      {
        'tag': 'EVENING ENERGY (4:30 - 5:00 PM)',
        'calories': '150 kcal',
        'icon': Icons.coffee_outlined,
        'title': 'Sprouted Moong Salad or Roasted Makhana',
        'description': 'Crunchy, low-glycemic snack preventing late afternoon blood sugar dips.',
        'macros': 'Carbs: 18g | Protein: 8g | Fats: 2g',
        'allergySafe': 'Nut-free, light on digestion',
      },
      {
        'tag': 'DINNER (7:30 - 8:30 PM)',
        'calories': '420 kcal',
        'icon': Icons.dinner_dining_outlined,
        'title': _dietFilter == 'High-Protein'
            ? 'Baked Fish or Tofu Stir-fry with Zucchini & Broccoli'
            : 'Warm Vegetable Soup with Multi-Millet Roti',
        'description': 'Light and restorative dinner promoting deep sleep without digestive strain.',
        'macros': 'Carbs: 35g | Protein: 22g | Fats: 8g',
        'allergySafe': 'Low sodium, gut friendly',
      },
    ];

    return Column(
      children: meals.map((m) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(m['icon'] as IconData, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          m['tag'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m['calories'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  m['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['description'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.fitness_center_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      m['macros'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- SECTION 3: Nutrition Principles (The Healthy Plate) ---
  Widget _buildHealthyPlateCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Healthy Plate Composition',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    Expanded(
                      flex: 50,
                      child: Container(color: const Color(0xFF16A34A)),
                    ),
                    Expanded(
                      flex: 25,
                      child: Container(color: const Color(0xFF0284C7)),
                    ),
                    Expanded(
                      flex: 25,
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildPlateRow(
              color: const Color(0xFF16A34A),
              percentage: '50% Vegetables & Fruits',
              detail: 'Leafy greens, carrots, broccoli, and low-sugar seasonal fruits for gut fiber.',
            ),
            const SizedBox(height: 8),
            _buildPlateRow(
              color: const Color(0xFF0284C7),
              percentage: '25% Lean Protein',
              detail: 'Lentils, pulses, tofu, paneer, fish, or poultry for muscle recovery.',
            ),
            const SizedBox(height: 8),
            _buildPlateRow(
              color: const Color(0xFFF59E0B),
              percentage: '25% Complex Carbohydrates',
              detail: 'Brown rice, whole wheat, millets, oats, or sweet potatoes for continuous energy.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlateRow({
    required Color color,
    required String percentage,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
              children: [
                TextSpan(
                  text: '$percentage: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: detail,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- SECTION 4: Activity & Movement ---
  Widget _buildActivityCards() {
    final activities = [
      {
        'title': 'Morning Mobility & Stretching',
        'duration': '15-20 min',
        'intensity': 'Light',
        'icon': Icons.self_improvement_rounded,
        'description': 'Gentle neck, shoulder, and spinal rolls with deep diaphragmatic breaths.',
      },
      {
        'title': 'Brisk Walking / Cardio',
        'duration': '30-40 min',
        'intensity': 'Moderate',
        'icon': Icons.directions_walk_rounded,
        'description': 'Elevates heart rate, improves endothelial function, and burns ~180-250 kcal.',
      },
      {
        'title': 'Functional Bodyweight Strength',
        'duration': '15 min',
        'intensity': 'Moderate-High',
        'icon': Icons.fitness_center_rounded,
        'description': 'Chair squats, wall push-ups, and core bird-dogs to maintain bone density.',
      },
      {
        'title': 'Post-Meal Digestive Stroll',
        'duration': '10 min',
        'intensity': 'Gentle',
        'icon': Icons.nordic_walking_rounded,
        'description': 'A brief walk 15 min after main meals significantly stabilizes glucose spikes.',
      },
    ];

    return Column(
      children: activities.map((a) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a['icon'] as IconData, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              a['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              a['duration'] as String,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a['description'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- SECTION 5: Daily Habits Checklist ---
  Widget _buildHabitsChecklistCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: _dailyHabits.entries.map((entry) {
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: entry.value ? FontWeight.w600 : FontWeight.normal,
                  decoration: entry.value ? TextDecoration.lineThrough : null,
                  color: entry.value ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
              value: entry.value,
              onChanged: (val) {
                setState(() {
                  _dailyHabits[entry.key] = val ?? false;
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- SECTION 6: Health Goals Focus ---
  Widget _buildGoalsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _healthGoals.map((g) {
            final isSelected = _selectedGoal == g;
            return ChoiceChip(
              label: Text(g),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedGoal = g),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCFCE7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getGoalGuidance(_selectedGoal),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getGoalGuidance(String goal) {
    switch (goal) {
      case 'Weight Management':
        return 'Focus on caloric awareness, whole food volume, high dietary fiber, and adequate protein to sustain satiety without rapid insulin spikes.';
      case 'Boost Energy':
        return 'Avoid high-glycemic sugar spikes. Pair complex carbohydrates with healthy plant fats, stay hydrated with 2.5L water, and take short movement breaks.';
      case 'Heart Health':
        return 'Prioritize monounsaturated fats (extra virgin olive oil, nuts, seeds), eliminate trans fats, restrict sodium below 2,000 mg, and walk 30 minutes daily.';
      case 'Better Digestion':
        return 'Incorporate naturally fermented foods (curd, kefir), chew food thoroughly in a relaxed posture, and space meals 3-4 hours apart.';
      case 'Blood Sugar Balance':
        return 'Eat fiber and vegetables before carbohydrates, walk 10 minutes following each meal, and replace refined grains with barley, oats, or quinoa.';
      case 'Muscle Tone':
        return 'Target 1.2g - 1.6g of quality protein per kg of body weight, paired with resistance training exercises 3 times per week.';
      default:
        return 'Balanced nutrition, mindful eating, and regular physical movement form the foundation of lifelong health.';
    }
  }

  // --- Optional AI Tailored Plan ---
  Widget _buildAiPlanCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9333EA), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MedGuard AI Personalized Plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Synthesize a custom routine with your medical profile',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isGeneratingAi ? null : _generateAiPlan,
                icon: _isGeneratingAi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isGeneratingAi ? 'Analyzing Profile & Generating...' : 'Personalize with AI',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            if (_customAiPlan != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SelectableText(
                  _customAiPlan!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- SECTION 7: Medical Guidance & Disclaimer ---
  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF475569)),
              SizedBox(width: 8),
              Text(
                'Clinical Safety Principles & Disclaimer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The diet, nutrition, and exercise recommendations in MEDGUARD are provided strictly for general wellness education. They do not constitute formal medical diagnoses or prescriptions. Individuals with diabetes, hypertension, cardiovascular conditions, kidney disorders, eating disorders, or those who are pregnant or nursing should consult their primary physician or a licensed clinical nutritionist before making substantial dietary or exercise changes.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
