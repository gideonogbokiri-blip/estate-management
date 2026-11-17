import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class TenancyApprovalApiPage extends StatefulWidget {
  const TenancyApprovalApiPage({super.key, required this.repository, required this.estateId, required this.estateName});
  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TenancyApprovalApiPage> createState() => _TenancyApprovalApiPageState();
}

class _TenancyApprovalApiPageState extends State<TenancyApprovalApiPage> {
  List<TenancyApprovalRecord> _items = const [];
  bool _loading = true;
  String? _workingId;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await widget.repository.loadPendingTenancyApprovals(widget.estateId);
    } catch (error) {
      _error = error is EstateApiException ? error.message : 'Pending tenancy approvals could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(TenancyApprovalRecord record) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ApprovalReasonDialog());
    if (reason == null || !mounted) return;
    setState(() { _workingId = record.id; _error = null; });
    try {
      await widget.repository.approveTenancy(estateId: widget.estateId, tenancyId: record.id, reason: reason);
      _items = await widget.repository.loadPendingTenancyApprovals(widget.estateId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenancy approved. Resident access is now active.')));
    } catch (error) {
      _error = error is EstateApiException ? error.message : 'The tenancy could not be approved.';
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tenancy approvals'),
      actions: [IconButton(tooltip: 'Refresh', onPressed: _loading || _workingId != null ? null : _load, icon: const Icon(Icons.refresh_rounded))],
    ),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(widget.estateName, style: const TextStyle(color: EstateColors.muted)),
        const SizedBox(height: 5),
        const Text('Pending tenancy terms', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: EstateColors.ink)),
        const SizedBox(height: 6),
        const Text('Review the tenant, landlord and agreed rent before activating the tenancy.', style: TextStyle(color: EstateColors.muted, height: 1.5)),
        const SizedBox(height: 16),
        const _InfoCard(message: 'Approval activates the tenancy, records tenant occupancy and grants resident membership. The API only allows approval for a tenancy whose start date is effective.'),
        const SizedBox(height: 14),
        if (_error != null) _InfoCard(message: _error!, error: true),
        if (_loading) const LinearProgressIndicator(minHeight: 2)
        else if (_items.isEmpty)
          const _InfoCard(message: 'No pending tenancy terms are waiting for approval.')
        else ..._items.map((record) => _TenancyCard(
          record: record,
          busy: _workingId == record.id,
          disabled: _workingId != null,
          onApprove: () => _approve(record),
        )),
      ]),
    )),
  );
}

class _TenancyCard extends StatelessWidget {
  const _TenancyCard({required this.record, required this.busy, required this.disabled, required this.onApprove});
  final TenancyApprovalRecord record;
  final bool busy;
  final bool disabled;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFFE9F2ED), child: Icon(Icons.key_outlined, color: EstateColors.forest)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.propertyCode, style: const TextStyle(fontWeight: FontWeight.w700, color: EstateColors.ink)),
          Text('Tenant: ${record.tenantName}', style: const TextStyle(color: EstateColors.muted, fontSize: 12)),
        ])),
        if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 22, runSpacing: 10, children: [
        _Term(label: 'Rent', value: '${record.currency} ${record.amount} / ${record.frequency}'),
        _Term(label: 'Payee', value: record.payeeName),
        _Term(label: 'Due day', value: 'Day ${record.dueDay}'),
        _Term(label: 'Starts', value: _date(record.effectiveFrom)),
      ]),
      if (record.termsNote?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Text(record.termsNote!, style: const TextStyle(color: EstateColors.muted, height: 1.4)),
      ],
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(
        onPressed: disabled ? null : onApprove,
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Approve tenancy'),
      )),
    ])),
  );

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: EstateColors.muted, fontSize: 11)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
    color: error ? const Color(0xFFFFF0EE) : null,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: TextStyle(color: error ? EstateColors.red : EstateColors.muted, height: 1.45))),
  );
}

class _ApprovalReasonDialog extends StatefulWidget {
  const _ApprovalReasonDialog();
  @override
  State<_ApprovalReasonDialog> createState() => _ApprovalReasonDialogState();
}

class _ApprovalReasonDialogState extends State<_ApprovalReasonDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Approve tenancy'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      minLines: 3,
      maxLines: 5,
      maxLength: 1000,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'Approval reason', hintText: 'Record what you checked.'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, _reason.text.trim()), child: const Text('Confirm approval')),
    ],
  );
}
