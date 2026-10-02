import 'package:flutter/material.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Skeleton
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),

          // SOS Card Skeleton
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Actions Skeleton Header
          Container(
            height: 20,
            width: 140,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Actions Grid Skeleton
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: List.generate(
              8,
              (index) => Container(
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Health Overview Cards Skeleton
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 110,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
