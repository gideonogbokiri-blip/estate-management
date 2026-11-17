import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class EstateExpensesApiPage extends StatefulWidget {
  const EstateExpensesApiPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
    required this.roles,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
  final List<String> roles;

  @override
  State<EstateExpensesApiPage> createState() => _EstateExpensesApiPageState();
}

class _EstateExpensesApiPageState extends State<EstateExpensesApiPage> {
  Map<String, dynamic> _policyResponse = const {};
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _payees = const [];
  List<Map<String, dynamic>> _expenses = const [];
  List<Map<String, dynamic>> _budgets = const [];
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _canConfigure => widget.roles.any(
    (role) => role == 'estate_administrator' || role == 'finance_manager',
  );

  Map<String, dynamic>? get _policy =>
      _policyResponse['policy'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.repository.loadExpensePolicy(widget.estateId),
        widget.repository.loadExpenseCategories(widget.estateId),
        widget.repository.loadExpensePayees(widget.estateId),
        widget.repository.loadExpenseRequests(widget.estateId),
        widget.repository.loadEstateBudgets(widget.estateId),
      ]);
      _policyResponse = result[0] as Map<String, dynamic>;
      _categories = result[1] as List<Map<String, dynamic>>;
      _payees = result[2] as List<Map<String, dynamic>>;
      _expenses = result[3] as List<Map<String, dynamic>>;
      _budgets = result[4] as List<Map<String, dynamic>>;
    } catch (error) {
      _error = error is EstateApiException
          ? error.message
          : 'Expense data could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _configurePolicy() async {
    if (!_canConfigure || _working) return;
    var firstRole = 'FINANCE_MANAGER';
    var secondRole = 'ESTATE_ADMINISTRATOR';
    var addSecondStage = false;
    var allowUnbudgeted = _policy?['allowUnbudgeted'] == true;
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Expense approval policy'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the roles that review requests. The person who requests an expense cannot approve it.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: firstRole,
                  decoration: const InputDecoration(
                    labelText: 'First approval stage',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'FINANCE_MANAGER',
                      child: Text('Finance manager'),
                    ),
                    DropdownMenuItem(
                      value: 'ESTATE_ADMINISTRATOR',
                      child: Text('Estate administrator'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialog(() => firstRole = value ?? firstRole),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require a second approver'),
                  value: addSecondStage,
                  onChanged: (value) => setDialog(() => addSecondStage = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow requests without an approved budget line',
                  ),
                  value: allowUnbudgeted,
                  onChanged: (value) =>
                      setDialog(() => allowUnbudgeted = value),
                ),
                if (addSecondStage)
                  DropdownButtonFormField<String>(
                    initialValue: secondRole,
                    decoration: const InputDecoration(
                      labelText: 'Second approval stage',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FINANCE_MANAGER',
                        child: Text('Finance manager'),
                      ),
                      DropdownMenuItem(
                        value: 'ESTATE_ADMINISTRATOR',
                        child: Text('Estate administrator'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialog(() => secondRole = value ?? secondRole),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Approved budgets are estate and category scoped. Approval authorizes spend but does not send money or mark it paid.',
                  style: TextStyle(
                    color: EstateColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (addSecondStage && firstRole == secondRole) return;
                Navigator.pop(dialogContext, {
                  'stages': [
                    {'role': firstRole},
                    if (addSecondStage) {'role': secondRole},
                  ],
                  'allowUnbudgeted': allowUnbudgeted,
                  'requireDistinctApprovers': true,
                });
              },
              child: const Text('Save policy'),
            ),
          ],
        ),
      ),
    );
    if (saved == null || !mounted) return;
    await _run(() async {
      await widget.repository.configureExpensePolicy(
        estateId: widget.estateId,
        policy: saved,
      );
      await _load();
    });
  }

  Future<void> _createBudget() async {
    if (!_canConfigure || _working) return;
    if (_categories.where((item) => item['active'] == true).isEmpty) {
      setState(
        () => _error = 'Add at least one active expense category first.',
      );
      return;
    }
    final now = DateTime.now();
    final start = TextEditingController(text: '${now.year}-01-01');
    final end = TextEditingController(text: '${now.year}-12-31');
    final currency = TextEditingController(text: 'NGN');
    final allocations = <String, TextEditingController>{
      for (final category in _categories.where(
        (item) => item['active'] == true,
      ))
        category['id'] as String: TextEditingController(),
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create estate budget'),
        content: SizedBox(
          width: 480,
          height: 440,
          child: ListView(
            children: [
              const Text(
                'Amounts are allocated by category for this inclusive period.',
              ),
              TextField(
                controller: start,
                decoration: const InputDecoration(
                  labelText: 'Period starts (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: end,
                decoration: const InputDecoration(
                  labelText: 'Period ends (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: currency,
                maxLength: 3,
                decoration: const InputDecoration(labelText: 'Currency code'),
              ),
              const SizedBox(height: 10),
              for (final category in _categories.where(
                (item) => item['active'] == true,
              ))
                TextField(
                  controller: allocations[category['id'] as String],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${category['name']} allocation (optional)',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lines = allocations.entries
                  .where((entry) => entry.value.text.trim().isNotEmpty)
                  .map(
                    (entry) => {
                      'categoryId': entry.key,
                      'allocatedAmount': entry.value.text.trim(),
                    },
                  )
                  .toList();
              Navigator.pop(dialogContext, {
                'periodStart': start.text.trim(),
                'periodEnd': end.text.trim(),
                'currency': currency.text.trim().toUpperCase(),
                'lines': lines,
              });
            },
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await _run(() async {
        await widget.repository.createEstateBudget(
          estateId: widget.estateId,
          budget: result,
        );
        await _load();
      });
    }
    start.dispose();
    end.dispose();
    currency.dispose();
    for (final controller in allocations.values) {
      controller.dispose();
    }
  }

  Future<void> _submitBudget(Map<String, dynamic> budget) async {
    await _run(() async {
      await widget.repository.submitEstateBudget(
        estateId: widget.estateId,
        budgetId: budget['id'] as String,
      );
      await _load();
    });
  }

  Future<void> _decideBudget(
    Map<String, dynamic> budget,
    String decision,
  ) async {
    String? reason;
    if (decision == 'reject') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject budget'),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Reject budget'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    await _run(() async {
      await widget.repository.decideEstateBudget(
        estateId: widget.estateId,
        budgetId: budget['id'] as String,
        decision: decision,
        reason: reason,
      );
      await _load();
    });
  }

  Future<void> _createCategory() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add expense category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            TextField(
              controller: code,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Category code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add category'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await _run(() async {
        await widget.repository.createExpenseCategory(
          estateId: widget.estateId,
          code: code.text.trim(),
          name: name.text.trim(),
        );
        await _load();
      });
    }
    code.dispose();
    name.dispose();
  }

  Future<void> _createPayee() async {
    final reference = TextEditingController();
    final name = TextEditingController();
    final destination = TextEditingController(text: 'ref:');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add payee'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Vendor or payee name',
                ),
              ),
              TextField(
                controller: reference,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Estate reference',
                ),
              ),
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Currency',
                  hintText: 'NGN',
                ),
              ),
              TextField(
                controller: destination,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Opaque payout reference',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Do not enter bank or account numbers. Store an external `ref:` identifier here; verification records your offline check only. This app will not send a payment.',
                style: TextStyle(
                  color: EstateColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add payee'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await _run(() async {
        await widget.repository.createExpensePayee(
          estateId: widget.estateId,
          payee: {
            'reference': reference.text.trim(),
            'displayName': name.text.trim(),
            'currency': 'NGN',
            'destinationReference': destination.text.trim(),
          },
        );
        await _load();
      });
    }
    reference.dispose();
    name.dispose();
    destination.dispose();
  }

  Future<void> _verifyPayee(Map<String, dynamic> payee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify payee destination?'),
        content: Text(
          'Confirm that an authorized estate officer independently checked the payout reference for ${payee['displayName']}. This records verification; it does not transfer funds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm verification'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _run(() async {
        await widget.repository.verifyExpensePayee(
          estateId: widget.estateId,
          payeeId: payee['id'] as String,
        );
        await _load();
      });
    }
  }

  Future<void> _createDraft() async {
    final allowUnbudgeted = _policy?['allowUnbudgeted'] == true;
    final eligibleCategories = _categories
        .where(
          (item) =>
              item['active'] == true &&
              (allowUnbudgeted ||
                  _budgetLinesFor(item['id'] as String).isNotEmpty),
        )
        .toList();
    if (_categories.isEmpty ||
        !_payees.any((payee) => payee['verified'] == true)) {
      setState(
        () => _error =
            'Add a category and verify a payee before creating a request.',
      );
      return;
    }
    if (eligibleCategories.isEmpty) {
      setState(
        () => _error = 'Create and approve an in-period budget line before requesting this expense.',
      );
      return;
    }
    final description = TextEditingController();
    final amount = TextEditingController();
    Map<String, dynamic> category = eligibleCategories.first;
    Map<String, dynamic> payee = _payees.firstWhere(
      (item) => item['verified'] == true,
    );
    String budgetLineId = _budgetLinesFor(category['id'] as String).isNotEmpty
        ? _budgetLinesFor(category['id'] as String).first['id'] as String
        : '';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New expense request'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: eligibleCategories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialog(() {
                    category = value ?? category;
                    final lines = _budgetLinesFor(category['id'] as String);
                    budgetLineId = lines.isNotEmpty
                        ? lines.first['id'] as String
                        : '';
                  }),
                ),
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
                          '${line['periodStart']} · ${line['currency']} ${line['available']} available',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialog(() => budgetLineId = value ?? ''),
                ),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: payee,
                  decoration: const InputDecoration(
                    labelText: 'Verified payee',
                  ),
                  items: _payees
                      .where((item) => item['verified'] == true)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item['displayName'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialog(() => payee = value ?? payee),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount (NGN)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: !allowUnbudgeted && budgetLineId.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'description': description.text.trim(),
                      'categoryId': category['id'],
                      'payeeId': payee['id'],
                      'amount': amount.text.trim(),
                      'currency': 'NGN',
                      if (budgetLineId.isNotEmpty) 'budgetLineId': budgetLineId,
                    }),
              child: const Text('Save draft'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await _run(() async {
        await widget.repository.createExpenseDraft(
          estateId: widget.estateId,
          expense: result,
          idempotencyKey: List<int>.generate(
            24,
            (_) => Random.secure().nextInt(256),
          ).map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
        );
        await _load();
      });
    }
    description.dispose();
    amount.dispose();
  }

  Future<void> _submitExpense(String expenseId) async {
    await _run(() async {
      await widget.repository.submitExpense(
        estateId: widget.estateId,
        expenseId: expenseId,
      );
      await _load();
    });
  }

  Future<void> _decide(Map<String, dynamic> expense, String decision) async {
    String? reason;
    if (decision == 'reject') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject expense'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Reject request'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    await _run(() async {
      await widget.repository.decideExpense(
        estateId: widget.estateId,
        expenseId: expense['id'] as String,
        decision: decision,
        reason: reason,
      );
      await _load();
    });
  }

  Future<void> _reconcileExpense(Map<String, dynamic> expense) async {
    final amount = TextEditingController(
      text: expense['balance'] as String? ?? '',
    );
    final reference = TextEditingController();
    final receivedAt = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final note = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record verified expense payment'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'First verify the transfer in the bank record. This records a manual reconciliation; no bank feed or transfer is connected.',
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${expense['currency']})',
                ),
              ),
              TextField(
                controller: reference,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Bank transaction reference',
                ),
              ),
              TextField(
                controller: receivedAt,
                decoration: const InputDecoration(
                  labelText: 'Received date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: note,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'How was it verified? (required)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reference.text.trim().isEmpty ||
                  note.text.trim().length < 8) {
                return;
              }
              Navigator.pop(dialogContext, {
                'amount': amount.text.trim(),
                'bankReference': reference.text.trim(),
                'receivedAt': receivedAt.text.trim(),
                'verificationNote': note.text.trim(),
              });
            },
            child: const Text('Record verified payment'),
          ),
        ],
      ),
    );
    amount.dispose();
    reference.dispose();
    receivedAt.dispose();
    note.dispose();
    if (result == null || !mounted) return;
    await _run(() async {
      await widget.repository.reconcileExpense(
        estateId: widget.estateId,
        expenseId: expense['id'] as String,
        settlement: result,
        idempotencyKey: List<int>.generate(
          24,
          (_) => Random.secure().nextInt(256),
        ).map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
      );
      await _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is EstateApiException
              ? error.message
              : 'The expense action could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _money(Map<String, dynamic> expense) =>
      '${expense['currency']} ${expense['amount']}';

  List<Map<String, dynamic>> _budgetLinesFor(String categoryId) => [
    for (final budget in _budgets.where(
      (item) =>
          item['status'] == 'approved' &&
          item['effectiveToday'] == true &&
          item['currency'] == 'NGN',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EstateColors.canvas,
    appBar: AppBar(
      title: Text('${widget.estateName} · Expenses'),
      actions: [
        IconButton(
          onPressed: _working || _loading ? null : _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    'Expense requests',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Requests and approvals are recorded separately from payment. This workspace does not send money or mark expenses paid.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _error = null),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                  if (_working) const LinearProgressIndicator(),
                  const SizedBox(height: 18),
                  _budgetSection(),
                  const SizedBox(height: 12),
                  _policyCard(context),
                  const SizedBox(height: 12),
                  _setupCard(context),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Requests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _working || _policy == null
                            ? null
                            : _createDraft,
                        icon: const Icon(Icons.add),
                        label: const Text('New request'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_expenses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'No expense requests have been recorded for this estate.',
                        ),
                      ),
                    )
                  else
                    for (final expense in _expenses) _expenseCard(expense),
                ],
              ),
      ),
    ),
  );

  Widget _budgetSection() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Estate budgets',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (_canConfigure)
                OutlinedButton.icon(
                  onPressed: _working ? null : _createBudget,
                  icon: const Icon(Icons.add),
                  label: const Text('New budget'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Committed amounts are derived from approved expense requests. Payment totals are not available in this view.',
          ),
          if (_budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'No budget versions have been recorded for this estate.',
              ),
            )
          else ...[
            const Divider(height: 22),
            for (final budget in _budgets) _budgetCard(budget),
          ],
        ],
      ),
    ),
  );

  Widget _budgetCard(Map<String, dynamic> budget) {
    final allowed = (budget['allowedCommands'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final lines = (budget['lines'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final decisions = (budget['decisions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EstateColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${budget['periodStart']} to ${budget['periodEnd']} · v${budget['version']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(
                  (budget['status'] as String? ?? '').replaceAll('_', ' '),
                ),
              ),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${(line['category'] as Map<String, dynamic>?)?['name'] ?? 'Category'} · allocated ${budget['currency']} ${line['allocated']} · committed ${line['committed']} · paid ${line['paid'] ?? '0.00'} · available ${line['available']}',
              ),
            ),
          if (decisions.isNotEmpty)
            for (final decision in decisions)
              Text(
                '${decision['decision']} · ${decision['actorName']} · ${decision['occurredAt']}',
                style: const TextStyle(color: EstateColors.muted, fontSize: 12),
              ),
          if (allowed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (allowed.contains('submit'))
                  OutlinedButton(
                    onPressed: _working ? null : () => _submitBudget(budget),
                    child: const Text('Submit for approval'),
                  ),
                if (allowed.contains('approve'))
                  FilledButton(
                    onPressed: _working
                        ? null
                        : () => _decideBudget(budget, 'approve'),
                    child: const Text('Approve budget'),
                  ),
                if (allowed.contains('reject'))
                  OutlinedButton(
                    onPressed: _working
                        ? null
                        : () => _decideBudget(budget, 'reject'),
                    child: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _policyCard(BuildContext context) {
    final policy = _policy;
    final stages = (policy?['stages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule_folder_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Approval policy',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (_canConfigure)
                  OutlinedButton(
                    onPressed: _working ? null : _configurePolicy,
                    child: Text(policy == null ? 'Configure' : 'Edit policy'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (policy == null)
              const Text(
                'Set the authorized approval roles before expense drafts can be submitted.',
              )
            else
              Text(
                'Version ${policy['version']} · ${stages.map((stage) => (stage['role'] as String).replaceAll('_', ' ').toLowerCase()).join(' then ')} · ${policy['allowUnbudgeted'] == true ? 'unbudgeted requests allowed' : 'budget required'}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categories and payees',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Payee verification records an offline check. Bank details stay outside this app.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _canConfigure && !_working ? _createCategory : null,
                icon: const Icon(Icons.category_outlined),
                label: Text('Categories (${_categories.length})'),
              ),
              OutlinedButton.icon(
                onPressed: _canConfigure && !_working ? _createPayee : null,
                icon: const Icon(Icons.business_outlined),
                label: Text('Add payee (${_payees.length})'),
              ),
            ],
          ),
          if (_payees.isNotEmpty) ...[
            const Divider(height: 22),
            for (final payee in _payees)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  payee['verified'] == true
                      ? Icons.verified_outlined
                      : Icons.pending_outlined,
                ),
                title: Text(payee['displayName'] as String? ?? 'Payee'),
                subtitle: Text(
                  '${payee['reference']} · ${payee['currency']} · ${payee['verified'] == true ? 'verified offline' : 'not verified'}',
                ),
                trailing: payee['verified'] == true || !_canConfigure
                    ? null
                    : TextButton(
                        onPressed: _working ? null : () => _verifyPayee(payee),
                        child: const Text('Verify'),
                      ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _expenseCard(Map<String, dynamic> expense) {
    final allowed = (expense['allowedCommands'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final category = expense['category'] as Map<String, dynamic>? ?? const {};
    final payee = expense['payee'] as Map<String, dynamic>? ?? const {};
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${expense['code']} · ${expense['description']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(
                    (expense['status'] as String? ?? '').replaceAll('_', ' '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_money(expense)} · ${category['name'] ?? 'Category'} · ${payee['displayName'] ?? 'Payee'}',
            ),
            Text('Requested by ${expense['requesterName'] ?? 'Estate staff'}'),
            if (expense['status'] == 'partially_paid' ||
                expense['status'] == 'paid')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Verified received: ${expense['currency']} ${expense['paidAmount']} · outstanding: ${expense['currency']} ${expense['balance']}',
                  style: const TextStyle(
                    color: EstateColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final payment
                in (expense['settlements'] as List? ?? const [])
                    .whereType<Map<String, dynamic>>())
              Text(
                'Receipt reference ${payment['receiptNumber']} · ${payment['currency']} ${payment['amount']} · ${payment['receivedAt']}',
                style: const TextStyle(color: EstateColors.muted, fontSize: 12),
              ),
            if (expense['status'] == 'approved')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Approved to spend · payment not recorded',
                  style: TextStyle(
                    color: EstateColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if ((expense['decisions'] as List? ?? const []).isNotEmpty) ...[
              const Divider(height: 20),
              for (final decision
                  in (expense['decisions'] as List)
                      .whereType<Map<String, dynamic>>())
                Text(
                  '${decision['decision']} · ${decision['actorName']} · ${decision['occurredAt']}',
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
            if (allowed.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (allowed.contains('submit'))
                    OutlinedButton(
                      onPressed: _working
                          ? null
                          : () => _submitExpense(expense['id'] as String),
                      child: const Text('Submit for approval'),
                    ),
                  if (allowed.contains('approve'))
                    FilledButton(
                      onPressed: _working
                          ? null
                          : () => _decide(expense, 'approve'),
                      child: const Text('Approve'),
                    ),
                  if (allowed.contains('reject'))
                    OutlinedButton(
                      onPressed: _working
                          ? null
                          : () => _decide(expense, 'reject'),
                      child: const Text('Reject'),
                    ),
                  if (allowed.contains('reconcile'))
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _reconcileExpense(expense),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Record verified payment'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
