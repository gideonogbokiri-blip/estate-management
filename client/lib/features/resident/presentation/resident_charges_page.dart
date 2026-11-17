import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentChargesPage extends StatelessWidget {
  const ResidentChargesPage({
    super.key,
    required this.charges,
    required this.onBack,
  });
  final List<ResidentEstateCharge> charges;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Community'),
        ),
      ),
      const SizedBox(height: 7),
      Text('Estate charges', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      const Text(
        'Current charge rules that apply to your property.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 17),
      const _ResidentChargesNotice(),
      const SizedBox(height: 14),
      if (charges.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No applicable charges were returned for your property.',
              ),
            ),
          ),
        ),
      ...charges.map(
        (charge) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1EC),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            charge.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _label(charge.category),
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${charge.currency} ${_money(charge.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _ChargeFact(
                      icon: Icons.event_repeat_outlined,
                      label: _label(charge.recurrence),
                    ),
                    _ChargeFact(
                      icon: Icons.calendar_today_outlined,
                      label: 'Effective ${_date(charge.effectiveFrom)}',
                    ),
                    _ChargeFact(
                      icon: Icons.schedule_outlined,
                      label: charge.dueRule,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'This is a charge rule, not an invoice or current balance. Issued invoices appear in Invoices and receipts.',
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
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

class _ResidentChargesNotice extends StatelessWidget {
  const _ResidentChargesNotice();
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
        Icon(Icons.info_outline, color: EstateColors.forest),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Preview charge rules for this property. Your estate service determines applicability and current invoice balances.',
            style: TextStyle(fontSize: 12, color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _ChargeFact extends StatelessWidget {
  const _ChargeFact({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: EstateColors.muted),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: EstateColors.muted),
      ),
    ],
  );
}
