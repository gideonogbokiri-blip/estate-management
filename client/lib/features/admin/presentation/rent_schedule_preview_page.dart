import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';

class RentSchedulePreviewPage extends StatefulWidget {
  const RentSchedulePreviewPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<RentSchedulePreviewPage> createState() =>
      _RentSchedulePreviewPageState();
}

class _RentSchedulePreviewPageState extends State<RentSchedulePreviewPage> {
  late DateTime _period;
  late Future<RentSchedulePreview> _preview;

  List<DateTime> get _periodChoices {
    final now = DateTime.now();
    return [DateTime(now.year, now.month), DateTime(now.year, now.month + 1)];
  }

  @override
  void initState() {
    super.initState();
    _period = _periodChoices.first;
    _preview = _load();
  }

  Future<RentSchedulePreview> _load() =>
      widget.repository.loadRentSchedulePreview(
        estateId: widget.estateId,
        year: _period.year,
        month: _period.month,
      );

  void _refresh() => setState(() => _preview = _load());

  @override
  Widget build(BuildContext context) {
    final periods = _periodChoices;
    return Scaffold(
      appBar: AppBar(title: const Text('Rent schedule preview')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.estateName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              const Text(
                'Upcoming landlord rent from active, approved tenancy terms.',
                style: TextStyle(color: EstateColors.muted),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<DateTime>(
                          initialValue: _period,
                          decoration: const InputDecoration(
                            labelText: 'Billing month',
                          ),
                          items: [
                            for (final period in periods)
                              DropdownMenuItem(
                                value: period,
                                child: Text(_monthLabel(period)),
                              ),
                          ],
                          onChanged: (period) {
                            if (period == null) return;
                            setState(() {
                              _period = period;
                              _preview = _load();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh schedule',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'This is a schedule preview, not an invoice or payment record. Rent remains payable to the named landlord under the tenancy terms; this page does not route money through the estate.',
                    style: TextStyle(color: EstateColors.muted, height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<RentSchedulePreview>(
                future: _preview,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: Color(0xFF984B43),
                        ),
                        title: const Text('Rent schedule could not be loaded'),
                        subtitle: Text(snapshot.error.toString()),
                        trailing: IconButton(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final result = snapshot.requireData;
                  if (result.items.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'No active tenancy rent is due in ${_monthLabel(_period)}.',
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${result.items.length} scheduled payments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in result.items)
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE9F0EA),
                              child: Icon(
                                Icons.home_work_outlined,
                                color: EstateColors.forest,
                              ),
                            ),
                            title: Text(
                              '${item.propertyCode}${item.unitNumber == null ? '' : ' · ${item.unitNumber}'}  •  ${item.currency} ${_money(item.amount)}',
                            ),
                            subtitle: Text(
                              'Tenant: ${item.tenantName}  •  Payee: ${item.rentPayeeName}\nDue ${_formatDate(item.dueDate)}  •  ${item.frequency}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthLabel(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day}/${date.month}/${date.year}';
  }

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
