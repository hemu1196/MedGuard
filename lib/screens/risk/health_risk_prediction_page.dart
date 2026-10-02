import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/health_risk_assessment.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/health_risk_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class HealthRiskPredictionPage extends StatefulWidget {
  const HealthRiskPredictionPage({super.key});

  @override
  State<HealthRiskPredictionPage> createState() =>
      _HealthRiskPredictionPageState();
}

class _HealthRiskPredictionPageState extends State<HealthRiskPredictionPage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthRepository _authRepository = AuthRepository();
  final HealthRiskService _riskService = HealthRiskService();

  HealthRiskAssessment? _assessment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  void _loadAssessment() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final profile = await _profileRepository.getProfile(userId: userId);
    final result = await _riskService.calculateRisk(profile);
    if (mounted) {
      setState(() {
        _assessment = result;
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String category) {
    switch (category) {
      case 'Low':
        return AppColors.success;
      case 'Moderate':
        return AppColors.warning;
      case 'High':
      default:
        return AppColors.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Health Risk Prediction',
        subtitle: 'Informational risk estimates & health score',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Calculating Health Risk Score...')
            : _assessment == null
            ? const Center(child: Text('Unable to calculate risk score.'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informational Disclaimer Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade900,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _assessment!.disclaimer,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Score & Category Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text(
                              'Overall Health Score',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value: _assessment!.overallScore / 100,
                                    strokeWidth: 12,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation(
                                      _getRiskColor(_assessment!.riskCategory),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_assessment!.overallScore}',
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      '/ 100',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getRiskColor(
                                  _assessment!.riskCategory,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_assessment!.riskCategory} Risk Level',
                                style: TextStyle(
                                  color: _getRiskColor(
                                    _assessment!.riskCategory,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Specific Risk Indicators',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Risk Breakdown Cards
                    _buildRiskIndicatorTile(
                      'Heart Disease Risk',
                      '${_assessment!.heartRiskPercent.toStringAsFixed(1)}%',
                      _assessment!.heartRiskPercent / 100,
                      Icons.favorite_outline,
                      AppColors.emergency,
                    ),
                    _buildRiskIndicatorTile(
                      'Diabetes Risk',
                      '${_assessment!.diabetesRiskPercent.toStringAsFixed(1)}%',
                      _assessment!.diabetesRiskPercent / 100,
                      Icons.water_drop_outlined,
                      AppColors.secondary,
                    ),
                    _buildRiskIndicatorTile(
                      'Obesity Risk (BMI: ${_assessment!.bmi} - ${_assessment!.bmiCategory})',
                      '${_assessment!.obesityRiskPercent.toStringAsFixed(1)}%',
                      _assessment!.obesityRiskPercent / 100,
                      Icons.monitor_weight_outlined,
                      AppColors.warning,
                    ),
                    const SizedBox(height: 24),

                    // Action Plan Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.auto_graph_rounded,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Improve Your Score',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            ..._assessment!.recommendations.map(
                              (tip) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tip,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRiskIndicatorTile(
    String label,
    String valueText,
    double progress,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  valueText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
