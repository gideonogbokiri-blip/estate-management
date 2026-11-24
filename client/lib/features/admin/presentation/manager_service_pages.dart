import 'package:flutter/material.dart';

import '../../../core/config/report_download.dart';
import '../../../core/design/dashboard_design.dart';
import '../../../core/design/service_page_scaffold.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../data/api.dart';

class ManagerServiceContext {
  const ManagerServiceContext({required this.repository, required this.estateId, required this.estateName});
  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
}

Future<T?> openManagerPage<T extends Object?>(BuildContext context, Widget page) =>
    AppNavigation.push<T>(context, page);

// ---------------------------------------------------------------------------
// Payouts
// ---------------------------------------------------------------------------

class ManagerPayoutsPage extends StatefulWidget {
  const ManagerPayoutsPage({super.key, required this.serviceContext});
  final ManagerServiceContext serviceContext;

  @override
  State<ManagerPayoutsPage> createState() => _ManagerPayoutsPageState();
}

class _ManagerPayoutsPageState extends State<ManagerPayoutsPage> {
  List<EstatePayoutBeneficiaryRecord> _beneficiaries = const [];
  List<EstatePayoutRecord> _payouts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _beneficiaries = await widget.serviceContext.repository.loadPayoutBeneficiaries(widget.serviceContext.estateId);
      _payouts = await widget.serviceContext.repository.loadPayouts(widget.serviceContext.estateId);
    } catch (_) {
      _error = 'Payout data could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_beneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No verified beneficiary is configured.')),
      );
      return;
    }
    var beneficiary = _beneficiaries.first;
    final amount = TextEditingController(text: '10000.00');
    final purpose = TextEditingController(text: 'Estate operations');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Initiate payout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<EstatePayoutBeneficiaryRecord>(
                  initialValue: beneficiary,
                  decoration: const InputDecoration(labelText: 'Beneficiary'),
                  items: _beneficiaries
                      .map((item) => DropdownMenuItem(value: item, child: Text('${item.displayName} Â· ${item.bankName}')))
                      .toList(),
                  onChanged: (value) => setState(() => beneficiary = value ?? _beneficiaries.first),
                ),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount')),
                const SizedBox(height: 10),
                TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Initiate')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await widget.serviceContext.repository.createPayout(
        estateId: widget.serviceContext.estateId,
        beneficiaryId: beneficiary.id,
        amount: amount.text.trim(),
        purpose: purpose.text.trim(),
        idempotencyKey: 'payout-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout could not be initiated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ServicePageScaffold(
      title: 'Payouts',
      description: '${widget.serviceContext.estateName} Â· Estate disbursements and approvals.',
      icon: Icons.payments_outlined,
      onRefresh: _load,
      actions: [
        IconButton(tooltip: 'Initiate payout', onPressed: _create, icon: const Icon(Icons.add)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _payouts.isEmpty
                  ? const ServiceStateMessage(message: 'No payout requests yet.')
                  : Column(
                      children: _payouts.map(
                        (payout) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined, color: DashboardTokens.greenLeaf),
                            title: Text('${payout.currency} ${payout.amount} Â· ${payout.status}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(payout.purpose, style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                      ).toList(),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Property map
// ---------------------------------------------------------------------------

class ManagerPropertyMapPage extends StatefulWidget {
  const ManagerPropertyMapPage({super.key, required this.serviceContext});
  final ManagerServiceContext serviceContext;

  @override
  State<ManagerPropertyMapPage> createState() => _ManagerPropertyMapPageState();
}

class _ManagerPropertyMapPageState extends State<ManagerPropertyMapPage> {
  List<PropertyLocationRecord> _locations = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _locations = await widget.serviceContext.repository.loadPropertyLocations(widget.serviceContext.estateId);
    } catch (_) {
      _error = 'Property locations could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture(PropertyLocationRecord property) async {
    final latitude = TextEditingController(text: property.latitude ?? '');
    final longitude = TextEditingController(text: property.longitude ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pin ${property.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: latitude, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Latitude')),
            const SizedBox(height: 10),
            TextField(controller: longitude, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longitude')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await widget.serviceContext.repository.capturePropertyLocation(
        estateId: widget.serviceContext.estateId,
        propertyId: property.id,
        latitude: latitude.text.trim(),
        longitude: longitude.text.trim(),
        captureMethod: 'MAP_PIN',
      );
      await _load();
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin could not be saved.')),
      );
    }
  }

  Future<void> _verify(PropertyLocationRecord property) async {
    try {
      await widget.serviceContext.repository.verifyPropertyLocation(
        estateId: widget.serviceContext.estateId,
        propertyId: property.id,
        decision: 'verify',
      );
      await _load();
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin could not be verified.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ServicePageScaffold(
      title: 'Property map',
      description: '${widget.serviceContext.estateName} Â· GPS capture and verification.',
      icon: Icons.map_outlined,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : Column(
                  children: _locations.map(
                    (location) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: DashboardTokens.greenLeaf),
                        title: Text('${location.code} Â· ${location.verificationStatus}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          location.latitude == null
                              ? 'No pin captured'
                              : '${location.latitude}, ${location.longitude} Â· ${location.captureMethod ?? ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(onPressed: () => _capture(location), child: const Text('Pin')),
                            if (location.verificationStatus == 'pending_verification')
                              TextButton(onPressed: () => _verify(location), child: const Text('Verify')),
                          ],
                        ),
                      ),
                    ),
                  ).toList(),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({super.key, required this.serviceContext});
  final ManagerServiceContext serviceContext;

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage> {
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _summary = await widget.serviceContext.repository.loadManagerReportSummary(widget.serviceContext.estateId);
    } catch (_) {
      _error = 'Reports could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String type) async {
    try {
      final csv = await widget.serviceContext.repository.fetchReportCsv(widget.serviceContext.estateId, type);
      downloadReportCsv('${widget.serviceContext.estateName}-$type.csv', csv);
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report could not be exported.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String value(String section, String key) {
      if (section == 'auditEvents') return _summary['auditEvents']?.toString() ?? '0';
      return (_summary[section] as Map? ?? const {})[key]?.toString() ?? '0';
    }

    return ServicePageScaffold(
      title: 'Reports',
      description: '${widget.serviceContext.estateName} Â· Financial and operational summary.',
      icon: Icons.summarize_outlined,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _ReportMetric(label: 'Invoices', value: value('invoices', 'total')),
                        _ReportMetric(label: 'Billed', value: '${_summary['currency'] ?? 'NGN'} ${value('invoices', 'billed')}'),
                        _ReportMetric(label: 'Rent outstanding', value: '${_summary['currency'] ?? 'NGN'} ${value('rent', 'outstanding')}'),
                        _ReportMetric(label: 'Expenses', value: value('expenses', 'total')),
                        _ReportMetric(label: 'Payouts', value: value('payouts', 'total')),
                        _ReportMetric(label: 'Audit events', value: value('auditEvents', '')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DashboardSectionTitle(title: 'Exports'),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _export('wallet'),
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Wallet CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _export('ledger'),
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Ledger CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _export('audit'),
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Audit CSV'),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: DashboardTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: DashboardTokens.muted, fontSize: 11)),
          ],
        ),
      );
}

