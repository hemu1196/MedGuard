import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../controllers/dashboard_controller.dart';
import '../../widgets/dashboard/ask_ai_banner_card.dart';
import '../../widgets/dashboard/dark_scenic_hero_header.dart';
import '../../widgets/dashboard/dashboard_skeleton.dart';
import '../../widgets/dashboard/health_insights_section.dart';
import '../../widgets/dashboard/nearby_hospital_preview_card.dart';
import '../../widgets/dashboard/profile_completion_card.dart';
import '../../widgets/dashboard/recent_health_record_card.dart';
import '../../widgets/dashboard/upcoming_appointment_preview_card.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkDashboardOverlay,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isDesktop = MediaQuery.of(context).size.width >= 900;

          if (_controller.isLoadingProfile &&
              _controller.isLoadingMedicines &&
              _controller.isLoadingRecords &&
              _controller.isLoadingHospitals) {
            return const Scaffold(
              backgroundColor: Color(0xFF0E2333),
              body: SafeArea(child: DashboardSkeleton()),
            );
          }

          return Scaffold(
            backgroundColor: const Color(0xFF0E2333),
            body: RefreshIndicator(
              color: const Color(0xFF00BFA5),
              onRefresh: () async {
                await _controller.init();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: isDesktop
                    ? _buildDesktopLayout(context)
                    : _buildMobileLayout(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dark Scenic Hero Header (Includes Logo, Avatar, Greeting, Date, SOS, and 8 Quick Actions)
        DarkScenicHeroHeader(
          controller: _controller,
          onNavigateTab: widget.onNavigateTab,
        ),

        // 2. White Card Container for Health Insights, Appointments, Hospitals, AI, and Records
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile completion banner if incomplete
              if (_controller.profileCompletionPercentage < 100) ...[
                ProfileCompletionCard(
                  completionPercentage: _controller.profileCompletionPercentage,
                ),
                const SizedBox(height: 16),
              ],

              // Health Insights: 3 Arc Metric Cards (BMI, Water, Records)
              HealthInsightsSection(
                controller: _controller,
                onNavigateTab: widget.onNavigateTab,
              ),
              const SizedBox(height: 22),

              // Upcoming Appointment Card
              UpcomingAppointmentPreviewCard(
                appointment: _controller.upcomingAppointment,
                isLoading: _controller.isLoadingAppointments,
              ),
              const SizedBox(height: 22),

              // Nearby Hospitals Card
              NearbyHospitalPreviewCard(
                hospitals: _controller.nearbyHospitals,
                isLoading: _controller.isLoadingHospitals,
                error: _controller.hospitalsError,
                onRetry: () => _controller.loadHospitals(),
              ),
              const SizedBox(height: 22),

              // ASK MEDGUARD AI Banner Card
              AskAiBannerCard(
                onNavigateTab: widget.onNavigateTab,
              ),
              const SizedBox(height: 22),

              // Optional Compact Recent Health Records
              if (_controller.healthRecords.isNotEmpty) ...[
                RecentHealthRecordCard(
                  records: _controller.recentRecords,
                  isLoading: _controller.isLoadingRecords,
                  onNavigateTab: widget.onNavigateTab,
                ),
                const SizedBox(height: 22),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            DarkScenicHeroHeader(
              controller: _controller,
              onNavigateTab: widget.onNavigateTab,
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F8FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column (55%)
                  Expanded(
                    flex: 55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HealthInsightsSection(
                          controller: _controller,
                          onNavigateTab: widget.onNavigateTab,
                        ),
                        const SizedBox(height: 24),
                        UpcomingAppointmentPreviewCard(
                          appointment: _controller.upcomingAppointment,
                          isLoading: _controller.isLoadingAppointments,
                        ),
                        const SizedBox(height: 24),
                        if (_controller.healthRecords.isNotEmpty)
                          RecentHealthRecordCard(
                            records: _controller.recentRecords,
                            isLoading: _controller.isLoadingRecords,
                            onNavigateTab: widget.onNavigateTab,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right Column (45%)
                  Expanded(
                    flex: 45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_controller.profileCompletionPercentage < 100) ...[
                          ProfileCompletionCard(
                            completionPercentage: _controller.profileCompletionPercentage,
                          ),
                          const SizedBox(height: 20),
                        ],
                        NearbyHospitalPreviewCard(
                          hospitals: _controller.nearbyHospitals,
                          isLoading: _controller.isLoadingHospitals,
                          error: _controller.hospitalsError,
                          onRetry: () => _controller.loadHospitals(),
                        ),
                        const SizedBox(height: 24),
                        AskAiBannerCard(
                          onNavigateTab: widget.onNavigateTab,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
