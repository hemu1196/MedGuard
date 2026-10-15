import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/routes.dart';
import '../../controllers/dashboard_controller.dart';

class QuickActionData {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  QuickActionData({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });
}

class DarkScenicHeroHeader extends StatelessWidget {
  final DashboardController controller;
  final Function(int)? onNavigateTab;

  const DarkScenicHeroHeader({
    super.key,
    required this.controller,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdayStr = DateFormat('EEE').format(now);
    final dateStr = DateFormat('MMM d').format(now);

    final List<QuickActionData> quickActions = [
      QuickActionData(
        label: 'AI',
        subtitle: 'Symptom & advice',
        icon: Icons.smart_toy_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () {
          if (onNavigateTab != null) {
            onNavigateTab!(1);
          } else {
            Navigator.of(context).pushNamed(AppRoutes.ai);
          }
        },
      ),
      QuickActionData(
        label: 'Medicines',
        subtitle: 'Schedule & stock',
        icon: Icons.medication_rounded,
        iconColor: const Color(0xFFEF4444),
        bgColor: const Color(0xFFFEF2F2),
        onTap: () {
          if (onNavigateTab != null) {
            onNavigateTab!(3);
          } else {
            Navigator.of(context).pushNamed(AppRoutes.medicines);
          }
        },
      ),
      QuickActionData(
        label: 'Vault',
        subtitle: 'Records & vault',
        icon: Icons.folder_rounded,
        iconColor: const Color(0xFF0F766E),
        bgColor: const Color(0xFFF0FDF4),
        onTap: () {
          if (onNavigateTab != null) {
            onNavigateTab!(2);
          } else {
            Navigator.of(context).pushNamed(AppRoutes.vault);
          }
        },
      ),
      QuickActionData(
        label: 'Appts',
        subtitle: 'Doctor visits',
        icon: Icons.calendar_month_rounded,
        iconColor: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.appointments);
        },
      ),
      QuickActionData(
        label: 'Hospitals',
        subtitle: '24/7 Facilities',
        icon: Icons.local_hospital_rounded,
        iconColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.hospitals);
        },
      ),
      QuickActionData(
        label: 'Maps',
        subtitle: 'Live navigation',
        icon: Icons.location_on_rounded,
        iconColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDF4),
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.map);
        },
      ),
      QuickActionData(
        label: 'Ambulance',
        subtitle: 'SOS & dispatch',
        icon: Icons.airport_shuttle_rounded,
        iconColor: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.ambulance);
        },
      ),
      QuickActionData(
        label: 'Water',
        subtitle: 'Hydration goal',
        icon: Icons.water_drop_rounded,
        iconColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.waterIntake);
        },
      ),
    ];

    return Stack(
      children: [
        // 1. Scenic Mountain Background with Dark Overlay
        Positioned.fill(
          child: Image.asset(
            'assets/images/scenic_mountain_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF07212F), Color(0xFF102B3B), Color(0xFF0B1F2D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              );
            },
          ),
        ),

        // Gradient tint over background for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF07212F).withValues(alpha: 0.65),
                  const Color(0xFF0A2232).withValues(alpha: 0.85),
                  const Color(0xFF0E2A3B).withValues(alpha: 0.98),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 2. Foreground Content
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 8,
            16,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Shield Logo, App Title, Notification Bell, User Avatar
              _buildTopBar(context),
              const SizedBox(height: 20),

              // Greeting & Date Card Row
              _buildGreetingAndDate(context, weekdayStr, dateStr),
              const SizedBox(height: 20),

              // Emergency SOS Card
              _buildEmergencySOSCard(context),
              const SizedBox(height: 22),

              // Quick Actions Header & 2x4 Grid
              _buildQuickActionsHeader(context),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(context, quickActions),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        // MEDGUARD Shield Icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // App Name and Tagline
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEDGUARD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Your Health & Emergency Companion',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // Notification Bell with Badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.unreadNotifications > 0
                          ? 'You have ${controller.unreadNotifications} unread notifications.'
                          : 'No new notifications at this time.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Notifications',
              visualDensity: VisualDensity.compact,
            ),
            if (controller.unreadNotifications > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${controller.unreadNotifications}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // User Profile Avatar
        GestureDetector(
          onTap: () {
            if (onNavigateTab != null) {
              onNavigateTab!(4);
            } else {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage: (controller.userProfile?.profileImagePath != null &&
                      controller.userProfile!.profileImagePath!.isNotEmpty)
                  ? NetworkImage(controller.userProfile!.profileImagePath!)
                  : null,
              child: (controller.userProfile?.profileImagePath == null ||
                      controller.userProfile!.profileImagePath!.isEmpty)
                  ? Text(
                      controller.firstName.isNotEmpty
                          ? controller.firstName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingAndDate(BuildContext context, String weekdayStr, String dateStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Greeting & Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${controller.greeting},',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                controller.firstName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Stay healthy, stay safe!',
                style: TextStyle(
                  color: Color(0xFF80E5D8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Glassmorphic Date Card
        Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF163248).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekdayStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencySOSCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.emergency);
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE52D27),
                Color(0xFFB31217),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE52D27).withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // White Circle with Emergency Phone Icon
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Color(0xFFD32F2F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EMERGENCY SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to get immediate help',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Circular Forward Chevron Button
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFD32F2F),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        GestureDetector(
          onTap: () {
            if (onNavigateTab != null) {
              onNavigateTab!(1);
            }
          },
          child: const Text(
            'See All',
            style: TextStyle(
              color: Color(0xFF64D2C3),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, List<QuickActionData> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWideDesktop = width >= 800;
        final isTablet = width >= 500 && width < 800;

        // Controlled height preventing oversized vertical expansion on desktop/web
        final double mainAxisExtent = isWideDesktop
            ? 130.0
            : (isTablet ? 112.0 : 96.0);

        final double iconBoxSize = isWideDesktop ? 48.0 : (isTablet ? 42.0 : 38.0);
        final double iconSize = isWideDesktop ? 26.0 : (isTablet ? 22.0 : 20.0);
        final double labelFontSize = isWideDesktop ? 13.0 : (isTablet ? 12.0 : 11.0);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: isWideDesktop ? 14 : 10,
            crossAxisSpacing: isWideDesktop ? 14 : 10,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _QuickActionCardTile(
              item: item,
              iconBoxSize: iconBoxSize,
              iconSize: iconSize,
              labelFontSize: labelFontSize,
              showSubtitle: isWideDesktop,
            );
          },
        );
      },
    );
  }
}

class _QuickActionCardTile extends StatefulWidget {
  final QuickActionData item;
  final double iconBoxSize;
  final double iconSize;
  final double labelFontSize;
  final bool showSubtitle;

  const _QuickActionCardTile({
    required this.item,
    required this.iconBoxSize,
    required this.iconSize,
    required this.labelFontSize,
    required this.showSubtitle,
  });

  @override
  State<_QuickActionCardTile> createState() => _QuickActionCardTileState();
}

class _QuickActionCardTileState extends State<_QuickActionCardTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? const Color(0xFF00BFA5) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0xFF00BFA5).withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: widget.iconBoxSize,
                    height: widget.iconBoxSize,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: widget.iconSize,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.labelFontSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF142432),
                      height: 1.15,
                    ),
                  ),
                  if (widget.showSubtitle && item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
