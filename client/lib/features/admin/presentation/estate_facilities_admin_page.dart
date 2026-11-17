import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateFacilitiesAdminPage extends StatefulWidget {
  const EstateFacilitiesAdminPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });
  final EstateApplicationApiRepository repository;
  final String estateId, estateName;
  @override
  State<EstateFacilitiesAdminPage> createState() =>
      _EstateFacilitiesAdminPageState();
}

class _EstateFacilitiesAdminPageState extends State<EstateFacilitiesAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'recreation');
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  final _duration = TextEditingController(text: '60');
  final _opening = TextEditingController(text: '08:00');
  final _closing = TextEditingController(text: '22:00');
  final _lead = TextEditingController(text: '2');
  List<EstateFacilityRecord> _facilities = const [];
  List<EstateFacilityBookingRecord> _bookings = const [];
  bool _loading = true;
  bool _saving = false;
  bool _showForm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final item in [
      _code,
      _name,
      _category,
      _description,
      _location,
      _capacity,
      _duration,
      _opening,
      _closing,
      _lead,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.loadEstateFacilities(widget.estateId),
        widget.repository.loadEstateFacilityBookings(widget.estateId),
      ]);
      _facilities = values[0] as List<EstateFacilityRecord>;
      _bookings = values[1] as List<EstateFacilityBookingRecord>;
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Facility operations could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createEstateFacility(
        estateId: widget.estateId,
        fields: {
          'code': _code.text.trim(),
          'name': _name.text.trim(),
          'category': _category.text.trim(),
          'description': _description.text.trim(),
          'location': _location.text.trim(),
          'capacity': int.parse(_capacity.text),
          'durationMinutes': int.parse(_duration.text),
          'openingTime': _opening.text.trim(),
          'closingTime': _closing.text.trim(),
          'bookingLeadHours': int.parse(_lead.text),
        },
      );
      _code.clear();
      _name.clear();
      _description.clear();
      _location.clear();
      setState(() => _showForm = false);
      await _load();
    } catch (error) {
      setState(() {
        _saving = false;
        _error = error is EstateApiException
            ? error.message
            : 'Facility could not be saved.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(
    EstateFacilityBookingRecord booking,
    String command,
  ) async {
    String? reason;
    if (command == 'decline') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline booking'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason required'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty)
                  Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.reviewEstateFacilityBooking(
        estateId: widget.estateId,
        bookingId: booking.id,
        command: command,
        reason: reason,
      );
      await _load();
    } catch (error) {
      setState(
        () => _error = error is EstateApiException
            ? error.message
            : 'Booking review could not be saved.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _positiveInt(String? value) =>
      int.tryParse(value ?? '') == null || int.parse(value!) < 1
      ? 'Enter a positive number'
      : null;
  String _when(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.estateName} facilities',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: EstateColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configure shared spaces and review resident booking requests.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () => setState(() => _showForm = !_showForm),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add facility'),
          ),
        ],
      ),
      if (_error != null)
        Card(
          color: const Color(0xFFFFF0EE),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: EstateColors.red),
            ),
          ),
        ),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_showForm)
        Card(
          margin: const EdgeInsets.only(top: 14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Facility details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _code,
                          decoration: const InputDecoration(labelText: 'Code'),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextFormField(
                          controller: _location,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                          ),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _capacity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max attendees',
                          ),
                          validator: _positiveInt,
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration (min)',
                          ),
                          validator: _positiveInt,
                        ),
                      ),
                      SizedBox(
                        width: 115,
                        child: TextFormField(
                          controller: _opening,
                          decoration: const InputDecoration(
                            labelText: 'Opens (HH:mm)',
                          ),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 115,
                        child: TextFormField(
                          controller: _closing,
                          decoration: const InputDecoration(
                            labelText: 'Closes (HH:mm)',
                          ),
                          validator: _required,
                        ),
                      ),
                      SizedBox(
                        width: 115,
                        child: TextFormField(
                          controller: _lead,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Lead hours',
                          ),
                          validator: (value) =>
                              int.tryParse(value ?? '') == null ||
                                  int.parse(value!) < 0
                              ? 'Invalid hours'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 420,
                        child: TextFormField(
                          controller: _description,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                          validator: _required,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Bookings require staff confirmation. Times use the estate time zone (Africa/Lagos); no booking fee is configured.',
                      style: TextStyle(color: EstateColors.muted, fontSize: 12),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _create,
                      child: Text(_saving ? 'Saving…' : 'Create facility'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 18),
      const Text(
        'Facilities',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      if (!_loading && _facilities.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No facilities configured for this estate.'),
          ),
        ),
      for (final facility in _facilities)
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.pool_outlined)),
            title: Text('${facility.name} · ${facility.code}'),
            subtitle: Text(
              '${facility.category} · ${facility.location} · up to ${facility.capacity} attendees · ${facility.durationMinutes} min · ${facility.openingTime}–${facility.closingTime} · policy v${facility.policyVersion}',
            ),
          ),
        ),
      const SizedBox(height: 22),
      const Text(
        'Booking review',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      if (!_loading && _bookings.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('There are no facility booking requests yet.'),
          ),
        ),
      for (final booking in _bookings)
        Card(
          child: ListTile(
            isThreeLine: true,
            leading: Icon(
              booking.status == 'confirmed'
                  ? Icons.event_available
                  : booking.status == 'declined'
                  ? Icons.event_busy
                  : Icons.event_note_outlined,
            ),
            title: Text(
              '${booking.reference} · ${booking.facilityName} · ${booking.status.replaceAll('_', ' ')}',
            ),
            subtitle: Text(
              '${booking.requesterName} · ${booking.propertyCode} · ${booking.attendeeCount} attendees\n${_when(booking.startsAt)} – ${_when(booking.endsAt)}${booking.purpose == null ? '' : '\n${booking.purpose}'}',
            ),
            trailing: booking.status == 'pending_review'
                ? Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Confirm',
                        onPressed: _saving
                            ? null
                            : () => _review(booking, 'confirm'),
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: EstateColors.forest,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        onPressed: _saving
                            ? null
                            : () => _review(booking, 'decline'),
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: EstateColors.red,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'Pending requests do not hold a time slot. Confirmation rechecks availability and prevents overlapping confirmed bookings.',
          style: TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ),
    ],
  );
}
