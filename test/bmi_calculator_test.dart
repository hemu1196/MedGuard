import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/core/utils/bmi_calculator.dart';

void main() {
  group('BmiCalculator Tests', () {
    test('Calculates BMI accurately for 168 cm and 50 kg', () {
      final bmi = BmiCalculator.calculateBMI(heightCm: 168, weightKg: 50);
      expect(bmi, equals(17.7));
    });

    test('Calculates BMI accurately for 174 cm and 52 kg', () {
      final bmi = BmiCalculator.calculateBMI(heightCm: 174, weightKg: 52);
      expect(bmi, equals(17.2));
    });

    test('Calculates BMI accurately for 175 cm and 70 kg', () {
      final bmi = BmiCalculator.calculateBMI(heightCm: 175, weightKg: 70);
      expect(bmi, equals(22.9));
    });

    test('Handles invalid zero/negative inputs gracefully', () {
      expect(BmiCalculator.calculateBMI(heightCm: 0, weightKg: 50), equals(0.0));
      expect(BmiCalculator.calculateBMI(heightCm: 170, weightKg: -10), equals(0.0));
    });

    test('Categorizes adult BMI values correctly', () {
      expect(BmiCalculator.getBMICategory(17.2), equals('Underweight'));
      expect(BmiCalculator.getBMICategory(22.0), equals('Normal range'));
      expect(BmiCalculator.getBMICategory(27.5), equals('Overweight'));
      expect(BmiCalculator.getBMICategory(32.0), equals('Obesity'));
    });

    test('Handles under 18 pediatric warning note', () {
      final res = BmiCalculator.evaluate(heightCm: 160, weightKg: 45, age: 16);
      expect(res.isUnder18, isTrue);
      expect(res.note, equals('Adult BMI categories are not intended for users under 18.'));
    });

    test('Provides exact Health Insight suggestions based on category', () {
      final underweightGuidance = BmiCalculator.getBMIGuidance(17.2, age: 25);
      expect(underweightGuidance, contains('Focus on balanced, nutrient-dense meals'));

      final normalGuidance = BmiCalculator.getBMIGuidance(22.0, age: 25);
      expect(normalGuidance, contains('Continue maintaining balanced nutrition'));

      final overweightGuidance = BmiCalculator.getBMIGuidance(27.5, age: 25);
      expect(overweightGuidance, contains('Focus on balanced nutrition and regular physical activity'));

      final obesityGuidance = BmiCalculator.getBMIGuidance(33.0, age: 25);
      expect(obesityGuidance, contains('obesity range'));
    });

    test('Evaluate returns complete BmiResult', () {
      final res = BmiCalculator.evaluate(heightCm: 174, weightKg: 52, age: 25);
      expect(res.bmi, equals(17.2));
      expect(res.category, equals('Underweight'));
      expect(res.note, equals('Based on your entered height and weight.'));
    });
  });
}
