import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/platform_application_repository.dart';

class PlatformMoneyPage extends StatefulWidget {
  const PlatformMoneyPage({super.key, required this.repository});
  final PlatformApplicationApiRepository repository;

  @override
  State<PlatformMoneyPage> createState() => _PlatformMoneyPageState();
}

class _PlatformMoneyPageState extends State<PlatformMoneyPage> {
  late Future<PlatformMoneyOverview> _overview;
  late Future<List<PlatformEstateRecord>> _estates;
  String? _estateId;
  late Future<List<PlatformMoneyAccount>> _accounts;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _overview = widget.repository.loadPlatformMoneyOverview();
    _estates = widget.repository.loadPlatformEstates();
    _accounts = Future.value(const []);
    _estates.then((items) {
      if (items.isNotEmpty && mounted) {
        setState(() {
          _estateId = items.first.id;
          _accounts = widget.repository.loadPlatformMoneyAccounts(_estateId!);
        });
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _overview = widget.repository.loadPlatformMoneyOverview();
      _estates = widget.repository.loadPlatformEstates();
      if (_estateId != null) {
        _accounts = widget.repository.loadPlatformMoneyAccounts(_estateId!);
      }
    });
  }

  Future<void> _adjust(PlatformMoneyAccount account) async {
    final request = await showDialog<_Adjustment>(
      context: context,
      builder: (context) => const _AdjustmentDialog(),
    );
    if (request == null) return;
    final key = 'balance-adjust-${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(1 << 30)}';
    try {
      await widget.repository.adjustPlatformBalance(
        estateId: _estateId!,
        userId: account.userId,
        amount: request.amount,
        currency: request.currency,
        direction: request.direction,
        reason: request.reason,
        idempotencyKey: key,
      );
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance adjustment recorded and audited.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustment failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Account balances',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 5),
      const Text(
        'Platform super administrators only. Adjustments are staff-entered ledger entries, not provider payments; every change is audited.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 14),
      FutureBuilder<PlatformMoneyOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final data = snapshot.requireData;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(label: 'Estates', value: '${data.estatesActive}/${data.estatesTotal}'),
              _Metric(label: 'Users', value: '${data.users}'),
              _Metric(label: 'Adjustments', value: '${data.adjustmentsTotal}'),
              _Metric(label: 'Credited', value: data.credited),
              _Metric(label: 'Debited', value: data.debited),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      FutureBuilder<List<PlatformEstateRecord>>(
        future: _estates,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final items = snapshot.requireData;
          if (items.isEmpty) {
            return const Text('No estates have been approved yet.');
          }
          return DropdownButtonFormField<String>(
            initialValue: _estateId,
            decoration: const InputDecoration(
              labelText: 'Estate',
              border: OutlineInputBorder(),
            ),
            items: items
                .map((estate) => DropdownMenuItem(
                      value: estate.id,
                      child: Text(estate.name),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _estateId = value;
                _accounts = widget.repository.loadPlatformMoneyAccounts(value);
              });
            },
          );
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search resident or landlord',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<PlatformMoneyAccount>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Accounts could not be loaded: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final term = _search.text.toLowerCase().trim();
          final rows = snapshot.requireData.where((account) {
            return term.isEmpty ||
                '${account.displayName} ${account.email}'
                    .toLowerCase()
                    .contains(term);
          }).toList();
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No resident or landlord accounts in this estate.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: rows
                .map(
                  (account) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: account.accountRole == 'LANDLORD'
                            ? const Color(0xFFFFECEA)
                            : const Color(0xFFEAF3EE),
                        child: Icon(
                          account.accountRole == 'LANDLORD'
                              ? Icons.home_outlined
                              : Icons.person_outline,
                          color: account.accountRole == 'LANDLORD'
                              ? EstateColors.red
                              : EstateColors.forest,
                        ),
                      ),
                      title: Text(account.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${account.email}\n${account.accountRole} · '
                        '${account.balances.isEmpty ? 'No manual adjustments' : account.balances.entries.map((entry) => '${entry.key} ${entry.value}').join(', ')}',
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      isThreeLine: true,
                      trailing: FilledButton.tonal(
                        onPressed: () => _adjust(account),
                        child: const Text('Adjust'),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          Text(label, style: const TextStyle(color: EstateColors.muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _Adjustment {
  const _Adjustment({
    required this.amount,
    required this.currency,
    required this.direction,
    required this.reason,
  });
  final String amount;
  final String currency;
  final String direction;
  final String reason;
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog();
  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'NGN');
  final _reason = TextEditingController();
  String _direction = 'credit';

  @override
  void dispose() {
    _amount.dispose();
    _currency.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adjust account balance'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _direction,
              decoration: const InputDecoration(labelText: 'Direction'),
              items: const [
                DropdownMenuItem(value: 'credit', child: Text('Credit (add money)')),
                DropdownMenuItem(value: 'debit', child: Text('Debit (subtract money)')),
              ],
              onChanged: (value) => setState(() => _direction = value ?? _direction),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (e.g. 2500.00)'),
              validator: (value) => value == null || !RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(value.trim())
                  ? 'Enter a positive amount with up to 2 decimals.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _currency,
              maxLength: 3,
              decoration: const InputDecoration(labelText: 'Currency (e.g. NGN)'),
              validator: (value) => value == null || !RegExp(r'^[A-Z]{3}$').hasMatch(value.trim())
                  ? 'Enter a 3-letter uppercase currency code.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason (required, audited)'),
              validator: (value) => value == null || value.trim().length < 5
                  ? 'A reason of at least 5 characters is required.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _Adjustment(
              amount: _amount.text.trim(),
              currency: _currency.text.trim().toUpperCase(),
              direction: _direction,
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Record adjustment'),
      ),
    ],
  );
}
