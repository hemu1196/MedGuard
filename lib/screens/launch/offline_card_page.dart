import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/encrypted_emergency_card.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/offline_emergency_store.dart';

class OfflineCardPage extends StatefulWidget {
  const OfflineCardPage({super.key});
  @override
  State<OfflineCardPage> createState() => _OfflineCardPageState();
}

class _OfflineCardPageState extends State<OfflineCardPage> {
  String _userId = '';
  Map<String, dynamic>? _snapshot;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _userId = await AuthRepository().getCurrentUserId();
      final snapshot = await OfflineEmergencyStore.read(_userId);
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {
      _error = 'Unable to open protected offline storage.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save emergency information on this device?'),
        content: const Text(
          'A minimal medical card will be stored using device-protected storage. Anyone using your unlocked app can read it. It is removed on sign-out. Update it whenever your health details change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save card'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ProfileRepository().getProfile(userId: _userId);
      if (profile == null) throw StateError('No profile');
      await OfflineEmergencyStore.save(_userId, profile);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Unable to save. Sign in and update your health profile first.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _handoff(bool sms) async {
    final phone = (_snapshot?['emergencyPhone'] ?? '').toString().replaceAll(
      RegExp(r'[^+0-9]'),
      '',
    );
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
      setState(
        () => _error =
            'No valid emergency contact in this card. Update your profile and save again.',
      );
      return;
    }
    final uri = Uri(
      scheme: sms ? 'sms' : 'tel',
      path: phone,
      queryParameters: sms
          ? {'body': 'I need medical assistance. Please contact me.'}
          : null,
    );
    try {
      if (!await launchUrl(uri)) throw StateError('Unavailable');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This device could not open the ${sms ? 'message composer' : 'dialer'}.',
        );
      }
    }
  }

  Future<String?> _password(bool create) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(create ? 'Create card password' : 'Unlock encrypted card'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password (12+ characters for export)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  Future<void> _exportEncrypted() async {
    if (_snapshot == null) return;
    final password = await _password(true);
    if (password == null) return;
    try {
      final bytes = await EncryptedEmergencyCard.encrypt(_snapshot!, password);
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/octet-stream',
          name: 'medguard-emergency.medguard',
        ),
      ]);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Export failed. Use a password of at least 12 characters.',
        );
      }
    }
  }

  Future<void> _importEncrypted() async {
    try {
      final files = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['medguard'],
      );
      if (files == null || files.files.single.bytes == null || !mounted) return;
      final password = await _password(false);
      if (password == null) return;
      final card = await EncryptedEmergencyCard.decrypt(
        files.files.single.bytes!,
        password,
      );
      if (mounted) setState(() => _snapshot = card);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to unlock this card. Check the password and file.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Emergency')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Emergency information without internet',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Calls and SMS still require telephone service. You complete the call or message in the phone app. Live hospital search, routing and AI need internet. This page never queues emergency messages.',
        ),
        if (_busy) const LinearProgressIndicator(),
        OutlinedButton(
          onPressed: _busy ? null : _importEncrypted,
          child: const Text('Unlock encrypted emergency file'),
        ),
        if (_snapshot != null)
          OutlinedButton(
            onPressed: _exportEncrypted,
            child: const Text('Export password-encrypted card'),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Browser cards stay in memory. Export a password-encrypted card to keep a portable copy, and unlock it here offline. The app page must already be available on your device.',
            ),
          ),
        if (_snapshot != null) ...[
          const SizedBox(height: 20),
          Text('Saved ${_snapshot!['savedAt']} · may be outdated'),
          ...{
            'userName': 'Name',
            'bloodGroup': 'Blood group',
            'allergies': 'Allergies',
            'conditions': 'Conditions',
            'medicines': 'Medicines / medical notes',
            'emergencyContactName': 'Contact',
            'emergencyPhone': 'Phone',
          }.entries.map(
            (e) => ListTile(
              title: Text(e.value),
              subtitle: Text((_snapshot![e.key] ?? 'Not provided').toString()),
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _handoff(false),
                icon: const Icon(Icons.phone),
                label: const Text('Open contact dialer'),
              ),
              OutlinedButton.icon(
                onPressed: () => _handoff(true),
                icon: const Icon(Icons.sms),
                label: const Text('Prepare SMS'),
              ),
            ],
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await OfflineEmergencyStore.remove(_userId);
                    await _load();
                  },
            child: const Text('Remove offline card'),
          ),
        ] else if (!_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No saved emergency card for this account. Save one while signed in before you need it offline.',
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(
            _snapshot == null ? 'Save emergency card' : 'Update saved card',
          ),
        ),
      ],
    ),
  );
}
