import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateFinancePage extends StatefulWidget {
  const EstateFinancePage({
    super.key,
    required this.budgets,
    required this.expenses,
    required this.metrics,
    required this.repository,
    required this.onExpensesChanged,
  });

  final List<FinanceBudgetLine> budgets;
  final List<EstateExpenseRequest> expenses;
  final FinanceMetrics? metrics;
  final EstateAdminRepository repository;
  final VoidCallback onExpensesChanged;

  @override
  State<EstateFinancePage> createState() => _EstateFinancePageState();
}

class _EstateFinancePageState extends State<EstateFinancePage> {
  final _search = TextEditingController();
  int _view = 0;
  String _status = 'all';
  late Future<List<FinanceActivityEntry>> _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.repository.loadFinanceActivity();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.expenses
        .where((item) => item.status == 'pending_approval')
        .length;
    final visible = widget.expenses.where((item) {
      final query = _search.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          '${item.reference} ${item.description} ${item.requesterName} ${item.payeeName} ${item.category}'
              .toLowerCase()
              .contains(query);
      return matchesQuery && (_status == 'all' || item.status == _status);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
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
                  'Finance and expenses',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Monitor approved budgets and review estate spending.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Request expense'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _FinancePreviewNotice(),
        const SizedBox(height: 17),
        _FinanceSummary(metrics: widget.metrics, pending: pending),
        const SizedBox(height: 23),
        SegmentedButton<int>(
          segments: [
            const ButtonSegment(
              value: 0,
              label: Text('Budget overview'),
              icon: Icon(Icons.pie_chart_outline_rounded),
            ),
            ButtonSegment(
              value: 1,
              label: Text(
                'Expense requests${pending == 0 ? '' : ' · $pending'}',
              ),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
            const ButtonSegment(
              value: 2,
              label: Text('Recent activity'),
              icon: Icon(Icons.history_rounded),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (selected) =>
              setState(() => _view = selected.first),
        ),
        const SizedBox(height: 17),
        if (_view == 0) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current budget lines',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${widget.budgets.length} approved lines',
                style: const TextStyle(color: EstateColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.budgets.isEmpty)
            const _FinanceEmpty(
              message:
                  'No approved budgets are available in this estate preview.',
            )
          else
            for (final budget in widget.budgets) _BudgetCard(budget: budget),
        ] else if (_view == 1) ...[
          Text(
            'Expense approval queue',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Approval authorizes spend; payment is recorded only after trusted reconciliation.',
            style: TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 13),
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
                    hintText: 'Search request, category or payee',
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
                    labelText: 'Expense status',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(
                      value: 'pending_approval',
                      child: Text('Pending approval'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'partially_paid',
                      child: Text('Partially paid'),
                    ),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${visible.length} expense requests',
            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const _FinanceEmpty(
              message: 'No expense requests match these filters.',
            )
          else
            for (final expense in visible)
              _ExpenseCard(
                expense: expense,
                onTap: () => _openExpense(expense),
              ),
        ] else ...[
          Text(
            'Finance activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Review expense decisions and payment allocations recorded for this estate.',
            style: TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<FinanceActivityEntry>>(
            future: _activity,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _FinanceEmpty(
                  message: 'Finance activity could not be loaded.',
                  action: TextButton(
                    onPressed: () => setState(() {
                      _activity = widget.repository.loadFinanceActivity();
                    }),
                    child: const Text('Retry'),
                  ),
                );
              }
              return _FinanceActivityList(entries: snapshot.data ?? const []);
            },
          ),
        ],
      ],
    );
  }

  Future<void> _openExpense(EstateExpenseRequest expense) async {
    final decided = await showDialog<bool>(
      context: context,
      builder: (context) => _ExpenseDetailDialog(
        expense: expense,
        repository: widget.repository,
        onDecision: (decision, reason) =>
            widget.repository.decideExpenseRequest(
              expenseId: expense.id,
              decision: decision,
              reason: reason,
            ),
      ),
    );
    if (decided == true && mounted) widget.onExpensesChanged();
  }
}

class _FinancePreviewNotice extends StatelessWidget {
  const _FinancePreviewNotice();
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
        Icon(Icons.verified_outlined, size: 19, color: Color(0xFF8A5B13)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Sample finance data. Budgets and paid amounts must be derived from estate records and verified payment allocations.',
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

class _FinanceSummary extends StatelessWidget {
  const _FinanceSummary({required this.metrics, required this.pending});
  final FinanceMetrics? metrics;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final finance = metrics;
    final tiles = <_FinanceMetricTile>[
      _FinanceMetricTile(
        'Rent collected',
        finance?.rentCollected ?? '—',
        Icons.home_work_outlined,
        EstateColors.forest,
      ),
      _FinanceMetricTile(
        'Estate charges',
        finance?.estateFeesCollected ?? '—',
        Icons.apartment_outlined,
        const Color(0xFF476B91),
      ),
      _FinanceMetricTile(
        'Expenses paid',
        finance?.expensesPaid ?? '—',
        Icons.payments_outlined,
        const Color(0xFF8A5B13),
      ),
      _FinanceMetricTile(
        'Awaiting approval',
        '$pending',
        Icons.pending_actions_outlined,
        const Color(0xFF765797),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        return compact
            ? Column(
                children: [
                  for (final tile in tiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _MetricCard(tile: tile),
                    ),
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == tiles.length - 1 ? 0 : 11,
                        ),
                        child: _MetricCard(tile: tiles[i]),
                      ),
                    ),
                ],
              );
      },
    );
  }
}

class _FinanceMetricTile {
  const _FinanceMetricTile(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.tile});
  final _FinanceMetricTile tile;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tile.color.withValues(alpha: .1),
            foregroundColor: tile.color,
            child: Icon(tile.icon),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tile.label,
                style: const TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});
  final FinanceBudgetLine budget;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      budget.periodLabel,
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(budget.committedRatio * 100).round()}% committed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: EstateColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: budget.committedRatio.clamp(0, 1),
              minHeight: 7,
              backgroundColor: const Color(0xFFE9EDE9),
              color: EstateColors.forest,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final small = constraints.maxWidth < 650;
              final values = [
                _BudgetValue(label: 'Allocated', value: budget.allocatedLabel),
                _BudgetValue(label: 'Committed', value: budget.committedLabel),
                _BudgetValue(label: 'Paid · verified', value: budget.paidLabel),
                _BudgetValue(
                  label: 'Available',
                  value: budget.availableLabel,
                  emphasis: true,
                ),
              ];
              return small
                  ? Wrap(spacing: 22, runSpacing: 12, children: values)
                  : Row(
                      children: [
                        for (final item in values) Expanded(child: item),
                      ],
                    );
            },
          ),
        ],
      ),
    ),
  );
}

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: EstateColors.muted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: emphasis ? EstateColors.forest : null,
        ),
      ),
    ],
  );
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.onTap});
  final EstateExpenseRequest expense;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final state = _expenseState(expense.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3EE),
          child: Icon(
            _categoryIcon(expense.category),
            color: EstateColors.forest,
          ),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${expense.reference} · ${expense.category} · ${expense.requesterName}\nPayee: ${expense.payeeName} · ${expense.submittedAt}',
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              expense.amountLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            _StatusChip(label: state.$1, color: state.$2, background: state.$3),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailDialog extends StatefulWidget {
  const _ExpenseDetailDialog({
    required this.expense,
    required this.repository,
    required this.onDecision,
  });
  final EstateExpenseRequest expense;
  final EstateAdminRepository repository;

  final Future<EstateExpenseRequest> Function(String decision, String reason)
  onDecision;

  @override
  State<_ExpenseDetailDialog> createState() => _ExpenseDetailDialogState();
}

class _ExpenseDetailDialogState extends State<_ExpenseDetailDialog> {
  final _reason = TextEditingController();
  late Future<EstateExpenseDetail> _detail;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.readExpenseRequestDetail(widget.expense.id);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    final reason = _reason.text.trim();
    if (decision == 'reject' && reason.isEmpty) {
      setState(() => _error = 'Enter a reason before rejecting this request.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onDecision(decision, reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The decision could not be recorded. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final status = _expenseState(expense.status);
    final canApprove = expense.allowedCommands.contains('approve');
    final canReject = expense.allowedCommands.contains('reject');
    return AlertDialog(
      title: Text(expense.reference),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expense.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 13),
              _DetailRow(label: 'Category', value: expense.category),
              _DetailRow(label: 'Requester', value: expense.requesterName),
              _DetailRow(label: 'Payee', value: expense.payeeName),
              _DetailRow(label: 'Requested amount', value: expense.amountLabel),
              _DetailRow(label: 'Submitted', value: expense.submittedAt),
              _DetailRow(label: 'Status', value: status.$1),
              const SizedBox(height: 5),
              FutureBuilder<EstateExpenseDetail>(
                future: _detail,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Approval history is unavailable.',
                      style: TextStyle(color: EstateColors.muted, fontSize: 11),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  return _ApprovalHistoryBlock(detail: snapshot.requireData);
                },
              ),
              if (expense.verifiedPaidLabel != null)
                _DetailRow(
                  label: 'Verified payments allocated',
                  value: expense.verifiedPaidLabel!,
                ),
              if (expense.decisionNote != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Decision note',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  expense.decisionNote!,
                  style: const TextStyle(height: 1.4),
                ),
              ],
              if (expense.status == 'pending_approval' &&
                  (canApprove || canReject)) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Decision note',
                    hintText: 'Required when rejecting',
                    alignLabelWithHint: true,
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preview decisions are stored in this session only. A real decision is subject to estate policy and audit.',
                  style: TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ] else if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFF984B43))),
              ],
              const SizedBox(height: 12),
              const Text(
                'Payment state reflects verified payment allocations. Approving a request does not mark it as paid.',
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (canReject)
          OutlinedButton(
            onPressed: _saving ? null : () => _decide('reject'),
            child: const Text('Reject request'),
          ),
        if (canApprove)
          FilledButton(
            onPressed: _saving ? null : () => _decide('approve'),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve expense'),
          ),
      ],
    );
  }
}

class _ApprovalHistoryBlock extends StatelessWidget {
  const _ApprovalHistoryBlock({required this.detail});
  final EstateExpenseDetail detail;

  @override
  Widget build(BuildContext context) {
    final completedStages = detail.approvalHistory
        .where((entry) => entry.decision == 'approve')
        .length;
    final hasCurrentStage = detail.currentStageLabel != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Approval progress',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              if (detail.approvalPolicyVersion != null)
                Text(
                  detail.approvalPolicyVersion!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: EstateColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (detail.approvalStageCount > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: (completedStages / detail.approvalStageCount).clamp(
                  0.0,
                  1.0,
                ),
                backgroundColor: const Color(0xFFE3E9E4),
                color: EstateColors.forest,
              ),
            ),
          const SizedBox(height: 7),
          Text(
            hasCurrentStage
                ? 'Stage ${detail.approvalStageIndex + 1} of ${detail.approvalStageCount} · ${detail.currentStageLabel}'
                : '${detail.approvalHistory.length} decision${detail.approvalHistory.length == 1 ? '' : 's'} recorded',
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
          if (detail.approvalHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final entry in detail.approvalHistory) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    entry.decision == 'approve'
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: entry.decision == 'approve'
                        ? EstateColors.forest
                        : const Color(0xFF984B43),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.stageLabel} · ${entry.decision == 'approve' ? 'Approved' : 'Rejected'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.actorName} · ${entry.decidedAt}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: EstateColors.muted,
                          ),
                        ),
                        if (entry.reason != null &&
                            entry.reason!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            entry.reason!,
                            style: const TextStyle(fontSize: 11, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (entry != detail.approvalHistory.last)
                const Divider(height: 17),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No approval decisions have been recorded yet.',
                style: TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
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
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _FinanceEmpty extends StatelessWidget {
  const _FinanceEmpty({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_outlined,
            size: 38,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 10),
          Text(message),
          ?action,
        ],
      ),
    ),
  );
}

class _FinanceActivityList extends StatefulWidget {
  const _FinanceActivityList({required this.entries});
  final List<FinanceActivityEntry> entries;

  @override
  State<_FinanceActivityList> createState() => _FinanceActivityListState();
}

class _FinanceActivityListState extends State<_FinanceActivityList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries.where((entry) {
      return _filter == 'all' ||
          (_filter == 'payments'
              ? entry.type == 'payment_allocated'
              : entry.type != 'payment_allocated');
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All activity')),
            ButtonSegment(value: 'decisions', label: Text('Decisions')),
            ButtonSegment(value: 'payments', label: Text('Verified payments')),
          ],
          selected: {_filter},
          onSelectionChanged: (selected) =>
              setState(() => _filter = selected.first),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const _FinanceEmpty(
            message: 'No finance activity matches this filter.',
          )
        else
          for (final entry in entries) _FinanceActivityCard(entry: entry),
      ],
    );
  }
}

class _FinanceActivityCard extends StatelessWidget {
  const _FinanceActivityCard({required this.entry});
  final FinanceActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final isPayment = entry.type == 'payment_allocated';
    final isApproved = entry.type == 'expense_approved';
    final tone = isPayment
        ? EstateColors.forest
        : isApproved
        ? const Color(0xFF476B91)
        : const Color(0xFF984B43);
    final badge = isPayment
        ? 'Verified payment'
        : isApproved
        ? 'Approved · not a payment'
        : 'Rejected';
    final localTime = entry.occurredAt.toLocal();
    final date =
        '${localTime.day} ${_monthName(localTime.month)} ${localTime.year} · '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tone.withValues(alpha: .10),
              foregroundColor: tone,
              child: Icon(
                isPayment ? Icons.verified_rounded : Icons.fact_check_outlined,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        badge,
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        entry.reference,
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$date · ${entry.actorName}',
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (entry.verifiedAt != null)
                    Text(
                      'Payment verified ${entry.verifiedAt!.toLocal()}',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              entry.amountLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) => const [
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
][month - 1];

(String, Color, Color) _expenseState(String status) => switch (status) {
  'pending_approval' => (
    'Pending approval',
    const Color(0xFFFFF2D8),
    const Color(0xFF8A5B13),
  ),
  'approved' => ('Approved', const Color(0xFFEAF1F8), const Color(0xFF476B91)),
  'partially_paid' => (
    'Partially paid',
    const Color(0xFFF0EAF7),
    const Color(0xFF765797),
  ),
  'paid' => ('Paid', const Color(0xFFE9F4ED), EstateColors.forest),
  'rejected' => ('Rejected', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  _ => (status, const Color(0xFFF0F1F2), EstateColors.muted),
};

IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
  'security operations' => Icons.shield_outlined,
  'utilities' => Icons.bolt_outlined,
  'community and facilities' => Icons.apartment_outlined,
  _ => Icons.handyman_outlined,
};
