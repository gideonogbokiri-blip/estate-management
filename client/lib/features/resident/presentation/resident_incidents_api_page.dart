import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class ResidentIncidentsApiPage extends StatefulWidget {
  const ResidentIncidentsApiPage({
    super.key,
    required this.repository,
    required this.estates,
    required this.onBack,
  });
  final EstateApplicationApiRepository repository;
  final List<ManagedEstateChoice> estates;
  final VoidCallback onBack;
  @override
  State<ResidentIncidentsApiPage> createState() =>
      _ResidentIncidentsApiPageState();
}

class _ResidentIncidentsApiPageState extends State<ResidentIncidentsApiPage> {
  String? _estateId;
  List<EstateSecurityIncidentRecord> _items = const [];
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _estateId = widget.estates.firstOrNull?.id;
    _load();
  }

  Future<void> _load() async {
    final estateId = _estateId;
    if (estateId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await widget.repository.loadMySecurityIncidents(estateId);
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is EstateApiException
      ? error.message
      : 'Incident reports could not be loaded. Try again.';

  Future<void> _report() async {
    final estateId = _estateId;
    if (estateId == null) return;
    final description = TextEditingController();
    final location = TextEditingController();
    var category = 'safety';
    var priority = 'normal';
    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Report an incident'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Incident type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'safety',
                        child: Text('Safety concern'),
                      ),
                      DropdownMenuItem(
                        value: 'theft',
                        child: Text('Theft or attempted theft'),
                      ),
                      DropdownMenuItem(
                        value: 'suspicious_activity',
                        child: Text('Suspicious activity'),
                      ),
                      DropdownMenuItem(
                        value: 'property_damage',
                        child: Text('Property damage'),
                      ),
                      DropdownMenuItem(
                        value: 'access_control',
                        child: Text('Access control'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) =>
                        setDialog(() => category = value ?? category),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (value) =>
                        setDialog(() => priority = value ?? priority),
                  ),
                  TextField(
                    controller: location,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                    ),
                  ),
                  TextField(
                    controller: description,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'For immediate danger, contact estate security or local emergency services directly. This report does not trigger an emergency response.',
                      style: TextStyle(
                        color: EstateColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
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
                if (description.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'category': category,
                    'priority': priority,
                    'description': description.text.trim(),
                    if (location.text.trim().isNotEmpty)
                      'locationDescription': location.text.trim(),
                    'observedAt': DateTime.now().toUtc().toIso8601String(),
                  });
                }
              },
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    location.dispose();
    if (form == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createSecurityIncident(
        estateId: estateId,
        fields: form,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report submitted to the estate team.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadEvidence(EstateSecurityIncidentRecord incident) async {
    final estateId = _estateId;
    if (estateId == null || _saving) return;
    try {
      final selection = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (selection == null) return;
      final length = await selection.length();
      if (length == null || length == 0 || length > 10 * 1024 * 1024) {
        throw const EstateApiException('Choose a non-empty file up to 10 MB.');
      }
      setState(() {
        _saving = true;
        _error = null;
      });
      await widget.repository.uploadSecurityIncidentEvidence(
        estateId: estateId,
        incidentId: incident.id,
        fileName: selection.name,
        bytes: await selection.readAsBytes(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Private evidence attached to the report.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadEvidence(
    EstateSecurityIncidentRecord incident,
    EstateSecurityIncidentEvidenceRecord evidence,
  ) async {
    final estateId = _estateId;
    if (estateId == null) return;
    try {
      final bytes = await widget.repository.downloadSecurityIncidentEvidence(
        estateId: estateId,
        incidentId: incident.id,
        evidenceId: evidence.id,
      );
      await FilePicker.saveFile(fileName: evidence.displayName, bytes: bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  String _date(String raw) {
    final value = DateTime.tryParse(raw)?.toLocal();
    if (value == null) return raw;
    return '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(
      leading: IconButton(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Safety and incidents'),
      actions: [
        IconButton(
          onPressed: _loading || _saving ? null : _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'Report a concern to your estate team and follow its status here.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            if (widget.estates.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _estateId,
                decoration: const InputDecoration(labelText: 'Estate'),
                items: widget.estates
                    .map(
                      (estate) => DropdownMenuItem(
                        value: estate.id,
                        child: Text(estate.name),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _estateId = value);
                        _load();
                      },
              ),
            Card(
              color: const Color(0xFFFFF7E8),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF8A5B13)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This form sends a report to estate staff. It is not monitored as an emergency service.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving || _estateId == null ? null : _report,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Report incident'),
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: EstateColors.red),
                ),
              ),
            const SizedBox(height: 18),
            Text('My reports', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'You have not submitted an incident report for this estate.',
                  ),
                ),
              )
            else
              for (final item in _items)
                Card(
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
                                item.category.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Chip(label: Text(item.status.replaceAll('_', ' '))),
                          ],
                        ),
                        Text(
                          '${item.reference} · ${item.priority.toUpperCase()} · ${item.locationDescription ?? 'Location not specified'}',
                        ),
                        const SizedBox(height: 8),
                        Text(item.description),
                        const SizedBox(height: 8),
                        Text(
                          'Reported ${_date(item.reportedAt)}',
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (item.statusHistory.length > 1) ...[
                          const Divider(height: 24),
                          const Text(
                            'Status updates',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          for (final entry in item.statusHistory.skip(1))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3, right: 9),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: EstateColors.forest,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entry.toStatus.replaceAll('_', ' ')} · ${_date(entry.occurredAt)}',
                                      style: const TextStyle(
                                        color: EstateColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (item.evidence.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Supporting evidence',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          for (final evidence in item.evidence)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                evidence.contentType.startsWith('image/')
                                    ? Icons.image_outlined
                                    : Icons.picture_as_pdf_outlined,
                              ),
                              title: Text(evidence.displayName),
                              subtitle: Text(
                                '${(evidence.byteSize / 1024).ceil()} KB · ${_date(evidence.uploadedAt.toIso8601String())}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Download evidence',
                                onPressed: () =>
                                    _downloadEvidence(item, evidence),
                                icon: const Icon(Icons.download_outlined),
                              ),
                            ),
                        ],
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _saving || item.status == 'closed'
                              ? null
                              : () => _uploadEvidence(item),
                          icon: const Icon(Icons.attach_file_rounded),
                          label: Text(
                            item.status == 'closed'
                                ? 'Incident closed'
                                : 'Attach photo or document',
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
  );
}
