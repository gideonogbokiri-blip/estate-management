import 'package:flutter/material.dart';

import '../../../core/design/terra_theme.dart';
import '../../../core/design/service_page_scaffold.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/api.dart';
import '../../resident/presentation/resident_facilities_api_page.dart';
import '../../resident/presentation/resident_incidents_api_page.dart';
import 'resident_service_pages.dart';

/// Dark-themed Facilities page. Replaces the old light page returned by the
/// previous implementation so this service matches the rest of the bank UI.
class FacilitiesServicePage extends StatefulWidget {
  const FacilitiesServicePage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;

  @override
  State<FacilitiesServicePage> createState() => _FacilitiesServicePageState();
}

class _FacilitiesServicePageState extends State<FacilitiesServicePage> {
  List<EstateFacilityRecord> _facilities = const [];
  List<EstateFacilityBookingRecord> _bookings = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repository = widget.serviceContext.repository;
      final estateId = widget.serviceContext.estateId;
      _facilities = await repository.loadResidentEstateFacilities(estateId);
      _bookings = await repository.loadMyFacilityBookings(estateId);
    } catch (_) {
      _error = 'Facilities could not be loaded right now.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBooking() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResidentFacilitiesApiPage(
          repository: widget.serviceContext.repository,
          estateId: widget.serviceContext.estateId,
          estateName: widget.serviceContext.estateName,
          properties: widget.serviceContext.properties,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'facilities');
    return ServicePageScaffold(
      title: service.label,
      description: service.description,
      icon: service.icon,
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: 'Request a booking',
          onPressed: _openBooking,
          icon: const Icon(Icons.add),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TerraSectionTitle(title: 'Places you can book'),
                    if (_facilities.isEmpty)
                      const ServiceStateMessage(
                        message: 'Your estate has not listed any bookable spaces yet.',
                      )
                    else
                      ..._facilities.map(
                        (facility) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.calendar_month_outlined,
                                color: TerraColors.forest),
                            title: Text(facility.name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${facility.location} · fits ${facility.capacity} people',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: _openBooking,
                              child: const Text('Book'),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    TerraSectionTitle(title: 'Your bookings'),
                    if (_bookings.isEmpty)
                      const ServiceStateMessage(
                        message: 'You have not booked any facility yet.',
                      )
                    else
                      ..._bookings.map(
                        (booking) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_available_outlined,
                                color: TerraColors.forest),
                            title: Text(booking.facilityName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${AppFormat.date(booking.startsAt)} · ${booking.status}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// Dark-themed Safety / Emergency page, backed by the resident incident API.
class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  List<EstateSecurityIncidentRecord> _incidents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _incidents = await widget.serviceContext.repository
          .loadMySecurityIncidents(widget.serviceContext.estateId);
    } catch (_) {
      _error = 'Safety reports could not be loaded right now.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'emergency');
    return ServicePageScaffold(
      title: service.label,
      description: service.description,
      icon: service.icon,
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: TerraColors.surfaceMuted,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Need urgent help?',
                      style: TextStyle(
                          color: TerraColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text(
                    'Call your estate security office or gate first. Then record the '
                    'issue here so management can follow it up.',
                    style: TextStyle(
                        color: TerraColors.ink, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => ResidentIncidentsApiPage(
                            repository: widget.serviceContext.repository,
                            estates: widget.serviceContext.estates,
                            onBack: () => Navigator.of(context).pop(false),
                          ),
                        ),
                      );
                      if (result == true || result == null) await _load();
                    },
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Report a problem'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          TerraSectionTitle(title: 'Your reports'),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            ServiceStateMessage(message: _error!, error: true, onRetry: _load)
          else if (_incidents.isEmpty)
            const ServiceStateMessage(message: 'No safety reports have been made yet.')
          else
            ..._incidents.map(
              (incident) => Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined,
                      color: TerraColors.amber),
                  title: Text('${incident.reference} · ${incident.category}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${incident.description} · ${incident.status}',
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


