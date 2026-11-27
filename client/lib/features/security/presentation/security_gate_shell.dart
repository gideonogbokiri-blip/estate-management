import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../../core/navigation/auth_redirect.dart';
import '../data/security_repository.dart';

class SecurityGateShell extends StatefulWidget {
  const SecurityGateShell({super.key, required this.repository});
  final SecurityRepository repository;
  @override
  State<SecurityGateShell> createState() => _SecurityGateShellState();
}

class _SecurityGateShellState extends State<SecurityGateShell> {
  int _tab = 0;
  late Future<SecurityGateContext?> _gate;
  late Future<List<SecurityExpectedVisitor>> _expected;
  late Future<List<SecurityCurrentVisitor>> _current;
  late Future<List<SecurityEmergencyContact>> _contacts;
  late Future<List<SecurityAccessEvent>> _accessEvents;
  late Future<List<SecurityIncidentReport>> _reports;

  @override
  void initState() {
    super.initState();
    _gate = widget.repository.loadAssignedGate();
    _expected = _loadExpected();
    _current = _loadCurrent();
    _contacts = _loadContacts();
    _accessEvents = _loadAccessEvents();
    _reports = _loadReports();
  }

  Future<List<SecurityExpectedVisitor>> _loadExpected() async {
    if (await _gate == null) return const [];
    return widget.repository.loadExpectedVisitors();
  }

  Future<List<SecurityCurrentVisitor>> _loadCurrent() async {
    if (await _gate == null) return const [];
    return widget.repository.loadCurrentVisitors();
  }

  Future<List<SecurityEmergencyContact>> _loadContacts() async {
    if (await _gate == null) return const [];
    return widget.repository.loadEmergencyContacts();
  }

  Future<List<SecurityAccessEvent>> _loadAccessEvents() async {
    if (await _gate == null) return const [];
    return widget.repository.loadAccessEvents();
  }

  Future<List<SecurityIncidentReport>> _loadReports() async {
    if (await _gate == null) return const [];
    return widget.repository.loadMyIncidentReports();
  }

  void _refresh() => setState(() {
    _gate = widget.repository.loadAssignedGate();
    _expected = _loadExpected();
    _current = _loadCurrent();
    _contacts = _loadContacts();
    _accessEvents = _loadAccessEvents();
    _reports = _loadReports();
  });

  Future<void> _signIn() async {
    final credentials = await showDialog<({String email, String password})>(
      context: context,
      builder: (context) => const _SecuritySignInDialog(),
    );
    if (credentials == null || !mounted) return;
    try {
      await widget.repository.signIn(
        email: credentials.email,
        password: credentials.password,
      );
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign in failed: $error')));
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    _refresh();
    await _signIn();
  }

  Future<void> _manualAdmission() async {
    final request =
        await showDialog<({String name, String property, String reason})>(
          context: context,
          builder: (context) =>
              _ManualAdmissionDialog(preview: widget.repository.isPreview),
        );
    if (request == null || !mounted) return;
    try {
      await widget.repository.createManualAdmission(
        visitorName: request.name,
        propertyReference: request.property,
        reason: request.reason,
      );
      if (!mounted) return;
      _refresh();
      setState(() => _tab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Manual admission added to this preview only.'
                : '${request.name} admitted and the access event recorded.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Manual admission could not be added.'
                : 'Manual admission failed. Check the property reference and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _checkOutVisitorPreview(SecurityCurrentVisitor visitor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check out visitor?'),
        content: Text(
          widget.repository.isPreview
              ? 'This will remove ${visitor.visitorName} from the current visitors list in this preview. No live access event will be recorded.'
              : 'Record ${visitor.visitorName} as checked out from this gate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              widget.repository.isPreview
                  ? 'Check out in preview'
                  : 'Check out',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.checkOutVisitor(visitor.visitId);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Visitor removed from the preview list. No live event was recorded.'
                : 'Visitor checked out and the access event was recorded.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Visitor could not be removed from the preview list.'
                : 'Visitor could not be checked out. Refresh and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _checkInVisitor() async {
    final credential = await showDialog<String>(
      context: context,
      builder: (context) => const _VisitorCredentialDialog(),
    );
    if (credential == null || !mounted) return;
    try {
      final admitted = await widget.repository.checkInVisitor(credential);
      if (!mounted) return;
      _refresh();
      setState(() => _tab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${admitted.visitorName} checked in at ${admitted.propertyLabel}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The pass could not be verified: $error')),
      );
    }
  }

  Future<void> _reportIncident() async {
    final report =
        await showDialog<
          ({
            String category,
            String priority,
            String location,
            String description,
            DateTime observedAt,
          })
        >(
          context: context,
          builder: (context) =>
              _IncidentReportDialog(preview: widget.repository.isPreview),
        );
    if (report == null || !mounted) return;
    try {
      await widget.repository.createIncidentReport(
        category: report.category,
        priority: report.priority,
        location: report.location,
        description: report.description,
        observedAt: report.observedAt,
      );
      if (!mounted) return;
      _refresh();
      setState(() => _tab = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Incident saved in this preview only. No live report was submitted.'
                : 'Incident report submitted to the estate team.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.isPreview
                ? 'Incident could not be saved in this preview.'
                : 'Incident could not be submitted. Refresh and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SecurityGateContext?>(
    future: _gate,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return singleSignInRedirect();
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final gate = snapshot.requireData;
      if (gate == null) {
        return _GateState(
          icon: Icons.lock_outline,
          title: 'No assigned gate',
          detail: 'This account has no active gate assignment. Sign in with another security account at /login/ or contact your supervisor.',
          action: 'Switch account',
          onAction: goToSingleSignIn,
        );
      }
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: EstateColors.forest),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gate.estateName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      gate.gateName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EstateColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh gate data',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Sign out / switch account',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            _GateShiftBanner(gate: gate),
            Expanded(
              child: _tab == 0
                  ? _OverviewTab(
                      expected: _expected,
                      current: _current,
                      contacts: _contacts,
                      onOpenVisitors: () => setState(() => _tab = 1),
                      onOpenEmergency: () => setState(() => _tab = 3),
                      onReportIncident: _reportIncident,
                      preview: widget.repository.isPreview,
                    )
                  : _tab == 1
                  ? _VisitorLists(
                      expected: _expected,
                      current: _current,
                      onManualAdmission: _manualAdmission,
                      onCheckOut: _checkOutVisitorPreview,
                      onCheckIn: _checkInVisitor,
                      supportsManualAdmission:
                          widget.repository.supportsManualAdmission,
                      preview: widget.repository.isPreview,
                    )
                  : _tab == 2
                  ? _IncidentReportsPage(
                      reports: _reports,
                      onReportIncident: _reportIncident,
                      preview: widget.repository.isPreview,
                    )
                  : _tab == 3
                  ? _EmergencyList(contacts: _contacts)
                  : _AccessLogPage(events: _accessEvents),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Gate',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Visitors',
            ),
            NavigationDestination(
              icon: Icon(Icons.report_gmailerrorred_outlined),
              selectedIcon: Icon(Icons.report_gmailerrorred),
              label: 'Incidents',
            ),
            NavigationDestination(
              icon: Icon(Icons.emergency_outlined),
              selectedIcon: Icon(Icons.emergency),
              label: 'Emergency',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Access log',
            ),
          ],
        ),
      );
    },
  );
}

class _GateShiftBanner extends StatelessWidget {
  const _GateShiftBanner({required this.gate});
  final SecurityGateContext gate;
  @override
  Widget build(BuildContext context) => Container(
    color: EstateColors.forest,
    padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
    child: Row(
      children: [
        const Icon(Icons.access_time, color: Colors.white70, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            gate.shiftLabel,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const Icon(
          Icons.verified_user_outlined,
          color: Colors.white70,
          size: 16,
        ),
        const SizedBox(width: 5),
        Text(
          gate.assignmentLabel,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.expected,
    required this.current,
    required this.contacts,
    required this.onOpenVisitors,
    required this.onOpenEmergency,
    required this.onReportIncident,
    required this.preview,
  });
  final Future<List<SecurityExpectedVisitor>> expected;
  final Future<List<SecurityCurrentVisitor>> current;
  final Future<List<SecurityEmergencyContact>> contacts;
  final VoidCallback onOpenVisitors;
  final VoidCallback onOpenEmergency;
  final VoidCallback onReportIncident;
  final bool preview;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      if (preview) ...const [_PreviewBanner(), SizedBox(height: 17)],
      Text('Gate overview', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text(
        'Visitor activity at your assigned gate.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onReportIncident,
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('Report an incident'),
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<SecurityCurrentVisitor>>(
        future: current,
        builder: (context, snapshot) => Row(
          children: [
            Expanded(
              child: _CountCard(
                label: 'Currently inside',
                count: snapshot.data?.length,
                icon: Icons.sensor_door_outlined,
                color: const Color(0xFF476B91),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _ExpectedCountCard(expected: expected)),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              'Currently inside',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(onPressed: onOpenVisitors, child: const Text('View all')),
        ],
      ),
      FutureBuilder<List<SecurityCurrentVisitor>>(
        future: current,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _LoadTileError();
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.requireData.isEmpty) {
            return const _EmptyCard(
              message: 'No visitors are currently checked in at this gate.',
            );
          }
          return Column(
            children: snapshot.requireData
                .take(4)
                .map((visitor) => _CurrentVisitorCard(visitor: visitor))
                .toList(),
          );
        },
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<SecurityEmergencyContact>>(
        future: contacts,
        builder: (context, snapshot) => Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFECEA),
              child: Icon(Icons.emergency_outlined, color: EstateColors.red),
            ),
            title: const Text(
              'Emergency contacts',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              snapshot.data?.firstOrNull?.displayName ??
                  'No emergency contacts configured',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenEmergency,
          ),
        ),
      ),
    ],
  );
}

class _IncidentReportsPage extends StatelessWidget {
  const _IncidentReportsPage({
    required this.reports,
    required this.onReportIncident,
    required this.preview,
  });

  final Future<List<SecurityIncidentReport>> reports;
  final VoidCallback onReportIncident;
  final bool preview;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(
        'My incident reports',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 5),
      const Text(
        'Record a safety or security concern for the estate team.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 14),
      if (preview) ...const [_PreviewBanner(), SizedBox(height: 12)],
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onReportIncident,
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('Report an incident'),
        ),
      ),
      const SizedBox(height: 18),
      Text('Reports', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 9),
      FutureBuilder<List<SecurityIncidentReport>>(
        future: reports,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _LoadTileError();
          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final items = snapshot.requireData;
          if (items.isEmpty) {
            return _EmptyCard(
              message: preview
                  ? 'You have not prepared any incident reports in this preview.'
                  : 'No incident reports have been submitted from this account.',
            );
          }
          return Column(
            children: items
                .map(
                  (report) => _IncidentReportCard(
                    report: report,
                    preview: preview,
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _IncidentReportCard extends StatelessWidget {
  const _IncidentReportCard({required this.report, required this.preview});
  final SecurityIncidentReport report;
  final bool preview;

  static const _categoryLabels = {
    'safety': 'Safety concern',
    'theft': 'Theft',
    'suspicious_activity': 'Suspicious activity',
    'property_damage': 'Property damage',
    'access_control': 'Access control',
    'other': 'Other',
  };
  static const _statusLabels = {
    'reported': 'Reported',
    'acknowledged': 'Acknowledged',
    'investigating': 'Investigating',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  @override
  Widget build(BuildContext context) {
    final referenceLabel = preview
        ? '${report.reference} (preview)'
        : report.reference;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: EstateColors.forest),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _categoryLabels[report.category] ?? report.category,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _ReportPriorityPill(priority: report.priority),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$referenceLabel · ${_statusLabels[report.status] ?? report.status}',
            style: const TextStyle(color: EstateColors.muted, fontSize: 11),
          ),
          if (report.location != null) ...[
            const SizedBox(height: 6),
            Text('Location: ${report.location}'),
          ],
          const SizedBox(height: 6),
          Text(
            'Observed ${_formatReportDate(report.observedAt)}',
            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(report.description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 10),
          Text(
            preview
                ? 'Not submitted to the estate team.'
                : 'Recorded for the estate security team.',
            style: const TextStyle(color: EstateColors.muted, fontSize: 11),
          ),
        ],
      ),
      ),
    );
  }
}

class _ReportPriorityPill extends StatelessWidget {
  const _ReportPriorityPill({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    String label;
    final color = switch (priority.toLowerCase()) {
      'urgent' => EstateColors.red,
      'high' => const Color(0xFF8A5B13),
      _ => EstateColors.muted,
    };
    label = switch (priority.toLowerCase()) {
      'urgent' => 'Urgent',
      'high' => 'High',
      _ => 'Normal',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IncidentReportDialog extends StatefulWidget {
  const _IncidentReportDialog({required this.preview});
  final bool preview;

  @override
  State<_IncidentReportDialog> createState() => _IncidentReportDialogState();
}

class _IncidentReportDialogState extends State<_IncidentReportDialog> {
  static const _categories = {
    'safety': 'Safety concern',
    'theft': 'Theft',
    'suspicious_activity': 'Suspicious activity',
    'property_damage': 'Property damage',
    'access_control': 'Access control',
    'other': 'Other',
  };
  static const _priorities = {
    'normal': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
  };
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _category = 'safety';
  String _priority = 'normal';
  DateTime _observedAt = DateTime.now();

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Report an incident'),
    content: SizedBox(
      width: 460,
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
                  for (final entry in _categories.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final entry in _priorities.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? _priority),
              ),
              TextFormField(
                controller: _location,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('When did it happen?'),
                subtitle: Text(_formatReportDate(_observedAt)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: _chooseObservedAt,
              ),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Describe the incident.'
                    : null,
              ),
              const SizedBox(height: 6),
              if (widget.preview)
                const Text(
                  'Preview only. No report, notification or audit event will be created.',
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
        child: Text(widget.preview ? 'Save preview report' : 'Submit report'),
      ),
    ],
  );

  Future<void> _chooseObservedAt() async {
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
    final observedAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (observedAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The observed time cannot be in the future.'),
        ),
      );
      return;
    }
    setState(() => _observedAt = observedAt);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      category: _category,
      priority: _priority,
      location: _location.text.trim(),
      description: _description.text.trim(),
      observedAt: _observedAt,
    ));
  }
}

String _formatReportDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _ExpectedCountCard extends StatelessWidget {
  const _ExpectedCountCard({required this.expected});
  final Future<List<SecurityExpectedVisitor>> expected;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<SecurityExpectedVisitor>>(
        future: expected,
        builder: (context, snapshot) => _CountCard(
          label: 'Expected today',
          count: snapshot.data?.length,
          icon: Icons.event_available_outlined,
          color: EstateColors.forest,
        ),
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String label;
  final int? count;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count?.toString() ?? '—',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ManualAdmissionDialog extends StatefulWidget {
  const _ManualAdmissionDialog({required this.preview});
  final bool preview;

  @override
  State<_ManualAdmissionDialog> createState() => _ManualAdmissionDialogState();
}

class _ManualAdmissionDialogState extends State<_ManualAdmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _property = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _property.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Manual admission'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Visitor name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the visitor name.'
                    : null,
              ),
              TextFormField(
                controller: _property,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Property reference',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the property reference.'
                    : null,
              ),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason (10–500 characters)',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Provide a reason of at least 10 characters.'
                    : null,
              ),
              const SizedBox(height: 8),
              if (widget.preview)
                const Text(
                  'Preview only. This does not resolve the property, verify gate permission or create a live access event.',
                  style: TextStyle(
                    color: EstateColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                )
              else
                const Text(
                  'Use the estate property reference (for example PC-001). The admission is recorded with your staff identity and a reason.',
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop((
            name: _name.text.trim(),
            property: _property.text.trim(),
            reason: _reason.text.trim(),
          ));
        },
        child: Text(widget.preview ? 'Add preview record' : 'Admit visitor'),
      ),
    ],
  );
}

class _VisitorLists extends StatefulWidget {
  const _VisitorLists({
    required this.expected,
    required this.current,
    required this.onManualAdmission,
    required this.onCheckOut,
    required this.onCheckIn,
    required this.supportsManualAdmission,
    required this.preview,
  });
  final Future<List<SecurityExpectedVisitor>> expected;
  final Future<List<SecurityCurrentVisitor>> current;
  final VoidCallback onManualAdmission;
  final ValueChanged<SecurityCurrentVisitor> onCheckOut;
  final VoidCallback onCheckIn;
  final bool supportsManualAdmission;
  final bool preview;
  @override
  State<_VisitorLists> createState() => _VisitorListsState();
}

class _VisitorListsState extends State<_VisitorLists> {
  bool _inside = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      if (widget.preview) ...const [_PreviewBanner(), SizedBox(height: 14)],
      Text('Visitor list', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      if (widget.supportsManualAdmission)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: widget.onManualAdmission,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Manual admission'),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search visitor or property',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Expected')),
          ButtonSegment(value: true, label: Text('Currently inside')),
        ],
        selected: {_inside},
        onSelectionChanged: (value) => setState(() => _inside = value.first),
      ),
      const SizedBox(height: 12),
      if (_inside)
        FutureBuilder<List<SecurityCurrentVisitor>>(
          future: widget.current,
          builder: (context, snapshot) =>
              _VisitorResult<SecurityCurrentVisitor>(
                snapshot: snapshot,
                filter: (item) =>
                    '${item.visitorName} ${item.hostName} ${item.propertyLabel}'
                        .toLowerCase()
                        .contains(_search.text.toLowerCase()),
                card: (item) => _CurrentVisitorCard(
                  visitor: item,
                  onCheckOut: () => widget.onCheckOut(item),
                ),
              ),
        )
      else
        FutureBuilder<List<SecurityExpectedVisitor>>(
          future: widget.expected,
          builder: (context, snapshot) =>
              _VisitorResult<SecurityExpectedVisitor>(
                snapshot: snapshot,
                filter: (item) =>
                    '${item.visitorName} ${item.hostName} ${item.propertyLabel}'
                        .toLowerCase()
                        .contains(_search.text.toLowerCase()),
                card: (item) => _ExpectedVisitorCard(
                  visitor: item,
                  onCheckIn: () => widget.onCheckIn(),
                  preview: widget.preview,
                ),
              ),
        ),
    ],
  );
}

class _VisitorResult<T> extends StatelessWidget {
  const _VisitorResult({
    required this.snapshot,
    required this.filter,
    required this.card,
  });
  final AsyncSnapshot<List<T>> snapshot;
  final bool Function(T) filter;
  final Widget Function(T) card;
  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return const _LoadTileError();
    }
    if (!snapshot.hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final items = snapshot.requireData.where(filter).toList();
    if (items.isEmpty) {
      return const _EmptyCard(message: 'No visitor records match this view.');
    }
    return Column(children: items.map(card).toList());
  }
}

class _ExpectedVisitorCard extends StatelessWidget {
  const _ExpectedVisitorCard({
    required this.visitor,
    required this.onCheckIn,
    required this.preview,
  });
  final SecurityExpectedVisitor visitor;
  final VoidCallback onCheckIn;
  final bool preview;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF3EE),
                child: Icon(Icons.person_outline, color: EstateColors.forest),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.visitorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Host: ${visitor.hostName}',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.schedule_outlined,
                size: 17,
                color: EstateColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 11),
          _SmallMeta(
            icon: Icons.home_work_outlined,
            label: visitor.propertyLabel,
          ),
          const SizedBox(height: 6),
          _SmallMeta(
            icon: Icons.event_outlined,
            label: 'Valid until ${visitor.validUntilLabel}',
          ),
          if (visitor.vehicleSummary != null) ...[
            const SizedBox(height: 6),
            _SmallMeta(
              icon: Icons.directions_car_outlined,
              label: visitor.vehicleSummary!,
            ),
          ],
          if (preview)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Pass verification is not available in this preview.',
                style: TextStyle(color: EstateColors.muted, fontSize: 11),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Enter pass code'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CurrentVisitorCard extends StatelessWidget {
  const _CurrentVisitorCard({required this.visitor, this.onCheckOut});
  final SecurityCurrentVisitor visitor;
  final VoidCallback? onCheckOut;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEAF3EE),
        child: Icon(Icons.person_outline, color: EstateColors.forest),
      ),
      title: Text(
        visitor.visitorName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${visitor.propertyLabel} · ${visitor.hostName}\nChecked in ${visitor.checkedInLabel}${visitor.admissionType == 'manual' ? ' · Manual admission' : ''}',
        style: const TextStyle(fontSize: 11, height: 1.5),
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Check out visitor',
        onPressed: onCheckOut,
        icon: const Icon(Icons.logout_outlined),
      ),
    ),
  );
}

class _EmergencyList extends StatelessWidget {
  const _EmergencyList({required this.contacts});
  final Future<List<SecurityEmergencyContact>> contacts;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(
        'Emergency contacts',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 5),
      const Text(
        'Use the estate-approved contact for urgent response.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<SecurityEmergencyContact>>(
        future: contacts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _LoadTileError();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.requireData.isEmpty) {
            return const _EmptyCard(
              message:
                  'No emergency contacts are configured for this estate. '
                  'Use the contact published by your estate manager.',
            );
          }
          return Column(
            children: snapshot.requireData
                .map(
                  (contact) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFECEA),
                        child: Icon(
                          Icons.call_outlined,
                          color: EstateColors.red,
                        ),
                      ),
                      title: Text(
                        contact.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${contact.displayName}\n${contact.phoneDisplay}',
                        style: const TextStyle(height: 1.5),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(
                        Icons.call,
                        color: EstateColors.forest,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _AccessLogPage extends StatelessWidget {
  const _AccessLogPage({required this.events});
  final Future<List<SecurityAccessEvent>> events;

  static const _labels = {
    'entry': 'Visitor entry',
    'exit': 'Visitor exit',
    'denied': 'Credential denied',
    'manual_admission': 'Manual admission',
  };

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text('Access log', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 5),
      const Text(
        'Recent gate events recorded by the estate service.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<SecurityAccessEvent>>(
        future: events,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _LoadTileError();
          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.requireData.isEmpty) {
            return const _EmptyCard(
              message: 'No gate events have been recorded yet.',
            );
          }
          return Column(
            children: snapshot.requireData
                .map(
                  (event) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF3EE),
                        child: Icon(
                          Icons.sensor_door_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: Text(
                        _labels[event.eventKind] ?? event.eventKind,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${event.occurredAt}${event.propertyLabel != null ? ' · ${event.propertyLabel}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: EstateColors.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
      ),
    ],
  );
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF1D9AE)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: EstateColors.amber),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Preview gate data. Assignment and visitor verification will be handled by the estate security service.',
            style: TextStyle(fontSize: 11, color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: EstateColors.muted),
        ),
      ),
    ),
  );
}

class _LoadTileError extends StatelessWidget {
  const _LoadTileError();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Gate records are unavailable. Refresh to try again.'),
    ),
  );
}

class _SecuritySignInDialog extends StatefulWidget {
  const _SecuritySignInDialog();

  @override
  State<_SecuritySignInDialog> createState() => _SecuritySignInDialogState();
}

class _SecuritySignInDialogState extends State<_SecuritySignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Security staff sign in'),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
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
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            email: _email.text.trim(),
            password: _password.text,
          ));
        },
        child: const Text('Sign in'),
      ),
    ],
  );
}

class _VisitorCredentialDialog extends StatefulWidget {
  const _VisitorCredentialDialog();

  @override
  State<_VisitorCredentialDialog> createState() =>
      _VisitorCredentialDialogState();
}

class _VisitorCredentialDialogState extends State<_VisitorCredentialDialog> {
  final _credential = TextEditingController();

  @override
  void dispose() {
    _credential.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify visitor pass'),
    content: SizedBox(
      width: 360,
      child: TextField(
        controller: _credential,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Visitor PIN or pass code',
          helperText:
              'The code is sent securely and is never shown in visitor lists.',
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
          if (_credential.text.trim().isEmpty) return;
          Navigator.pop(context, _credential.text.trim());
        },
        child: const Text('Verify and check in'),
      ),
    ],
  );
}

class _GateState extends StatelessWidget {
  const _GateState({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: EstateColors.muted),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: EstateColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    ),
  );
}
