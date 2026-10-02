class BmiResult {
  final double bmi;
  final String category;
  final String guidance;
  final String note;
  final String disclaimer;
  final bool isUnder18;

  const BmiResult({
    required this.bmi,
    required this.category,
    required this.guidance,
    required this.note,
    required this.disclaimer,
    this.isUnder18 = false,
  });
}

class BmiCalculator {
  static const String disclaimerText =
      'BMI is a general screening measurement based on height and weight. '
      'It does not diagnose health conditions. Consider discussing your overall health goals with a qualified healthcare professional.';

  /// Calculates BMI given height in cm and weight in kg.
  /// Returns 0.0 if inputs are invalid (<= 0).
  static double calculateBMI({required double heightCm, required double weightKg}) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightMeters = heightCm / 100.0;
    final bmiVal = weightKg / (heightMeters * heightMeters);
    return double.parse(bmiVal.toStringAsFixed(1));
  }

  /// Determines adult BMI reference category string.
  static String getBMICategory(double bmi, {int age = 25}) {
    if (age > 0 && age < 18) {
      return 'Pediatric / Under 18';
    }
    if (bmi <= 0) return 'Not Available';
    if (bmi < 18.5) {
      return 'Underweight';
    } else if (bmi <= 24.9) {
      return 'Normal range';
    } else if (bmi <= 29.9) {
      return 'Overweight';
    } else {
      return 'Obesity';
    }
  }

  /// Provides health guidance based on BMI category.
  static String getBMIGuidance(double bmi, {int age = 25}) {
    if (age > 0 && age < 18) {
      return 'Adult BMI categories are not intended for users under 18.';
    }
    if (bmi <= 0) {
      return 'Please enter valid height and weight to calculate your BMI overview.';
    }
    if (bmi < 18.5) {
      return 'Your BMI is below the standard adult range. Focus on balanced, nutrient-dense meals and consider discussing your weight with a qualified healthcare professional.';
    } else if (bmi <= 24.9) {
      return 'Your BMI is within the standard adult range. Continue maintaining balanced nutrition, regular physical activity, adequate sleep, and healthy hydration.';
    } else if (bmi <= 29.9) {
      return 'Your BMI is above the standard adult range. Focus on balanced nutrition and regular physical activity, and consider discussing personalized goals with a healthcare professional.';
    } else {
      return 'Your BMI is in the obesity range according to standard adult BMI categories. Consider discussing your overall health and personalized goals with a qualified healthcare professional.';
    }
  }

  /// Full BMI evaluation object.
  static BmiResult evaluate({
    required double heightCm,
    required double weightKg,
    int age = 25,
  }) {
    final bmi = calculateBMI(heightCm: heightCm, weightKg: weightKg);
    final isUnder18 = age > 0 && age < 18;
    final note = isUnder18
        ? 'Adult BMI categories are not intended for users under 18.'
        : 'Based on your entered height and weight.';

    return BmiResult(
      bmi: bmi,
      category: getBMICategory(bmi, age: age),
      guidance: getBMIGuidance(bmi, age: age),
      note: note,
      disclaimer: disclaimerText,
      isUnder18: isUnder18,
    );
  }
}
