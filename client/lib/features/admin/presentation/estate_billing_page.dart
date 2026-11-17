import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateBillingPage extends StatefulWidget {
  const EstateBillingPage({super.key, required this.invoices});
  final List<EstateInvoiceSummary> invoices;

  @override
  State<EstateBillingPage> createState() => _EstateBillingPageState();
}

class _EstateBillingPageState extends State<EstateBillingPage> {
  final _search = TextEditingController();
  String _status = 'all';
  bool _openDisputesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issued = widget.invoices
        .where((i) => i.status != 'draft' && i.balance != null)
        .length;
    final overdue = widget.invoices
        .where((i) => i.overdue && i.balance != '0')
        .length;
    final disputes = widget.invoices.where((i) => i.disputed).length;
    final query = _search.text.trim().toLowerCase();
    final visible = widget.invoices.where((i) {
      final text =
          '${i.invoiceNumber} ${i.category} ${i.payerDisplayName ?? ''} ${i.propertyCode ?? ''}'
              .toLowerCase();
      return (_status == 'all' || i.status == _status) &&
          (!_openDisputesOnly || i.disputed) &&
          (query.isEmpty || text.contains(query));
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Billing and notices',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review issued estate invoices, verified allocations and balances.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create invoice'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _BillingNotice(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 560
                ? box.maxWidth
                : (box.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BillingMetric(
                  width: width,
                  label: 'Issued invoices',
                  value: '$issued',
                  icon: Icons.receipt_long_outlined,
                  color: EstateColors.forest,
                ),
                _BillingMetric(
                  width: width,
                  label: 'Overdue balances',
                  value: '$overdue',
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFF984B43),
                ),
                _BillingMetric(
                  width: width,
                  label: 'Disputes flagged',
                  value: '$disputes',
                  icon: Icons.flag_outlined,
                  color: const Color(0xFF8A6731),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search invoice, payer or property',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'issued', child: Text('Issued')),
                    DropdownMenuItem(
                      value: 'partially_paid',
                      child: Text('Partially paid'),
                    ),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(
                      value: 'disputed',
                      child: Text('Disputed'),
                    ),
                    DropdownMenuItem(value: 'void', child: Text('Void')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
                FilterChip(
                  label: const Text('Disputed'),
                  selected: _openDisputesOnly,
                  onSelected: (value) =>
                      setState(() => _openDisputesOnly = value),
                ),
                Text(
                  '${visible.length} invoices',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('No invoices match these filters.')),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('INVOICE')),
                  DataColumn(label: Text('PAYER / PROPERTY')),
                  DataColumn(label: Text('DUE DATE')),
                  DataColumn(label: Text('TOTAL')),
                  DataColumn(label: Text('BALANCE')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: visible
                    .map(
                      (i) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 175,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.invoiceNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    i.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: EstateColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 145,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.payerDisplayName ?? '—'),
                                  Text(
                                    i.propertyCode ?? 'Estate-level',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: EstateColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(_date(i.dueAt))),
                          DataCell(Text(_amount(i.total, i.currency))),
                          DataCell(
                            Text(
                              i.balance == null
                                  ? 'Not issued'
                                  : _amount(i.balance!, i.currency),
                              style: TextStyle(
                                color: i.overdue && i.balance != '0'
                                    ? const Color(0xFF984B43)
                                    : EstateColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            _InvoiceState(
                              status: i.status,
                              overdue: i.overdue,
                              disputed: i.disputed,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Balances are derived by the billing service from verified payment allocations. Preview figures are illustrative.',
          style: TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
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

  String _amount(String value, String currency) =>
      '$currency ${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
}

class _BillingNotice extends StatelessWidget {
  const _BillingNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFDDE8E0)),
    ),
    child: const Row(
      children: [
        Icon(Icons.account_balance_outlined, color: EstateColors.forest),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview invoice register. A connected billing service must authorize the estate and derive balances only from verified allocations.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _BillingMetric extends StatelessWidget {
  const _BillingMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: const TextStyle(color: EstateColors.muted)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InvoiceState extends StatelessWidget {
  const _InvoiceState({
    required this.status,
    required this.overdue,
    required this.disputed,
  });
  final String status;
  final bool overdue;
  final bool disputed;
  @override
  Widget build(BuildContext context) {
    final value = disputed
        ? 'Disputed'
        : overdue && status != 'paid'
        ? 'Overdue'
        : status
              .split('_')
              .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
              .join(' ');
    final color = disputed || overdue && status != 'paid'
        ? const Color(0xFF984B43)
        : status == 'paid'
        ? EstateColors.forest
        : const Color(0xFF476B91);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
