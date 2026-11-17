import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentFacilitiesPage extends StatefulWidget {
  const ResidentFacilitiesPage({
    super.key,
    required this.facilities,
    required this.bookings,
    required this.onBack,
    required this.repository,
    required this.onBookingsChanged,
  });

  final List<ResidentFacility> facilities;
  final List<ResidentFacilityBooking> bookings;
  final VoidCallback onBack;
  final ResidentEstateRepository repository;
  final VoidCallback onBookingsChanged;

  @override
  State<ResidentFacilitiesPage> createState() => _ResidentFacilitiesPageState();
}

class _ResidentFacilitiesPageState extends State<ResidentFacilitiesPage> {
  late List<ResidentFacilityBooking> _bookings;
  int _tab = 0;
  String _bookingFilter = 'upcoming';

  @override
  void initState() {
    super.initState();
    _bookings = List.of(widget.bookings);
  }

  @override
  void didUpdateWidget(covariant ResidentFacilitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bookings, widget.bookings)) {
      _bookings = List.of(widget.bookings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = _bookings.where(_matchesBookingFilter).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Community services'),
          ),
        ),
        Text('Facilities', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        const Text('Browse shared spaces and review your booking requests.'),
        const SizedBox(height: 16),
        const _InfoBanner(),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Explore')),
            ButtonSegment(value: 1, label: Text('My bookings')),
          ],
          selected: {_tab},
          onSelectionChanged: (selected) =>
              setState(() => _tab = selected.first),
        ),
        const SizedBox(height: 14),
        if (_tab == 0)
          for (final facility in widget.facilities)
            _FacilityCard(
              facility: facility,
              onRequest: () => _openRequestDraft(facility),
            )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _bookingChip('Upcoming', 'upcoming'),
              _bookingChip('Needs action', 'needs_action'),
              _bookingChip('Confirmed', 'confirmed'),
              _bookingChip('Past', 'past'),
              _bookingChip('All', 'all'),
            ],
          ),
          const SizedBox(height: 12),
          if (bookings.isEmpty)
            _EmptyBookings(
              message: _bookings.isEmpty
                  ? 'You have no facility bookings yet.'
                  : 'No bookings match this filter.',
            )
          else
            for (final booking in bookings) _BookingCard(booking: booking),
        ],
      ],
    );
  }

  bool _matchesBookingFilter(ResidentFacilityBooking booking) {
    final ended =
        const {
          'declined',
          'expired',
          'cancelled',
          'completed',
        }.contains(booking.status) ||
        !booking.endsAt.isAfter(DateTime.now());
    return switch (_bookingFilter) {
      'needs_action' =>
        !ended &&
            const {
              'requested',
              'pending_review',
              'pending_payment',
              'preview_draft',
            }.contains(booking.status),
      'confirmed' => booking.status == 'confirmed' && !ended,
      'past' => ended,
      'upcoming' => !ended,
      _ => true,
    };
  }

  Widget _bookingChip(String label, String value) => ChoiceChip(
    label: Text(label),
    selected: _bookingFilter == value,
    onSelected: (_) => setState(() => _bookingFilter = value),
  );

  Future<void> _openRequestDraft(ResidentFacility facility) async {
    final request =
        await showDialog<({DateTime startsAt, int attendees, String purpose})>(
          context: context,
          builder: (context) => _FacilityBookingDraftDialog(facility: facility),
        );
    if (request == null || !mounted) return;
    final draftBooking = await widget.repository.createFacilityBookingDraft(
      facilityId: facility.id,
      startsAt: request.startsAt,
      attendeeCount: request.attendees,
      purpose: request.purpose,
      acceptedPolicyVersion: facility.policyVersion ?? '',
    );
    if (!mounted) return;
    setState(() {
      _bookings = [draftBooking, ..._bookings];
      _tab = 1;
      _bookingFilter = 'all';
    });
    widget.onBookingsChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Draft saved in this preview. No time slot was reserved.',
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6F3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD7E5DC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: EstateColors.forest, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample facility information. Requests here are local drafts only; the connected estate service must verify live availability and policy before a slot is reserved.',
            style: TextStyle(
              color: EstateColors.forest,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility, required this.onRequest});
  final ResidentFacility facility;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _facilityIcon(facility.category),
                  color: EstateColors.forest,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${facility.category}  ·  ${facility.location}',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _CategoryTag(
                label: facility.approvalMode == 'automatic'
                    ? 'Instant booking'
                    : 'Approval required',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(facility.description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _InfoItem(
                icon: Icons.schedule_rounded,
                text: facility.openingHours,
              ),
              _InfoItem(
                icon: Icons.groups_2_outlined,
                text: 'Up to ${facility.capacity} people',
              ),
              _InfoItem(
                icon: Icons.timelapse_rounded,
                text: '${facility.durationMinutes} min per slot',
              ),
              if (facility.feeLabel != null)
                _InfoItem(
                  icon: Icons.payments_outlined,
                  text: facility.feeLabel!,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Prepare booking request'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FacilityBookingDraftDialog extends StatefulWidget {
  const _FacilityBookingDraftDialog({required this.facility});
  final ResidentFacility facility;

  @override
  State<_FacilityBookingDraftDialog> createState() =>
      _FacilityBookingDraftDialogState();
}

class _FacilityBookingDraftDialogState
    extends State<_FacilityBookingDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _attendees = TextEditingController(text: '1');
  final _purpose = TextEditingController();
  late DateTime _startsAt;
  bool _acceptedPolicy = false;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _startsAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
  }

  @override
  void dispose() {
    _attendees.dispose();
    _purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facility = widget.facility;
    return AlertDialog(
      title: Text('Request ${facility.name}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${facility.durationMinutes} minute slot · capacity ${facility.capacity}',
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Requested start',
                    style: TextStyle(fontSize: 12, color: EstateColors.muted),
                  ),
                  subtitle: Text('${_date(_startsAt)} · ${_time(_startsAt)}'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _chooseStart,
                ),
                TextFormField(
                  controller: _attendees,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Attendees (up to ${facility.capacity})',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null ||
                            count < 1 ||
                            count > facility.capacity
                        ? 'Enter a number from 1 to ${facility.capacity}.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _purpose,
                  maxLength: 250,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedPolicy,
                  onChanged: (value) =>
                      setState(() => _acceptedPolicy = value ?? false),
                  title: Text(
                    'Accept preview policy ${facility.policyVersion ?? 'sample'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Text(
                  'This saves a local draft only. The displayed time is not checked for availability and no booking or payment is created.',
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
          child: const Text('Save request draft'),
        ),
      ],
    );
  }

  Future<void> _chooseStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the displayed policy to continue.'),
        ),
      );
      return;
    }
    if (!_startsAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future start time.')),
      );
      return;
    }
    Navigator.of(context).pop((
      startsAt: _startsAt,
      attendees: int.parse(_attendees.text),
      purpose: _purpose.text.trim(),
    ));
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final ResidentFacilityBooking booking;

  @override
  Widget build(BuildContext context) {
    final status = _bookingStatus(booking.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF3EE),
          child: Icon(Icons.event_note_outlined, color: EstateColors.forest),
        ),
        title: Text(
          booking.facilityName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_date(booking.startsAt)} · ${_time(booking.startsAt)}–${_time(booking.endsAt)}\n${booking.attendeeCount} attendees · Ref ${booking.reference}${booking.feeLabel == null ? '' : ' · ${booking.feeLabel}'}${booking.purpose == null ? '' : '\n${booking.purpose}'}',
          ),
        ),
        isThreeLine: true,
        trailing: _BookingStatusTag(status: booking.status, label: status),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3EE),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: EstateColors.forest,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _BookingStatusTag extends StatelessWidget {
  const _BookingStatusTag({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      'confirmed' => (EstateColors.forest, const Color(0xFFE9F4ED)),
      'requested' ||
      'pending_review' ||
      'preview_draft' => (const Color(0xFF795416), const Color(0xFFFFF2D8)),
      'pending_payment' => (const Color(0xFF476B91), const Color(0xFFEAF1F8)),
      'declined' ||
      'cancelled' => (const Color(0xFF984B43), const Color(0xFFF9EDEC)),
      'expired' || 'completed' => (EstateColors.muted, const Color(0xFFF0F1F2)),
      _ => (EstateColors.muted, const Color(0xFFF0F1F2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: style.$2,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.$1,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: EstateColors.muted),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: EstateColors.muted),
      ),
    ],
  );
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 36,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    ),
  );
}

IconData _facilityIcon(String category) => switch (category.toLowerCase()) {
  'sports' => Icons.sports_tennis_rounded,
  'events' => Icons.groups_rounded,
  _ => Icons.pool_rounded,
};

String _bookingStatus(String status) => switch (status) {
  'preview_draft' => 'Draft · preview only',
  'requested' => 'Requested',
  'confirmed' => 'Confirmed',
  'pending_review' => 'Awaiting review',
  'pending_payment' => 'Payment required',
  'declined' => 'Declined',
  'expired' => 'Expired',
  'cancelled' => 'Cancelled',
  'completed' => 'Completed',
  _ => status,
};

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
