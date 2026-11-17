import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';

class EstateReportsPage extends StatelessWidget {
  const EstateReportsPage({super.key, required this.dashboard});
  final EstateAdminDashboardSnapshot dashboard;

  static const _reportSections = [
    AdminSection.properties,
    AdminSection.residents,
    AdminSection.tenancies,
    AdminSection.visitors,
    AdminSection.maintenance,
    AdminSection.finance,
  ];

  @override
  Widget build(BuildContext context) {
    final sections = _reportSections
        .where(dashboard.availableSections.contains)
        .where(dashboard.sections.containsKey)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports and analytics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  '${dashboard.estateName} · ${dashboard.location}',
                  style: const TextStyle(color: EstateColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export report'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PeriodBanner(period: dashboard.periodLabel, asOf: dashboard.asOf),
        const SizedBox(height: 19),
        if (sections.isEmpty)
          const _NoReportSections()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100 ? 2 : 1;
              final cardWidth = columns == 2
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final section in sections)
                    SizedBox(
                      width: cardWidth,
                      child: _ReportSectionCard(
                        section: section,
                        result: dashboard.sections[section]!,
                        source: dashboard.sourceFreshness[section],
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 18),
        const _ReportFootnote(),
      ],
    );
  }
}

class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({required this.period, required this.asOf});
  final String period;
  final DateTime asOf;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE2E8E3)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: EstateColors.forest,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reporting period',
                  style: TextStyle(color: EstateColors.muted, fontSize: 10),
                ),
                Text(
                  period,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          'Snapshot as of ${_format(asOf)}',
          style: const TextStyle(color: EstateColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({
    required this.section,
    required this.result,
    this.source,
  });
  final AdminSection section;
  final DashboardSectionResult result;
  final DashboardSourceInfo? source;

  @override
  Widget build(BuildContext context) {
    final status = _status(result.status);
    final rows = _metricRows(result.metrics);
    final sourceFreshness = source == null
        ? 'Source freshness unavailable'
        : '${_freshnessLabel(source!.freshness)}${source!.asOf == null ? '' : ' · ${_format(source!.asOf!)}'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEAF3EE),
                  foregroundColor: EstateColors.forest,
                  child: Icon(_sectionIcon(section)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _sectionName(section),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ReportStatusPill(
                  label: status.$1,
                  color: status.$2,
                  background: status.$3,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                sourceFreshness,
                style: const TextStyle(color: EstateColors.muted, fontSize: 10),
              ),
            ),
            const SizedBox(height: 15),
            if (rows.isEmpty)
              Text(
                _unavailableMessage(result.status),
                style: const TextStyle(color: EstateColors.muted, fontSize: 12),
              )
            else ...[
              for (var i = 0; i < rows.length; i++) ...[
                _MetricRow(label: rows[i].$1, value: rows[i].$2),
                if (i < rows.length - 1) const Divider(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: EstateColors.muted, fontSize: 12),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ],
  );
}

class _ReportStatusPill extends StatelessWidget {
  const _ReportStatusPill({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

class _ReportFootnote extends StatelessWidget {
  const _ReportFootnote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6F3),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFD7E5DC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: EstateColors.forest, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Values are supplied by the estate dashboard sources for the stated period. Incomplete or unreconciled sources remain labelled and are not replaced with estimates.',
            style: TextStyle(
              color: EstateColors.forest,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoReportSections extends StatelessWidget {
  const _NoReportSections();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 38, color: EstateColors.muted),
          SizedBox(height: 10),
          Text('No report sections are available for this account.'),
        ],
      ),
    ),
  );
}

List<(String, String)> _metricRows(DashboardMetrics? metrics) =>
    switch (metrics) {
      PropertyMetrics(:final total, :final occupied, :final vacant) => [
        ('Total properties', '$total'),
        ('Occupied', '$occupied'),
        ('Vacant', '$vacant'),
      ],
      ResidentMetrics(:final registered, :final landlords) => [
        ('Registered residents', '$registered'),
        ('Landlords', '$landlords'),
      ],
      TenancyMetrics(:final tenants, :final activeTenancies) => [
        ('Tenants', '$tenants'),
        ('Active tenancies', '$activeTenancies'),
      ],
      VisitorMetrics(:final activity, :final checkedIn) => [
        ('Visitor activity in period', '$activity'),
        ('Currently checked in', '$checkedIn'),
      ],
      MaintenanceMetrics(:final openRequests) => [
        ('Open requests', '$openRequests'),
      ],
      FinanceMetrics(
        :final rentCollected,
        :final estateFeesCollected,
        :final otherChargesCollected,
        :final expensesPaid,
        :final netOperatingPosition,
      ) =>
        [
          ('Rent collected', rentCollected),
          ('Estate fees collected', estateFeesCollected),
          ('Other charges collected', otherChargesCollected),
          ('Expenses paid', expensesPaid),
          ('Net operating position', netOperatingPosition),
        ],
      _ => const [],
    };

(String, Color, Color) _status(DashboardDataStatus status) => switch (status) {
  DashboardDataStatus.available => (
    'Available',
    EstateColors.forest,
    const Color(0xFFE9F4ED),
  ),
  DashboardDataStatus.incomplete => (
    'Incomplete',
    const Color(0xFF8A5B13),
    const Color(0xFFFFF2D8),
  ),
  DashboardDataStatus.pendingReconciliation => (
    'Needs reconciliation',
    const Color(0xFF8A5B13),
    const Color(0xFFFFF2D8),
  ),
  DashboardDataStatus.unavailable => (
    'Unavailable',
    EstateColors.muted,
    const Color(0xFFF0F1F2),
  ),
};

String _freshnessLabel(DashboardFreshness freshness) => switch (freshness) {
  DashboardFreshness.current => 'Current source',
  DashboardFreshness.stale => 'Stale source',
  DashboardFreshness.delayed => 'Delayed source',
  DashboardFreshness.unavailable => 'Source unavailable',
};

String _unavailableMessage(DashboardDataStatus status) => switch (status) {
  DashboardDataStatus.incomplete => 'This source has incomplete data. Review its status before relying on totals.',
  DashboardDataStatus.pendingReconciliation => 'This source is awaiting reconciliation; financial totals are not presented as final.',
  DashboardDataStatus.unavailable =>
    'The source did not provide report values for this period.',
  DashboardDataStatus.available =>
    'No metric values were supplied for this section.',
};

String _sectionName(AdminSection section) => switch (section) {
  AdminSection.properties => 'Properties and occupancy',
  AdminSection.residents => 'Residents and landlords',
  AdminSection.tenancies => 'Tenancies',
  AdminSection.visitors => 'Visitor activity',
  AdminSection.maintenance => 'Maintenance',
  AdminSection.finance => 'Finance',
  _ => 'Estate operations',
};

IconData _sectionIcon(AdminSection section) => switch (section) {
  AdminSection.properties => Icons.apartment_rounded,
  AdminSection.residents => Icons.people_alt_outlined,
  AdminSection.tenancies => Icons.key_outlined,
  AdminSection.visitors => Icons.qr_code_2_rounded,
  AdminSection.maintenance => Icons.handyman_outlined,
  AdminSection.finance => Icons.account_balance_wallet_outlined,
  _ => Icons.bar_chart_rounded,
};

String _format(DateTime value) =>
    '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
