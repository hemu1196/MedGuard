import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/user_profile.dart';
import 'bmi_summary_dialog.dart';

class HealthOverviewCard extends StatelessWidget {
  final int recordsCount;
  final int activeMedicinesCount;
  final UserProfile? userProfile;
  final Function(int)? onNavigateTab;

  const HealthOverviewCard({
    super.key,
    required this.recordsCount,
    required this.activeMedicinesCount,
    this.userProfile,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final bmi = userProfile?.bmi ?? 0.0;
    final category = userProfile?.bmiCategory ?? 'Not Set';

    Color categoryBgColor;
    Color categoryTextColor;

    if (bmi <= 0) {
      categoryBgColor = const Color(0xFFF1F5F9);
      categoryTextColor = const Color(0xFF64748B);
    } else if (bmi < 18.5) {
      categoryBgColor = const Color(0xFFFEF3C7);
      categoryTextColor = const Color(0xFFD97706);
    } else if (bmi <= 24.9) {
      categoryBgColor = const Color(0xFFDCFCE7);
      categoryTextColor = const Color(0xFF16A34A);
    } else if (bmi <= 29.9) {
      categoryBgColor = const Color(0xFFFED7AA);
      categoryTextColor = const Color(0xFFEA580C);
    } else {
      categoryBgColor = const Color(0xFFFEE2E2);
      categoryTextColor = const Color(0xFFDC2626);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // 1. Health Records Card
            Expanded(
              child: _buildTile(
                context: context,
                icon: Icons.description_rounded,
                iconColor: AppColors.secondary,
                iconBg: const Color(0xFFEFF6FF),
                title: 'Health Records',
                value: '$recordsCount',
                subLabel: 'view all',
                subColor: AppTheme.accentGreen,
                onTap: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(2);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),

            // 2. Active Medicines Card
            Expanded(
              child: _buildTile(
                context: context,
                icon: Icons.medication_rounded,
                iconColor: const Color(0xFFF97316),
                iconBg: const Color(0xFFFFF7ED),
                title: 'Active Medicines',
                value: '$activeMedicinesCount',
                subLabel: 'today',
                subColor: AppTheme.accentGreen,
                onTap: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(3);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),

            // 3. BMI Card
            Expanded(
              child: _buildTile(
                context: context,
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.secondary,
                iconBg: const Color(0xFFEFF6FF),
                title: 'BMI',
                value: bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A',
                badgeText: bmi > 0 ? category : 'Set Height',
                badgeBg: categoryBgColor,
                badgeTextColor: categoryTextColor,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => BmiSummaryDialog(userProfile: userProfile),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    String? subLabel,
    Color? subColor,
    String? badgeText,
    Color? badgeBg,
    Color? badgeTextColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF1F5F9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.2) : iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),

              // Value
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),

              // SubLabel or Badge
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? (badgeBg?.withValues(alpha: 0.25) ?? Colors.grey) : badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : badgeTextColor,
                    ),
                  ),
                )
              else if (subLabel != null)
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subColor ?? AppTheme.primaryTeal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
