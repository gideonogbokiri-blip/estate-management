import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateRentManagementPage extends StatefulWidget {
  const EstateRentManagementPage({
    super.key,
    required this.tenancies,
    required this.repository,
  });
  final List<EstateTenancySummary> tenancies;
  final EstateAdminRepository repository;

  @override
  State<EstateRentManagementPage> createState() =>
      _EstateRentManagementPageState();
}

class _EstateRentManagementPageState extends State<EstateRentManagementPage> {
  final _search = TextEditingController();
  String _period = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now();
    final active = widget.tenancies.where((t) => t.status == 'active').toList();
    final dueThisMonth = active
        .where(
          (t) =>
              _date(t.nextDueDate)?.year == current.year &&
              _date(t.nextDueDate)?.month == current.month,
        )
        .length;
    final dueNextMonth = active
        .where(
          (t) =>
              _date(t.nextDueDate)?.year ==
                  current.add(const Duration(days: 32)).year &&
              _date(t.nextDueDate)?.month ==
                  current.add(const Duration(days: 32)).month,
        )
        .length;
    final noSchedule = active.where((t) => t.nextDueDate == null).length;
    final query = _search.text.trim().toLowerCase();
    final rows =
        active.where((t) {
          final nextDue = _date(t.nextDueDate);
          final periodMatches = switch (_period) {
            'this_month' =>
              nextDue?.year == current.year && nextDue?.month == current.month,
            'next_month' =>
              nextDue?.year == current.add(const Duration(days: 32)).year &&
                  nextDue?.month == current.add(const Duration(days: 32)).month,
            'missing' => t.nextDueDate == null,
            _ => true,
          };
          final searchable =
              '${t.propertyLabel} ${t.tenantLabel} ${t.landlordLabel ?? ''} ${t.rentFrequency}'
                  .toLowerCase();
          return periodMatches && (query.isEmpty || searchable.contains(query));
        }).toList()..sort(
          (a, b) =>
              (a.nextDueDate ?? '9999').compareTo(b.nextDueDate ?? '9999'),
        );

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
                  'Rent management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review rent terms and the next due dates from active tenancies.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _previewInvoiceRun,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Preview invoice run'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _RentNotice(),
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
                _RentMetric(
                  width: width,
                  label: 'Active rent schedules',
                  value: '${active.length}',
                  icon: Icons.event_repeat_outlined,
                  color: EstateColors.forest,
                ),
                _RentMetric(
                  width: width,
                  label: 'Due this month',
                  value: '$dueThisMonth',
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF476B91),
                ),
                _RentMetric(
                  width: width,
                  label: 'No next due date',
                  value: '$noSchedule',
                  icon: Icons.warning_amber_outlined,
                  color: noSchedule == 0
                      ? EstateColors.forest
                      : const Color(0xFF984B43),
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
                      hintText: 'Search tenant, landlord or property',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _period,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All due dates'),
                    ),
                    DropdownMenuItem(
                      value: 'this_month',
                      child: Text('Due this month'),
                    ),
                    DropdownMenuItem(
                      value: 'next_month',
                      child: Text('Due next month'),
                    ),
                    DropdownMenuItem(
                      value: 'missing',
                      child: Text('Missing due date'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _period = value ?? 'all'),
                ),
                Text(
                  '$dueNextMonth due next month',
                  style: const TextStyle(color: EstateColors.muted),
                ),
                Text(
                  '${rows.length} active schedules',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('No rent schedules match these filters.'),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('PROPERTY')),
                  DataColumn(label: Text('TENANT')),
                  DataColumn(label: Text('RENT TERMS')),
                  DataColumn(label: Text('NEXT DUE')),
                  DataColumn(label: Text('SCHEDULE')),
                ],
                rows: rows
                    .map(
                      (t) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 155,
                              child: Text(
                                t.propertyLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(width: 145, child: Text(t.tenantLabel)),
                          ),
                          DataCell(
                            Text(
                              '${t.currency} ${_money(t.rentAmount)} / ${t.rentFrequency}',
                            ),
                          ),
                          DataCell(
                            Text(
                              t.nextDueDate == null
                                  ? 'Not configured'
                                  : _format(t.nextDueDate!),
                              style: TextStyle(
                                color: t.nextDueDate == null
                                    ? const Color(0xFF984B43)
                                    : EstateColors.ink,
                              ),
                            ),
                          ),
                          DataCell(const _ScheduleBadge()),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'A rent schedule is not proof of an issued invoice or collected payment. Invoice balances and collections are available in Billing from verified allocation history.',
          style: TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  DateTime? _date(String? value) =>
      value == null ? null : DateTime.tryParse(value);
  String _format(String value) {
    final d = DateTime.tryParse(value);
    if (d == null) return '—';
    const m = [
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
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  Future<void> _previewInvoiceRun() => showDialog<void>(
    context: context,
    builder: (context) => _RentInvoicePreviewDialog(
      repository: widget.repository,
    ),
  );
}

class _RentInvoicePreviewDialog extends StatefulWidget {
  const _RentInvoicePreviewDialog({required this.repository});
  final EstateAdminRepository repository;

  @override
  State<_RentInvoicePreviewDialog> createState() =>
      _RentInvoicePreviewDialogState();
}

class _RentInvoicePreviewDialogState extends State<_RentInvoicePreviewDialog> {
  late DateTime _period;
  late Future<List<EstateTenancySummary>> _schedules;

  List<DateTime> get _periods {
    final now = DateTime.now();
    return [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ];
  }

  @override
  void initState() {
    super.initState();
    _period = _periods.first;
    _schedules = _loadSchedules();
  }

  Future<List<EstateTenancySummary>> _loadSchedules() =>
      widget.repository.previewRentInvoiceSchedules(
        year: _period.year,
        month: _period.month,
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rent invoice run preview'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<DateTime>(
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Billing month'),
            items: [
              for (final period in _periods)
                DropdownMenuItem(
                  value: period,
                  child: Text(_monthLabel(period)),
                ),
            ],
            onChanged: (period) {
              if (period == null) return;
              setState(() {
                _period = period;
                _schedules = _loadSchedules();
              });
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0DCA9)),
            ),
            child: const Text(
              'Sample schedule only. No invoice is created, issued or sent. The billing service must verify approved tenancy, settlement destination and duplicate-generation keys.',
              style: TextStyle(color: Color(0xFF795416), fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<EstateTenancySummary>>(
            future: _schedules,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Rent schedules could not be loaded.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final schedules = snapshot.requireData;
              if (schedules.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No active rent schedules are due in this month.'),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 330),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: schedules.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF3EE),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: Text(schedule.tenantLabel),
                      subtitle: Text(
                        '${schedule.propertyLabel} · Due ${_formatRentDate(schedule.nextDueDate!)}',
                      ),
                      trailing: Text(
                        '${schedule.currency} ${_formatRentAmount(schedule.rentAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

String _monthLabel(DateTime value) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _formatRentDate(String? value) {
  final date = value == null ? null : DateTime.tryParse(value);
  if (date == null) return 'Date unavailable';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatRentAmount(String value) =>
    value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _RentNotice extends StatelessWidget {
  const _RentNotice();
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
        Icon(Icons.info_outline, color: EstateColors.forest),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Preview schedule based on approved tenancy terms. Invoice generation must use an idempotent server command and the active settlement policy.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _RentMetric extends StatelessWidget {
  const _RentMetric({
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

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F2EB),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Active tenancy',
      style: TextStyle(
        color: EstateColors.forest,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
