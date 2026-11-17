import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateSecurityIncidentsApiPage extends StatefulWidget {
  const EstateSecurityIncidentsApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });
  final EstateApplicationApiRepository repository;
  final String estateId, estateName;
  @override
  State<EstateSecurityIncidentsApiPage> createState() =>
      _EstateSecurityIncidentsApiPageState();
}

class _EstateSecurityIncidentsApiPageState
    extends State<EstateSecurityIncidentsApiPage> {
  late Future<List<EstateSecurityIncidentRecord>> _incidents;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _incidents = widget.repository.loadSecurityIncidents(widget.estateId);
  }

  Future<void> _refresh() async {
    setState(() {
      _error = null;
      _incidents = widget.repository.loadSecurityIncidents(widget.estateId);
    });
    try {
      await _incidents;
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _report() async {
    final description = TextEditingController();
    final location = TextEditingController();
    var category = 'safety';
    var priority = 'normal';
    final payload = await showDialog<Map<String, dynamic>>(
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
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'safety', child: Text('Safety')),
                      DropdownMenuItem(value: 'theft', child: Text('Theft')),
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
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Observed now. Add private photos or documents after submitting the report.',
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
                    'locationDescription': location.text.trim().isEmpty
                        ? null
                        : location.text.trim(),
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
    if (payload == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createSecurityIncident(
        estateId: widget.estateId,
        fields: payload,
      );
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(
    EstateSecurityIncidentRecord incident,
    String command,
  ) async {
    String? note;
    if (command == 'resolve' || command == 'close') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            command == 'resolve' ? 'Resolve incident' : 'Close incident',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Required summary'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.reviewSecurityIncident(
        estateId: widget.estateId,
        incidentId: incident.id,
        command: command,
        note: note,
      );
      await _refresh();
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
    try {
      final bytes = await widget.repository.downloadSecurityIncidentEvidence(
        estateId: widget.estateId,
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

  String _message(Object error) => error is EstateApiException
      ? error.message
      : 'Incident data is unavailable. Try again.';
  String _when(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    return d == null
        ? raw
        : '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(
      title: Text('${widget.estateName} · Security incidents'),
      actions: [
        IconButton(
          onPressed: _saving ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<EstateSecurityIncidentRecord>>(
      future: _incidents,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <EstateSecurityIncidentRecord>[];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Security and incidents',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _report,
                  icon: const Icon(Icons.add),
                  label: const Text('Report incident'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Reports and status changes are saved to the estate service.',
            ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No incident reports recorded for this estate.'),
                ),
              ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.category.replaceAll('_', ' ')} · ${item.priority.toUpperCase()}',
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
                        '${item.reference} · ${item.locationDescription ?? 'Estate grounds'}',
                      ),
                      const SizedBox(height: 8),
                      Text(item.description),
                      if (item.evidence.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text(
                          'Private supporting evidence',
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
                              '${(evidence.byteSize / 1024).ceil()} KB · ${_when(evidence.uploadedAt.toIso8601String())}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Download evidence',
                              onPressed: () =>
                                  _downloadEvidence(item, evidence),
                              icon: const Icon(Icons.download_outlined),
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Reported by ${item.reporterName} · ${_when(item.reportedAt)}',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (item.status == 'reported')
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _review(item, 'acknowledge'),
                              child: const Text('Acknowledge'),
                            ),
                          if (item.status == 'acknowledged')
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _review(item, 'investigate'),
                              child: const Text('Start investigation'),
                            ),
                          if (item.status == 'investigating')
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _review(item, 'resolve'),
                              child: const Text('Resolve'),
                            ),
                          if (item.status == 'resolved')
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _review(item, 'close'),
                              child: const Text('Close'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
