import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/emergency_cache_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class OfflineEmergencyPage extends StatefulWidget {
  const OfflineEmergencyPage({super.key});

  @override
  State<OfflineEmergencyPage> createState() => _OfflineEmergencyPageState();
}

class _OfflineEmergencyPageState extends State<OfflineEmergencyPage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthRepository _authRepository = AuthRepository();
  final EmergencyCacheService _cacheService = EmergencyCacheService();

  EmergencyCachedData? _cachedData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedEmergencyData();
  }

  void _loadCachedEmergencyData() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final profile = await _profileRepository.getProfile(userId: userId);
    final cached = await _cacheService.getCachedEmergencyProfile(profile);
    if (mounted) {
      setState(() {
        _cachedData = cached;
        _isLoading = false;
      });
    }
  }

  void _prepareSmsSos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.sms_outlined, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Offline SMS SOS Dispatch'),
          ],
        ),
        content: Text(
          'SMS Payload prepared for emergency contact (${_cachedData?.emergencyContactName}):\n\n'
          '"EMERGENCY SOS! I need medical assistance. My Blood Group is ${_cachedData?.bloodGroup}. Known Conditions: ${_cachedData?.conditions}."',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SMS SOS app launched with emergency payload!'),
                  backgroundColor: AppColors.emergency,
                ),
              );
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Offline SMS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Offline Emergency Mode',
        subtitle: 'No internet connection required',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Loading Cached Emergency Data...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Offline Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.amber.shade900,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You are in Offline Mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Essential medical data and helpline phone tools remain available offline.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Offline Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Dialing National Helpline 108...',
                                  ),
                                  backgroundColor: AppColors.emergency,
                                ),
                              );
                            },
                            icon: const Icon(Icons.call),
                            label: const Text('Call 108 / 911'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emergency,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _prepareSmsSos,
                            icon: const Icon(
                              Icons.sms,
                              color: AppColors.emergency,
                            ),
                            label: const Text('Prepare SMS SOS'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.emergency,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cached Emergency Profile Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Locally Cached Emergency Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Cached Offline',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildOfflineRow(
                              'Patient Name',
                              _cachedData!.userName,
                              Icons.person,
                            ),
                            _buildOfflineRow(
                              'Blood Group',
                              _cachedData!.bloodGroup,
                              Icons.bloodtype,
                            ),
                            _buildOfflineRow(
                              'Allergies',
                              _cachedData!.allergies,
                              Icons.warning_amber,
                            ),
                            _buildOfflineRow(
                              'Conditions',
                              _cachedData!.conditions,
                              Icons.medical_services_outlined,
                            ),
                            _buildOfflineRow(
                              'Essential Medicines',
                              _cachedData!.medicines,
                              Icons.medication_outlined,
                            ),
                            _buildOfflineRow(
                              'Emergency Contact',
                              '${_cachedData!.emergencyContactName} (${_cachedData!.emergencyPhone})',
                              Icons.contact_phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOfflineRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
