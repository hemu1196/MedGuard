import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../controllers/dashboard_controller.dart';
import '../../widgets/dashboard/ai_promo_card.dart';
import '../../widgets/dashboard/dashboard_greeting_card.dart';
import '../../widgets/dashboard/dashboard_header.dart';
import '../../widgets/dashboard/dashboard_skeleton.dart';
import '../../widgets/dashboard/emergency_sos_card.dart';
import '../../widgets/dashboard/health_education_card.dart';
import '../../widgets/dashboard/health_overview_card.dart';
import '../../widgets/dashboard/health_statistics_chart.dart';
import '../../widgets/dashboard/medicine_schedule_card.dart';
import '../../widgets/dashboard/nearby_hospital_card.dart';
import '../../widgets/dashboard/profile_completion_card.dart';
import '../../widgets/dashboard/quick_action_card.dart';
import '../../widgets/dashboard/recent_health_record_card.dart';

class DashboardPage extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardPage({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isDesktop = MediaQuery.of(context).size.width >= 900;

        final quickActionItems = [
          QuickActionItem(
            title: 'AI Assistant',
            icon: Icons.smart_toy_rounded,
            iconColor: AppColors.secondary,
            backgroundColor: const Color(0xFFEFF6FF),
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(1);
              } else {
                Navigator.of(context).pushNamed(AppRoutes.ai);
              }
            },
          ),
          QuickActionItem(
            title: 'Medicines',
            icon: Icons.medication_rounded,
            iconColor: AppColors.emergency,
            backgroundColor: const Color(0xFFFEF2F2),
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3);
              } else {
                Navigator.of(context).pushNamed(AppRoutes.medicines);
              }
            },
          ),
          QuickActionItem(
            title: 'Health Vault',
            icon: Icons.folder_copy_rounded,
            iconColor: AppTheme.primaryTeal,
            backgroundColor: const Color(0xFFF0FDF4),
            onTap: () {
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(2);
              } else {
                Navigator.of(context).pushNamed(AppRoutes.vault);
              }
            },
          ),
          QuickActionItem(
            title: 'Appointments',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF8B5CF6),
            backgroundColor: const Color(0xFFF5F3FF),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.appointments);
            },
          ),
          QuickActionItem(
            title: 'Nearby Hospitals',
            icon: Icons.local_hospital_rounded,
            iconColor: AppTheme.primaryTeal,
            backgroundColor: const Color(0xFFECFDF5),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.hospitals);
            },
          ),
          QuickActionItem(
            title: 'Maps',
            icon: Icons.location_on_rounded,
            iconColor: AppTheme.accentGreen,
            backgroundColor: const Color(0xFFF0FDF4),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.map);
            },
          ),
          QuickActionItem(
            title: 'Ambulance',
            icon: Icons.airport_shuttle_rounded,
            iconColor: AppColors.emergency,
            backgroundColor: const Color(0xFFFEF2F2),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.ambulance);
            },
          ),
          QuickActionItem(
            title: 'Water Intake',
            icon: Icons.water_drop_rounded,
            iconColor: AppColors.accent,
            backgroundColor: const Color(0xFFE0F2FE),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.waterIntake);
            },
          ),
        ];

        return Scaffold(
          appBar: DashboardHeader(
            unreadNotifications: _controller.unreadNotifications,
          ),
          body: SafeArea(
            child: _controller.isLoadingProfile &&
                    _controller.isLoadingMedicines &&
                    _controller.isLoadingRecords
                ? const DashboardSkeleton()
                : RefreshIndicator(
                    onRefresh: () async {
                      await _controller.init();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: isDesktop
                              ? _buildDesktopLayout(context, quickActionItems)
                              : _buildMobileLayout(context, quickActionItems),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<QuickActionItem> quickActionItems) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Good Morning Card
        DashboardGreetingCard(
          greeting: _controller.greeting,
          firstName: _controller.firstName,
          profileImagePath: _controller.userProfile?.profileImagePath,
          isLoading: _controller.isLoadingProfile,
        ),
        const SizedBox(height: 14),

        // 2. Profile Completion Alert (if < 100%)
        ProfileCompletionCard(
          completionPercentage: _controller.profileCompletionPercentage,
        ),
        if (_controller.profileCompletionPercentage < 100) const SizedBox(height: 14),

        // 3. Emergency SOS Card
        const EmergencySOSCard(),
        const SizedBox(height: 20),

        // 4. Quick Actions Header & Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                }
              },
              child: const Text(
                'See All',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemCount: quickActionItems.length,
          itemBuilder: (context, index) {
            return QuickActionCard(item: quickActionItems[index]);
          },
        ),
        const SizedBox(height: 20),

        // 5. Health Overview Section Header & 3 Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Health Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 10),

        HealthOverviewCard(
          recordsCount: _controller.healthRecords.length,
          activeMedicinesCount: _controller.activeMedicinesCount,
          userProfile: _controller.userProfile,
          onNavigateTab: widget.onNavigateTab,
        ),
        const SizedBox(height: 22),

        // 6. Today's Medicines
        MedicineScheduleCard(
          medicines: _controller.todaysMedicines,
          isLoading: _controller.isLoadingMedicines,
          controller: _controller,
          onNavigateTab: widget.onNavigateTab,
        ),
        const SizedBox(height: 22),

        // 7. Recent Health Records
        RecentHealthRecordCard(
          records: _controller.recentRecords,
          isLoading: _controller.isLoadingRecords,
          onNavigateTab: widget.onNavigateTab,
        ),
        const SizedBox(height: 22),

        // 8. Health Statistics
        HealthStatisticsChart(
          categoryBreakdown: _controller.categoryBreakdown,
          totalRecords: _controller.healthRecords.length,
        ),
        const SizedBox(height: 22),

        // 9. Nearby Healthcare
        NearbyHospitalCard(
          hospitals: _controller.nearbyHospitals,
          isLoading: _controller.isLoadingHospitals,
          error: _controller.hospitalsError,
          onRetry: () => _controller.loadHospitals(),
        ),
        const SizedBox(height: 22),

        // 10. Ask MedGuard AI Promo
        AiPromoCard(onNavigateTab: widget.onNavigateTab),
        const SizedBox(height: 22),

        // 11. Health Education
        const HealthEducationCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, List<QuickActionItem> quickActionItems) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left / Center Column (65% width)
        Expanded(
          flex: 65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardGreetingCard(
                greeting: _controller.greeting,
                firstName: _controller.firstName,
                profileImagePath: _controller.userProfile?.profileImagePath,
                isLoading: _controller.isLoadingProfile,
              ),
              const SizedBox(height: 16),

              const EmergencySOSCard(),
              const SizedBox(height: 24),

              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: quickActionItems.length,
                itemBuilder: (context, index) {
                  return QuickActionCard(item: quickActionItems[index]);
                },
              ),
              const SizedBox(height: 24),

              Text(
                'Health Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),

              HealthOverviewCard(
                recordsCount: _controller.healthRecords.length,
                activeMedicinesCount: _controller.activeMedicinesCount,
                userProfile: _controller.userProfile,
                onNavigateTab: widget.onNavigateTab,
              ),
              const SizedBox(height: 24),

              MedicineScheduleCard(
                medicines: _controller.todaysMedicines,
                isLoading: _controller.isLoadingMedicines,
                controller: _controller,
                onNavigateTab: widget.onNavigateTab,
              ),
              const SizedBox(height: 24),

              RecentHealthRecordCard(
                records: _controller.recentRecords,
                isLoading: _controller.isLoadingRecords,
                onNavigateTab: widget.onNavigateTab,
              ),
              const SizedBox(height: 24),

              AiPromoCard(onNavigateTab: widget.onNavigateTab),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column (35% width)
        Expanded(
          flex: 35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileCompletionCard(
                completionPercentage: _controller.profileCompletionPercentage,
              ),
              if (_controller.profileCompletionPercentage < 100) const SizedBox(height: 16),

              HealthStatisticsChart(
                categoryBreakdown: _controller.categoryBreakdown,
                totalRecords: _controller.healthRecords.length,
              ),
              const SizedBox(height: 24),

              NearbyHospitalCard(
                hospitals: _controller.nearbyHospitals,
                isLoading: _controller.isLoadingHospitals,
                error: _controller.hospitalsError,
                onRetry: () => _controller.loadHospitals(),
              ),
              const SizedBox(height: 24),

              const HealthEducationCard(),
            ],
          ),
        ),
      ],
    );
  }
}
