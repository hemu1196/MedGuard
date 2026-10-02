import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/emergency_contact.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/emergency_contact_repository.dart';
import '../../services/emergency_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/emergency_contact_dialog.dart';
import '../../widgets/loading_view.dart';

class EmergencySosPage extends StatefulWidget {
  const EmergencySosPage({super.key});

  @override
  State<EmergencySosPage> createState() => _EmergencySosPageState();
}

class _EmergencySosPageState extends State<EmergencySosPage> {
  final AuthRepository _authRepository = AuthRepository();
  final EmergencyContactRepository _contactRepository = EmergencyContactRepository();
  final EmergencyService _emergencyService = EmergencyService();

  String? _currentUserId;
  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoadingContacts = true;
  bool _isProcessingSos = false;
  bool _isSharingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingContacts = true);
    final userId = await _authRepository.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }

    final contacts = await _contactRepository.getEmergencyContacts(userId: userId);
    if (mounted) {
      setState(() {
        _emergencyContacts = contacts;
        _isLoadingContacts = false;
      });
    }
  }

  void _onSosButtonTapped() async {
    final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
    final contacts = await _contactRepository.getEmergencyContacts(userId: userId);
    if (contacts.isEmpty) {
      _showNoContactDialog();
      return;
    }

    final primary = contacts.first;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 28),
            SizedBox(width: 8),
            Text('Confirm Emergency SOS'),
          ],
        ),
        content: Text(
          'Send Emergency SOS alert and share current location with ${primary.name} (${primary.displayPhone})?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('SEND SOS'),
            onPressed: () {
              Navigator.of(context).pop();
              _triggerRealSos();
            },
          ),
        ],
      ),
    );
  }

  void _triggerRealSos() async {
    if (_isProcessingSos) return;

    setState(() {
      _isProcessingSos = true;
    });

    final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
    final result = await _emergencyService.triggerSos(userId: userId);

    if (!mounted) return;

    setState(() {
      _isProcessingSos = false;
    });

    if (result.status == 'no_contacts') {
      _showNoContactDialog();
    } else {
      _showSosPreparedModal(result);
    }
  }

  void _shareLocationSms() async {
    if (_isSharingLocation) return;

    final userId = _currentUserId ?? await _authRepository.getCurrentUserId();
    final contacts = await _contactRepository.getEmergencyContacts(userId: userId);

    if (contacts.isEmpty) {
      _showNoContactDialog();
      return;
    }

    final primary = contacts.first;
    if (!primary.isValidPhoneNumber) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid emergency contact phone number before sharing your location.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSharingLocation = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your current location...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final result = await _emergencyService.triggerSos(userId: userId);

    if (!mounted) return;

    setState(() {
      _isSharingLocation = false;
    });

    if (!result.success) {
      if (result.status == 'no_contacts') {
        _showNoContactDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }

    if (result.launchedUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS composer opened. Review and send your location.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS is not available on this device.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  void _showNoContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed),
            SizedBox(width: 8),
            Text('No Emergency Contact'),
          ],
        ),
        content: const Text(
          'No emergency contact configured.\n\nPlease add an emergency contact with a valid phone number to share location and trigger SOS alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Contact'),
            onPressed: () async {
              Navigator.of(context).pop();
              await showEmergencyContactDialog(
                context,
                onSaved: () => _loadData(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSosPreparedModal(EmergencySosResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sos_rounded, color: AppTheme.accentRed, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency SOS Payload Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Recipient: ${result.recipientName ?? "Emergency Contact"} (${result.recipientPhone ?? ""})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Emergency Location Message Payload:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                result.message,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            if (result.launchedUrl)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SMS composer opened. Review and send the location.',
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Message'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Emergency SOS message copied to clipboard!'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Contact'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (result.recipientPhone != null) {
                        _makePhoneCall(result.recipientPhone!);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number configured.')),
        );
      }
      return;
    }

    final Uri phoneUri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calling is not supported on this device.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling is not supported on this device.')),
        );
      }
    }
  }

  void _confirmEmergencyCall(String target, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed),
            SizedBox(width: 8),
            Text('Confirm Emergency Call'),
          ],
        ),
        content: Text(
          'Do you want to initiate emergency call to $target ($number)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await _makePhoneCall(number);
            },
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  void _triggerVoiceSos() async {
    await Permission.microphone.request();
    if (!mounted) return;
    final speech = stt.SpeechToText();
    String detectedText = 'Listening for keywords: "HELP ME", "SOS", or "EMERGENCY"...';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            speech.initialize().then((available) {
              if (available) {
                speech.listen(onResult: (result) {
                  final words = result.recognizedWords.toUpperCase();
                  setModalState(() {
                    detectedText = 'Heard: "$words"';
                  });
                  if (words.contains('HELP ME') ||
                      words.contains('HELP') ||
                      words.contains('SOS') ||
                      words.contains('EMERGENCY')) {
                    speech.stop();
                    Navigator.of(context).pop();
                    _onSosButtonTapped();
                  }
                });
              }
            });

            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: AppTheme.accentRed,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Voice Emergency Assistant',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detectedText,
                    style: const TextStyle(color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      speech.stop();
                      Navigator.of(context).pop();
                      _onSosButtonTapped();
                    },
                    icon: const Icon(Icons.emergency),
                    label: const Text('Trigger Keyword: "HELP ME" / "SOS"'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null || _isLoadingContacts) {
      return Scaffold(
        appBar: const AppHeader(
          title: 'Emergency SOS',
          subtitle: 'Immediate medical assistance',
        ),
        body: const LoadingView(message: 'Loading Emergency Contacts...'),
      );
    }

    return StreamBuilder<List<EmergencyContact>>(
      stream: _contactRepository.watchEmergencyContacts(_currentUserId!),
      builder: (context, snapshot) {
        final contacts = snapshot.hasData && snapshot.data!.isNotEmpty
            ? snapshot.data!
            : _emergencyContacts;

        final hasContact = contacts.isNotEmpty;
        final primaryContact = hasContact ? contacts.first : null;
        final contactName = primaryContact?.name ?? 'Emergency Contact';
        final contactPhone = hasContact
            ? primaryContact!.displayPhone
            : 'No emergency contact configured.';

        return Scaffold(
          appBar: const AppHeader(
            title: 'Emergency SOS',
            subtitle: 'Immediate medical assistance',
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Massive Emergency SOS Button
                  GestureDetector(
                    onTap: _onSosButtonTapped,
                    child: Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentRed.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessingSos
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.sos_rounded, color: Colors.white, size: 48),
                                  SizedBox(height: 4),
                                  Text(
                                    'TAP FOR SOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Voice SOS Trigger Button
                  OutlinedButton.icon(
                    onPressed: _triggerVoiceSos,
                    icon: const Icon(Icons.mic, color: AppTheme.accentRed),
                    label: const Text('🎙 Activate Voice SOS'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      side: const BorderSide(color: AppTheme.accentRed),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Emergency Contact Card Status Display
                  Card(
                    elevation: 1.5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: hasContact
                                ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                                : Colors.grey.shade200,
                            child: Icon(
                              hasContact ? Icons.person : Icons.person_off_outlined,
                              color: hasContact ? AppTheme.primaryTeal : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasContact ? contactName : 'No Emergency Contact',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  contactPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasContact ? AppTheme.textMuted : AppTheme.accentRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await showEmergencyContactDialog(
                                context,
                                existing: primaryContact,
                                onSaved: () => _loadData(),
                              );
                            },
                            icon: Icon(hasContact ? Icons.edit : Icons.add, size: 16),
                            label: Text(hasContact ? 'Edit' : 'Add'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Emergency Action Options
                  Column(
                    children: [
                      _buildEmergencyActionTile(
                        title: 'Call Emergency Services',
                        subtitle: 'National hotline (108 / 911)',
                        icon: Icons.phone_forwarded,
                        color: AppTheme.accentRed,
                        onTap: () =>
                            _confirmEmergencyCall('National Helpline', '108'),
                      ),
                      _buildEmergencyActionTile(
                        title: 'Find Nearest Hospital',
                        subtitle: 'Locate 24/7 medical centers',
                        icon: Icons.local_hospital,
                        color: AppTheme.primaryTeal,
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.hospitals),
                      ),
                      _buildEmergencyActionTile(
                        title: 'Request Ambulance',
                        subtitle: 'Dispatch emergency vehicle',
                        icon: Icons.airport_shuttle,
                        color: Colors.orange.shade800,
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.ambulance),
                      ),
                      _buildEmergencyActionTile(
                        title: 'Call Saved Emergency Contact',
                        subtitle: hasContact
                            ? '$contactName ($contactPhone)'
                            : 'No contact configured',
                        icon: Icons.contact_phone,
                        color: AppTheme.primaryBlue,
                        onTap: () {
                          if (hasContact) {
                            _makePhoneCall(primaryContact!.phone);
                          } else {
                            _showNoContactDialog();
                          }
                        },
                      ),
                      _buildEmergencyActionTile(
                        title: 'Share My Location',
                        subtitle: _isSharingLocation
                            ? 'Getting location & opening SMS composer...'
                            : 'Send GPS coordinates via SMS to emergency contact',
                        icon: Icons.share_location,
                        color: Colors.green.shade700,
                        onTap: _shareLocationSms,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}
