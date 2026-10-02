import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/utils/image_helper.dart';

class DashboardGreetingCard extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String? profileImagePath;
  final bool isLoading;

  const DashboardGreetingCard({
    super.key,
    required this.greeting,
    required this.firstName,
    this.profileImagePath,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nowStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    if (isLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final imgProvider = ImageHelper.getImageProvider(profileImagePath);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F2942),
                  const Color(0xFF1E3A5F),
                ]
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFFECFDF5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.primaryTeal.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryTeal.withValues(alpha: 0.2),
              border: Border.all(
                color: AppTheme.primaryTeal,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: AppTheme.primaryTeal,
              backgroundImage: imgProvider,
              child: imgProvider == null
                  ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          // Greeting Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$greeting,',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white70
                        : const Color(0xFF334155),
                  ),
                ),
                Text(
                  firstName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay healthy, stay safe!',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.accentGreen
                        : AppTheme.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right graphic icon
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber : const Color(0xFFFDE047)).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  greeting.contains('Morning') || greeting.contains('Afternoon')
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round,
                  color: isDark ? Colors.amber : const Color(0xFFEAB308),
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nowStr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
