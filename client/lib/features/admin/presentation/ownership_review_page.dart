import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class OwnershipReviewPage extends StatefulWidget {
  const OwnershipReviewPage({
    super.key,
    required this.records,
    required this.onBack,
  });
  final List<EstatePropertyRecord> records;
  final VoidCallback onBack;

  @override
  State<OwnershipReviewPage> createState() => _OwnershipReviewPageState();
}

class _OwnershipReviewPageState extends State<OwnershipReviewPage> {
  String _filter = 'pending_review';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.records
        .where((record) => record.ownershipReview != null)
        .toList();
    final pending = reviews
        .where(
          (record) =>
              record.ownershipReview!.verificationStatus == 'pending_review',
        )
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = reviews.where((record) {
      final review = record.ownershipReview!;
      final matchesFilter =
          _filter == 'all' || review.verificationStatus == _filter;
      final matchesSearch =
          query.isEmpty ||
          '${record.code} ${record.structureLabel ?? ''} ${review.ownerDisplayName}'
              .toLowerCase()
              .contains(query);
      return matchesFilter && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Property register'),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
        ),
        const SizedBox(height: 6),
        Text(
          'Ownership verification',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Review property ownership claims and their verification status.',
          style: TextStyle(color: EstateColors.muted),
        ),
        const SizedBox(height: 16),
        const _OwnershipNotice(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 560
                ? box.maxWidth
                : (box.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ReviewMetric(
                  width: width,
                  label: 'Awaiting review',
                  value: '$pending',
                  color: const Color(0xFF8A6731),
                  icon: Icons.pending_actions_outlined,
                ),
                _ReviewMetric(
                  width: width,
                  label: 'Reviewed records',
                  value: '${reviews.length - pending}',
                  color: EstateColors.forest,
                  icon: Icons.verified_outlined,
                ),
                _ReviewMetric(
                  width: width,
                  label: 'Records returned',
                  value: '${reviews.length}',
                  color: const Color(0xFF476B91),
                  icon: Icons.home_work_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search owner, property or structure',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(
                      value: 'pending_review',
                      child: Text('Awaiting review'),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verified'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All review states'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filter = value ?? 'pending_review'),
                ),
                Text(
                  '${visible.length} records',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(26),
              child: Center(
                child: Text('No ownership reviews match these filters.'),
              ),
            ),
          )
        else
          ...visible.map((record) {
            final review = record.ownershipReview!;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFEAF1EC),
                              child: Icon(
                                Icons.person_outline,
                                color: EstateColors.forest,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.ownerDisplayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${record.code} · ${record.structureLabel ?? 'Estate property'}',
                                  style: const TextStyle(
                                    color: EstateColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _ReviewStatus(status: review.verificationStatus),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 22,
                      runSpacing: 10,
                      children: [
                        _ReviewDetail(
                          label: 'Ownership share',
                          value: review.ownershipShare,
                        ),
                        _ReviewDetail(
                          label: 'Effective from',
                          value: _date(review.effectiveFrom),
                        ),
                        _ReviewDetail(
                          label: 'Relationship',
                          value: _label(review.ownershipStatus),
                        ),
                        _ReviewDetail(
                          label: 'Evidence category',
                          value: review.evidenceCategory ?? 'Not listed',
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'Evidence files open through the authorized private-file service. This summary contains no file reference or document content.',
                      style: TextStyle(color: EstateColors.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Review evidence'),
                        ),
                        const Spacer(),
                        if (review.verificationStatus == 'pending_review') ...[
                          TextButton(
                            onPressed: null,
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 7),
                          FilledButton(
                            onPressed: null,
                            child: const Text('Verify ownership'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        const Text(
          'Verification decisions require the ownership.verify permission, authorized evidence access, a reason where applicable and an audit event.',
          style: TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _label(String value) => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _OwnershipNotice extends StatelessWidget {
  const _OwnershipNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_user_outlined, color: EstateColors.forest),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Preview ownership records. Verification applies only to the linked property relationship and never grants estate staff permissions.',
            style: TextStyle(color: EstateColors.ink, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final double width;
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReviewDetail extends StatelessWidget {
  const _ReviewDetail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: EstateColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 9,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'verified'
        ? EstateColors.forest
        : status == 'rejected'
        ? const Color(0xFF984B43)
        : const Color(0xFF8A6731);
    final label = status
        .split('_')
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
