import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/routes.dart';
import '../app/theme.dart';
import 'dashboard/dashboard_page.dart';
import 'ai/ai_assistant_page.dart';
import 'vault/health_vault_page.dart';
import 'medicines/medicine_page.dart';
import 'profile/profile_page.dart';

import 'dart:async';
import '../services/notification_service.dart';
import '../widgets/medicine_reminder_dialog.dart';

class MainNavigationFrame extends StatefulWidget {
  final int initialIndex;

  const MainNavigationFrame({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationFrame> createState() => _MainNavigationFrameState();
}

class _MainNavigationFrameState extends State<MainNavigationFrame> {
  late int _currentIndex;
  StreamSubscription<MedicineAlertEvent>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initAlertListener();
  }

  void _initAlertListener() {
    _alertSubscription = NotificationService().onMedicineAlert.listen((event) {
      if (mounted) {
        MedicineReminderDialog.show(context, event);
      }
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final List<Widget> pages = [
      DashboardPage(onNavigateTab: _onTabTapped),
      const AiAssistantPage(),
      const HealthVaultPage(),
      const MedicinePage(),
      const ProfilePage(),
    ];

    final overlayStyle = _currentIndex == 0 ? AppTheme.darkDashboardOverlay : AppTheme.lightPageOverlay;
    final scaffoldBg = _currentIndex == 0 ? const Color(0xFF102B3B) : const Color(0xFFE8F5F3);

    if (isDesktop) {
      final isExtended = MediaQuery.of(context).size.width >= 1000;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              extended: isExtended,
              minExtendedWidth: 240,
              minWidth: 72,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF00BFA5).withValues(alpha: 0.15),
              selectedIconTheme: const IconThemeData(color: Color(0xFF00BFA5), size: 24),
              unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B), size: 24),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xFF00BFA5),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Color(0xFF00BFA5),
                        size: 28,
                      ),
                    ),
                    if (isExtended) ...[
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEDGUARD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF07212F),
                            ),
                          ),
                          Text(
                            'Health & Emergency',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy_rounded),
                  label: Text('AI Assistant'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded),
                  label: Text('Health Vault'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.medication_outlined),
                  selectedIcon: Icon(Icons.medication_rounded),
                  label: Text('Medicines'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: isExtended
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.emergency_rounded, size: 18),
                            label: const Text(
                              'Emergency SOS',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRoutes.emergency);
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626)),
                            tooltip: 'Emergency SOS',
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRoutes.emergency);
                            },
                          ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
      ),
    );
  }

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: overlayStyle,
    child: Scaffold(
      backgroundColor: scaffoldBg,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF102B3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: const Color(0xFF102B3B),
              indicatorColor: const Color(0xFF00BFA5).withValues(alpha: 0.22),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFF00BFA5), size: 24);
                }
                return const IconThemeData(color: Color(0xFF859BA8), size: 24);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: Color(0xFF00BFA5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  );
                }
                return const TextStyle(
                  color: Color(0xFF859BA8),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              backgroundColor: const Color(0xFF102B3B),
              height: 68,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy_rounded),
                  label: 'AI',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded),
                  label: 'Vault',
                ),
                NavigationDestination(
                  icon: Icon(Icons.medication_outlined),
                  selectedIcon: Icon(Icons.medication_rounded),
                  label: 'Medicines',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
