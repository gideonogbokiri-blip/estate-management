import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class SecurityIncidentsPage extends StatefulWidget {
  const SecurityIncidentsPage({
    super.key,
    required this.incidents,
    required this.repository,
    required this.onIncidentsChanged,
  });
  final List<EstateSecurityIncident> incidents;
  final EstateAdminRepository repository;
  final VoidCallback onIncidentsChanged;

  @override
  State<SecurityIncidentsPage> createState() => _SecurityIncidentsPageState();
}

class _SecurityIncidentsPageState extends State<SecurityIncidentsPage> {
  final _search = TextEditingController();
  late List<EstateSecurityIncident> _incidents;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _incidents = List.of(widget.incidents);
  }

  @override
  void didUpdateWidget(covariant SecurityIncidentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.incidents, widget.incidents)) {
      _incidents = List.of(widget.incidents);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _incidents
        .where((item) => !const ['resolved', 'closed'].contains(item.status))
        .length;
    final urgent = _incidents
        .where((item) => item.priority.toLowerCase() == 'urgent')
        .length;
    final contained = _incidents
        .where((item) => item.status == 'contained')
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = _incidents.where((item) {
      final matchesQuery =
          query.isEmpty ||
          '${item.id} ${item.category} ${item.locationLabel ?? ''} ${item.gateLabel ?? ''} ${item.reporterName}'
              .toLowerCase()
              .contains(query);
      return matchesQuery && (_status == 'all' || item.status == _status);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security and incidents',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Track reported safety and security incidents across the estate.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _createPreviewReport,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Report incident'),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const _IncidentPreviewNotice(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _IncidentMetric(
                label: 'Open incidents',
                value: '$open',
                icon: Icons.shield_outlined,
                color: const Color(0xFF476B91),
              ),
              _IncidentMetric(
                label: 'Urgent priority',
                value: '$urgent',
                icon: Icons.priority_high_rounded,
                color: const Color(0xFF984B43),
              ),
              _IncidentMetric(
                label: 'Contained',
                value: '$contained',
                icon: Icons.health_and_safety_outlined,
                color: EstateColors.forest,
              ),
            ];
            return constraints.maxWidth < 750
                ? Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: card,
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i == cards.length - 1 ? 0 : 12,
                            ),
                            child: cards[i],
                          ),
                        ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 23),
        Row(
          children: [
            Expanded(
              child: Text(
                'Incident register',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${visible.length} records',
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search incident, location or reporter',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Incident status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'reported', child: Text('Reported')),
                  DropdownMenuItem(
                    value: 'acknowledged',
                    child: Text('Acknowledged'),
                  ),
                  DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                  DropdownMenuItem(
                    value: 'investigating',
                    child: Text('Investigating'),
                  ),
                  DropdownMenuItem(
                    value: 'contained',
                    child: Text('Contained'),
                  ),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'reopened', child: Text('Reopened')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const _IncidentEmpty()
        else
          for (final incident in visible)
            _IncidentCard(
              incident: incident,
              onOpenDetails: incident.id.startsWith('PREVIEW-')
                  ? () => _openPreviewDetails(incident)
                  : null,
              onTransition: incident.id.startsWith('PREVIEW-')
                  ? (command) => _transitionPreviewIncident(incident, command)
                  : null,
            ),
      ],
    );
  }

  Future<void> _createPreviewReport() async {
    final draft =
        await showDialog<
          ({
            String category,
            String priority,
            String description,
            String location,
            DateTime observedAt,
          })
        >(
          context: context,
          builder: (context) => const _IncidentReportDialog(),
        );
    if (draft == null || !mounted) return;
    try {
      final incident = await widget.repository.createSecurityIncidentPreview(
        category: draft.category,
        priority: draft.priority,
        description: draft.description,
        location: draft.location,
        observedAt: draft.observedAt,
      );
      if (!mounted) return;
      setState(() => _incidents = [incident, ..._incidents]);
      widget.onIncidentsChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident added to this preview only. No notification was sent.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident could not be added to this preview.'),
        ),
      );
    }
  }

  Future<void> _openPreviewDetails(EstateSecurityIncident incident) async {
    try {
      final details = await widget.repository
          .readSecurityIncidentPreviewDetails(incident.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(incident.category),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${incident.id} · Preview only'),
                const SizedBox(height: 12),
                Text(details.description),
                if (details.history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Preview activity',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  for (final event in details.history) ...[
                    Text(
                      '${_incidentActionLabel(event.action)} · ${_incidentDateTime(event.occurredAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (event.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 5),
                        child: Text(
                          event.reason!,
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 14),
                const Text(
                  'This local detail is not part of the production queue summary.',
                  style: TextStyle(color: EstateColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident details are unavailable.')),
      );
    }
  }

  Future<void> _transitionPreviewIncident(
    EstateSecurityIncident incident,
    String command,
  ) async {
    final reasonRequired = const {
      'contain',
      'resolve',
      'close',
      'reopen',
    }.contains(command);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _IncidentTransitionDialog(
        command: command,
        reasonRequired: reasonRequired,
      ),
    );
    if (reason == null || !mounted) return;
    try {
      final updated = await widget.repository.transitionSecurityIncidentPreview(
        incidentId: incident.id,
        command: command,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        final index = _incidents.indexWhere((item) => item.id == incident.id);
        if (index >= 0) _incidents[index] = updated;
      });
      widget.onIncidentsChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preview status updated. No live incident or audit record was changed.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This incident action is not available in the preview.',
          ),
        ),
      );
    }
  }
}

String _incidentDateTime(DateTime value) =>
    '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _incidentActionLabel(String command) => switch (command) {
  'acknowledge' => 'Acknowledged',
  'investigate' => 'Investigation started',
  'contain' => 'Marked contained',
  'resolve' => 'Resolved',
  'close' => 'Closed',
  'reopen' => 'Reopened',
  _ => command,
};

class _IncidentTransitionDialog extends StatefulWidget {
  const _IncidentTransitionDialog({
    required this.command,
    required this.reasonRequired,
  });
  final String command;
  final bool reasonRequired;

  @override
  State<_IncidentTransitionDialog> createState() =>
      _IncidentTransitionDialogState();
}

class _IncidentTransitionDialogState extends State<_IncidentTransitionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_incidentActionLabel(widget.command)),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: widget.reasonRequired ? 'Reason' : 'Note (optional)',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  widget.reasonRequired &&
                      (value == null || value.trim().isEmpty)
                  ? 'Enter a reason to continue.'
                  : null,
            ),
            const SizedBox(height: 6),
            const Text(
              'Preview only. This action does not write an incident update or audit event to the estate service.',
              style: TextStyle(
                color: EstateColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop(_reason.text.trim());
        },
        child: const Text('Update preview'),
      ),
    ],
  );
}

class _IncidentReportDialog extends StatefulWidget {
  const _IncidentReportDialog();

  @override
  State<_IncidentReportDialog> createState() => _IncidentReportDialogState();
}

class _IncidentReportDialogState extends State<_IncidentReportDialog> {
  static const _categories = [
    'Unauthorized access',
    'Safety concern',
    'Property damage',
    'Noise disturbance',
    'Other',
  ];
  static const _priorities = ['Normal', 'High', 'Urgent'];
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _location = TextEditingController();
  String _category = _categories.first;
  String _priority = _priorities.first;
  DateTime _observedAt = DateTime.now();

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report an incident'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final priority in _priorities)
                    DropdownMenuItem(value: priority, child: Text(priority)),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? _priority),
              ),
              TextFormField(
                controller: _location,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter where this happened.'
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Observed at'),
                subtitle: Text(_incidentDateTime(_observedAt)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: _chooseObservedTime,
              ),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Incident description',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Describe what happened.'
                    : null,
              ),
              const SizedBox(height: 6),
              const Text(
                'Preview only. The form uses sample categories and does not create an incident, notify staff or write an audit event.',
                style: TextStyle(
                  color: EstateColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Save preview report'),
      ),
    ],
  );

  Future<void> _chooseObservedTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observed time cannot be in the future.')),
      );
      return;
    }
    setState(() => _observedAt = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      category: _category,
      priority: _priority,
      description: _description.text.trim(),
      location: _location.text.trim(),
      observedAt: _observedAt,
    ));
  }
}

class _IncidentPreviewNotice extends StatelessWidget {
  const _IncidentPreviewNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFF0DCA9)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 19, color: Color(0xFF8A5B13)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample incident summaries only. Investigation details and private attachments require the authorized incident service; every status change must be audited.',
            style: TextStyle(
              color: Color(0xFF795416),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IncidentMetric extends StatelessWidget {
  const _IncidentMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .1),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    this.onOpenDetails,
    this.onTransition,
  });
  final EstateSecurityIncident incident;
  final VoidCallback? onOpenDetails;
  final ValueChanged<String>? onTransition;
  @override
  Widget build(BuildContext context) {
    final status = _incidentStatus(incident.status);
    final priority = _priorityStyle(incident.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 245,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${incident.id} · ${incident.locationLabel ?? incident.gateLabel ?? 'Estate grounds'}',
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 175,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observed ${incident.observedAt}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reported ${incident.reportedAt} · ${incident.reporterName}',
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (incident.gateLabel != null)
              _IncidentChip(
                label: incident.gateLabel!,
                foreground: const Color(0xFF476B91),
                background: const Color(0xFFEAF1F8),
              ),
            _IncidentChip(
              label: incident.priority,
              foreground: priority.$1,
              background: priority.$2,
            ),
            _IncidentChip(
              label: status.$1,
              foreground: status.$2,
              background: status.$3,
            ),
            if (onOpenDetails != null)
              OutlinedButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('Details'),
              ),
            if (onTransition != null)
              PopupMenuButton<String>(
                tooltip: 'Update preview status',
                onSelected: onTransition,
                itemBuilder: (context) => [
                  for (final action in _availableIncidentActions(
                    incident.status,
                  ))
                    PopupMenuItem(
                      value: action,
                      child: Text(_incidentActionLabel(action)),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.more_horiz_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<String> _availableIncidentActions(String status) => switch (status) {
  'reported' => ['acknowledge'],
  'acknowledged' => ['investigate'],
  'investigating' => ['contain', 'resolve'],
  'contained' => ['investigate', 'resolve'],
  'resolved' => ['close', 'reopen'],
  'closed' => ['reopen'],
  'reopened' => ['acknowledge'],
  _ => const [],
};

class _IncidentChip extends StatelessWidget {
  const _IncidentChip({
    required this.label,
    required this.foreground,
    required this.background,
  });
  final String label;
  final Color foreground;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
    ),
  );
}

class _IncidentEmpty extends StatelessWidget {
  const _IncidentEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 38, color: EstateColors.muted),
          SizedBox(height: 10),
          Text('No incidents match these filters.'),
        ],
      ),
    ),
  );
}

(String, Color, Color) _incidentStatus(String status) => switch (status) {
  'reported' => ('Reported', const Color(0xFFFFF2D8), const Color(0xFF8A5B13)),
  'acknowledged' => (
    'Acknowledged',
    const Color(0xFFEAF1F8),
    const Color(0xFF476B91),
  ),
  'assigned' => ('Assigned', const Color(0xFFF0EAF7), const Color(0xFF765797)),
  'investigating' => (
    'Investigating',
    const Color(0xFFF0EAF7),
    const Color(0xFF765797),
  ),
  'contained' => ('Contained', const Color(0xFFE9F4ED), EstateColors.forest),
  'resolved' => ('Resolved', const Color(0xFFE9F4ED), EstateColors.forest),
  'closed' => ('Closed', const Color(0xFFF0F1F2), EstateColors.muted),
  'reopened' => ('Reopened', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  _ => (status, const Color(0xFFF0F1F2), EstateColors.muted),
};

(Color, Color) _priorityStyle(String priority) => switch (priority
    .toLowerCase()) {
  'urgent' || 'critical' => (const Color(0xFF984B43), const Color(0xFFF9EDEC)),
  'high' => (const Color(0xFF8A5B13), const Color(0xFFFFF2D8)),
  _ => (EstateColors.muted, const Color(0xFFF0F1F2)),
};
