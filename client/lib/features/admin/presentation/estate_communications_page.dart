import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateCommunicationsPage extends StatefulWidget {
  const EstateCommunicationsPage({
    super.key,
    required this.announcements,
    required this.repository,
    required this.onDraftSaved,
  });
  final List<EstateAnnouncementSummary> announcements;
  final EstateAdminRepository repository;
  final VoidCallback onDraftSaved;

  @override
  State<EstateCommunicationsPage> createState() =>
      _EstateCommunicationsPageState();
}

class _EstateCommunicationsPageState extends State<EstateCommunicationsPage> {
  String _status = 'all';
  String _audience = 'all';
  final Set<String> _channels = {'push'};
  bool _emergency = false;
  bool _saving = false;
  String? _schedulingId;
  String? _dispatchingId;
  String? _retryingId;
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAnnouncements = widget.announcements;
    final drafts = allAnnouncements.where((a) => a.status == 'draft').length;
    final scheduled = allAnnouncements
        .where((a) => a.status == 'scheduled')
        .length;
    final published = allAnnouncements
        .where((a) => a.status == 'published')
        .length;
    final failed = allAnnouncements.where((a) => a.status == 'failed').length;
    final visible = allAnnouncements
        .where((a) => _status == 'all' || a.status == _status)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Announcements',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Prepare resident updates and review scheduled or published communications.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _CommunicationsNotice(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 560
                ? box.maxWidth
                : (box.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CommsMetric(
                  width: width,
                  label: 'Published',
                  value: '$published',
                  icon: Icons.mark_email_read_outlined,
                  color: EstateColors.forest,
                ),
                _CommsMetric(
                  width: width,
                  label: 'Scheduled',
                  value: '$scheduled',
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFF476B91),
                ),
                _CommsMetric(
                  width: width,
                  label: 'Drafts',
                  value: '$drafts',
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFF8A6731),
                ),
                _CommsMetric(
                  width: width,
                  label: 'Failed delivery',
                  value: '$failed',
                  icon: Icons.error_outline_rounded,
                  color: const Color(0xFF984B43),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final composer = _Composer(
              title: _title,
              body: _body,
              audience: _audience,
              onAudienceChanged: (value) => setState(() => _audience = value),
              channels: _channels,
              onChannelChanged: _toggleChannel,
              emergency: _emergency,
              onEmergencyChanged: (value) => setState(() => _emergency = value),
              onSaveDraft: _saveDraft,
              saving: _saving,
            );
            final list = _Timeline(
              announcements: visible,
              status: _status,
              onStatusChanged: (value) => setState(() => _status = value),
              onSchedule: _schedulePreviewAnnouncement,
              schedulingId: _schedulingId,
              onDispatch: _dispatchPreviewAnnouncement,
              dispatchingId: _dispatchingId,
              onRetry: _retryPreviewAnnouncement,
              retryingId: _retryingId,
            );
            return narrow
                ? Column(children: [composer, const SizedBox(height: 16), list])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: composer),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: list),
                    ],
                  );
          },
        ),
      ],
    );
  }

  void _toggleChannel(String channel, bool selected) {
    setState(() {
      if (selected) {
        _channels.add(channel);
      } else {
        _channels.remove(channel);
      }
    });
  }

  Future<void> _saveDraft() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty || _channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title, message and at least one channel.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.createAnnouncementDraft(
        title: title,
        body: body,
        priority: _emergency ? 'emergency' : 'normal',
        audienceLabel: _audience == 'all'
            ? 'All residents'
            : _audience == 'property'
            ? 'Apartment residents'
            : 'Estate staff',
        channels: _channels.toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _title.clear();
        _body.clear();
        _emergency = false;
        _channels
          ..clear()
          ..add('push');
        _status = 'draft';
      });
      widget.onDraftSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved to this preview session only.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The draft could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _schedulePreviewAnnouncement(
    EstateAnnouncementSummary announcement,
  ) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Select a send date in Africa/Lagos time',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Select a send time in Africa/Lagos time',
    );
    if (time == null || !mounted) return;

    // Lagos is UTC+1. Convert the selected wall time into the explicit instant
    // required by the scheduling contract; the timezone travels separately.
    final sendAt = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour - 1,
      time.minute,
    ).toIso8601String();
    setState(() => _schedulingId = announcement.id);
    try {
      await widget.repository.scheduleAnnouncement(
        announcementId: announcement.id,
        scheduledAt: sendAt,
        timeZone: 'Africa/Lagos',
      );
      if (!mounted) return;
      widget.onDraftSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled in the preview. No notification was sent.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a future time and try scheduling again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _schedulingId = null);
    }
  }

  Future<void> _dispatchPreviewAnnouncement(
    EstateAnnouncementSummary announcement,
  ) async {
    final emergency = announcement.priority == 'emergency';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          emergency ? 'Confirm emergency dispatch' : 'Send this update now?',
        ),
        content: Text(
          emergency
              ? 'Confirm this is an emergency. The preview will show the request as Sending; it will not contact residents.'
              : 'The preview will show the request as Sending. It will not contact residents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(emergency ? 'Confirm and continue' : 'Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _dispatchingId = announcement.id);
    try {
      await widget.repository.requestAnnouncementDispatch(
        announcementId: announcement.id,
        confirmEmergency: emergency,
      );
      if (!mounted) return;
      widget.onDraftSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dispatch is pending in the preview. No notification was sent.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This announcement is not ready to send.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _dispatchingId = null);
    }
  }

  Future<void> _retryPreviewAnnouncement(
    EstateAnnouncementSummary announcement,
  ) async {
    setState(() => _retryingId = announcement.id);
    try {
      await widget.repository.retryAnnouncementDispatch(
        announcementId: announcement.id,
      );
      if (!mounted) return;
      widget.onDraftSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Retry queued in the preview. No notification was sent.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This failed dispatch could not be retried.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _retryingId = null);
    }
  }
}

class _CommunicationsNotice extends StatelessWidget {
  const _CommunicationsNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.notifications_active_outlined, color: EstateColors.forest),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview communication workspace. Sending requires the estate notification service; recipient lists, delivery details and private file references are not exposed here.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _CommsMetric extends StatelessWidget {
  const _CommsMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: const TextStyle(color: EstateColors.muted)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.title,
    required this.body,
    required this.audience,
    required this.onAudienceChanged,
    required this.channels,
    required this.onChannelChanged,
    required this.emergency,
    required this.onEmergencyChanged,
    required this.onSaveDraft,
    required this.saving,
  });
  final TextEditingController title;
  final TextEditingController body;
  final String audience;
  final ValueChanged<String> onAudienceChanged;
  final Set<String> channels;
  final void Function(String, bool) onChannelChanged;
  final bool emergency;
  final ValueChanged<bool> onEmergencyChanged;
  final Future<void> Function() onSaveDraft;
  final bool saving;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compose an update',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start a resident announcement draft.',
            style: TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 17),
          const Text(
            'AUDIENCE',
            style: TextStyle(
              fontSize: 10,
              color: EstateColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 6),
          DropdownMenu<String>(
            initialSelection: audience,
            expandedInsets: EdgeInsets.zero,
            onSelected: (value) {
              if (value != null) onAudienceChanged(value);
            },
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'all', label: 'All residents'),
              DropdownMenuEntry(
                value: 'property',
                label: 'Apartment residents (preview)',
              ),
              DropdownMenuEntry(
                value: 'staff',
                label: 'Estate staff (preview)',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Announcement title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: body,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'DELIVERY CHANNELS',
            style: TextStyle(
              fontSize: 10,
              color: EstateColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text('Push'),
                selected: channels.contains('push'),
                onSelected: (value) => onChannelChanged('push', value),
              ),
              FilterChip(
                label: Text('Email'),
                selected: channels.contains('email'),
                onSelected: (value) => onChannelChanged('email', value),
              ),
              FilterChip(
                label: Text('SMS'),
                selected: channels.contains('sms'),
                onSelected: (value) => onChannelChanged('sms', value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: emergency,
            onChanged: (value) => onEmergencyChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Mark as emergency', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Emergency dispatch requires server permission and confirmation.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : onSaveDraft,
              child: Text(saving ? 'Saving…' : 'Save draft'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.announcements,
    required this.status,
    required this.onStatusChanged,
    required this.onSchedule,
    required this.schedulingId,
    required this.onDispatch,
    required this.dispatchingId,
    required this.onRetry,
    required this.retryingId,
  });
  final List<EstateAnnouncementSummary> announcements;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<EstateAnnouncementSummary> onSchedule;
  final String? schedulingId;
  final ValueChanged<EstateAnnouncementSummary> onDispatch;
  final String? dispatchingId;
  final ValueChanged<EstateAnnouncementSummary> onRetry;
  final String? retryingId;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text(
            'Recent announcements',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          DropdownButton<String>(
            value: status,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All updates')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              DropdownMenuItem(
                value: 'sending',
                child: Text('Awaiting delivery'),
              ),
              DropdownMenuItem(value: 'failed', child: Text('Failed delivery')),
              DropdownMenuItem(value: 'draft', child: Text('Drafts')),
            ],
            onChanged: (value) => onStatusChanged(value ?? 'all'),
          ),
        ],
      ),
      const SizedBox(height: 9),
      if (announcements.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No announcements in this view.')),
          ),
        ),
      ...announcements.map(
        (item) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _AnnouncementBadge(
                      status: item.status,
                      emergency: item.priority == 'emergency',
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.bodyPreview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _MetaChip(
                      icon: Icons.groups_outlined,
                      label: item.audienceLabel,
                    ),
                    ...item.channels.map(
                      (channel) => _MetaChip(
                        icon: channel == 'email'
                            ? Icons.mail_outline
                            : channel == 'sms'
                            ? Icons.sms_outlined
                            : Icons.notifications_none,
                        label: channel.toUpperCase(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.status == 'scheduled'
                      ? 'Scheduled ${_format(item.scheduledAt)}'
                      : item.status == 'published'
                      ? 'Published ${_format(item.publishedAt)}'
                      : item.status == 'sending'
                      ? 'Dispatch requested · awaiting notification service'
                      : item.status == 'failed'
                      ? 'Delivery failed${item.failureCode == null ? '' : ' · ${item.failureCode}'}'
                      : 'Created ${_format(item.createdAt)}',
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                  ),
                ),
                if (item.status == 'draft') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item.priority != 'emergency')
                        TextButton.icon(
                          onPressed:
                              schedulingId == null && dispatchingId == null
                              ? () => onSchedule(item)
                              : null,
                          icon: schedulingId == item.id
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.schedule_rounded, size: 17),
                          label: const Text('Schedule'),
                        ),
                      const SizedBox(width: 5),
                      FilledButton.tonalIcon(
                        onPressed: dispatchingId == null && schedulingId == null
                            ? () => onDispatch(item)
                            : null,
                        icon: dispatchingId == item.id
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          item.priority == 'emergency'
                              ? 'Dispatch emergency'
                              : 'Send now',
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.status == 'failed') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: retryingId == null
                          ? () => onRetry(item)
                          : null,
                      icon: retryingId == item.id
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Retry delivery'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );
  String _format(String? value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · ${date.hour}:$minute';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F4F2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: EstateColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: EstateColors.muted),
        ),
      ],
    ),
  );
}

class _AnnouncementBadge extends StatelessWidget {
  const _AnnouncementBadge({required this.status, required this.emergency});
  final String status;
  final bool emergency;
  @override
  Widget build(BuildContext context) {
    final color = emergency
        ? const Color(0xFF984B43)
        : status == 'failed'
        ? const Color(0xFF984B43)
        : status == 'published'
        ? EstateColors.forest
        : status == 'scheduled'
        ? const Color(0xFF476B91)
        : const Color(0xFF8A6731);
    final label = emergency
        ? 'Emergency'
        : status == 'sending'
        ? 'Awaiting delivery'
        : status == 'failed'
        ? 'Failed delivery'
        : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
