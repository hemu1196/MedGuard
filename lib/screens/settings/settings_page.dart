import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../repositories/auth_repository.dart';
import '../../services/user_state_service.dart';
import '../../widgets/app_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthRepository _authRepository = AuthRepository();

  // Notification Preferences
  bool _medicineReminders = true;
  bool _appointmentReminders = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationEnabled = true;
  bool _emergencyVoiceEnabled = true;

  // OS Notification Permission Status
  String _notificationPermissionText = 'Checking...';
  bool _hasNotificationPermission = true;

  // Appearance
  String _themeMode = 'System';

  // User details
  String _userEmail = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkNotificationPermission();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = ProfileStateManager.instance.currentProfile;

    setState(() {
      _medicineReminders = prefs.getBool('settings_medicine_reminders') ?? true;
      _appointmentReminders = prefs.getBool('settings_appointment_reminders') ?? true;
      _soundEnabled = prefs.getBool('settings_sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('settings_vibration_enabled') ?? true;
      _locationEnabled = prefs.getBool('settings_location_enabled') ?? true;
      _emergencyVoiceEnabled = prefs.getBool('settings_emergency_voice_enabled') ?? true;
      _themeMode = prefs.getString('settings_theme_mode') ?? 'System';

      _userName = profile?.name ?? prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'hem469469@gmail.com';
    });
  }

  Future<void> _checkNotificationPermission() async {
    if (kIsWeb) {
      setState(() {
        _notificationPermissionText = 'Browser Supported';
        _hasNotificationPermission = true;
      });
      return;
    }

    try {
      final status = await Permission.notification.status;
      setState(() {
        if (status.isGranted) {
          _notificationPermissionText = 'Granted';
          _hasNotificationPermission = true;
        } else if (status.isDenied) {
          _notificationPermissionText = 'Denied';
          _hasNotificationPermission = false;
        } else if (status.isPermanentlyDenied) {
          _notificationPermissionText = 'Permanently Denied';
          _hasNotificationPermission = false;
        } else {
          _notificationPermissionText = 'Not Requested';
          _hasNotificationPermission = false;
        }
      });
    } catch (_) {
      setState(() {
        _notificationPermissionText = 'Active';
        _hasNotificationPermission = true;
      });
    }
  }

  Future<void> _updateBoolPref(String key, bool val, void Function(bool) updateState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() => updateState(val));
  }

  Future<void> _updateStringPref(String key, String val, void Function(String) updateState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    setState(() => updateState(val));
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController(text: _userEmail);
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Set a new secure password for your MEDGUARD account.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Account Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newPass = passwordController.text.trim();
                      final confirmPass = confirmController.text.trim();
                      if (newPass.length < 6) {
                        setDialogState(() => errorText = 'Password must be at least 6 characters.');
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialogState(() => errorText = 'Passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });

                      try {
                        await _authRepository.resetPassword(
                          email: _userEmail.trim(),
                          newPassword: newPass,
                        );
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully in MongoDB Atlas.'),
                              backgroundColor: AppTheme.primaryTeal,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = e.toString().replaceAll('Exception:', '').trim();
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.primaryTeal),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Privacy & Medical Data Safety',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF12254A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'MEDGUARD is committed to absolute medical privacy:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildPrivacyBullet(
              icon: Icons.lock_outline,
              title: 'Authenticated Private Storage',
              description: 'Medical vault documents and files are stored in MongoDB GridFS with strict per-user JWT authorization.',
            ),
            const SizedBox(height: 8),
            _buildPrivacyBullet(
              icon: Icons.phone_android_outlined,
              title: 'Local-First Alarm Scheduling',
              description: 'Medicine & appointment alerts operate directly via Android alarm channels and never share device location or private logs.',
            ),
            const SizedBox(height: 8),
            _buildPrivacyBullet(
              icon: Icons.security_rounded,
              title: 'Zero Third-Party Telemetry',
              description: 'Your health records, emergency contacts, and vital stats are never sold or shared with external ad platforms.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of MEDGUARD?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authRepository.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              children: [
                // SECTION 1: Notifications
                _buildSectionHeader('Notification Settings', Icons.notifications_active_outlined),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Medicine Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Native system alarms and tray notifications for scheduled doses'),
                        secondary: const Icon(Icons.medication_outlined, color: AppTheme.primaryTeal),
                        value: _medicineReminders,
                        activeThumbColor: AppTheme.primaryTeal,
                        onChanged: (val) => _updateBoolPref(
                          'settings_medicine_reminders',
                          val,
                          (v) => _medicineReminders = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Appointment Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Advance reminder notifications for upcoming clinic visits'),
                        secondary: const Icon(Icons.event_available_outlined, color: AppTheme.primaryTeal),
                        value: _appointmentReminders,
                        activeThumbColor: AppTheme.primaryTeal,
                        onChanged: (val) => _updateBoolPref(
                          'settings_appointment_reminders',
                          val,
                          (v) => _appointmentReminders = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Sound Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Play audible ringtone on urgent medical notifications'),
                        secondary: const Icon(Icons.volume_up_outlined, color: AppTheme.primaryTeal),
                        value: _soundEnabled,
                        activeThumbColor: AppTheme.primaryTeal,
                        onChanged: (val) => _updateBoolPref(
                          'settings_sound_enabled',
                          val,
                          (v) => _soundEnabled = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Vibration Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Vibrate phone when medicine reminder alarms trigger'),
                        secondary: const Icon(Icons.vibration_outlined, color: AppTheme.primaryTeal),
                        value: _vibrationEnabled,
                        activeThumbColor: AppTheme.primaryTeal,
                        onChanged: (val) => _updateBoolPref(
                          'settings_vibration_enabled',
                          val,
                          (v) => _vibrationEnabled = v,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          _hasNotificationPermission ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          color: _hasNotificationPermission ? AppTheme.accentGreen : Colors.orange,
                        ),
                        title: const Text('Device Notification Permission', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Current status: $_notificationPermissionText'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            if (!kIsWeb) {
                              await openAppSettings();
                              _checkNotificationPermission();
                            }
                          },
                          child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: Account Settings
                _buildSectionHeader('Account & Security', Icons.person_outline),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryTeal),
                        title: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_userEmail),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryTeal),
                        title: const Text('Edit Health Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Update age, blood group, height, weight & emergency contacts'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.profileSetup),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.password_rounded, color: AppTheme.primaryTeal),
                        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Update your MongoDB Atlas account password securely'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: Emergency & Location Services
                _buildSectionHeader('Emergency & Services', Icons.emergency_outlined),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Location Services', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Enable GPS location for discovering nearest emergency hospitals'),
                        secondary: const Icon(Icons.location_on_outlined, color: AppTheme.primaryTeal),
                        value: _locationEnabled,
                        activeThumbColor: AppTheme.primaryTeal,
                        onChanged: (val) => _updateBoolPref(
                          'settings_location_enabled',
                          val,
                          (v) => _locationEnabled = v,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Voice SOS Detection', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Enable keyword detection for hands-free emergency dispatch'),
                        secondary: const Icon(Icons.mic_outlined, color: Color(0xFFDC2626)),
                        value: _emergencyVoiceEnabled,
                        activeThumbColor: const Color(0xFFDC2626),
                        onChanged: (val) => _updateBoolPref(
                          'settings_emergency_voice_enabled',
                          val,
                          (v) => _emergencyVoiceEnabled = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4: Appearance & Theme
                _buildSectionHeader('Appearance', Icons.palette_outlined),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.brightness_medium_outlined, color: AppTheme.primaryTeal),
                    title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Current: $_themeMode (MedGuard Teal & Navy)'),
                    trailing: DropdownButton<String>(
                      value: _themeMode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'System', child: Text('System Default')),
                        DropdownMenuItem(value: 'Light', child: Text('Light Mode')),
                        DropdownMenuItem(value: 'Dark', child: Text('Dark Mode')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateStringPref('settings_theme_mode', val, (v) => _themeMode = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 5: Privacy & About
                _buildSectionHeader('Privacy & About', Icons.info_outline),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shield_outlined, color: AppTheme.primaryTeal),
                        title: const Text('Privacy & Medical Data Safety', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Review our medical data protection commitments'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: _showPrivacyModal,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined, color: AppTheme.primaryTeal),
                        title: const Text('Clear Local App Cache', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Remove temporary cached files without altering cloud data'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('cached_hospitals');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Local cache cleared.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.medical_information_outlined, color: AppTheme.primaryTeal),
                        title: const Text('About MEDGUARD', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Version 1.0.0 (Build 1) • Release Candidate'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'MEDGUARD',
                            applicationVersion: 'v1.0.0 (Release 1)',
                            applicationLegalese:
                                'MEDGUARD Smart Emergency Assistance & Health Management System.\nProtected medical records, real-time alarms, and hospital discovery.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // SECTION 6: Logout
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12254A),
            ),
          ),
        ],
      ),
    );
  }
}
