import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class OwnershipReviewApiPage extends StatefulWidget {
  const OwnershipReviewApiPage({super.key, required this.repository, required this.estateId, required this.estateName});
  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<OwnershipReviewApiPage> createState() => _OwnershipReviewApiPageState();
}

class _OwnershipReviewApiPageState extends State<OwnershipReviewApiPage> {
  List<OwnershipReviewRecord> _items = const [];
  bool _loading = true;
  String? _workingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await widget.repository.loadPendingOwnershipReviews(widget.estateId);
    } catch (error) {
      _error = error is EstateApiException ? error.message : 'Ownership reviews could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(OwnershipReviewRecord record, String decision) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _OwnershipDecisionDialog(decision: decision),
    );
    if (reason == null || !mounted) return;
    setState(() { _workingId = record.id; _error = null; });
    try {
      await widget.repository.decideOwnershipReview(
        estateId: widget.estateId,
        ownershipId: record.id,
        decision: decision,
        reason: reason,
      );
      _items = await widget.repository.loadPendingOwnershipReviews(widget.estateId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(decision == 'verify' ? 'Ownership verified and landlord access updated.' : 'Ownership claim rejected.'),
        ));
      }
    } catch (error) {
      _error = error is EstateApiException ? error.message : 'The ownership decision could not be saved.';
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ownership verification'),
      actions: [IconButton(tooltip: 'Refresh', onPressed: _loading || _workingId != null ? null : _load, icon: const Icon(Icons.refresh_rounded))],
    ),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(widget.estateName, style: const TextStyle(color: EstateColors.muted)),
        const SizedBox(height: 5),
        const Text('Pending ownership claims', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: EstateColors.ink)),
        const SizedBox(height: 6),
        const Text('Check the evidence recorded by your estate team, then verify or reject the claim with a reason.', style: TextStyle(color: EstateColors.muted, height: 1.5)),
        const SizedBox(height: 18),
        if (_error != null) _Notice(message: _error!, error: true),
        if (_loading) const LinearProgressIndicator(minHeight: 2)
        else if (_items.isEmpty)
          const _Notice(message: 'No active ownership claims are waiting for review.')
        else ..._items.map((record) => _OwnershipReviewCard(
          record: record,
          busy: _workingId == record.id,
          disabled: _workingId != null,
          onVerify: () => _decide(record, 'verify'),
          onReject: () => _decide(record, 'reject'),
        )),
      ]),
    )),
  );
}

class _OwnershipReviewCard extends StatelessWidget {
  const _OwnershipReviewCard({required this.record, required this.busy, required this.disabled, required this.onVerify, required this.onReject});
  final OwnershipReviewRecord record;
  final bool busy;
  final bool disabled;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFFE9F2ED), child: Icon(Icons.person_outline_rounded, color: EstateColors.forest)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.ownerName, style: const TextStyle(fontWeight: FontWeight.w700, color: EstateColors.ink)),
            Text('${record.propertyCode} · ${record.propertyType}', style: const TextStyle(color: EstateColors.muted, fontSize: 12)),
          ])),
          if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 24, runSpacing: 8, children: [
          _Detail(label: 'Ownership share', value: '${record.share}%'),
          _Detail(label: 'Effective from', value: _date(record.effectiveFrom)),
          _Detail(label: 'Claim submitted', value: _date(record.createdAt)),
        ]),
        const SizedBox(height: 12),
        const Text('Evidence checked by estate team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(record.evidenceNote, style: const TextStyle(color: EstateColors.muted, height: 1.45)),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: disabled ? null : onReject, icon: const Icon(Icons.close_rounded), label: const Text('Reject claim')),
          FilledButton.icon(onPressed: disabled ? null : onVerify, icon: const Icon(Icons.verified_outlined), label: const Text('Verify ownership')),
        ]),
      ]),
    ),
  );

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: EstateColors.muted, fontSize: 11)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
    color: error ? const Color(0xFFFFF0EE) : null,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: TextStyle(color: error ? EstateColors.red : EstateColors.muted))),
  );
}

class _OwnershipDecisionDialog extends StatefulWidget {
  const _OwnershipDecisionDialog({required this.decision});
  final String decision;
  @override
  State<_OwnershipDecisionDialog> createState() => _OwnershipDecisionDialogState();
}

class _OwnershipDecisionDialogState extends State<_OwnershipDecisionDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final verify = widget.decision == 'verify';
    return AlertDialog(
      title: Text(verify ? 'Verify ownership' : 'Reject ownership claim'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: verify ? 'Verification reason' : 'Rejection reason',
          hintText: verify ? 'Record what was verified.' : 'Explain what needs correction.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()),
          child: Text(verify ? 'Confirm verification' : 'Confirm rejection'),
        ),
      ],
    );
  }
}
