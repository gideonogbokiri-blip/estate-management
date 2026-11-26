import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Estate payouts in the Terra Crest visual language.
///
/// An estate manager may initiate a payout, but policy requires a separate
/// approver to make the decision.
class TerraPayoutsPage extends StatefulWidget {
  const TerraPayoutsPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraPayoutsPage> createState() => _TerraPayoutsPageState();
}

class _TerraPayoutsPageState extends State<TerraPayoutsPage> {
  List<EstatePayoutBeneficiaryRecord> _beneficiaries = const [];
  List<EstatePayoutRecord> _payouts = const [];
  bool _loading = true;
  bool _working = false;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Beneficiaries and payouts load independently.
    Future<void> load<T>(Future<T> Function() read, void Function(T) apply) async {
      try {
        apply(await read());
      } catch (_) {
        // Keep the previous value for this section.
      }
      if (mounted) setState(() {});
    }

    await Future.wait([
      load(
        () => widget.repository.loadPayoutBeneficiaries(widget.estateId),
        (value) => _beneficiaries = value,
      ),
      load(
        () => widget.repository.loadPayouts(widget.estateId),
        (value) => _payouts = value,
      ),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  int get _pendingCount => _payouts
      .where((payout) => payout.status.toLowerCase().contains('pending'))
      .length;

  double get _totalAmount => _payouts.fold<double>(
        0,
        (sum, payout) => sum + (double.tryParse(payout.amount) ?? 0),
      );

  String _idempotencyKey() =>
      'payout-${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  Future<void> _initiate() async {
    if (_beneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No beneficiary is configured for this estate.'),
        ),
      );
      return;
    }
    var beneficiary = _beneficiaries.first;
    final amount = TextEditingController(text: '10000.00');
    final purpose = TextEditingController(text: 'Estate operations');
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? dialogError;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Initiate payout'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Initiating a payout records a request only. A separate approver must decide on it before anything is paid.',
                      style: TextStyle(
                        color: TerraColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<EstatePayoutBeneficiaryRecord>(
                      initialValue: beneficiary,
                      decoration: const InputDecoration(labelText: 'Beneficiary'),
                      items: _beneficiaries
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                '${item.displayName} · ${item.bankName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          refresh(() => beneficiary = value ?? beneficiary),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount (NGN)'),
                      validator: (value) => value == null ||
                              !RegExp(r'^(0|[1-9]\d{0,9})\.\d{2}$')
                                  .hasMatch(value.trim())
                          ? 'Enter an amount with two decimal places.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: purpose,
                      decoration: const InputDecoration(labelText: 'Purpose'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a purpose.'
                          : null,
                    ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: TerraColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      refresh(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await widget.repository.createPayout(
                          estateId: widget.estateId,
                          beneficiaryId: beneficiary.id,
                          amount: amount.text.trim(),
                          purpose: purpose.text.trim(),
                          idempotencyKey: _idempotencyKey(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (_) {
                        refresh(() {
                          saving = false;
                          dialogError = 'The payout could not be initiated.';
                        });
                      }
                    },
              child: Text(saving ? 'Initiating…' : 'Initiate'),
            ),
          ],
        ),
      ),
    );

    amount.dispose();
    purpose.dispose();
    if (created != true || !mounted) return;

    setState(() => _working = true);
    try {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout initiated. It is awaiting a separate approver.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _decide(EstatePayoutRecord payout, String decision) async {
    setState(() => _workingId = payout.id);
    try {
      await widget.repository.decidePayout(
        estateId: widget.estateId,
        payoutId: payout.id,
        decision: decision,
        note: decision == 'approve'
            ? 'Approved after estate review.'
            : 'Declined after estate review.',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approve' ? 'Payout approved.' : 'Payout declined.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A separate approver must approve this payout.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  TerraBadgeTone _tone(String status) => switch (status.toLowerCase()) {
        'approved' || 'paid' || 'settled' => TerraBadgeTone.sage,
        'pending' || 'pending_approval' || 'initiated' || 'draft' =>
          TerraBadgeTone.amber,
        'rejected' || 'declined' || 'cancelled' => TerraBadgeTone.danger,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Payouts'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _working ? null : _load,
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
                  TerraSectionTitle(
                    title: 'Estate payouts',
                    trailing: FilledButton.icon(
                      onPressed: _loading || _working ? null : _initiate,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Initiate payout'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.estateName,
                    style: const TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Managers initiate payouts; policy requires a separate approver for every decision.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TerraCard(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 170,
                          child: TerraMetric(
                            label: 'Total payouts',
                            value: '${_payouts.length}',
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: TerraMetric(
                            label: 'Pending approvals',
                            value: '$_pendingCount',
                            icon: Icons.pending_outlined,
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: TerraMetric(
                            label: 'Total amount',
                            value: AppFormat.money(_totalAmount.toStringAsFixed(2)),
                            icon: Icons.account_balance_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const TerraSectionTitle(title: 'Beneficiaries'),
                  const SizedBox(height: 12),
                  if (_beneficiaries.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No payout beneficiaries are configured for this estate.',
                        icon: Icons.account_balance_outlined,
                      ),
                    )
                  else
                    ..._beneficiaries.map(
                      (beneficiary) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: TerraColors.sage,
                                child: Icon(
                                  Icons.business_outlined,
                                  size: 18,
                                  color: TerraColors.forest,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      beneficiary.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                    Text(
                                      '${beneficiary.bankName} · ${beneficiary.accountNumber}',
                                      style: const TextStyle(
                                        color: TerraColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  TerraSectionTitle(
                    title: 'Payout requests',
                    trailing: TerraBadge(
                      label: '${_payouts.length} records',
                      tone: TerraBadgeTone.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loading && _payouts.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_payouts.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No payouts have been initiated for this estate.',
                        icon: Icons.payments_outlined,
                      ),
                    )
                  else
                    ..._payouts.map(
                      (payout) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppFormat.money(
                                        payout.amount,
                                        currency: payout.currency.isEmpty
                                            ? 'NGN'
                                            : payout.currency,
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: payout.status.replaceAll('_', ' '),
                                    tone: _tone(payout.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 22,
                                runSpacing: 10,
                                children: [
                                  _term('Purpose', payout.purpose.isEmpty ? '—' : payout.purpose),
                                  _term(
                                    'Beneficiary',
                                    payout.beneficiaryName.isEmpty
                                        ? '—'
                                        : payout.beneficiaryName,
                                  ),
                                  _term(
                                    'Initiated',
                                    AppFormat.date(payout.createdAt),
                                  ),
                                ],
                              ),
                              if (payout.status.toLowerCase().contains('pending')) ...[
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _workingId != null
                                          ? null
                                          : () => _decide(payout, 'reject'),
                                      icon: const Icon(Icons.close_outlined, size: 16),
                                      label: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton.icon(
                                      onPressed: _workingId != null
                                          ? null
                                          : () => _decide(payout, 'approve'),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text('Approve'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const TerraCard(
                    child: TerraEmpty(
                      message:
                          'Approvals are recorded separately from initiation. The manager who starts a payout cannot be its approver.',
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _term(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerraLabel(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TerraColors.ink,
            ),
          ),
        ],
      );
}
