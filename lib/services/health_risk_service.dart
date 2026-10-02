import '../models/health_risk_assessment.dart';
import '../models/user_profile.dart';

class HealthRiskService {
  Future<HealthRiskAssessment> calculateRisk(UserProfile? profile) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (profile == null || profile.name.isEmpty) {
      return HealthRiskAssessment(
        overallScore: 78,
        riskCategory: 'Low',
        heartRiskPercent: 12.0,
        diabetesRiskPercent: 15.0,
        obesityRiskPercent: 18.0,
        bmi: 22.5,
        bmiCategory: 'Normal Weight',
        recommendations: [
          'Complete your health profile for personalized risk analysis.',
          'Maintain 150 minutes of moderate aerobic exercise per week.',
          'Schedule annual preventive health checkups.',
        ],
      );
    }

    double heightM = double.tryParse(profile.height) ?? 170.0;
    if (heightM > 3) heightM = heightM / 100.0; // convert cm to m
    double weightKg = double.tryParse(profile.weight) ?? 70.0;

    double bmi = weightKg / (heightM * heightM);
    if (bmi.isNaN || bmi.isInfinite || bmi <= 0) bmi = 23.0;

    String bmiCat = 'Normal Weight';
    double obesityRisk = 15.0;
    if (bmi < 18.5) {
      bmiCat = 'Underweight';
      obesityRisk = 5.0;
    } else if (bmi >= 25 && bmi < 30) {
      bmiCat = 'Overweight';
      obesityRisk = 45.0;
    } else if (bmi >= 30) {
      bmiCat = 'Obese';
      obesityRisk = 75.0;
    }

    final age = profile.age;
    double heartRisk = (age * 0.4) + (obesityRisk * 0.3);
    if (profile.existingConditions.toLowerCase().contains('hypertension') ||
        profile.existingConditions.toLowerCase().contains('bp')) {
      heartRisk += 25.0;
    }

    double diabetesRisk = (age * 0.3) + (obesityRisk * 0.4);
    if (profile.existingConditions.toLowerCase().contains('diabetes')) {
      diabetesRisk += 35.0;
    }

    heartRisk = heartRisk.clamp(5.0, 95.0);
    diabetesRisk = diabetesRisk.clamp(5.0, 95.0);

    int overallScore =
        (100 - (heartRisk * 0.4 + diabetesRisk * 0.4 + obesityRisk * 0.2))
            .round();
    overallScore = overallScore.clamp(10, 98);

    String category = 'Low';
    if (overallScore < 60) {
      category = 'High';
    } else if (overallScore < 80) {
      category = 'Moderate';
    }

    final List<String> tips = [];
    if (obesityRisk > 30) {
      tips.add(
        'Incorporate 30 minutes of daily brisk walking to reach healthy BMI target.',
      );
    }
    if (heartRisk > 30) {
      tips.add(
        'Reduce dietary sodium intake and monitor blood pressure weekly.',
      );
    }
    if (diabetesRisk > 30) {
      tips.add('Limit refined sugars and processed carbohydrates.');
    }
    if (tips.isEmpty) {
      tips.add(
        'Maintain your current healthy lifestyle and regular hydration.',
      );
      tips.add(
        'Schedule routine blood sugar and cholesterol screenings once a year.',
      );
    }

    return HealthRiskAssessment(
      overallScore: overallScore,
      riskCategory: category,
      heartRiskPercent: heartRisk,
      diabetesRiskPercent: diabetesRisk,
      obesityRiskPercent: obesityRisk,
      bmi: double.parse(bmi.toStringAsFixed(1)),
      bmiCategory: bmiCat,
      recommendations: tips,
    );
  }
}
