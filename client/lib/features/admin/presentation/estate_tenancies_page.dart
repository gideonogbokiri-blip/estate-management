import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateTenanciesPage extends StatefulWidget {
  const EstateTenanciesPage({
    super.key,
    required this.tenancies,
    required this.repository,
    required this.onTenanciesChanged,
  });
  final List<EstateTenancySummary> tenancies;
  final EstateAdminRepository repository;
  final VoidCallback onTenanciesChanged;

  @override
  State<EstateTenanciesPage> createState() => _EstateTenanciesPageState();
}

class _EstateTenanciesPageState extends State<EstateTenanciesPage> {
  final _search = TextEditingController();
  late List<EstateTenancySummary> _tenancies;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _tenancies = List.of(widget.tenancies);
  }

  @override
  void didUpdateWidget(covariant EstateTenanciesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tenancies, widget.tenancies)) {
      _tenancies = List.of(widget.tenancies);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _tenancies.where((t) => t.status == 'active').length;
    final pending = _tenancies.where((t) => t.status == 'pending').length;
    final ending = _tenancies.where(_isEndingSoon).length;
    final q = _search.text.trim().toLowerCase();
    final rows = _tenancies
        .where(
          (t) =>
              (_status == 'all' ||
                  (_status == 'ending_soon'
                      ? _isEndingSoon(t)
                      : t.status == _status)) &&
              (q.isEmpty ||
                  '${t.propertyLabel} ${t.tenantLabel} ${t.landlordLabel ?? ''} ${t.id}'
                      .toLowerCase()
                      .contains(q)),
        )
        .toList();

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
                  'Tenants and tenancies',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review occupancy, agreement dates and rent terms.',
                  style: TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _createPreviewTenancy,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add tenancy'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _PreviewNotice(),
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
                _Metric(
                  width: width,
                  label: 'Active tenancies',
                  value: '$active',
                  icon: Icons.key_outlined,
                  color: EstateColors.forest,
                ),
                _Metric(
                  width: width,
                  label: 'Pending start',
                  value: '$pending',
                  icon: Icons.pending_actions_outlined,
                  color: const Color(0xFF8A6731),
                ),
                _Metric(
                  width: width,
                  label: 'Ending soon',
                  value: '$ending',
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFF984B43),
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
                      hintText: 'Search tenant, property or landlord',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'ending_soon',
                      child: Text('Ending within 60 days'),
                    ),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'expired', child: Text('Expired')),
                    DropdownMenuItem(
                      value: 'terminated',
                      child: Text('Terminated'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'all'),
                ),
                Text(
                  '${rows.length} records',
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
              child: Center(child: Text('No tenancies match these filters.')),
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
                  DataColumn(label: Text('TERM')),
                  DataColumn(label: Text('RENT')),
                  DataColumn(label: Text('NEXT DUE')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: rows
                    .map(
                      (t) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                t.propertyLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 160,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.tenantLabel),
                                  if (t.landlordLabel != null)
                                    Text(
                                      t.landlordLabel!,
                                      style: const TextStyle(
                                        color: EstateColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text('${_date(t.startDate)} – ${_date(t.endDate)}'),
                          ),
                          DataCell(
                            Text(
                              '${t.currency} ${_money(t.rentAmount)} / ${t.rentFrequency}',
                            ),
                          ),
                          DataCell(Text(_date(t.nextDueDate))),
                          DataCell(_StatusPill(status: t.status)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _createPreviewTenancy() async {
    try {
      final options = await widget.repository.loadTenancyCreationOptions();
      if (!mounted) return;
      if (options.properties.isEmpty ||
          options.tenants.isEmpty ||
          options.payees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No eligible property or sample accounts are available.',
            ),
          ),
        );
        return;
      }
      final draft =
          await showDialog<
            ({
              String propertyId,
              String tenantId,
              String payeeId,
              String rentAmount,
              String rentFrequency,
              DateTime startDate,
              DateTime? endDate,
            })
          >(
            context: context,
            builder: (context) => _TenancyDraftDialog(options: options),
          );
      if (draft == null || !mounted) return;
      final tenancy = await widget.repository.createTenancyDraftPreview(
        propertyId: draft.propertyId,
        tenantId: draft.tenantId,
        payeeId: draft.payeeId,
        rentAmount: draft.rentAmount,
        rentFrequency: draft.rentFrequency,
        startDate: draft.startDate,
        endDate: draft.endDate,
      );
      if (!mounted) return;
      setState(() {
        _tenancies = [tenancy, ..._tenancies];
        _status = 'all';
      });
      widget.onTenanciesChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pending tenancy added to this preview. No approval or occupancy was created.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The tenancy preview could not be created.'),
        ),
      );
    }
  }

  String _date(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
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

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  bool _isEndingSoon(EstateTenancySummary tenancy) {
    if (tenancy.status != 'active' || tenancy.endDate == null) return false;
    final end = DateTime.tryParse(tenancy.endDate!);
    if (end == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    final cutoff = today.add(const Duration(days: 60));
    return !end.isBefore(today) && !end.isAfter(cutoff);
  }
}

class _TenancyDraftDialog extends StatefulWidget {
  const _TenancyDraftDialog({required this.options});
  final EstateTenancyCreationOptions options;

  @override
  State<_TenancyDraftDialog> createState() => _TenancyDraftDialogState();
}

class _TenancyDraftDialogState extends State<_TenancyDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rent = TextEditingController();
  late String _propertyId;
  late String _tenantId;
  late String _payeeId;
  String _frequency = 'monthly';
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _propertyId = widget.options.properties.first.id;
    _tenantId = widget.options.tenants.first.id;
    _payeeId = widget.options.payees.first.id;
  }

  @override
  void dispose() {
    _rent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add tenancy'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _propertyId,
                decoration: const InputDecoration(
                  labelText: 'Available property',
                ),
                items: [
                  for (final property in widget.options.properties)
                    DropdownMenuItem(
                      value: property.id,
                      child: Text(
                        '${property.code} · ${property.structureLabel ?? ''}',
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _propertyId = value ?? _propertyId),
              ),
              DropdownButtonFormField<String>(
                initialValue: _tenantId,
                decoration: const InputDecoration(labelText: 'Tenant account'),
                items: [
                  for (final tenant in widget.options.tenants)
                    DropdownMenuItem(
                      value: tenant.id,
                      child: Text(tenant.displayName),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _tenantId = value ?? _tenantId),
              ),
              DropdownButtonFormField<String>(
                initialValue: _payeeId,
                decoration: const InputDecoration(
                  labelText: 'Landlord / payee',
                ),
                items: [
                  for (final payee in widget.options.payees)
                    DropdownMenuItem(
                      value: payee.id,
                      child: Text(payee.displayName),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _payeeId = value ?? _payeeId),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rent amount',
                        prefixText: 'NGN ',
                      ),
                      validator: (value) {
                        final amount = value?.trim() ?? '';
                        if (!RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,2})?$')
                            .hasMatch(amount)) {
                          return 'Enter a valid amount (up to 2 decimals).';
                        }
                        if (amount
                            .replaceAll('.', '')
                            .split('')
                            .every((digit) => digit == '0')) {
                          return 'Rent must be greater than zero.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: Text('Quarterly'),
                        ),
                        DropdownMenuItem(
                          value: 'annually',
                          child: Text('Annually'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _frequency = value ?? _frequency),
                    ),
                  ),
                ],
              ),
              _dateTile(
                'Start date',
                _start,
                (value) => setState(() => _start = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End date (optional)'),
                subtitle: Text(
                  _end == null ? 'No fixed end date' : _formatDate(_end!),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (_end != null)
                      IconButton(
                        tooltip: 'Clear end date',
                        onPressed: () => setState(() => _end = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      tooltip: 'Choose end date',
                      onPressed: _chooseEndDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Preview only. Account eligibility, payee authority, rent policy and property availability are not checked by this screen. No tenancy approval, occupancy or invoice will be created.',
                style: TextStyle(
                  color: EstateColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Create preview tenancy'),
      ),
    ],
  );

  Widget _dateTile(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(_formatDate(value)),
    trailing: const Icon(Icons.calendar_month_outlined),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateUtils.dateOnly(DateTime.now()),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (date != null && mounted) onChanged(DateUtils.dateOnly(date));
    },
  );

  Future<void> _chooseEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _end ?? _start.add(const Duration(days: 365)),
      firstDate: _start.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null && mounted) {
      setState(() => _end = DateUtils.dateOnly(date));
    }
  }

  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_end != null && !_end!.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The end date must be after the start date.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((
      propertyId: _propertyId,
      tenantId: _tenantId,
      payeeId: _payeeId,
      rentAmount: _rent.text.trim(),
      rentFrequency: _frequency,
      startDate: _start,
      endDate: _end,
    ));
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();
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
            'Preview tenancy data. The connected service must enforce estate scope and actor permissions before returning records.',
            style: TextStyle(color: EstateColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => EstateColors.forest,
      'pending' => const Color(0xFF8A6731),
      'expired' => const Color(0xFF476B91),
      _ => const Color(0xFF984B43),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
