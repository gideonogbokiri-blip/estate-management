import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class VisitorAccessPage extends StatefulWidget {
  const VisitorAccessPage({
    super.key,
    required this.passes,
    required this.currentVisitors,
  });

  final List<VisitorPassSummary> passes;
  final List<GateVisitorSummary> currentVisitors;

  @override
  State<VisitorAccessPage> createState() => _VisitorAccessPageState();
}

class _VisitorAccessPageState extends State<VisitorAccessPage> {
  final _search = TextEditingController();
  int _view = 0;
  String _status = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passes = widget.passes.where((pass) {
      final query = _search.text.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          '${pass.visitorName} ${pass.hostName} ${pass.propertyLabel}'
              .toLowerCase()
              .contains(query);
      return matchesSearch && (_status == 'all' || pass.status == _status);
    }).toList();
    final checkedIn = widget.currentVisitors.where((visitor) {
      final query = _search.text.trim().toLowerCase();
      return query.isEmpty ||
          '${visitor.visitorName} ${visitor.hostName} ${visitor.propertyLabel} ${visitor.gateName}'
              .toLowerCase()
              .contains(query);
    }).toList();
    final active = widget.passes
        .where((pass) => pass.status == 'active')
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 14,
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visitor access',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review invitations and see who is currently inside the estate.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create pass'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _PreviewNotice(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final cards = [
              _MetricCard(
                label: 'Currently checked in',
                value: '${widget.currentVisitors.length}',
                icon: Icons.directions_walk_rounded,
                color: EstateColors.forest,
              ),
              _MetricCard(
                label: 'Active passes',
                value: '$active',
                icon: Icons.confirmation_number_outlined,
                color: const Color(0xFFB57914),
              ),
              _MetricCard(
                label: 'Gates reporting',
                value:
                    '${widget.currentVisitors.map((e) => e.gateName).toSet().length}',
                icon: Icons.meeting_room_outlined,
                color: const Color(0xFF476B91),
              ),
            ];
            return compact
                ? Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
        const SizedBox(height: 24),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Passes'),
              icon: Icon(Icons.badge_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Currently inside'),
              icon: Icon(Icons.sensor_door_outlined),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (selection) =>
              setState(() => _view = selection.first),
        ),
        const SizedBox(height: 16),
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
                  hintText: 'Search visitor, host or property',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            if (_view == 0)
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Pass status',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'checked_in',
                      child: Text('Checked in'),
                    ),
                    DropdownMenuItem(value: 'expired', child: Text('Expired')),
                    DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _view == 0
              ? '${passes.length} invitation records'
              : '${checkedIn.length} active visits',
          style: const TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_view == 0)
          for (final pass in passes) _PassCard(pass: pass)
        else if (checkedIn.isEmpty)
          const _EmptyVisitors()
        else
          for (final visitor in checkedIn) _GateVisitorCard(visitor: visitor),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .1),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: EstateColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

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
        Icon(Icons.info_outline_rounded, color: EstateColors.forest, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Sample preview data. Gate verification, pass creation and check-out require the estate security service.',
            style: TextStyle(color: EstateColors.forest, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass});
  final VisitorPassSummary pass;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(pass.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 14,
          spacing: 20,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 290,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.visitorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${pass.propertyLabel}  ·  Host: ${pass.hostName}',
                    style: const TextStyle(color: EstateColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 230,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pass.validFrom} – ${pass.validUntil}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${pass.uses} of ${pass.useLimit} entries used${pass.vehicleSummary == null ? '' : '  ·  ${pass.vehicleSummary}'}',
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(
              label: status.$1,
              color: status.$2,
              background: status.$3,
            ),
            const Tooltip(
              message: 'Pass credentials are never shown in this list.',
              child: Icon(
                Icons.lock_outline_rounded,
                color: EstateColors.muted,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateVisitorCard extends StatelessWidget {
  const _GateVisitorCard({required this.visitor});
  final GateVisitorSummary visitor;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitor.visitorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${visitor.propertyLabel}  ·  Host: ${visitor.hostName}',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${visitor.gateName}  ·  ${visitor.checkedInAt}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          _StatusPill(
            label: visitor.admissionType == 'manual'
                ? 'Manual admission'
                : 'Pass verified',
            color: visitor.admissionType == 'manual'
                ? const Color(0xFF8A5B13)
                : EstateColors.forest,
            background: visitor.admissionType == 'manual'
                ? const Color(0xFFFFF2D8)
                : const Color(0xFFE9F4ED),
          ),
          if (visitor.vehicleSummary != null)
            Text(
              visitor.vehicleSummary!,
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}

class _EmptyVisitors extends StatelessWidget {
  const _EmptyVisitors();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.door_front_door_outlined,
            size: 36,
            color: EstateColors.muted,
          ),
          SizedBox(height: 10),
          Text('No current visitors match your search.'),
        ],
      ),
    ),
  );
}

(String, Color, Color) _statusStyle(String status) => switch (status) {
  'active' => ('Active', EstateColors.forest, const Color(0xFFE9F4ED)),
  'checked_in' => (
    'Checked in',
    const Color(0xFF476B91),
    const Color(0xFFEAF1F8),
  ),
  'expired' => ('Expired', EstateColors.muted, const Color(0xFFF0F1F2)),
  'revoked' => ('Revoked', const Color(0xFF984B43), const Color(0xFFF9EDEC)),
  _ => (status, EstateColors.muted, const Color(0xFFF0F1F2)),
};
