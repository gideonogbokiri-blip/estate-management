import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/platform_application_repository.dart';
import 'platform_admin_pages.dart';
import 'platform_money_page.dart';
import 'platform_plans_page.dart';

class PlatformAdminShell extends StatefulWidget {
  const PlatformAdminShell({
    super.key,
    required this.repository,
    required this.onSignOut,
  });
  final PlatformApplicationApiRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<PlatformAdminShell> createState() => _PlatformAdminShellState();
}

class _PlatformAdminShellState extends State<PlatformAdminShell> {
  late Future<List<PlatformApplication>> _applications;
  late Future<List<PlatformEstateRecord>> _estates;
  late Future<List<PlatformTeamMember>> _team;
  final _search = TextEditingController();
  String _status = 'all';
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _applications = widget.repository.loadApplications();
    _estates = widget.repository.loadPlatformEstates();
    _team = widget.repository.loadPlatformTeam();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _applications = widget.repository.loadApplications();
    _estates = widget.repository.loadPlatformEstates();
    _team = widget.repository.loadPlatformTeam();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8F6),
    appBar: AppBar(
      backgroundColor: Colors.white,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: EstateColors.forest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estate Management',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                'Platform operations',
                style: TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh applications',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 8, right: 18),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFE4EFE8),
            child: Text(
              'P',
              style: TextStyle(
                color: EstateColors.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
    body: Row(
      children: [
        NavigationRail(
          backgroundColor: Colors.white,
          selectedIndex: _selectedNav,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) {
            setState(() => _selectedNav = index);
          },
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.fact_check_outlined),
              label: Text('Applications'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.apartment_outlined),
              label: Text('Estates'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.card_membership_outlined),
              label: Text('Plans'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              label: Text('Platform team'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: Text('Balances'),
            ),
          ],
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _selectedNav == 1
              ? PlatformEstatesPage(
                  estates: _estates,
                  onRefresh: _reload,
                )
              : _selectedNav == 2
              ? const PlatformPlansPage()
              : _selectedNav == 3
              ? PlatformTeamPage(
                  repository: widget.repository,
                  team: _team,
                  onChanged: _reload,
                )
              : _selectedNav == 4
              ? PlatformMoneyPage(repository: widget.repository)
              : FutureBuilder<List<PlatformApplication>>(
                  future: _applications,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _PageFailure(
                        error: snapshot.error,
                        onRetry: _reload,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _applicationPage(snapshot.requireData);
                  },
                ),
        ),
      ],
    ),
  );

  Widget _applicationPage(List<PlatformApplication> applications) {
    final submitted = applications
        .where((item) => item.status == 'submitted')
        .length;
    final reviewing = applications
        .where((item) => item.status == 'under_review')
        .length;
    final waiting = applications
        .where((item) => item.status == 'more_information_required')
        .length;
    final query = _search.text.trim().toLowerCase();
    final visible = applications.where((item) {
      final matchesStatus = _status == 'all' || item.status == _status;
      final matchesQuery =
          query.isEmpty ||
          '${item.code} ${item.estateName} ${item.applicantName} ${item.location}'
              .toLowerCase()
              .contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 30,
            24,
            compact ? 18 : 30,
            36,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estate applications',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Review estate registrations and manage the approval queue.',
                        style: TextStyle(color: EstateColors.muted),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _AccessBanner(),
            const SizedBox(height: 17),
            _SummaryRow(
              submitted: submitted,
              reviewing: reviewing,
              waiting: waiting,
              total: applications.length,
              compact: compact,
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review queue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${visible.length} records',
                  style: const TextStyle(
                    color: EstateColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 360,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search estate, applicant or application ID',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Application status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'submitted',
                        child: Text('Submitted'),
                      ),
                      DropdownMenuItem(
                        value: 'under_review',
                        child: Text('Under review'),
                      ),
                      DropdownMenuItem(
                        value: 'more_information_required',
                        child: Text('More information required'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'all'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const _EmptyQueue()
            else if (compact)
              for (final item in visible)
                _ApplicationCard(
                  item: item,
                  onTap: () => _openApplication(item),
                )
            else
              _ApplicationTable(items: visible, onOpen: _openApplication),
          ],
        );
      },
    );
  }

  Future<void> _openApplication(PlatformApplication application) async {
    try {
      final detail = await widget.repository.loadApplication(application.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _ApplicationDetailDialog(
          application: detail,
          repository: widget.repository,
          onAction: _runApplicationAction,
          onDocumentDownload: (document) =>
              _downloadApplicationDocument(detail, document),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open application: $error')),
      );
    }
  }

  Future<void> _downloadApplicationDocument(
    PlatformApplication application,
    PlatformApplicationDocument document,
  ) async {
    try {
      final bytes = await widget.repository.downloadApplicationDocument(
        application.id,
        document.id,
      );
      await FilePicker.saveFile(
        fileName: document.label,
        bytes: Uint8List.fromList(bytes),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download document: $error')),
      );
    }
  }

  Future<void> _runApplicationAction(
    BuildContext dialogContext,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (!mounted || !dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Application updated.')));
    } catch (error) {
      if (!mounted || !dialogContext.mounted) return;
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('The action could not be completed: $error')),
      );
    }
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFF0DCA9)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFF8A5B13)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Application access follows your platform role. Review decisions and estate activation are recorded in the audit history.',
            style: TextStyle(
              color: Color(0xFF795416),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.submitted,
    required this.reviewing,
    required this.waiting,
    required this.total,
    required this.compact,
  });
  final int submitted;
  final int reviewing;
  final int waiting;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        label: 'Submitted',
        value: '$submitted',
        icon: Icons.inbox_outlined,
        color: const Color(0xFF476B91),
      ),
      _SummaryCard(
        label: 'Under review',
        value: '$reviewing',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF8063A1),
      ),
      _SummaryCard(
        label: 'Needs information',
        value: '$waiting',
        icon: Icons.mark_email_unread_outlined,
        color: const Color(0xFFB57914),
      ),
      _SummaryCard(
        label: 'All applications',
        value: '$total',
        icon: Icons.folder_open_outlined,
        color: EstateColors.forest,
      ),
    ];
    return compact
        ? Column(
            children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.only(bottom: 9), child: card),
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < cards.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == cards.length - 1 ? 0 : 12,
                    ),
                    child: cards[i],
                  ),
                ),
            ],
          );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .1),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
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

class _ApplicationTable extends StatelessWidget {
  const _ApplicationTable({required this.items, required this.onOpen});
  final List<PlatformApplication> items;
  final ValueChanged<PlatformApplication> onOpen;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF6F8F6)),
        columns: const [
          DataColumn(label: Text('ESTATE / APPLICATION')),
          DataColumn(label: Text('APPLICANT')),
          DataColumn(label: Text('SUBMITTED')),
          DataColumn(label: Text('DOCUMENTS')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.estateName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item.code} · ${item.location}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: EstateColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => onOpen(item),
                ),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.applicantName),
                        Text(
                          item.applicantEmail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: EstateColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => onOpen(item),
                ),
                DataCell(
                  Text(_date(item.submittedAt)),
                  onTap: () => onOpen(item),
                ),
                DataCell(
                  Text(
                    '${item.documentCount - item.pendingDocumentCount}/${item.documentCount} reviewed',
                  ),
                  onTap: () => onOpen(item),
                ),
                DataCell(
                  _StatusChip(status: item.status),
                  onTap: () => onOpen(item),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Open application',
                    onPressed: () => onOpen(item),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.item, required this.onTap});
  final PlatformApplication item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      title: Text(
        item.estateName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${item.code} · ${item.location}\n${item.applicantName} · ${_date(item.submittedAt)}\n${item.documentCount - item.pendingDocumentCount}/${item.documentCount} documents reviewed',
        ),
      ),
      isThreeLine: true,
      trailing: _StatusChip(status: item.status),
      onTap: onTap,
    ),
  );
}

class _ApplicationDetailDialog extends StatefulWidget {
  const _ApplicationDetailDialog({
    required this.application,
    required this.repository,
    required this.onAction,
    required this.onDocumentDownload,
  });
  final PlatformApplication application;
  final PlatformApplicationApiRepository repository;
  final Future<void> Function(BuildContext, Future<void> Function()) onAction;
  final void Function(PlatformApplicationDocument document) onDocumentDownload;

  @override
  State<_ApplicationDetailDialog> createState() =>
      _ApplicationDetailDialogState();
}

class _ApplicationDetailDialogState extends State<_ApplicationDetailDialog> {
  late final Future<List<PlatformAdministratorChoice>> _administrators;
  PlatformAdministratorChoice? _selectedAdministrator;

  PlatformApplication get application => widget.application;
  PlatformApplicationApiRepository get repository => widget.repository;
  Future<void> Function(BuildContext, Future<void> Function()) get onAction =>
      widget.onAction;
  void Function(PlatformApplicationDocument) get onDocumentDownload =>
      widget.onDocumentDownload;

  @override
  void initState() {
    super.initState();
    _administrators =
        application.status == 'submitted' ||
            application.status == 'under_review'
        ? repository.loadInitialAdministrators()
        : Future.value(const []);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 690, maxHeight: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.estateName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${application.code} · ${application.estateType}',
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DetailFact(
                        label: 'APPLICANT',
                        value: application.applicantName,
                      ),
                    ),
                    Expanded(
                      child: _DetailFact(
                        label: 'SUBMITTED',
                        value: _date(application.submittedAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailFact(
                  label: 'CONTACT',
                  value: application.applicantEmail,
                ),
                const SizedBox(height: 16),
                _DetailFact(
                  label: 'ESTATE LOCATION',
                  value: application.location,
                ),
                if (application.managementEntityName != null) ...[
                  const SizedBox(height: 16),
                  _DetailFact(
                    label: 'MANAGEMENT ENTITY',
                    value: application.managementEntityName!,
                  ),
                ],
                if (application.registrationNumber != null) ...[
                  const SizedBox(height: 16),
                  _DetailFact(
                    label: 'REGISTRATION NUMBER',
                    value: application.registrationNumber!,
                  ),
                ],
                if (application.applicantRelationship != null) ...[
                  const SizedBox(height: 16),
                  _DetailFact(
                    label: 'APPLICANT RELATIONSHIP',
                    value: application.applicantRelationship!,
                  ),
                ],
                const SizedBox(height: 16),
                _DetailFact(
                  label: 'APPLICATION STATUS',
                  value: _statusLabel(application.status),
                ),
                if (application.homeCount != null ||
                    application.phaseCount != null ||
                    application.structureSummary != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Estate structure',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (application.homeCount != null)
                    _DetailFact(
                      label: 'HOMES OR UNITS',
                      value: '${application.homeCount}',
                    ),
                  if (application.phaseCount != null) ...[
                    const SizedBox(height: 12),
                    _DetailFact(
                      label: 'DEVELOPMENT PHASES',
                      value: '${application.phaseCount}',
                    ),
                  ],
                  if (application.structureSummary != null) ...[
                    const SizedBox(height: 12),
                    _DetailFact(
                      label: 'STRUCTURE SUMMARY',
                      value: application.structureSummary!,
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                const Text(
                  'Submitted documents',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Submitted documents',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${application.documentCount - application.pendingDocumentCount}/${application.documentCount} reviewed',
                      style: const TextStyle(
                        color: EstateColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (application.documents.isEmpty)
                  _DocumentReviewNote(
                    text: 'No supporting documents have been uploaded.',
                  )
                else
                  ...application.documents.map(
                    (document) => _ApplicationDocumentTile(
                      document: document,
                      onDownload: () => onDocumentDownload(document),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'Document files remain private. This view only displays document metadata returned by the estate service.',
                  style: TextStyle(
                    color: EstateColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                if (application.reviewMessage != null) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Review message',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    application.reviewMessage!,
                    style: const TextStyle(height: 1.45),
                  ),
                ],
                if (application.status == 'submitted' ||
                    application.status == 'under_review') ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Initial estate administrator',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  FutureBuilder<List<PlatformAdministratorChoice>>(
                    future: _administrators,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator(minHeight: 2);
                      }
                      if (snapshot.hasError) {
                        return const _DocumentReviewNote(
                          text: 'Only a platform super administrator can select the first estate administrator and approve this application.',
                        );
                      }
                      final choices = snapshot.data ?? const [];
                      if (choices.isEmpty) {
                        return const _DocumentReviewNote(
                          text: 'No active accounts are available for the first administrator role.',
                        );
                      }
                      return InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Choose an active account',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PlatformAdministratorChoice>(
                            isExpanded: true,
                            value: _selectedAdministrator,
                            hint: const Text('Select an estate administrator'),
                            items: choices
                                .map(
                                  (choice) => DropdownMenuItem(
                                    value: choice,
                                    child: Text(
                                      '${choice.displayName}  -  ${choice.email}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (choice) =>
                                setState(() => _selectedAdministrator = choice),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Approval activates the estate and grants this account administrator access.',
                    style: TextStyle(color: EstateColors.muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 9,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: application.status == 'submitted'
                      ? () => onAction(
                          context,
                          () => repository.startReview(application.id),
                        )
                      : null,
                  child: const Text('Start review'),
                ),
                OutlinedButton(
                  onPressed: application.status == 'under_review'
                      ? () => _requestDecisionReason(
                          context,
                          title: 'Request information',
                          actionLabel: 'Send request',
                          onAction: onAction,
                          submit: (message) => repository.requestInformation(
                            application.id,
                            message,
                          ),
                        )
                      : null,
                  child: const Text('Request information'),
                ),
                OutlinedButton(
                  onPressed: application.status == 'under_review'
                      ? () => _requestDecisionReason(
                          context,
                          title: 'Reject application',
                          actionLabel: 'Reject application',
                          onAction: onAction,
                          submit: (reason) =>
                              repository.reject(application.id, reason),
                        )
                      : null,
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed:
                      application.status == 'under_review' &&
                          _selectedAdministrator != null
                      ? () => onAction(
                          context,
                          () => repository.approve(
                            application.id,
                            _selectedAdministrator!.id,
                          ),
                        )
                      : null,
                  child: const Text('Approve estate'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _requestDecisionReason(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required Future<void> Function(BuildContext, Future<void> Function())
  onAction,
  required Future<void> Function(String) submit,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 2000,
        decoration: const InputDecoration(
          labelText: 'Message',
          hintText:
              'Explain what is needed or why the application is rejected.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
          },
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  if (reason == null || reason.trim().isEmpty || !context.mounted) return;
  await onAction(context, () => submit(reason.trim()));
}

class _ApplicationDocumentTile extends StatelessWidget {
  const _ApplicationDocumentTile({
    required this.document,
    required this.onDownload,
  });
  final PlatformApplicationDocument document;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final status = document.reviewStatus;
    final color = status == 'verified'
        ? EstateColors.forest
        : status == 'rejected'
        ? EstateColors.red
        : const Color(0xFF8A5B13);
    final background = status == 'verified'
        ? const Color(0xFFE9F4ED)
        : status == 'rejected'
        ? const Color(0xFFF9EDEC)
        : const Color(0xFFFFF2D8);
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
        leading: const Icon(
          Icons.description_outlined,
          color: EstateColors.forest,
        ),
        title: Text(
          document.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${document.category.replaceAll('_', ' ')} · uploaded ${_date(document.uploadedAt)}',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Download document',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                status.replaceAll('_', ' '),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        onTap: null,
      ),
    );
  }
}

class _DocumentReviewNote extends StatelessWidget {
  const _DocumentReviewNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F8F6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: EstateColors.muted),
    ),
  );
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: EstateColors.muted,
          fontSize: 10,
          letterSpacing: .5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: style.$2,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        style.$1,
        style: TextStyle(
          color: style.$3,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 50),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: EstateColors.muted),
          SizedBox(height: 10),
          Text('No applications match these filters.'),
        ],
      ),
    ),
  );
}

class _PageFailure extends StatelessWidget {
  const _PageFailure({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 36,
          color: EstateColors.muted,
        ),
        const SizedBox(height: 10),
        const Text('Estate applications could not be loaded.'),
        if (error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

(String, Color, Color) _statusStyle(String status) => switch (status) {
  'submitted' => (
    'Submitted',
    const Color(0xFFEAF1F8),
    const Color(0xFF476B91),
  ),
  'under_review' => (
    'Under review',
    const Color(0xFFF0EAF7),
    const Color(0xFF765797),
  ),
  'more_information_required' => (
    'Needs information',
    const Color(0xFFFFF2D8),
    const Color(0xFF8A5B13),
  ),
  'approved' => ('Approved', const Color(0xFFE9F4ED), EstateColors.forest),
  'rejected' => ('Rejected', const Color(0xFFF9EDEC), const Color(0xFF984B43)),
  _ => (status, const Color(0xFFF0F1F2), EstateColors.muted),
};

String _statusLabel(String status) => _statusStyle(status).$1;
String _date(DateTime value) =>
    '${value.day}/${value.month}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
