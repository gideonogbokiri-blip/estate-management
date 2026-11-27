import 'package:flutter/material.dart';

import '../../../../core/config/report_download.dart';
import '../../../../core/design/terra_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/api.dart';

class TerraReportsPage extends StatefulWidget {
  const TerraReportsPage({
    super.key,
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;

  @override
  State<TerraReportsPage> createState() => _TerraReportsPageState();
}

class _TerraReportsPageState extends State<TerraReportsPage> {
  Map<String, dynamic> _summary = const {};
  Map<String, dynamic> _audit = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _summary = await widget.repository.loadManagerReportSummary(widget.estateId);
    } catch (_) {
      _summary = const {};
    }
    try {
      _audit = await widget.repository.loadAuditLog(widget.estateId);
    } catch (_) {
      _audit = const {};
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export(String type) async {
    try {
      final csv = await widget.repository.fetchReportCsv(widget.estateId, type);
      downloadReportCsv('${widget.estateName}-$type.csv', csv);
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report could not be exported.')),
      );
    }
  }

  String _value(String section, String key) {
    if (section == 'auditEvents') return _summary['auditEvents']?.toString() ?? '0';
    return (_summary[section] as Map? ?? const {})[key]?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  TerraSectionTitle(title: 'Reports'),
                  const SizedBox(height: 4),
                  Text(
                    widget.estateName,
                    style: const TextStyle(color: TerraColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: TerraColors.forest))
                  else ...[
                    TerraCard(
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _Metric(label: 'Invoices', value: _value('invoices', 'total')),
                          _Metric(label: 'Billed', value: '₦${AppFormat.amount(_value('invoices', 'billed'))}'),
                          _Metric(label: 'Rent outstanding', value: '₦${AppFormat.amount(_value('rent', 'outstanding'))}'),
                          _Metric(label: 'Expenses', value: _value('expenses', 'total')),
                          _Metric(label: 'Payouts', value: _value('payouts', 'total')),
                          _Metric(label: 'Audit events', value: _value('auditEvents', '')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TerraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TerraSectionTitle(title: 'Exports'),
                          const SizedBox(height: 12),
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
                    ),
                    const SizedBox(height: 18),
                    TerraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TerraSectionTitle(
                            title: 'Audit trail',
                            trailing: TerraBadge(
                              label: '${(_audit['items'] as List? ?? const []).length}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(_audit['items'] as List? ?? const []).take(8).map(
                                (entry) {
                                  final row = entry is Map<String, dynamic>
                                      ? entry
                                      : <String, dynamic>{};
                                  final action = (row['action']?.toString() ?? '')
                                      .replaceAll('_', ' ');
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      action,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                      '${row['actorName'] ?? 'Estate staff'} · '
                                      '${AppFormat.date(row['occurredAt']?.toString())}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
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
                    color: TerraColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: TerraColors.muted, fontSize: 11)),
          ],
        ),
      );
}
