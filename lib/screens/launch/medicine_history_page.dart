import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../services/notification_service.dart';

class MedicineHistoryPage extends StatefulWidget {
  final String medicineId;
  final String name;
  const MedicineHistoryPage({
    super.key,
    required this.medicineId,
    required this.name,
  });
  @override
  State<MedicineHistoryPage> createState() => _MedicineHistoryPageState();
}

class _MedicineHistoryPageState extends State<MedicineHistoryPage> {
  Map<String, dynamic> _data = {};
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient().get(
        '/medicines/${widget.medicineId}/history',
      );
      if (mounted) setState(() => _data = data);
    } catch (_) {
      _error = 'History could not be loaded.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _correct(Map<String, dynamic> receipt) async {
    final reason = TextEditingController();
    String target = receipt['status'] == 'taken' ? 'skipped' : 'taken';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Correct a dose action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Corrections remain in your audit history. Stock is adjusted once.',
              ),
              DropdownButton<String>(
                value: target,
                items: ['taken', 'skipped', 'missed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => update(() => target = v!),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (3+ characters)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save correction'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final random = Random.secure();
      final operation = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await ApiClient().post(
        '/medicines/${widget.medicineId}/corrections',
        body: {
          'occurrenceId': receipt['occurrenceId'],
          'expectedStatus': receipt['status'],
          'status': target,
          'reason': reason.text.trim(),
          'operationId': operation,
        },
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Correction not confirmed. Refresh history before retrying.';
          _busy = false;
        });
      }
    }
    reason.dispose();
  }

  Future<void> _diagnostics() async {
    final service = NotificationService();
    final allowed = await service.canScheduleExactAlarms();
    final pending = await service.getPendingNotifications();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reminder diagnostics'),
        content: Text(
          kIsWeb
              ? 'Browser reminders work while this page is running. Closing the browser can stop them. Use Android for device-scheduled reminders.'
              : 'Exact-alarm access: $allowed\nPending device reminders: ${pending.length}\nSchedules cover the next 30 days and refresh when the app is opened or resumed. Force-stop and device restrictions may block delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.name} history'),
      actions: [
        IconButton(
          onPressed: _diagnostics,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        Text('Stock: ${_data['remainingStock'] ?? '—'} units'),
        ...((_data['receipts'] ?? []) as List).reversed.map(
          (r) => Card(
            child: ListTile(
              title: Text('${r['status']} · ${r['at']}'),
              subtitle: Text(
                'Original action: ${r['originalStatus'] ?? r['status']}',
              ),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => _correct(Map<String, dynamic>.from(r)),
                child: const Text('Correct'),
              ),
            ),
          ),
        ),
        const Text(
          'Correction audit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...((_data['corrections'] ?? []) as List).reversed.map(
          (c) => ListTile(
            title: Text('${c['fromStatus']} → ${c['toStatus']}'),
            subtitle: Text('${c['reason']} · ${c['at']}'),
          ),
        ),
      ],
    ),
  );
}
