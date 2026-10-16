import 'package:flutter/material.dart';
import '../../services/in_app_notification_service.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final InAppNotificationService _notificationService =
      InAppNotificationService();
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.medicine:
        return Icons.medication_rounded;
      case NotificationType.appointment:
        return Icons.calendar_month_rounded;
      case NotificationType.emergency:
        return Icons.emergency_rounded;
      case NotificationType.healthTip:
        return Icons.eco_rounded;
      case NotificationType.general:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.medicine:
        return const Color(0xFF009E8F);
      case NotificationType.appointment:
        return const Color(0xFF2563EB);
      case NotificationType.emergency:
        return const Color(0xFFDC2626);
      case NotificationType.healthTip:
        return const Color(0xFF16A34A);
      case NotificationType.general:
        return const Color(0xFF087F7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _notificationService.items;
    final displayItems = _showOnlyUnread
        ? allItems.where((i) => !i.isRead).toList()
        : allItems;
    final unreadCount = _notificationService.unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Color(0xFF12254A),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF009E8F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allItems.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF009E8F)),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                  color: Color(0xFF009E8F),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${allItems.length})'),
                    selected: !_showOnlyUnread,
                    selectedColor: const Color(0xFFE8FAF8),
                    labelStyle: TextStyle(
                      color: !_showOnlyUnread
                          ? const Color(0xFF009E8F)
                          : const Color(0xFF64748B),
                      fontWeight:
                          !_showOnlyUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: !_showOnlyUnread
                          ? const Color(0xFF009E8F)
                          : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (val) => setState(() => _showOnlyUnread = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Unread ($unreadCount)'),
                    selected: _showOnlyUnread,
                    selectedColor: const Color(0xFFE8FAF8),
                    labelStyle: TextStyle(
                      color: _showOnlyUnread
                          ? const Color(0xFF009E8F)
                          : const Color(0xFF64748B),
                      fontWeight:
                          _showOnlyUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: _showOnlyUnread
                          ? const Color(0xFF009E8F)
                          : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (val) => setState(() => _showOnlyUnread = true),
                  ),
                  const Spacer(),
                  if (allItems.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B)),
                      tooltip: 'Clear All',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear All Notifications?'),
                            content: const Text(
                                'This will delete all saved notification history.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _notificationService.clearAll();
                        }
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Notification List
            Expanded(
              child: displayItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FAF8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_off_outlined,
                                size: 40,
                                color: Color(0xFF009E8F),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF12254A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _showOnlyUnread
                                  ? 'You have caught up with all your unread alerts.'
                                  : 'Your medicine reminders and appointment alerts will appear here.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayItems.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final item = displayItems[index];
                        final itemColor = _getColorForType(item.type);

                        return Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          ),
                          onDismissed: (_) {
                            _notificationService.deleteNotification(item.id);
                          },
                          child: InkWell(
                            onTap: () async {
                              await _notificationService.markAsRead(item.id);
                              if (item.targetRoute != null && context.mounted) {
                                Navigator.pushNamed(context, item.targetRoute!);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? Colors.white
                                    : const Color(0xFFF0FDFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: item.isRead
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF99F6E4),
                                  width: item.isRead ? 1 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: itemColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getIconForType(item.type),
                                      color: itemColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Text Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: item.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.bold,
                                                  fontSize: 15,
                                                  color: const Color(0xFF12254A),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTimeAgo(item.createdAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: Color(0xFF64748B),
                                            height: 1.3,
                                          ),
                                        ),
                                        if (item.targetRoute != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                'View Details',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: itemColor,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 13,
                                                color: itemColor,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Unread indicator dot
                                  if (!item.isRead)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8, top: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF009E8F),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
