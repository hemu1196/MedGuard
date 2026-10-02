import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/app_header.dart';

class DietFitnessPage extends StatelessWidget {
  const DietFitnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'AI Diet & Fitness',
        subtitle: 'Personalized nutrition & workout recommendations',
        showBack: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        size: 44,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tailored Nutrition & Exercise',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI recommendations tailored to your BMI, allergies, and existing medical conditions.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Generating personalized meal plan based on profile...',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Meal Plan'),
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
}
