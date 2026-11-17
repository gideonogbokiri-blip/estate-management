import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateAnnouncementsApiPage extends StatefulWidget {
  const EstateAnnouncementsApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });
  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<EstateAnnouncementsApiPage> createState() =>
      _EstateAnnouncementsApiPageState();
}

class _EstateAnnouncementsApiPageState
    extends State<EstateAnnouncementsApiPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _emergency = false;
  bool _busy = false;
  String? _error;
  late Future<List<EstateAnnouncementRecord>> _announcements;

  @override
  void initState() {
    super.initState();
    _announcements = widget.repository.loadEstateAnnouncements(widget.estateId);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (_title.text.trim().length < 3 || _body.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title and message before saving.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createEstateAnnouncementDraft(
        estateId: widget.estateId,
        title: _title.text.trim(),
        body: _body.text.trim(),
        priority: _emergency ? 'emergency' : 'normal',
      );
      _title.clear();
      _body.clear();
      _emergency = false;
      _reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement draft saved.')),
        );
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Draft could not be saved.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reload() => setState(
    () => _announcements = widget.repository.loadEstateAnnouncements(
      widget.estateId,
    ),
  );

  Future<void> _publish(EstateAnnouncementRecord announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          announcement.category == 'emergency'
              ? 'Publish emergency notice?'
              : 'Publish announcement?',
        ),
        content: const Text(
          'This will make the notice visible in the in-app feed for active residents and landlords in this estate. Email and SMS are not sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.publishEstateAnnouncement(
        estateId: widget.estateId,
        announcementId: announcement.id,
      );
      _reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement published to the estate in-app feed.'),
          ),
        );
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Announcement could not be published.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Estate announcements')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.estateName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Write an update for residents and landlords in this estate.',
              style: TextStyle(color: EstateColors.muted),
            ),
            const SizedBox(height: 14),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Publishing adds the notice to the authenticated in-app feed. No push, email or SMS delivery is connected yet.',
                  style: TextStyle(color: EstateColors.muted, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'New announcement',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _body,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _emergency,
                      title: const Text('Emergency priority'),
                      subtitle: const Text(
                        'Emergency notices can only be created and published by an estate administrator.',
                      ),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _emergency = value),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFF984B43)),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _saveDraft,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save draft'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent announcements',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            FutureBuilder<List<EstateAnnouncementRecord>>(
              future: _announcements,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Card(
                    child: ListTile(
                      title: const Text('Announcements could not be loaded'),
                      subtitle: Text(snapshot.error.toString()),
                      trailing: IconButton(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                final items = snapshot.requireData;
                if (items.isEmpty)
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No announcements yet.')),
                    ),
                  );
                return Column(
                  children: [
                    for (final item in items)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.category == 'emergency'
                                ? const Color(0xFFFFE9E5)
                                : const Color(0xFFE9F0EA),
                            child: Icon(
                              item.category == 'emergency'
                                  ? Icons.warning_amber_rounded
                                  : Icons.campaign_outlined,
                              color: item.category == 'emergency'
                                  ? const Color(0xFF984B43)
                                  : EstateColors.forest,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.body}\n${item.audienceLabel} · ${item.status}${item.publishedAt == null ? '' : ' · ${_date(item.publishedAt!)}'}',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: item.status == 'draft'
                              ? TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _publish(item),
                                  child: const Text('Publish'),
                                )
                              : const Chip(label: Text('Published')),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  String _date(DateTime value) =>
      '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}';
}
