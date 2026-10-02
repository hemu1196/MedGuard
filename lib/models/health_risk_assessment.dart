class HealthRiskAssessment {
  final int overallScore; // 0 (Extremely High Risk) to 100 (Optimal Health)
  final String riskCategory; // Low, Moderate, High
  final double heartRiskPercent;
  final double diabetesRiskPercent;
  final double obesityRiskPercent;
  final double bmi;
  final String bmiCategory;
  final List<String> recommendations;
  final String disclaimer;

  HealthRiskAssessment({
    required this.overallScore,
    required this.riskCategory,
    required this.heartRiskPercent,
    required this.diabetesRiskPercent,
    required this.obesityRiskPercent,
    required this.bmi,
    required this.bmiCategory,
    required this.recommendations,
    this.disclaimer =
        'Informational Estimate Only: This risk score is calculated based on self-reported health attributes and does not constitute a formal clinical diagnosis.',
  });
}
