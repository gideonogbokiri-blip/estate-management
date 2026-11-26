import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Terra-styled security overview: incidents, gates, assigned officers and
/// the recent gate access trail for an estate.
class TerraSecurityPage extends StatefulWidget {
  const TerraSecurityPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraSecurityPage> createState() => _TerraSecurityPageState();
}

class _TerraSecurityPageState extends State<TerraSecurityPage> {
  List<EstateSecurityIncidentRecord> _incidents = const [];
  List<EstateGateRecord> _gates = const [];
  List<EstateStaffChoice> _officers = const [];
  List<EstateGateAccessEventRecord> _events = const [];
  bool _loading = true;
  bool _saving = false;
  String? _incidentsError;
  String? _gatesError;
  String? _officersError;
  String? _eventsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _incidentsError = null;
      _gatesError = null;
      _officersError = null;
      _eventsError = null;
    });
    // Each feed is loaded on its own so one unavailable endpoint cannot wipe
    // the rest of the overview.
    try {
      _incidents =
          await widget.repository.loadSecurityIncidents(widget.estateId);
    } catch (_) {
      _incidentsError = 'Security incidents could not be loaded.';
    }
    try {
      _gates = await widget.repository.loadEstateGates(widget.estateId);
    } catch (_) {
      _gatesError = 'Gates could not be loaded.';
    }
    try {
      _officers =
          await widget.repository.loadSecurityOfficers(widget.estateId);
    } catch (_) {
      _officersError = 'Security officers could not be loaded.';
    }
    try {
      _events = await widget.repository.loadGateAccessEvents(
        estateId: widget.estateId,
      );
    } catch (_) {
      _eventsError = 'Gate access activity could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _askNote(String command) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(command == 'resolve' ? 'Resolve incident' : 'Close incident'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Summary'),
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
    return note;
  }

  ({String label, String command})? _nextAction(String status) => switch (status) {
        'reported' => (label: 'Acknowledge', command: 'acknowledge'),
        'acknowledged' => (label: 'Investigate', command: 'investigate'),
        'investigating' => (label: 'Resolve', command: 'resolve'),
        'resolved' => (label: 'Close', command: 'close'),
        _ => null,
      };

  Future<void> _review(
    EstateSecurityIncidentRecord incident,
    String command,
  ) async {
    String? note;
    if (command == 'resolve' || command == 'close') {
      note = await _askNote(command);
      if (note == null) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.reviewSecurityIncident(
        estateId: widget.estateId,
        incidentId: incident.id,
        command: command,
        note: note,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _incidentsError = 'Incident review could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TerraBadgeTone _priorityTone(String priority) => switch (priority) {
        'urgent' => TerraBadgeTone.danger,
        'high' => TerraBadgeTone.amber,
        'normal' => TerraBadgeTone.sage,
        _ => TerraBadgeTone.outline,
      };

  TerraBadgeTone _statusTone(String status) => switch (status) {
        'closed' || 'resolved' => TerraBadgeTone.sage,
        'investigating' || 'acknowledged' => TerraBadgeTone.amber,
        'reported' => TerraBadgeTone.danger,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Security'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
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
                  TerraSectionTitle(title: widget.estateName),
                  const SizedBox(height: 4),
                  const Text(
                    'Incident reports, gate coverage and recent access activity.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else ...[
                    TerraSectionTitle(
                      title: 'Security incidents',
                      trailing: TerraBadge(label: '${_incidents.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_incidentsError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _incidentsError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_incidents.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'No incident reports recorded for this estate.',
                          icon: Icons.shield_outlined,
                        ),
                      )
                    else
                      for (final incident in _incidents)
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
                                        '${incident.reference} · '
                                        '${incident.category.replaceAll('_', ' ')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: TerraColors.ink,
                                        ),
                                      ),
                                    ),
                                    TerraBadge(
                                      label: incident.priority.toUpperCase(),
                                      tone: _priorityTone(incident.priority),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  incident.description,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TerraBadge(
                                      label: incident.status.replaceAll('_', ' '),
                                      tone: _statusTone(incident.status),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Reported by ${incident.reporterName} · '
                                        '${AppFormat.date(incident.reportedAt)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: TerraColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Observed ${AppFormat.date(incident.observedAt)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TerraColors.muted,
                                  ),
                                ),
                                finalAction(incident),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    TerraSectionTitle(
                      title: 'Gates',
                      trailing: TerraBadge(label: '${_gates.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_gatesError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _gatesError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_gates.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'No gates are configured for this estate.',
                          icon: Icons.sensors_outlined,
                        ),
                      )
                    else
                      for (final gate in _gates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TerraCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.sensors_outlined,
                                  color: TerraColors.forest),
                              title: Text(
                                gate.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('Gate ${gate.code}'),
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    TerraSectionTitle(
                      title: 'Security officers',
                      trailing: TerraBadge(label: '${_officers.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_officersError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _officersError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_officers.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'No security officers are assigned yet.',
                          icon: Icons.person_outline,
                        ),
                      )
                    else
                      TerraCard(
                        child: Column(
                          children: [
                            for (final officer in _officers)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.shield_outlined,
                                    color: TerraColors.forest),
                                title: Text(officer.displayName),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    TerraSectionTitle(
                      title: 'Gate access activity',
                      trailing: TerraBadge(label: '${_events.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_eventsError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _eventsError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_events.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'No gate access events recorded yet.',
                          icon: Icons.history_toggle_off_outlined,
                        ),
                      )
                    else
                      TerraCard(
                        child: Column(
                          children: [
                            for (final event in _events)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.access_time_outlined,
                                    color: TerraColors.forest),
                                title: Text(
                                  event.eventKind.replaceAll('_', ' '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  '${AppFormat.date(event.occurredAt)} · '
                                  'Gate ${event.gateId}'
                                  '${event.propertyLabel == null ? '' : ' · ${event.propertyLabel}'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget finalAction(EstateSecurityIncidentRecord incident) {
    final action = _nextAction(incident.status);
    if (action == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: _saving ? null : () => _review(incident, action.command),
          child: Text(action.label),
        ),
      ),
    );
  }
}
