import 'package:flutter/material.dart';
import '../app/routes.dart';
import '../app/theme.dart';
import 'dashboard/dashboard_page.dart';
import 'ai/ai_assistant_page.dart';
import 'vault/health_vault_page.dart';
import 'medicines/medicine_page.dart';
import 'profile/profile_page.dart';

class MainNavigationFrame extends StatefulWidget {
  final int initialIndex;

  const MainNavigationFrame({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationFrame> createState() => _MainNavigationFrameState();
}

class _MainNavigationFrameState extends State<MainNavigationFrame> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              extended: MediaQuery.of(context).size.width >= 1200,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: AppTheme.primaryTeal,
                        size: 28,
                      ),
                    ),
                    if (MediaQuery.of(context).size.width >= 1200) ...[
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEDGUARD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                          Text(
                            'Health & Emergency',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryTeal),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy_rounded, color: AppTheme.primaryTeal),
                  label: Text('AI Assistant'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded, color: AppTheme.primaryTeal),
                  label: Text('Health Vault'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.medication_outlined),
                  selectedIcon: Icon(Icons.medication_rounded, color: AppTheme.primaryTeal),
                  label: Text('Medicines'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryTeal),
                  label: Text('Profile'),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: IconButton(
                      icon: const Icon(Icons.emergency_outlined, color: AppColors.emergency),
                      tooltip: 'Emergency SOS',
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.emergency);
                      },
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        indicatorColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryTeal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.primaryTeal,
            ),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(
              Icons.folder_rounded,
              color: AppTheme.primaryTeal,
            ),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(
              Icons.medication_rounded,
              color: AppTheme.primaryTeal,
            ),
            label: 'Medicines',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppTheme.primaryTeal,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
