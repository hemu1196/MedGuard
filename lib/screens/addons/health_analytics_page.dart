import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/app_header.dart';

class HealthAnalyticsPage extends StatelessWidget {
  const HealthAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Health Insights & Analytics',
        subtitle: 'Longitudinal health trends & record statistics',
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
                        Icons.analytics_outlined,
                        size: 44,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Longitudinal Health Trends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Analyze blood pressure, cholesterol, glucose level trends over time from your Health Vault.',
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
                                  'Exporting Health Analytics Report...',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export Analytics PDF Report'),
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
