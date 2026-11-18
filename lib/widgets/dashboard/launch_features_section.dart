import 'package:flutter/material.dart';
import '../../app/routes.dart';

/// Visible entry points to the seven connected health and access tools.
class LaunchFeaturesSection extends StatelessWidget {
  const LaunchFeaturesSection({super.key});

  static const features = [
    (
      Icons.qr_code_2,
      'Medical ID QR',
      'Choose emergency details, create a QR and revoke access.',
      AppRoutes.qrProfile,
    ),
    (
      Icons.family_restroom,
      'Family Caregiver',
      'Invite an account, review shared care and manage access.',
      AppRoutes.caregiverAccess,
    ),
    (
      Icons.medication_outlined,
      'Medicine Tracking',
      'Manage schedules, dose history, snooze and reminder diagnostics.',
      AppRoutes.medicines,
    ),
    (
      Icons.offline_bolt_outlined,
      'Offline Emergency',
      'Save an emergency card and unlock an encrypted backup.',
      AppRoutes.offlineEmergency,
    ),
    (
      Icons.folder_shared_outlined,
      'Secure Vault Sharing',
      'Choose records and manage recipient access or expiring links.',
      AppRoutes.vaultSharing,
    ),
    (
      Icons.local_hospital_outlined,
      'Hospital Search',
      'Search by location, radius and category; call or get directions.',
      AppRoutes.hospitals,
    ),
    (
      Icons.privacy_tip_outlined,
      'Privacy Center',
      'Review sessions, sharing, export and account deletion.',
      AppRoutes.privacyCenter,
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Your safety & care tools',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: const Color(0xFF123544),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'All seven tools in one place',
        style: TextStyle(color: Color(0xFF526775)),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 800
              ? 3
              : constraints.maxWidth >= 500
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final feature in features)
                SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      leading: Icon(feature.$1, color: const Color(0xFF00897B)),
                      title: Text(
                        feature.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123544),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          feature.$3,
                          style: const TextStyle(color: Color(0xFF526775)),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF526775),
                      ),
                      onTap: () => Navigator.pushNamed(context, feature.$4),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      const Text(
        'QR links, caregiver access and Vault sharing need internet. Prepare your offline card before an emergency.',
        style: TextStyle(fontSize: 12, color: Color(0xFF526775)),
      ),
    ],
  );
}
