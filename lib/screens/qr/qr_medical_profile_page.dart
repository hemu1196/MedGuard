import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/qr_medical_profile_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class QrMedicalProfilePage extends StatefulWidget {
  const QrMedicalProfilePage({super.key});

  @override
  State<QrMedicalProfilePage> createState() => _QrMedicalProfilePageState();
}

class _QrMedicalProfilePageState extends State<QrMedicalProfilePage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthRepository _authRepository = AuthRepository();
  final QrMedicalProfileService _qrService = QrMedicalProfileService();

  QrMedicalProfilePayload? _payload;
  bool _isLoading = true;
  bool _isEmergencyViewMode = false;

  @override
  void initState() {
    super.initState();
    _loadPayload();
  }

  void _loadPayload() async {
    setState(() => _isLoading = true);
    final userId = await _authRepository.getCurrentUserId();
    final profile = await _profileRepository.getProfile(userId: userId);
    final p = _qrService.generatePayload(profile);
    if (mounted) {
      setState(() {
        _payload = p;
        _isLoading = false;
      });
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Emergency QR Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select format to share with first responders or medical personnel.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.qr_code_2,
                  color: AppTheme.primaryTeal,
                ),
                title: const Text('Share QR Image'),
                subtitle: const Text('Export emergency QR code'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('QR Code exported to gallery/clipboard'),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.text_snippet_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: const Text('Share Emergency Summary Text'),
                subtitle: const Text('Send SMS / Message text summary'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Emergency text payload copied: ${_payload?.name} (${_payload?.bloodGroup})',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: _isEmergencyViewMode
            ? '🚨 Emergency Medical View'
            : 'QR Medical Profile',
        subtitle: 'Emergency-safe medical summary',
        showBack: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Generating Emergency QR Profile...')
            : _payload == null
            ? const Center(child: Text('Unable to load profile data.'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mode Toggle Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Emergency QR Card',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        FilterChip(
                          label: Text(
                            _isEmergencyViewMode
                                ? 'Mode: Emergency'
                                : 'Mode: Standard',
                          ),
                          selected: _isEmergencyViewMode,
                          selectedColor: AppTheme.accentRed.withValues(
                            alpha: 0.15,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _isEmergencyViewMode = selected;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // QR Graphic Card
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Visual QR Generator Representation
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isEmergencyViewMode
                                      ? AppTheme.accentRed
                                      : AppTheme.primaryTeal,
                                  width: 2,
                                ),
                              ),
                              child: CustomPaint(
                                painter: _QrMatrixPainter(
                                  color: _isEmergencyViewMode
                                      ? AppTheme.accentRed
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _payload!.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Age: ${_payload!.age} yrs • Blood Group: ${_payload!.bloodGroup}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primaryTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Emergency-Safe Medical Attributes Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Medical Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Divider(height: 20),
                            _buildAttributeRow(
                              'Known Allergies',
                              _payload!.allergies,
                              Icons.warning_amber_rounded,
                              AppTheme.accentRed,
                            ),
                            _buildAttributeRow(
                              'Existing Conditions',
                              _payload!.existingConditions,
                              Icons.medical_services_outlined,
                              AppTheme.primaryBlue,
                            ),
                            _buildAttributeRow(
                              'Current Medications',
                              _payload!.currentMedications,
                              Icons.medication_outlined,
                              AppTheme.primaryTeal,
                            ),
                            _buildAttributeRow(
                              'Emergency Contact',
                              _payload!.emergencyContact,
                              Icons.contact_phone_outlined,
                              Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showShareOptions,
                            icon: const Icon(Icons.share),
                            label: const Text('Share QR'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEmergencyViewMode = !_isEmergencyViewMode;
                              });
                            },
                            icon: const Icon(Icons.fullscreen),
                            label: Text(
                              _isEmergencyViewMode
                                  ? 'Standard View'
                                  : 'Emergency View',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEmergencyViewMode
                                  ? AppTheme.primaryTeal
                                  : AppTheme.accentRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAttributeRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
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

class _QrMatrixPainter extends CustomPainter {
  final Color color;

  _QrMatrixPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final double cellSize = size.width / 10;

    // Corner finder patterns
    _drawFinderPattern(canvas, 0, 0, cellSize, paint);
    _drawFinderPattern(canvas, size.width - 3 * cellSize, 0, cellSize, paint);
    _drawFinderPattern(canvas, 0, size.height - 3 * cellSize, cellSize, paint);

    // Decorative matrix data blocks
    for (int r = 1; r < 9; r++) {
      for (int c = 1; c < 9; c++) {
        if ((r + c) % 2 == 0 &&
            !(r < 3 && c < 3) &&
            !(r < 3 && c > 6) &&
            !(r > 6 && c < 3)) {
          canvas.drawRect(
            Rect.fromLTWH(
              c * cellSize + 2,
              r * cellSize + 2,
              cellSize - 4,
              cellSize - 4,
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(
    Canvas canvas,
    double x,
    double y,
    double size,
    Paint paint,
  ) {
    canvas.drawRect(Rect.fromLTWH(x, y, size * 3, size * 3), paint);
    canvas.drawRect(
      Rect.fromLTWH(x + size * 0.5, y + size * 0.5, size * 2, size * 2),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(Rect.fromLTWH(x + size, y + size, size, size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
