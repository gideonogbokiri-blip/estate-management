import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateNotificationsPage extends StatefulWidget {
  const EstateNotificationsPage({super.key, required this.repository});

  final EstateApplicationApiRepository repository;

  @override
  State<EstateNotificationsPage> createState() =>
      _EstateNotificationsPageState();
}

class _EstateNotificationsPageState extends State<EstateNotificationsPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await widget.repository.loadMyNotifications();
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Notifications could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['readAt'] != null) return;
    try {
      await widget.repository.markEstateNotificationRead(
        notification['id'] as String,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is EstateApiException
            ? error.message
            : 'Notification could not be marked as read.',
      );
    }
  }

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Refresh notifications',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Updates for your active estate memberships.',
                    style: TextStyle(color: EstateColors.muted),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('You have no new notifications.'),
                      ),
                    )
                  else
                    for (final item in _items) _notificationCard(item),
                  const SizedBox(height: 8),
                  const Text(
                    'These are in-app updates. Push, email and SMS delivery are not configured.',
                    style: TextStyle(color: EstateColors.muted, fontSize: 12),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _notificationCard(Map<String, dynamic> item) {
    final unread = item['readAt'] == null;
    final type = (item['type'] as String? ?? 'update').toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: unread
              ? const Color(0xFFE8F2EC)
              : EstateColors.canvas,
          child: Icon(
            type == 'INCIDENT'
                ? Icons.shield_outlined
                : Icons.receipt_long_outlined,
            color: EstateColors.forest,
          ),
        ),
        title: Text(
          item['title'] as String? ?? 'Estate update',
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${item['estateName'] ?? 'Estate'} · ${item['message'] ?? ''}\n${_date(item['createdAt'] as String?)}',
          ),
        ),
        isThreeLine: true,
        trailing: unread
            ? TextButton(
                onPressed: () => _markRead(item),
                child: const Text('Mark read'),
              )
            : const Icon(Icons.done_all_rounded, color: EstateColors.muted),
      ),
    );
  }
}
