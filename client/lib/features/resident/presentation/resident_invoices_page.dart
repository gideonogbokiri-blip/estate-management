import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentInvoicesPage extends StatelessWidget {
  const ResidentInvoicesPage({
    super.key,
    required this.invoices,
    required this.onBack,
  });

  final List<ResidentInvoice> invoices;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: _ResidentInvoicesTabs(invoices: invoices, onBack: onBack),
  );
}

class _ResidentInvoicesTabs extends StatelessWidget {
  const _ResidentInvoicesTabs({required this.invoices, required this.onBack});
  final List<ResidentInvoice> invoices;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final outstanding = invoices
        .where((invoice) => invoice.balanceLabel != '₦0')
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Community services'),
          ),
        ),
        Text('Billing', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        const Text(
          'Outstanding estate charges and verified payments linked to your property.',
        ),
        const SizedBox(height: 16),
        const _BillingNotice(),
        const SizedBox(height: 16),
        const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Outstanding'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Receipts'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: TabBarView(
            children: [
              _InvoiceHistoryTab(invoices: invoices, outstanding: outstanding),
              _VerifiedReceiptsTab(invoices: invoices),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceHistoryTab extends StatelessWidget {
  const _InvoiceHistoryTab({required this.invoices, required this.outstanding});
  final List<ResidentInvoice> invoices;
  final int outstanding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 22),
    children: [
      Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Invoices',
              value: '${invoices.length}',
              icon: Icons.receipt_long_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'With balance',
              value: '$outstanding',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (invoices.isEmpty)
        const _EmptyInvoices()
      else
        for (final invoice in invoices) _InvoiceCard(invoice: invoice),
    ],
  );
}

class _VerifiedReceiptsTab extends StatefulWidget {
  const _VerifiedReceiptsTab({required this.invoices});
  final List<ResidentInvoice> invoices;

  @override
  State<_VerifiedReceiptsTab> createState() => _VerifiedReceiptsTabState();
}

class _VerifiedReceiptsTabState extends State<_VerifiedReceiptsTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final records = [
      for (final invoice in widget.invoices)
        for (final payment in invoice.verifiedPayments)
          if (payment.status == 'verified')
            (invoice: invoice, payment: payment),
    ]..sort((a, b) => b.payment.paidAt.compareTo(a.payment.paidAt));
    final filtered = records.where((record) {
      if (_filter == 'with_receipt') {
        return record.payment.receiptNumber != null;
      }
      if (_filter == 'without_receipt') {
        return record.payment.receiptNumber == null;
      }
      return true;
    }).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${records.length} verified ${records.length == 1 ? 'payment' : 'payments'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DropdownButton<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All payments')),
                DropdownMenuItem(
                  value: 'with_receipt',
                  child: Text('With receipt'),
                ),
                DropdownMenuItem(
                  value: 'without_receipt',
                  child: Text('No receipt number'),
                ),
              ],
              onChanged: (value) => setState(() => _filter = value ?? 'all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final record in filtered)
          _ReceiptCard(invoice: record.invoice, payment: record.payment),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text('No verified payments match this filter.'),
            ),
          ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.invoice, required this.payment});
  final ResidentInvoice invoice;
  final ResidentVerifiedPayment payment;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: EstateColors.forest),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  payment.receiptNumber ?? 'Verified payment',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                payment.amountLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${invoice.invoiceNumber} · ${invoice.category}'),
          const SizedBox(height: 4),
          Text(
            '${invoice.propertyLabel} · Paid ${_date(payment.paidAt)}',
            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline),
              label: Text(
                payment.receiptNumber == null
                    ? 'Receipt not issued'
                    : 'Private receipt unavailable in preview',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BillingNotice extends StatelessWidget {
  const _BillingNotice();
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
        Icon(
          Icons.verified_user_outlined,
          color: EstateColors.forest,
          size: 19,
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Outstanding charges are shown here. A charge is not a payment, and receipts appear only after settlement is verified.',
            style: TextStyle(
              color: EstateColors.forest,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: EstateColors.forest),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: EstateColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final ResidentInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final state = _invoiceState(invoice.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3EE),
          child: Icon(
            _categoryIcon(invoice.category),
            color: EstateColors.forest,
          ),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('${invoice.category} · Due ${_date(invoice.dueAt)}'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              invoice.balanceLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: state.$2,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                state.$1,
                style: TextStyle(
                  color: state.$3,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 16),
          _AmountRow(label: 'Property', value: invoice.propertyLabel),
          const SizedBox(height: 9),
          _AmountRow(label: 'Issued', value: _date(invoice.issuedAt)),
          const SizedBox(height: 9),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Invoice items',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          for (final line in invoice.lines) ...[
            _AmountRow(label: line.description, value: line.amountLabel),
            const SizedBox(height: 7),
          ],
          const Divider(height: 12),
          _AmountRow(
            label: 'Invoice total',
            value: invoice.totalLabel,
            emphasize: true,
          ),
          if (invoice.verifiedPayments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Verified payments',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            for (final payment in invoice.verifiedPayments) ...[
              _AmountRow(
                label: '${payment.amountLabel} · ${_date(payment.paidAt)}',
                value: payment.status == 'verified' ? 'Verified' : 'Reversed',
                positive: payment.status == 'verified',
              ),
              if (payment.receiptNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Receipt ${payment.receiptNumber} · private access required',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 7),
            ],
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Payment unavailable in this preview'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.positive,
  });
  final String label;
  final String value;
  final bool emphasize;
  final bool? positive;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: emphasize ? EstateColors.ink : EstateColors.muted,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
          color: positive == true
              ? EstateColors.forest
              : positive == false
              ? const Color(0xFF984B43)
              : null,
        ),
      ),
    ],
  );
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 42),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: EstateColors.muted,
          ),
          SizedBox(height: 10),
          Text('No invoices are available for this property.'),
        ],
      ),
    ),
  );
}

(String, Color, Color) _invoiceState(String status) => switch (status) {
  'paid' => ('Paid', const Color(0xFFE9F4ED), EstateColors.forest),
  'partially_paid' => (
    'Partially paid',
    const Color(0xFFFFF2D8),
    const Color(0xFF8A5B13),
  ),
  'overdue' => ('Overdue', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  'cancelled' => ('Cancelled', const Color(0xFFF0F1F2), EstateColors.muted),
  _ => ('Due', const Color(0xFFEAF1F8), const Color(0xFF476B91)),
};

IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
  'rent' => Icons.home_work_outlined,
  'facility booking' => Icons.sports_tennis_rounded,
  _ => Icons.apartment_rounded,
};

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
