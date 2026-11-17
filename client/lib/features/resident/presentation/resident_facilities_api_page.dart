import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class ResidentFacilitiesApiPage extends StatefulWidget {
  const ResidentFacilitiesApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
    required this.properties,
  });
  final EstateApplicationApiRepository repository;
  final String estateId, estateName;
  final List<({String id, String label})> properties;
  @override
  State<ResidentFacilitiesApiPage> createState() =>
      _ResidentFacilitiesApiPageState();
}

class _ResidentFacilitiesApiPageState extends State<ResidentFacilitiesApiPage> {
  List<EstateFacilityRecord> _facilities = const [];
  List<EstateFacilityBookingRecord> _bookings = const [];
  bool _loading = true, _busy = false;
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
      final values = await Future.wait([
        widget.repository.loadResidentEstateFacilities(widget.estateId),
        widget.repository.loadMyFacilityBookings(widget.estateId),
      ]);
      _facilities = values[0] as List<EstateFacilityRecord>;
      _bookings = values[1] as List<EstateFacilityBookingRecord>;
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Facilities could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _key() => List.generate(
    48,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  String _format(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cancel(EstateFacilityBookingRecord booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
          'This will cancel your request or confirmed booking and release its time slot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
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
      await widget.repository.cancelResidentFacilityBooking(
        estateId: widget.estateId,
        bookingId: booking.id,
      );
      await _load();
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is EstateApiException
              ? error.message
              : 'Booking could not be cancelled.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request(EstateFacilityRecord facility) async {
    if (widget.properties.isEmpty) {
      setState(
        () => _error =
            'An active property relationship is needed to request a booking.',
      );
      return;
    }
    final property = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose your property'),
        children: [
          for (final item in widget.properties)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.id),
              child: Text(item.label),
            ),
        ],
      ),
    );
    if (property == null || !mounted) return;
    final now = DateTime.now();
    final chosenDate = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(hours: facility.bookingLeadHours + 25)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Choose a booking date',
    );
    if (chosenDate == null || !mounted) return;
    final date =
        '${chosenDate.year.toString().padLeft(4, '0')}-${chosenDate.month.toString().padLeft(2, '0')}-${chosenDate.day.toString().padLeft(2, '0')}';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final slots = await widget.repository.loadFacilityAvailability(
        estateId: widget.estateId,
        facilityId: facility.id,
        date: date,
      );
      if (!mounted) return;
      if (slots.isEmpty) {
        setState(
          () => _error = 'No available times on that date. Choose another day.',
        );
        return;
      }
      final slot = await showDialog<EstateFacilitySlotRecord>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Available times · Africa/Lagos'),
          children: [
            for (final item in slots)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(
                  '${_format(item.startsAt)} – ${_format(item.endsAt)}',
                ),
              ),
          ],
        ),
      );
      if (slot == null || !mounted) return;
      final attendees = TextEditingController(text: '1');
      final purpose = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final result = await showDialog<({int count, String purpose})>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Request ${facility.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_format(slot.startsAt)} · ${widget.estateName}',
                  style: const TextStyle(color: EstateColors.muted),
                ),
                TextFormField(
                  controller: attendees,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Attendee count',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null ||
                            count < 1 ||
                            count > facility.capacity
                        ? 'Enter 1–${facility.capacity} attendees.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: purpose,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate())
                  Navigator.pop(context, (
                    count: int.parse(attendees.text),
                    purpose: purpose.text.trim(),
                  ));
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      );
      attendees.dispose();
      purpose.dispose();
      if (result == null || !mounted) return;
      await widget.repository.createResidentFacilityBooking(
        estateId: widget.estateId,
        facilityId: facility.id,
        idempotencyKey: _key(),
        fields: {
          'propertyId': property,
          'startsAt': slot.startsAt,
          'endsAt': slot.endsAt,
          'attendeeCount': result.count,
          'purpose': result.purpose,
          'acceptedPolicyVersion': slot.policyVersion,
        },
      );
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Booking request sent. It is pending staff review and does not reserve the time yet.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is EstateApiException
              ? error.message
              : 'Booking request could not be sent.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.estateName} facilities'),
      actions: [
        IconButton(
          onPressed: _loading || _busy ? null : _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Shared spaces',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: EstateColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Check available times and send a request to your estate team. A time is reserved only after confirmation.',
          style: TextStyle(color: EstateColors.muted),
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
        if (_loading || _busy) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 16),
        const Text(
          'Facilities',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        if (!_loading && _facilities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Your estate has not added any bookable facilities yet.',
              ),
            ),
          ),
        for (final facility in _facilities)
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.sports_tennis_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          facility.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        facility.category,
                        style: const TextStyle(color: EstateColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(facility.description),
                  const SizedBox(height: 7),
                  Text(
                    '${facility.location} · Capacity ${facility.capacity} · ${facility.durationMinutes} min · ${facility.openingTime}–${facility.closingTime}',
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _request(facility),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Choose a time'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'My booking requests',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        if (!_loading && _bookings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('You have no facility booking requests.'),
            ),
          ),
        for (final booking in _bookings)
          Card(
            child: ListTile(
              leading: Icon(
                booking.status == 'confirmed'
                    ? Icons.event_available
                    : Icons.event_note_outlined,
              ),
              title: Text(
                '${booking.facilityName} · ${booking.status.replaceAll('_', ' ')}',
              ),
              subtitle: Text(
                '${_format(booking.startsAt)} · ${booking.attendeeCount} attendees · ${booking.reference}\n${booking.purpose ?? ''}',
              ),
              trailing:
                  (booking.status == 'pending_review' ||
                          booking.status == 'confirmed') &&
                      DateTime.tryParse(booking.startsAt)
                              ?.isAfter(DateTime.now()) ==
                          true
                  ? TextButton(
                      onPressed: _busy ? null : () => _cancel(booking),
                      child: const Text('Cancel'),
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}
