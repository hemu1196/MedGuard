import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../controllers/dashboard_controller.dart';
import 'bmi_summary_dialog.dart';

class SemiCircleArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  SemiCircleArcPainter({
    required this.progress,
    required this.activeColor,
    this.trackColor = const Color(0xFFE2E8F0),
    this.strokeWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    // Active arc
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = math.pi * progress.clamp(0.05, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SemiCircleArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class HealthInsightsSection extends StatelessWidget {
  final DashboardController controller;
  final Function(int)? onNavigateTab;

  const HealthInsightsSection({
    super.key,
    required this.controller,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final bmiVal = controller.bmi;
    final bmiDisplay = bmiVal > 0 ? bmiVal.toStringAsFixed(1) : '--';
    String bmiCat = 'Not Set';
    if (bmiVal > 0) {
      final rawCat = controller.bmiCategory;
      if (rawCat.toLowerCase().contains('normal')) {
        bmiCat = 'Normal';
      } else if (rawCat.toLowerCase().contains('overweight')) {
        bmiCat = 'Overweight';
      } else if (rawCat.toLowerCase().contains('underweight')) {
        bmiCat = 'Underweight';
      } else if (rawCat.toLowerCase().contains('obese') || rawCat.toLowerCase().contains('obesity')) {
        bmiCat = 'Obese';
      } else {
        bmiCat = rawCat;
      }
    }
    final bmiProgress = bmiVal > 0 ? (bmiVal / 35.0).clamp(0.1, 1.0) : 0.1;

    // BMI pill styling
    Color pillBg = const Color(0xFFDCFCE7);
    Color pillText = const Color(0xFF166534);
    if (bmiCat == 'Overweight') {
      pillBg = const Color(0xFFFEF3C7);
      pillText = const Color(0xFF92400E);
    } else if (bmiCat == 'Underweight') {
      pillBg = const Color(0xFFE0F2FE);
      pillText = const Color(0xFF0369A1);
    } else if (bmiCat == 'Obese') {
      pillBg = const Color(0xFFFEE2E2);
      pillText = const Color(0xFF991B1B);
    } else if (bmiVal <= 0) {
      pillBg = const Color(0xFFF1F5F9);
      pillText = const Color(0xFF64748B);
    }

    // Water data
    final waterRatio = controller.waterProgressRatio;
    final waterText = controller.waterDisplay;

    // Records count
    final recordsCount = controller.healthRecords.length;
    final recordsProgress = (recordsCount / 10.0).clamp(0.1, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF142432),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 1. BMI Card
            Expanded(
              child: _buildInsightCard(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => BmiSummaryDialog(
                      userProfile: controller.userProfile,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(62, 34),
                            painter: SemiCircleArcPainter(
                              progress: bmiProgress,
                              activeColor: const Color(0xFF059669),
                              trackColor: const Color(0xFFE2E8F0),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            child: Icon(
                              Icons.spa_rounded,
                              size: 16,
                              color: const Color(0xFF059669).withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      bmiDisplay,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bmiCat,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: pillText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 2. Water Card
            Expanded(
              child: _buildInsightCard(
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.waterIntake);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(62, 34),
                            painter: SemiCircleArcPainter(
                              progress: waterRatio > 0 ? waterRatio : 0.08,
                              activeColor: const Color(0xFF0284C7),
                              trackColor: const Color(0xFFE2E8F0),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            child: Icon(
                              Icons.water_drop_rounded,
                              size: 16,
                              color: const Color(0xFF0284C7).withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Water',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        waterText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(waterRatio * 100).round()}% Goal',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 3. Records Card
            Expanded(
              child: _buildInsightCard(
                onTap: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(2);
                  } else {
                    Navigator.of(context).pushNamed(AppRoutes.vault);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(62, 34),
                            painter: SemiCircleArcPainter(
                              progress: recordsProgress,
                              activeColor: const Color(0xFF8B5CF6),
                              trackColor: const Color(0xFFE2E8F0),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            child: Icon(
                              Icons.description_rounded,
                              size: 16,
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Records',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$recordsCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Vault',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
