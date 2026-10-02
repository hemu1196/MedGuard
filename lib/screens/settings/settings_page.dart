import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _emergencyVoiceEnabled = true;
  final AuthService _authService = AuthService();

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Settings',
        subtitle: 'App preferences & account management',
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Medicine Reminders'),
                    subtitle: const Text(
                      'Receive push notifications for daily medicine times',
                    ),
                    secondary: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                    },
                    activeThumbColor: AppTheme.primaryTeal,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Location Services'),
                    subtitle: const Text(
                      'Allow location access for nearby hospital search',
                    ),
                    secondary: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                    value: _locationEnabled,
                    onChanged: (val) {
                      setState(() => _locationEnabled = val);
                    },
                    activeThumbColor: AppTheme.primaryTeal,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Voice SOS Detection'),
                    subtitle: const Text(
                      'Enable background voice keyword emergency trigger',
                    ),
                    secondary: const Icon(
                      Icons.mic_outlined,
                      color: AppTheme.accentRed,
                    ),
                    value: _emergencyVoiceEnabled,
                    onChanged: (val) {
                      setState(() => _emergencyVoiceEnabled = val);
                    },
                    activeThumbColor: AppTheme.accentRed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.security_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                    title: const Text('Privacy & Medical Data Safety'),
                    subtitle: const Text('Local storage & privacy commitments'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'MEDGUARD',
                        applicationVersion: 'v1.0.0 (Review 1)',
                        applicationLegalese:
                            'MedGuard processes health data locally and securely. Privacy and safety centered.',
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryTeal,
                    ),
                    title: const Text('About MedGuard'),
                    subtitle: const Text('Version 1.0.0 (Build 1)'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'MEDGUARD',
                        applicationVersion: 'v1.0.0',
                        applicationLegalese:
                            'Your Intelligent Health & Emergency Companion.',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
