enum ActivityLevel { sedentary, moderate, active }
enum ClimateContext { temperate, hotHumid }

class HydrationGuidance {
  final int recommendedFluidMl; // From drinking fluids (~80%)
  final int totalWaterMl; // Total fluid including moisture in food (~100%)
  final String title;
  final String explanation;
  final bool isClinicianRestricted;
  final String disclaimer;

  const HydrationGuidance({
    required this.recommendedFluidMl,
    required this.totalWaterMl,
    required this.title,
    required this.explanation,
    required this.isClinicianRestricted,
    required this.disclaimer,
  });
}

class HydrationAdvisor {
  static const String disclaimerText =
      'Personalized fluid targets are evidence-informed general estimates, not a clinical prescription. '
      'Individual fluid requirements vary based on kidney health, cardiovascular condition, medications, and perspiration.';

  /// Calculates tailored hydration guidance taking into account weight, age group,
  /// activity level, climate, and prioritizing clinician fluid limits.
  static HydrationGuidance calculateGuidance({
    required double weightKg,
    int? age,
    ActivityLevel activity = ActivityLevel.moderate,
    ClimateContext climate = ClimateContext.temperate,
    int? clinicianFluidLimitMl, // Strictly overrides if specified!
  }) {
    // 1. Strict Priority: Clinician-prescribed restriction
    if (clinicianFluidLimitMl != null && clinicianFluidLimitMl > 0) {
      return HydrationGuidance(
        recommendedFluidMl: clinicianFluidLimitMl,
        totalWaterMl: (clinicianFluidLimitMl / 0.8).round(),
        title: 'Clinician Prescribed Fluid Limit',
        explanation:
            'Your healthcare provider has placed an explicit fluid restriction of $clinicianFluidLimitMl ml/day. '
            'This medical directive takes strict clinical precedence over general calculations.',
        isClinicianRestricted: true,
        disclaimer: disclaimerText,
      );
    }

    // 2. Weight and Age Baseline Calculation (~30-35 ml per kg for healthy adults)
    double baseMlPerKg = 35.0;
    if (age != null && age >= 65) {
      baseMlPerKg = 30.0; // Older adults have altered fluid balance and renal reserve
    } else if (age != null && age < 18) {
      baseMlPerKg = 40.0;
    }

    final effectiveWeight = weightKg > 0 ? weightKg : 65.0;
    double totalEstMl = effectiveWeight * baseMlPerKg;

    // 3. Activity adjustment
    if (activity == ActivityLevel.sedentary) {
      totalEstMl -= 200;
    } else if (activity == ActivityLevel.active) {
      totalEstMl += 450;
    }

    // 4. Climate adjustment
    if (climate == ClimateContext.hotHumid) {
      totalEstMl += 300;
    }

    // Clamp safe healthy range (1400 ml to 3800 ml)
    final clampedTotal = totalEstMl.clamp(1400.0, 3800.0).round();
    // 80% from beverages/drinking water, 20% from food moisture
    final beverageFluidTarget = ((clampedTotal * 0.8) / 50).round() * 50;

    return HydrationGuidance(
      recommendedFluidMl: beverageFluidTarget,
      totalWaterMl: clampedTotal,
      title: 'Personalized Hydration Estimate',
      explanation:
          'Based on weight (${effectiveWeight.round()} kg), ${activity.name} activity, and climate. '
          '~80% ($beverageFluidTarget ml) from beverages, ~20% from dietary food moisture.',
      isClinicianRestricted: false,
      disclaimer: disclaimerText,
    );
  }
}
