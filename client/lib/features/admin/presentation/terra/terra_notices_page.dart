import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Terra-styled estate notices with a manager create flow.
class TerraNoticesPage extends StatefulWidget {
  const TerraNoticesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraNoticesPage> createState() => _TerraNoticesPageState();
}

class _TerraNoticesPageState extends State<TerraNoticesPage> {
  List<EstateAnnouncementRecord> _notices = const [];
  bool _loading = true;
  bool _busy = false;
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
      _notices =
          await widget.repository.loadEstateAnnouncements(widget.estateId);
    } catch (_) {
      _error = 'Notices could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var priority = 'normal';
    final values = await showDialog<({String title, String body, String priority})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New notice'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: body,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(
                        value: 'emergency',
                        child: Text('Emergency'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialog(() => priority = value ?? priority),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty &&
                    body.text.trim().isNotEmpty) {
                  Navigator.pop(context, (
                    title: title.text.trim(),
                    body: body.text.trim(),
                    priority: priority,
                  ));
                }
              },
              child: const Text('Create notice'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.createEstateAnnouncementDraft(
        estateId: widget.estateId,
        title: values.title,
        body: values.body,
        priority: values.priority,
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Notice could not be created.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TerraBadgeTone _tone(String priority) => priority == 'emergency'
      ? TerraBadgeTone.danger
      : TerraBadgeTone.sage;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Notices'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TerraSectionTitle(
                    title: widget.estateName,
                    trailing: FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New notice'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Updates for residents and landlords in this estate.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TerraSectionTitle(
                    title: 'Notices',
                    trailing: TerraBadge(label: '${_notices.length}'),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_error != null)
                    TerraCard(
                      child: TerraEmpty(
                        message: _error!,
                        icon: Icons.error_outline,
                      ),
                    )
                  else if (_notices.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No notices have been posted for this estate.',
                        icon: Icons.campaign_outlined,
                      ),
                    )
                  else
                    for (final notice in _notices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notice.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: notice.category,
                                    tone: _tone(notice.category),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notice.body,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created ${AppFormat.date(notice.createdAt.toIso8601String())} · '
                                '${notice.audienceLabel} · ${notice.status}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TerraColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
