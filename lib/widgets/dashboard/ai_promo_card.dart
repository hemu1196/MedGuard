import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';

class AiPromoCard extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const AiPromoCard({
    super.key,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2942), const Color(0xFF06B6D4).withValues(alpha: 0.3)]
              : [const Color(0xFFECFEFF), const Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF0891B2),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASK MEDGUARD AI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    '24/7 Intelligent Health Guidance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0891B2),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Get instant information about symptoms, health questions, and understand when professional medical care may be appropriate.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(1);
                  } else {
                    Navigator.of(context).pushNamed(AppRoutes.ai);
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text(
                  'Start Chatting',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Text(
                    'General information only — not a medical diagnosis.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
