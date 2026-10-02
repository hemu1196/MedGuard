import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/app_header.dart';

class MentalWellnessPage extends StatelessWidget {
  const MentalWellnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Mental Wellness',
        subtitle: 'Guided breathing, mood check-in & stress support',
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
                        Icons.self_improvement,
                        size: 44,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mindfulness & Daily Mood Check',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Guided 4-7-8 breathing exercises, anxiety support tools, and daily mood tracking.',
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
                                  'Starting 2-minute guided breathing session...',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.air),
                          label: const Text('Start Guided Breathing'),
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
