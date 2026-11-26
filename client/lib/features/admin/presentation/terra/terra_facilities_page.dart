import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Terra-styled view of an estate's shared facilities and the booking
/// requests that still need a manager decision.
class TerraFacilitiesPage extends StatefulWidget {
  const TerraFacilitiesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraFacilitiesPage> createState() => _TerraFacilitiesPageState();
}

class _TerraFacilitiesPageState extends State<TerraFacilitiesPage> {
  List<EstateFacilityRecord> _facilities = const [];
  List<EstateFacilityBookingRecord> _bookings = const [];
  bool _loading = true;
  bool _saving = false;
  String? _facilitiesError;
  String? _bookingsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _facilitiesError = null;
      _bookingsError = null;
    });
    // The two feeds are independent: a failure in one must not hide the other.
    try {
      _facilities =
          await widget.repository.loadEstateFacilities(widget.estateId);
    } catch (_) {
      _facilitiesError = 'Shared facilities could not be loaded.';
    }
    try {
      _bookings =
          await widget.repository.loadEstateFacilityBookings(widget.estateId);
    } catch (_) {
      _bookingsError = 'Booking requests could not be loaded.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _askDeclineReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline booking'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason'),
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
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _review(
    EstateFacilityBookingRecord booking,
    String command,
  ) async {
    String? reason;
    if (command == 'decline') {
      reason = await _askDeclineReason();
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.reviewEstateFacilityBooking(
        estateId: widget.estateId,
        bookingId: booking.id,
        command: command,
        reason: reason,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _bookingsError = 'Booking review could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TerraBadgeTone _tone(String status) => switch (status) {
        'confirmed' => TerraBadgeTone.sage,
        'declined' || 'cancelled' => TerraBadgeTone.danger,
        'pending_review' => TerraBadgeTone.amber,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Facilities'),
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
                    'Shared spaces and resident booking requests for this estate.',
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
                      title: 'Shared facilities',
                      trailing: TerraBadge(label: '${_facilities.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_facilitiesError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _facilitiesError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_facilities.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'No shared facilities are configured for this estate.',
                          icon: Icons.meeting_room_outlined,
                        ),
                      )
                    else
                      for (final facility in _facilities)
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
                                        facility.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: TerraColors.ink,
                                        ),
                                      ),
                                    ),
                                    TerraBadge(label: facility.category),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${facility.code} · ${facility.location} · '
                                  'up to ${facility.capacity} attendees',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TerraColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    TerraSectionTitle(
                      title: 'Booking requests',
                      trailing: TerraBadge(label: '${_bookings.length}'),
                    ),
                    const SizedBox(height: 8),
                    if (_bookingsError != null)
                      TerraCard(
                        child: TerraEmpty(
                          message: _bookingsError!,
                          icon: Icons.error_outline,
                        ),
                      )
                    else if (_bookings.isEmpty)
                      const TerraCard(
                        child: TerraEmpty(
                          message: 'There are no facility booking requests yet.',
                          icon: Icons.event_note_outlined,
                        ),
                      )
                    else
                      for (final booking in _bookings)
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
                                        booking.facilityName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: TerraColors.ink,
                                        ),
                                      ),
                                    ),
                                    TerraBadge(
                                      label: booking.status.replaceAll('_', ' '),
                                      tone: _tone(booking.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Requested by ${booking.requesterName} · '
                                  '${booking.reference} · ${booking.propertyCode}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TerraColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${AppFormat.date(booking.startsAt)} – '
                                  '${AppFormat.date(booking.endsAt)} · '
                                  '${booking.attendeeCount} attendees',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TerraColors.muted,
                                  ),
                                ),
                                if (booking.status == 'pending_review') ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _saving
                                            ? null
                                            : () => _review(booking, 'confirm'),
                                        icon: const Icon(Icons.check_rounded, size: 16),
                                        label: const Text('Approve'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _saving
                                            ? null
                                            : () => _review(booking, 'decline'),
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: TerraColors.danger,
                                        ),
                                        label: const Text('Decline'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
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
}
