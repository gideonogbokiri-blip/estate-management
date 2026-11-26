import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../onboarding/data/estate_application_repository.dart';

/// Estate spending requests, budgets and approval policy in the Terra Crest
/// visual language. Approvals are recorded separately from payment.
class TerraExpensesPage extends StatefulWidget {
  const TerraExpensesPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraExpensesPage> createState() => _TerraExpensesPageState();
}

class _TerraExpensesPageState extends State<TerraExpensesPage> {
  Map<String, dynamic> _policyResponse = const {};
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _payees = const [];
  List<Map<String, dynamic>> _requests = const [];
  List<Map<String, dynamic>> _budgets = const [];
  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? get _policy =>
      _policyResponse['policy'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Each read is independent so one failing section cannot blank the page.
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
        () => widget.repository.loadExpensePolicy(widget.estateId),
        (value) => _policyResponse = value,
      ),
      load(
        () => widget.repository.loadExpenseCategories(widget.estateId),
        (value) => _categories = value,
      ),
      load(
        () => widget.repository.loadExpensePayees(widget.estateId),
        (value) => _payees = value,
      ),
      load(
        () => widget.repository.loadExpenseRequests(widget.estateId),
        (value) => _requests = value,
      ),
      load(
        () => widget.repository.loadEstateBudgets(widget.estateId),
        (value) => _budgets = value,
      ),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  String _newIdempotencyKey() => List<int>.generate(
        24,
        (_) => Random.secure().nextInt(256),
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  List<Map<String, dynamic>> _budgetLinesFor(String categoryId) => [
        for (final budget in _budgets.where(
          (item) =>
              item['status'] == 'approved' &&
              item['effectiveToday'] == true,
        ))
          for (final line
              in (budget['lines'] as List? ?? const [])
                  .whereType<Map<String, dynamic>>())
            if (line['categoryId'] == categoryId)
              {
                ...line,
                'periodStart': budget['periodStart'],
                'currency': budget['currency'],
              },
      ];

  Future<void> _createRequest() async {
    final allowUnbudgeted = _policy?['allowUnbudgeted'] == true;
    final categories = _categories.where((item) => item['active'] == true).toList();
    final payees = _payees.where((item) => item['verified'] == true).toList();
    if (categories.isEmpty || payees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add an active category and verify a payee before creating a request.',
            ),
          ),
        );
      }
      return;
    }

    final description = TextEditingController();
    final amount = TextEditingController();
    Map<String, dynamic> category = categories.first;
    Map<String, dynamic> payee = payees.first;
    String budgetLineId = _budgetLinesFor(category['id'] as String).isNotEmpty
        ? _budgetLinesFor(category['id'] as String).first['id'] as String
        : '';
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? dialogError;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('New expense request'),
          content: SizedBox(
            width: 470,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A request records intent to spend. Approval does not send money or mark the expense paid.',
                      style: TextStyle(
                        color: TerraColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: description,
                      maxLength: 1000,
                      decoration: const InputDecoration(labelText: 'Description'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a description.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text('${item['name'] ?? 'Category'}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => refresh(() {
                        category = value ?? category;
                        final lines = _budgetLinesFor(category['id'] as String);
                        budgetLineId = lines.isNotEmpty
                            ? lines.first['id'] as String
                            : '';
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: budgetLineId,
                      decoration: const InputDecoration(
                        labelText: 'Approved budget line',
                      ),
                      items: [
                        if (allowUnbudgeted)
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Unbudgeted request'),
                          ),
                        ..._budgetLinesFor(category['id'] as String).map(
                          (line) => DropdownMenuItem(
                            value: line['id'] as String,
                            child: Text(
                              '${line['periodStart']} · ${AppFormat.money(line['available'] ?? '0', currency: '${line['currency'] ?? 'NGN'}')} available',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          refresh(() => budgetLineId = value ?? ''),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: payee,
                      decoration: const InputDecoration(labelText: 'Verified payee'),
                      items: payees
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text('${item['displayName'] ?? 'Payee'}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => refresh(() => payee = value ?? payee),
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
                      if (!allowUnbudgeted && budgetLineId.isEmpty) return;
                      refresh(() {
                        saving = true;
                        dialogError = null;
                      });
                      final expense = <String, dynamic>{
                        'description': description.text.trim(),
                        'categoryId': category['id'],
                        'payeeId': payee['id'],
                        'amount': amount.text.trim(),
                        'currency': 'NGN',
                        if (budgetLineId.isNotEmpty) 'budgetLineId': budgetLineId,
                      };
                      try {
                        await widget.repository.createExpenseDraft(
                          estateId: widget.estateId,
                          expense: expense,
                          idempotencyKey: _newIdempotencyKey(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (_) {
                        refresh(() {
                          saving = false;
                          dialogError = 'The request could not be saved.';
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save request'),
            ),
          ],
        ),
      ),
    );

    description.dispose();
    amount.dispose();
    if (created != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense request saved as a draft.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TerraBadgeTone _tone(String status) => switch (status.toLowerCase()) {
        'approved' || 'paid' || 'active' || 'effective' => TerraBadgeTone.sage,
        'draft' || 'pending' || 'submitted' || 'partially_paid' =>
          TerraBadgeTone.amber,
        'rejected' || 'declined' || 'cancelled' => TerraBadgeTone.danger,
        _ => TerraBadgeTone.outline,
      };

  @override
  Widget build(BuildContext context) {
    final stages = (_policy?['stages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Expenses'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading || _saving ? null : _load,
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
                    title: 'Spending requests',
                    trailing: FilledButton.icon(
                      onPressed: _loading || _saving ? null : _createRequest,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New request'),
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
                    'Requests and approvals are recorded separately from payment. This workspace does not send money or mark expenses paid.',
                    style: TextStyle(
                      color: TerraColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_loading && _requests.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(color: TerraColors.forest),
                    )
                  else if (_requests.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No expense requests have been recorded for this estate.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    )
                  else
                    ..._requests.map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${expense['reference'] ?? expense['code'] ?? 'Request'} · ${expense['description'] ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: '${expense['status'] ?? 'draft'}'
                                        .replaceAll('_', ' '),
                                    tone: _tone('${expense['status'] ?? ''}'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 22,
                                runSpacing: 10,
                                children: [
                                  _term(
                                    'Amount',
                                    AppFormat.money(
                                      expense['amount'] ?? '0',
                                      currency: '${expense['currency'] ?? 'NGN'}',
                                    ),
                                  ),
                                  _term(
                                    'Category',
                                    '${(expense['category'] as Map? ?? const {})['name'] ?? '—'}',
                                  ),
                                  _term(
                                    'Payee',
                                    '${(expense['payee'] as Map? ?? const {})['displayName'] ?? '—'}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Requested by ${expense['requesterName'] ?? 'Estate staff'}',
                                style: const TextStyle(
                                  color: TerraColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  TerraSectionTitle(
                    title: 'Budget',
                    trailing: TerraBadge(
                      label: '${_budgets.length} versions',
                      tone: TerraBadgeTone.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_budgets.isEmpty)
                    const TerraCard(
                      child: TerraEmpty(
                        message: 'No budget versions have been recorded for this estate.',
                        icon: Icons.pie_chart_outline,
                      ),
                    )
                  else
                    ..._budgets.map(
                      (budget) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TerraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${AppFormat.date(budget['periodStart'])} – ${AppFormat.date(budget['periodEnd'])} · v${budget['version'] ?? '1'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: TerraColors.ink,
                                      ),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: '${budget['status'] ?? 'draft'}'
                                        .replaceAll('_', ' '),
                                    tone: _tone('${budget['status'] ?? ''}'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final line
                                  in (budget['lines'] as List? ?? const [])
                                      .whereType<Map<String, dynamic>>())
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${(line['category'] as Map? ?? const {})['name'] ?? 'Category'} · allocated ${AppFormat.money(line['allocated'] ?? '0', currency: '${budget['currency'] ?? 'NGN'}')} · committed ${AppFormat.money(line['committed'] ?? '0', currency: '${budget['currency'] ?? 'NGN'}')} · available ${AppFormat.money(line['available'] ?? '0', currency: '${budget['currency'] ?? 'NGN'}')}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),
                  TerraSectionTitle(
                    title: 'Categories & payees',
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        TerraBadge(
                          label: '${_categories.length} categories',
                          tone: TerraBadgeTone.outline,
                        ),
                        TerraBadge(
                          label: '${_payees.length} payees',
                          tone: TerraBadgeTone.outline,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TerraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_categories.isEmpty)
                          const TerraEmpty(
                            message: 'No expense categories have been added.',
                          )
                        else
                          ..._categories.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.category_outlined,
                                      size: 16, color: TerraColors.forest),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${category['name'] ?? 'Category'} · ${category['code'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: category['active'] == true
                                        ? 'Active'
                                        : 'Inactive',
                                    tone: category['active'] == true
                                        ? TerraBadgeTone.sage
                                        : TerraBadgeTone.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_payees.isNotEmpty) const Divider(height: 20),
                        if (_payees.isEmpty)
                          const TerraEmpty(
                            message: 'No payees have been added.',
                          )
                        else
                          ..._payees.map(
                            (payee) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    payee['verified'] == true
                                        ? Icons.verified_outlined
                                        : Icons.pending_outlined,
                                    size: 16,
                                    color: TerraColors.forest,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${payee['displayName'] ?? 'Payee'} · ${payee['reference'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TerraBadge(
                                    label: payee['verified'] == true
                                        ? 'Verified'
                                        : 'Unverified',
                                    tone: payee['verified'] == true
                                        ? TerraBadgeTone.sage
                                        : TerraBadgeTone.amber,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const TerraSectionTitle(title: 'Approval policy'),
                  const SizedBox(height: 12),
                  TerraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_policy == null)
                          const TerraEmpty(
                            message:
                                'No approval policy is configured for this estate yet.',
                            icon: Icons.rule_folder_outlined,
                          )
                        else ...[
                          TerraLabel('Version ${_policy?['version'] ?? '1'}'),
                          const SizedBox(height: 8),
                          if (stages.isEmpty)
                            const Text(
                              'No approval stages are configured.',
                              style: TextStyle(
                                color: TerraColors.muted,
                                fontSize: 12,
                              ),
                            )
                          else
                            ...stages.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Stage ${entry.key + 1}: ${(entry.value['role'] as String? ?? 'approver').replaceAll('_', ' ').toLowerCase()}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _policy?['allowUnbudgeted'] == true
                                ? 'Requests without an approved budget line are allowed.'
                                : 'Every request must have an approved budget line.',
                            style: const TextStyle(
                              color: TerraColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
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
