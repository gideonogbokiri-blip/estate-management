import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class FacilityBookingReviewPage extends StatefulWidget {
  const FacilityBookingReviewPage({super.key, required this.bookings});
  final List<EstateFacilityBooking> bookings;

  @override
  State<FacilityBookingReviewPage> createState() =>
      _FacilityBookingReviewPageState();
}

class _FacilityBookingReviewPageState extends State<FacilityBookingReviewPage> {
  final _search = TextEditingController();
  late List<EstateFacilityBooking> _bookings;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _bookings = List.of(widget.bookings);
  }

  @override
  void didUpdateWidget(covariant FacilityBookingReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bookings, widget.bookings)) {
      _bookings = List.of(widget.bookings);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _bookings
        .where((item) => item.status == 'pending_review')
        .length;
    final payment = _bookings
        .where((item) => item.status == 'pending_payment')
        .length;
    final confirmed = _bookings
        .where((item) => item.status == 'confirmed')
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = _bookings.where((item) {
      final matchesQuery =
          query.isEmpty ||
          '${item.reference} ${item.facilityName} ${item.propertyLabel} ${item.requesterName}'
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
                  'Facilities and bookings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review shared-space requests and monitor upcoming use.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Manage facilities'),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const _BookingPreviewNote(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _BookingMetric(
                label: 'Awaiting review',
                value: '$waiting',
                icon: Icons.pending_actions_outlined,
                color: const Color(0xFF8A5B13),
              ),
              _BookingMetric(
                label: 'Awaiting payment',
                value: '$payment',
                icon: Icons.payments_outlined,
                color: const Color(0xFF476B91),
              ),
              _BookingMetric(
                label: 'Confirmed upcoming',
                value: '$confirmed',
                icon: Icons.event_available_outlined,
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
                'Booking requests',
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
                  hintText: 'Search facility, resident or property',
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
                  labelText: 'Booking status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(
                    value: 'pending_review',
                    child: Text('Pending review'),
                  ),
                  DropdownMenuItem(
                    value: 'pending_payment',
                    child: Text('Pending payment'),
                  ),
                  DropdownMenuItem(
                    value: 'confirmed',
                    child: Text('Confirmed'),
                  ),
                  DropdownMenuItem(value: 'declined', child: Text('Declined')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const _BookingEmpty()
        else
          for (final booking in visible)
            _BookingCard(booking: booking, onTap: () => _openDetails(booking)),
      ],
    );
  }

  Future<void> _openDetails(EstateFacilityBooking booking) async {
    final result = await showDialog<({String decision, String reason})>(
      context: context,
      builder: (context) => _BookingDetailDialog(booking: booking),
    );
    if (result == null || !mounted) return;
    if (result.decision == 'confirm' && booking.paymentStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This booking needs verified payment before confirmation.',
          ),
        ),
      );
      return;
    }
    setState(() {
      final index = _bookings.indexWhere((item) => item.id == booking.id);
      if (index >= 0) {
        _bookings[index] = booking.copyWith(
          status: result.decision == 'confirm' ? 'confirmed' : 'declined',
          decisionNote: result.reason.trim().isEmpty
              ? booking.decisionNote
              : result.reason.trim(),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.decision == 'confirm'
              ? 'Booking confirmed in this preview.'
              : 'Booking declined in this preview.',
        ),
      ),
    );
  }
}

class _BookingPreviewNote extends StatelessWidget {
  const _BookingPreviewNote();
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
        Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFF8A5B13)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample booking data. Decisions stay in this preview session. Confirmation must recheck capacity and time conflicts; fees are paid only through a verified estate invoice.',
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

class _BookingMetric extends StatelessWidget {
  const _BookingMetric({
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});
  final EstateFacilityBooking booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = _bookingStatus(booking.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3EE),
          child: Icon(
            _facilityIcon(booking.facilityName),
            color: EstateColors.forest,
          ),
        ),
        title: Text(
          booking.facilityName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${booking.reference} · ${booking.propertyLabel} · ${booking.requesterName}\n${booking.startsAtLabel} – ${booking.endsAtLabel} · ${booking.attendeeCount} attendees',
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (booking.feeLabel != null)
              Text(
                booking.feeLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 5),
            _BookingStatusPill(
              label: status.$1,
              foreground: status.$2,
              background: status.$3,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingDetailDialog extends StatelessWidget {
  const _BookingDetailDialog({required this.booking});
  final EstateFacilityBooking booking;
  @override
  Widget build(BuildContext context) {
    final status = _bookingStatus(booking.status);
    return AlertDialog(
      title: Text('Booking ${booking.reference}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                booking.facilityName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              _BookingDetailRow(
                label: 'Requested by',
                value: booking.requesterName,
              ),
              _BookingDetailRow(
                label: 'Property',
                value: booking.propertyLabel,
              ),
              _BookingDetailRow(
                label: 'Time',
                value: '${booking.startsAtLabel} – ${booking.endsAtLabel}',
              ),
              _BookingDetailRow(
                label: 'Attendees',
                value: '${booking.attendeeCount}',
              ),
              _BookingDetailRow(label: 'Requested', value: booking.requestedAt),
              _BookingDetailRow(label: 'Status', value: status.$1),
              if (booking.feeLabel != null)
                _BookingDetailRow(
                  label: 'Facility fee',
                  value: booking.feeLabel!,
                ),
              _BookingDetailRow(
                label: 'Payment',
                value: _paymentStatus(booking.paymentStatus),
              ),
              if (booking.policyVersion != null)
                _BookingDetailRow(
                  label: 'Accepted policy version',
                  value: booking.policyVersion!,
                ),
              if (booking.purpose != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Purpose',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(booking.purpose!),
              ],
              if (booking.decisionNote != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Decision note',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(booking.decisionNote!),
              ],
              const SizedBox(height: 12),
              const Text(
                'Booking decisions recheck time conflicts and capacity. Approval does not imply payment.',
                style: TextStyle(
                  color: EstateColors.muted,
                  fontSize: 11,
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
          child: const Text('Close'),
        ),
        if (booking.status == 'pending_review') ...[
          OutlinedButton(
            onPressed: () => _askReason(context).then((reason) {
              if (reason != null && context.mounted) {
                Navigator.of(context)
                    .pop((decision: 'decline', reason: reason));
              }
            }),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: booking.paymentStatus == 'pending'
                ? null
                : () =>
                      Navigator.of(context)
                          .pop((decision: 'confirm', reason: '')),
            child: const Text('Confirm booking'),
          ),
        ],
      ],
    );
  }

  Future<String?> _askReason(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline booking'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason required'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a reason for the requester.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Decline booking'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}

class _BookingDetailRow extends StatelessWidget {
  const _BookingDetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 165,
          child: Text(
            label,
            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _BookingStatusPill extends StatelessWidget {
  const _BookingStatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });
  final String label;
  final Color foreground;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _BookingEmpty extends StatelessWidget {
  const _BookingEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 38, color: EstateColors.muted),
          SizedBox(height: 10),
          Text('No facility bookings match these filters.'),
        ],
      ),
    ),
  );
}

(String, Color, Color) _bookingStatus(String status) => switch (status) {
  'pending_review' => (
    'Pending review',
    const Color(0xFFFFF2D8),
    const Color(0xFF8A5B13),
  ),
  'pending_payment' => (
    'Pending payment',
    const Color(0xFFEAF1F8),
    const Color(0xFF476B91),
  ),
  'confirmed' => ('Confirmed', const Color(0xFFE9F4ED), EstateColors.forest),
  'declined' => ('Declined', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  'completed' => ('Completed', const Color(0xFFF0F1F2), EstateColors.muted),
  'cancelled' => ('Cancelled', const Color(0xFFF0F1F2), EstateColors.muted),
  _ => (status, const Color(0xFFF0F1F2), EstateColors.muted),
};

String _paymentStatus(String status) => switch (status) {
  'verified' => 'Verified payment recorded',
  'pending' => 'Payment is pending',
  'not_required' => 'No fee required',
  _ => 'Not due',
};

IconData _facilityIcon(String name) => switch (name.toLowerCase()) {
  'tennis court' => Icons.sports_tennis_rounded,
  'swimming pool' => Icons.pool_rounded,
  _ => Icons.groups_rounded,
};
