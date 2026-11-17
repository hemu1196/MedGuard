import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/database/database_helper.dart';
import '../../repositories/auth_repository.dart';
import '../../services/medicine_action_outbox.dart';

/// Online-only access controls. No caregiver data or bearer links are persisted.
class AccessCenterPage extends StatefulWidget {
  final String mode;
  const AccessCenterPage({super.key, this.mode = 'privacy'});
  @override
  State<AccessCenterPage> createState() => _AccessCenterPageState();
}

class _AccessCenterPageState extends State<AccessCenterPage> {
  final _api = ApiClient();
  List<dynamic> _grants = [];
  Map<String, dynamic> _privacy = {};
  Map<String, dynamic> _profile = {};
  String? _error;
  bool _busy = true;
  final Set<String> _fields = {
    'fullName',
    'bloodGroup',
    'allergies',
    'emergencyContactName',
    'emergencyPhone',
    'emergencyCountryCode',
  };
  static const _labels = {
    'fullName': 'Name',
    'bloodGroup': 'Blood group',
    'allergies': 'Allergies',
    'chronicConditions': 'Conditions',
    'emergencyMedicalInfo': 'Medical notes / medicines',
    'emergencyContactName': 'Contact name',
    'emergencyPhone': 'Contact phone',
    'emergencyCountryCode': 'Country code',
  };
  String get _title => switch (widget.mode) {
    'medical-id' => 'Emergency Medical ID',
    'caregiver' => 'Family Caregiver Mode',
    'vault' => 'Secure Vault Sharing',
    _ => 'Privacy Center',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final grants = await _api.get('/launch/grants');
      final privacy = widget.mode == 'privacy'
          ? await _api.get('/launch/privacy')
          : <String, dynamic>{};
      final user = widget.mode == 'medical-id'
          ? await _api.get('/users/me')
          : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _grants = grants['grants'] ?? [];
          _privacy = privacy;
          _profile = Map<String, dynamic>.from(user['user'] ?? {});
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to load access controls. Check your connection and that the updated backend is deployed.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Action could not be completed. Please check your connection and try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Future<String?> _input(String title, {bool secret = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: secret,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showLink(Map<String, dynamic> grant, String token) async {
    if (!mounted) return;
    final caregiver =
        grant['kind'] == 'caregiver' ||
        (grant['recipientEmail'] ?? '').toString().isNotEmpty;
    final value = caregiver ? token : '${_api.baseUrl}/launch/public/$token';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(caregiver ? 'Invitation code' : 'Your private link'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!caregiver)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 210,
                    height: 210,
                    child: QrImageView(data: value, size: 210),
                  ),
                ),
              Text(
                caregiver
                    ? 'Send this code yourself to the invited account. They accept it while signed in.'
                    : 'Anyone with this link can access the selected information until expiration or revocation.',
              ),
              const SizedBox(height: 12),
              SelectableText(value),
              const SizedBox(height: 8),
              const Text(
                'This code is shown only now. Create another link if it is lost. Saved or downloaded copies cannot be revoked.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Share.share(value),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _createMedical() async {
    if (_fields.isEmpty ||
        !await _confirm(
          'Publish selected information?',
          'Review the values above. Anyone scanning this QR can view these fields. The link expires in 365 days and requires internet.',
        )) {
      return;
    }
    await _run(() async {
      final result = await _api.post(
        '/launch/grants',
        body: {
          'consent': true,
          'kind': 'medical-id',
          'fields': _fields.toList(),
          'expiresInDays': 365,
        },
      );
      await _showLink(
        Map<String, dynamic>.from(result['grant']),
        result['token'],
      );
    });
    await _load();
  }

  Future<void> _invite() async {
    final email = await _input('Caregiver account email');
    if (email == null || email.isEmpty || !mounted) return;
    final selected = <String>{'profile'};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Read-only access for 7 days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['profile', 'medicines', 'appointments']
                .map(
                  (scope) => CheckboxListTile(
                    title: Text(scope),
                    value: selected.contains(scope),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(scope);
                      } else {
                        selected.remove(scope);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true),
              child: const Text('Create invitation'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await _api.post(
        '/launch/grants',
        body: {
          'consent': true,
          'kind': 'caregiver',
          'recipientEmail': email,
          'permissions': selected.toList(),
          'expiresInDays': 7,
        },
      );
      await _showLink(
        Map<String, dynamic>.from(result['grant']),
        result['token'],
      );
    });
    await _load();
  }

  Future<void> _accept() async {
    final code = await _input('Paste invitation code');
    if (code == null || code.isEmpty) return;
    await _run(() async {
      await _api.post('/launch/caregiver/accept', body: {'token': code});
    });
    await _load();
  }

  Future<void> _shareVault() async {
    final restricted = await _confirm(
      'Require a recipient account?',
      'Choose Confirm for account-bound sharing, or Cancel for an anonymous bearer link. Both options allow recipients to retain downloaded copies.',
    );
    String? recipientEmail;
    if (restricted) {
      recipientEmail = await _input('Recipient account email');
      if (recipientEmail == null || recipientEmail.isEmpty) return;
    }
    await _run(() async {
      final response = await _api.get('/health-records');
      final records = (response['records'] ?? []) as List;
      if (!mounted) return;
      final selected = <String>{};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
            title: const Text('Share originals for 7 days'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restricted
                          ? 'Only the invited account can accept this code and download originals.'
                          : 'Anyone with the link can download the selected originals and retain copies.',
                    ),
                    if (records.isEmpty)
                      const Text('Upload a record with an attachment first.'),
                    ...records
                        .where((r) => r['fileUrl'] != null)
                        .map(
                          (r) => CheckboxListTile(
                            title: Text(r['title'] ?? 'Record'),
                            value: selected.contains(r['_id']),
                            onChanged: (v) => update(() {
                              if (v == true) {
                                selected.add(r['_id']);
                              } else {
                                selected.remove(r['_id']);
                              }
                            }),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty || selected.length > 20
                    ? null
                    : () => Navigator.pop(c, true),
                child: const Text('Create link'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final result = await _api.post(
        '/launch/grants',
        body: {
          'consent': true,
          'kind': 'vault',
          if (restricted) 'recipientEmail': recipientEmail,
          'recordIds': selected.toList(),
          'expiresInDays': 7,
        },
      );
      await _showLink(
        Map<String, dynamic>.from(result['grant']),
        result['token'],
      );
    });
    await _load();
  }

  Future<void> _viewVault(Map<String, dynamic> grant) async {
    await _run(() async {
      final response = await _api.get('/launch/vault/${grant['_id']}');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Shared originals'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: ((response['records'] ?? []) as List)
                  .map(
                    (record) => ListTile(
                      title: Text(record['title'] ?? 'Record'),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          try {
                            final bytes = await _api.downloadBytes(
                              '/launch/vault/${grant['_id']}/files/${record['_id']}',
                            );
                            await Share.shareXFiles([
                              XFile.fromData(
                                bytes,
                                mimeType:
                                    record['mimeType'] ??
                                    'application/octet-stream',
                                name: record['fileName'] ?? 'record',
                              ),
                            ]);
                          } catch (_) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Download unavailable. Access may have expired or been revoked.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _rescanFiles() async {
    if (!await _confirm(
      'Scan your existing originals?',
      'Send your original files to the configured private malware scanner. Files cannot be shared in production until they pass.',
    )) {
      return;
    }
    await _run(() async {
      final response = await _api.get('/health-records');
      for (final record in (response['records'] ?? []) as List) {
        if (record['fileUrl'] != null) {
          await _api.post('/launch/vault/rescan/${record['_id']}', body: {});
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Scan requests completed. Production sharing still requires a clean result for each file.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _viewScope(Map<String, dynamic> grant, String scope) async {
    await _run(() async {
      final result = await _api.get('/launch/caregiver/${grant['_id']}/$scope');
      if (!mounted) return;
      final data = result['data'];
      final lines = data is List
          ? data
                .map(
                  (row) => Map<String, dynamic>.from(row).entries
                      .where((e) => e.key != '_id')
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                )
                .join('\n\n')
          : Map<String, dynamic>.from(data).entries
                .map(
                  (e) =>
                      '${_labels[e.key] ?? e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}',
                )
                .join('\n\n');
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${result['ownerName']} · $scope'),
          content: SingleChildScrollView(
            child: Text(lines.isEmpty ? 'No records.' : lines),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _export() async {
    final password = await _input(
      'Confirm your password to export',
      secret: true,
    );
    if (password == null || password.isEmpty) return;
    await _run(() async {
      final result = await _api.post(
        '/launch/privacy/export',
        body: {'password': password},
      );
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(result['export']),
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'application/json',
            name: 'medguard-export.json',
          ),
        ],
        text:
            'Private MEDGUARD export. Store securely. Original attachments are downloaded separately from Health Vault.',
      );
    });
  }

  Future<void> _deleteAccount() async {
    if (!await _confirm(
      'Delete your account?',
      'Your sessions and links will be disabled. Cloud cleanup runs in the background. Downloaded copies cannot be recalled. Hosting backups expire under the hosting retention policy.',
    )) {
      return;
    }
    final password = await _input('Confirm your password', secret: true);
    if (password == null || password.isEmpty) return;
    await _run(() async {
      final result = await _api.post(
        '/launch/privacy/delete-account',
        body: {'password': password, 'confirmation': 'DELETE'},
      );
      final statusUrl =
          '${_api.baseUrl}/launch/deletion-status/${result['receipt']}';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Deletion requested'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your access is disabled. Cleanup is pending. Save this private status link to check completion:',
              ),
              SelectableText(statusUrl),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: statusUrl)),
              child: const Text('Copy status link'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      await AuthRepository().signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grants = _grants
        .where((g) => widget.mode == 'privacy' || g['kind'] == widget.mode)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (widget.mode == 'medical-id') ...[
            const Text(
              'Choose what a responder can see',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Review your saved profile before publishing. Links show the latest values of the selected fields.',
            ),
            ..._labels.entries.map(
              (e) => CheckboxListTile(
                title: Text(e.value),
                subtitle: Text(
                  (_profile[e.key] is List
                          ? (_profile[e.key] as List).join(', ')
                          : _profile[e.key] ?? 'Not provided')
                      .toString(),
                ),
                value: _fields.contains(e.key),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _fields.add(e.key);
                        } else {
                          _fields.remove(e.key);
                        }
                      }),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _createMedical,
              icon: const Icon(Icons.qr_code),
              label: const Text('Create Medical ID QR'),
            ),
          ],
          if (widget.mode == 'caregiver') ...[
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/family-dashboard'),
              child: const Text('Manage family profiles'),
            ),
            const Text(
              'Invite a trusted person to view only the information you select. Access is read-only, expires after 7 days, and can be revoked here.',
            ),
            FilledButton(
              onPressed: _busy ? null : _invite,
              child: const Text('Invite caregiver'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _accept,
              child: const Text('Accept invitation code'),
            ),
          ],
          if (widget.mode == 'vault') ...[
            OutlinedButton(
              onPressed: _busy ? null : _accept,
              child: const Text('Accept record invitation'),
            ),
            TextButton(
              onPressed: _busy ? null : _rescanFiles,
              child: const Text('Scan existing originals before sharing'),
            ),
            const Text(
              'Choose specific original records to share. Links expire after 7 days. Recipients can keep downloaded copies.',
            ),
            FilledButton(
              onPressed: _busy ? null : _shareVault,
              child: const Text('Select records and share'),
            ),
          ],
          if (widget.mode == 'privacy') ...[
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (!await _confirm(
                        'Remove old plaintext caches?',
                        'MEDGUARD will create encrypted recovery backups, verify their contents, then remove old SQLite cache files on this device. The backup key is cleared when you sign out; export any records you need first. This does not delete cloud records.',
                      )) {
                        return;
                      }
                      final count = await DatabaseHelper.instance
                          .cleanupVerifiedLegacyCaches(confirmed: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Cleaned $count legacy database files after encrypted-backup verification.',
                            ),
                          ),
                        );
                      }
                    }),
              child: const Text('Clean up old plaintext caches'),
            ),

            const Text(
              'Your information, your controls',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Review access links, active sessions and access history. Offline emergency information stays on this device until you clear it or sign out.',
            ),
            Wrap(
              spacing: 8,
              children: ['medical-id', 'caregiver', 'vault']
                  .map(
                    (mode) => TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccessCenterPage(mode: mode),
                        ),
                      ),
                      child: Text(mode),
                    ),
                  )
                  .toList(),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final userId = await AuthRepository().getCurrentUserId();
                      await MedicineActionOutbox.flush(userId, force: true);
                      final count = await MedicineActionOutbox.pendingCount(
                        userId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$count medicine actions still pending synchronization.',
                            ),
                          ),
                        );
                      }
                    }),
              child: const Text('Sync pending medicine actions'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _export,
              child: const Text('Export account records'),
            ),
            TextButton(
              onPressed: _busy ? null : _deleteAccount,
              child: const Text('Request account deletion'),
            ),
            const SizedBox(height: 16),
            Text(
              'Hosting backup retention: ${_privacy['retention']?['backupRetentionDays'] == null ? 'not configured by operator' : '${_privacy['retention']['backupRetentionDays']} days'}. Downloaded copies cannot be recalled.',
            ),
            const Text(
              'Active sessions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...((_privacy['sessions'] ?? []) as List).map(
              (s) => ListTile(
                title: Text('Signed in ${s['createdAt']}'),
                subtitle: Text('Expires ${s['expiresAt']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          if (await _confirm(
                            'Revoke this session?',
                            'This device or another signed-in device will need to sign in again.',
                          )) {
                            await _api.delete(
                              '/launch/privacy/sessions/${s['_id']}',
                            );
                            await _load();
                          }
                        }),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Access links and invitations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (grants.isEmpty && !_busy)
            const Text('No access links or invitations.'),
          ...grants.map((g) {
            final grant = Map<String, dynamic>.from(g);
            final active =
                grant['revokedAt'] == null &&
                (DateTime.tryParse(
                      grant['expiresAt'] ?? '',
                    )?.isAfter(DateTime.now()) ??
                    false);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${grant['kind']} ${grant['recipientEmail'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${active ? 'Active' : 'Inactive'} · expires ${grant['expiresAt']}',
                    ),
                    if (grant['kind'] == 'caregiver' &&
                        grant['acceptedAt'] != null &&
                        grant['viewerRole'] == 'recipient' &&
                        active)
                      Wrap(
                        spacing: 8,
                        children: ((grant['permissions'] ?? []) as List)
                            .map(
                              (scope) => TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _viewScope(grant, scope),
                                child: Text('View $scope'),
                              ),
                            )
                            .toList(),
                      ),
                    if (active &&
                        grant['viewerRole'] == 'owner' &&
                        (grant['recipientEmail'] ?? '').toString().isNotEmpty)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (!await _confirm(
                                  'Replace invitation?',
                                  'Previously accepted access will stop. Share the new code with the intended recipient.',
                                )) {
                                  return;
                                }
                                final result = await _api.post(
                                  '/launch/grants/${grant['_id']}/reissue',
                                  body: {},
                                );
                                await _showLink(
                                  Map<String, dynamic>.from(result['grant']),
                                  result['token'],
                                );
                                await _load();
                              }),
                        child: const Text(
                          'Replace invitation / recover access',
                        ),
                      ),
                    if (active &&
                        grant['kind'] == 'vault' &&
                        grant['viewerRole'] == 'recipient')
                      TextButton(
                        onPressed: _busy ? null : () => _viewVault(grant),
                        child: const Text('View shared originals'),
                      ),
                    if (active)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (await _confirm(
                                  'Revoke access?',
                                  'This link or invitation will stop working. Previously saved copies remain outside MEDGUARD.',
                                )) {
                                  await _api.delete(
                                    '/launch/grants/${grant['_id']}',
                                  );
                                  await _load();
                                }
                              }),
                        child: const Text('Revoke access'),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (widget.mode == 'privacy') ...[
            const SizedBox(height: 20),
            const Text(
              'Recent access history',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...((_privacy['events'] ?? []) as List).map(
              (event) => ListTile(
                title: Text(event['action'] ?? ''),
                subtitle: Text(event['createdAt'] ?? ''),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
