import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/resident_estate_repository.dart';

class ResidentRentPage extends StatelessWidget {
  const ResidentRentPage({
    super.key,
    required this.rent,
    required this.onBack,
    required this.onOpenInvoices,
  });
  final ResidentRentSummary rent;
  final VoidCallback onBack;
  final VoidCallback onOpenInvoices;

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
      Text('My Rent', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      const Text(
        'Your current tenancy and rent terms.',
        style: TextStyle(color: EstateColors.muted),
      ),
      const SizedBox(height: 17),
      const _RentPreviewNotice(),
      const SizedBox(height: 14),
      Card(
        color: EstateColors.forest,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AGREED RENT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${rent.currency} ${_money(rent.amount)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'per ${rent.frequency}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _RentLine(
                icon: Icons.home_work_outlined,
                label: 'Property',
                value: rent.propertyLabel,
              ),
              const Divider(height: 23),
              _RentLine(
                icon: Icons.person_outline,
                label: 'Landlord',
                value: rent.landlordLabel,
              ),
              const Divider(height: 23),
              _RentLine(
                icon: Icons.calendar_today_outlined,
                label: 'Tenancy started',
                value: _date(rent.startDate),
              ),
              if (rent.endDate != null) ...[
                const Divider(height: 23),
                _RentLine(
                  icon: Icons.event_outlined,
                  label: 'Tenancy ends',
                  value: _date(rent.endDate!),
                ),
              ],
              if (rent.nextDueDate != null) ...[
                const Divider(height: 23),
                _RentLine(
                  icon: Icons.event_available_outlined,
                  label: 'Next rent due',
                  value: _date(rent.nextDueDate!),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          leading: const Icon(
            Icons.receipt_long_outlined,
            color: EstateColors.forest,
          ),
          title: const Text('Invoices and payment history'),
          subtitle: const Text(
            'View issued rent invoices and verified payments.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenInvoices,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'This page shows agreed tenancy rent, not a paid or outstanding balance. Payment status is shown in your invoice history after verified allocation.',
        style: TextStyle(color: EstateColors.muted, fontSize: 12, height: 1.4),
      ),
    ],
  );

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String _date(DateTime date) {
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
}

class _RentPreviewNotice extends StatelessWidget {
  const _RentPreviewNotice();
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
            'Preview tenancy information. Your rent terms are available only from an authorized tenant/property relationship.',
            style: TextStyle(fontSize: 12, color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _RentLine extends StatelessWidget {
  const _RentLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: EstateColors.muted),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
