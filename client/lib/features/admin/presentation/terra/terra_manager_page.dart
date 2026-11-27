import 'package:flutter/material.dart';

import '../../../../core/config/report_download.dart';
import '../../../../core/design/terra_shell.dart';
import '../../../../core/design/terra_theme.dart';
import '../../../../core/design/terra_navigation_rail.dart';
import '../../../../core/design/terra_service_drawer.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/auth_redirect.dart';
import '../../../../core/utils/formatters.dart';
import '../../../notifications/presentation/estate_notifications_page.dart';
import '../../../onboarding/data/estate_application_repository.dart';
import '../../../resident_access/presentation/resident_access_review_page.dart';
import '../manager_service_pages.dart';
import 'terra_residents_pages.dart';
import 'terra_tenancies_page.dart';
import 'terra_charges_page.dart';
import 'terra_expenses_page.dart';
import 'terra_payouts_page.dart';
import 'terra_facilities_page.dart';
import 'terra_security_page.dart';
import 'terra_notices_page.dart';
import 'terra_staff_page.dart';
import 'terra_settings_page.dart';
import 'terra_reports_page.dart';
import '../ownership_review_api_page.dart';

/// Estate manager home in the Terra Crest visual language.
class TerraManagerPage extends StatefulWidget {
  const TerraManagerPage({super.key, required this.repository});

  final EstateApplicationApiRepository repository;

  @override
  State<TerraManagerPage> createState() => _TerraManagerPageState();
}

class _TerraManagerPageState extends State<TerraManagerPage> {
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  EstateManagerDashboardSummary? _summary;
  EstateTreasurySummary? _treasury;
  Map<String, dynamic> _report = const {};
  List<HouseholdMemberRecord> _household = const [];
  List<IdentityVerificationRecord> _identity = const [];
  List<PropertyLocationRecord> _locations = const [];
  List<EstateServiceOrderRecord> _serviceOrders = const [];
  List<dynamic> _audit = const [];
  bool _restoring = true;
  bool _busy = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      _account = await widget.repository.restoreSession();
      if (_account != null) await _load();
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// One failing optional read must never block the dashboard.

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      _estates = await widget.repository.loadManagedEstates();
      final estateId = _estates.firstOrNull?.id;
      if (estateId == null) return;
      // Each section loads independently: a slow or cancelled request must not
      // leave the whole dashboard showing zeros.
      Future<void> load(Future<void> Function() apply) async {
        try {
          await apply();
        } catch (_) {
          // Keep the previous value; one section failing never blanks the page.
        }
        if (mounted) setState(() {});
      }

      await Future.wait([
        load(() async => _summary = await widget.repository.loadManagerDashboard(estateId)),
        load(() async => _treasury = await widget.repository.loadTreasurySummary(estateId)),
        load(() async => _report = await widget.repository.loadManagerReportSummary(estateId)),
        load(() async => _household = await widget.repository.loadEstateHousehold(estateId)),
        load(() async => _identity = await widget.repository.loadEstateIdentityVerifications(estateId)),
        load(() async => _locations = await widget.repository.loadPropertyLocations(estateId)),
        load(() async => _serviceOrders = await widget.repository.loadEstateServiceOrders(estateId)),
        load(() async {
          final log = await widget.repository.loadAuditLog(estateId);
          _audit = log['items'] as List<dynamic>? ?? const [];
        }),
      ]);
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _displayName => _account?.displayName ?? 'Estate Manager';
  String get _estateName => _estates.firstOrNull?.name ?? 'Terra Crest';
  String get _estateId => _estates.firstOrNull?.id ?? '';
  List<String> get _roles => _estates.firstOrNull?.roles ?? const [];
  String get _collections => _money(_treasury?.collections);

  ManagerServiceContext get _serviceContext => ManagerServiceContext(
        repository: widget.repository,
        estateId: _estateId,
        estateName: _estateName,
      );

  String _money(String? value) => '₦${AppFormat.amount(value ?? '0')}';

  String _reportValue(String section, String key) {
    if (section == 'auditEvents') {
      return _report['auditEvents']?.toString() ?? '0';
    }
    return (_report[section] as Map? ?? const {})[key]?.toString() ?? '0';
  }

  String _section = 'home';

  void _selectSection(String id) => setState(() => _section = id);

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    goToSingleSignIn();
  }

  List<TerraNavItem> _navigationItems() {
    final pending = (_report['invoices'] as Map? ?? const {})['issued'] ?? '0';
    return [
      const TerraNavItem(id: 'home', icon: Icons.home_outlined, label: 'Overview', section: 'WORKSPACE'),
      TerraNavItem(id: 'residents', icon: Icons.people_outline, label: 'Residents', section: 'WORKSPACE'),
      TerraNavItem(id: 'approvals', icon: Icons.how_to_reg_outlined, label: 'Approvals', section: 'WORKSPACE', badge: '$pending'),
      const TerraNavItem(id: 'ownership', icon: Icons.domain_outlined, label: 'Ownership', section: 'PEOPLE'),
      const TerraNavItem(id: 'tenancies', icon: Icons.home_outlined, label: 'Tenancies', section: 'PEOPLE'),
      const TerraNavItem(id: 'household', icon: Icons.family_restroom_outlined, label: 'Household', section: 'PEOPLE'),
      const TerraNavItem(id: 'levies', icon: Icons.receipt_long_outlined, label: 'Levies', section: 'FINANCE'),
      const TerraNavItem(id: 'payouts', icon: Icons.payments_outlined, label: 'Payouts', section: 'FINANCE'),
      const TerraNavItem(id: 'expenses', icon: Icons.account_balance_wallet_outlined, label: 'Expenses', section: 'FINANCE'),
      const TerraNavItem(id: 'reports', icon: Icons.summarize_outlined, label: 'Reports', section: 'FINANCE'),
      const TerraNavItem(id: 'map', icon: Icons.map_outlined, label: 'Property map', section: 'ESTATE'),
      const TerraNavItem(id: 'facilities', icon: Icons.storefront_outlined, label: 'Facilities', section: 'ESTATE'),
      const TerraNavItem(id: 'security', icon: Icons.shield_outlined, label: 'Security', section: 'ESTATE'),
      const TerraNavItem(id: 'notices', icon: Icons.campaign_outlined, label: 'Notices', section: 'ESTATE'),
      const TerraNavItem(id: 'staff', icon: Icons.badge_outlined, label: 'Staff', section: 'ESTATE'),
      const TerraNavItem(id: 'settings', icon: Icons.settings_outlined, label: 'Settings', section: 'ESTATE'),
    ];
  }

  Widget _sectionPage() {
    final repository = widget.repository;
    final estateId = _estateId;
    final estateName = _estateName;
    switch (_section) {
      case 'residents':
        return TerraResidentsPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'approvals':
        return ResidentAccessReviewPage(
          repository: repository, initialEstateId: estateId, showSignOutAction: false);
      case 'ownership':
        return OwnershipReviewApiPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'tenancies':
        return TerraTenanciesPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'levies':
        return TerraChargesPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'payouts':
        return TerraPayoutsPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'expenses':
        return TerraExpensesPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'reports':
        return TerraReportsPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'map':
        return ManagerPropertyMapPage(serviceContext: _serviceContext);
      case 'facilities':
        return TerraFacilitiesPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'security':
        return TerraSecurityPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'notices':
        return TerraNoticesPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'staff':
        return TerraStaffPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'settings':
        return TerraSettingsPage(
          repository: repository, estateId: estateId, estateName: estateName);
      case 'household':
        return TerraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TerraSectionTitle(title: 'Household'),
              const SizedBox(height: 8),
              const Text(
                'Household links and dependants are managed from each resident record.',
                style: TextStyle(color: TerraColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _selectSection('residents'),
                icon: const Icon(Icons.people_outlined),
                label: const Text('Open residents'),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _open(Widget page) => AppNavigation.push(context, page);

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TerraColors.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            TerraSectionTitle(
              title: 'All services',
              trailing: TerraBadge(label: '${_managerMenuServices().length}'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Open any service from here. Each one has its own page.',
              style: TextStyle(color: TerraColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ..._managerMenuServices().map(
              (service) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(service.icon, color: TerraColors.forest, size: 20),
                title: Text(service.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(service.section,
                    style: const TextStyle(fontSize: 10, color: TerraColors.muted)),
                trailing: const Icon(Icons.chevron_right,
                    size: 16, color: TerraColors.muted),
                onTap: () {
                  Navigator.of(context).pop();
                  service.onTap();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TerraMenuService> _managerMenuServices() => [
        TerraMenuService(label: 'Residents', icon: Icons.people_outline, section: 'People', onTap: _openResidents),
        TerraMenuService(label: 'Approvals', icon: Icons.how_to_reg_outlined, section: 'People', onTap: _openResidentAccessReview),
        TerraMenuService(label: 'Ownership', icon: Icons.domain_outlined, section: 'People', onTap: _openOwnershipReview),
        TerraMenuService(label: 'Tenancies', icon: Icons.home_outlined, section: 'People', onTap: _openTenancyApprovals),
        TerraMenuService(label: 'Levies', icon: Icons.receipt_long_outlined, section: 'Finance', onTap: _openEstateCharges),
        TerraMenuService(label: 'Payouts', icon: Icons.payments_outlined, section: 'Finance', onTap: _openManagerPayouts),
        TerraMenuService(label: 'Expenses', icon: Icons.account_balance_wallet_outlined, section: 'Finance', onTap: _openEstateExpenses),
        TerraMenuService(label: 'Reports', icon: Icons.summarize_outlined, section: 'Finance', onTap: _openManagerReports),
        TerraMenuService(label: 'Property map', icon: Icons.map_outlined, section: 'Estate', onTap: _openManagerPropertyMap),
        TerraMenuService(label: 'Facilities', icon: Icons.storefront_outlined, section: 'Estate', onTap: _openEstateFacilities),
        TerraMenuService(label: 'Security', icon: Icons.shield_outlined, section: 'Estate', onTap: _openSecurityIncidents),
        TerraMenuService(label: 'Notices', icon: Icons.campaign_outlined, section: 'Estate', onTap: _openEstateAnnouncements),
        TerraMenuService(label: 'Staff', icon: Icons.badge_outlined, section: 'Estate', onTap: _openStaffInvitations),
        TerraMenuService(label: 'Settings', icon: Icons.settings_outlined, section: 'Estate', onTap: _openEstateSettings),
      ];

  void _openResidents() => _open(
        TerraResidentsPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openResidentAccessReview() => _open(
        ResidentAccessReviewPage(
          repository: widget.repository,
          initialEstateId: _estateId.isEmpty ? null : _estateId,
          showSignOutAction: false,
        ),
      );

  void _openOwnershipReview() => _open(
        OwnershipReviewApiPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openTenancyApprovals() => _open(
        TerraTenanciesPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openEstateCharges() => _open(
        TerraChargesPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openEstateExpenses() => _open(
        TerraExpensesPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openManagerReports() => _open(
        TerraReportsPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openManagerPayouts() => _open(
        TerraPayoutsPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openManagerPropertyMap() =>
      _open(ManagerPropertyMapPage(serviceContext: _serviceContext));

  void _openEstateFacilities() => _open(
        TerraFacilitiesPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openSecurityIncidents() => _open(
        TerraSecurityPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openEstateAnnouncements() => _open(
        TerraNoticesPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openStaffInvitations() => _open(
        TerraStaffPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  void _openEstateSettings() => _open(
        TerraSettingsPage(
          repository: widget.repository,
          estateId: _estateId,
          estateName: _estateName,
        ),
      );

  Future<void> _sendBills() async {
    if (_estateId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final result =
          await widget.repository.generateRecurringLevies(_estateId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Levies: ${result['created']} new, ${result['issued']} issued, '
            '${result['replayed']} already generated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bills could not be sent: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportReport(String type) async {
    if (_estateId.isEmpty) return;
    try {
      final csv = await widget.repository.fetchReportCsv(_estateId, type);
      final slug =
          _estateName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase();
      downloadReportCsv('$slug-$type-report.csv', csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report exported as CSV.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export report: $error')),
      );
    }
  }

  void _showProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TerraColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerraSectionTitle(title: _displayName),
              const SizedBox(height: 6),
              Text(_estateName,
                  style: const TextStyle(color: TerraColors.muted)),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.logout, color: TerraColors.forest),
                title: const Text('Sign out'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await widget.repository.signOut();
                  if (mounted) navigator.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: TerraColors.forest)),
      );
    }
    if (_account == null) return singleSignInRedirect();

    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: TerraTopBar(
            estateName: 'Terra Crest',
            estateDescriptor: 'Emerald Living Sanctuary • Cluster Alpha-A',
            userName: _displayName,
            userSubtitle: 'Estate Manager • $_estateName',
            tier: 'Estate Manager',
            statuses: [
              TerraStatus(
                label: 'Collections',
                value: _collections,
                icon: Icons.account_balance_outlined,
              ),
              TerraStatus(
                label: 'Settlements',
                value: '${_treasury?.pendingSettlements ?? 0} pending',
                icon: Icons.swap_horiz_outlined,
              ),
              TerraStatus(
                label: 'Exceptions',
                value: '${_treasury?.reconciliationExceptions ?? 0} open',
                icon: Icons.report_problem_outlined,
              ),
            ],
            onNotification: () => AppNavigation.push(
              context,
              EstateNotificationsPage(repository: widget.repository),
            ),
            onMenu: _showMenu,
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final twoColumns = constraints.maxWidth >= 1100;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TerraNavigationRail(
                    items: _navigationItems(),
                    selectedId: _section,
                    onSelect: _selectSection,
                    width: wide ? 244 : 64,
                    header: TerraRailHeader(
                      estateName: 'Terra Crest',
                      subtitle: 'Estate Manager',
                      extended: wide,
                    ),
                    footer: wide
                        ? ListTile(
                            leading: const Icon(Icons.logout_outlined,
                                color: TerraColors.danger, size: 19),
                            title: const Text('Sign out',
                                style: TextStyle(
                                    color: TerraColors.danger, fontSize: 12)),
                            onTap: _signOut,
                          )
                        : IconButton(
                            tooltip: 'Sign out',
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout_outlined,
                                color: TerraColors.danger),
                          ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: _section == 'home'
                              ? twoColumns
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: _leftColumn()),
                                        const SizedBox(width: 20),
                                        Expanded(flex: 2, child: _rightColumn()),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _leftColumn(),
                                        const SizedBox(height: 18),
                                        _rightColumn(),
                                      ],
                                    )
                              : _sectionPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _leftColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TerraCard(
                color: TerraColors.amberWash,
                child: Text(_error!,
                    style: const TextStyle(
                        color: TerraColors.amber, fontSize: 12)),
              ),
            ),
          _greetingCard(),
          const SizedBox(height: 18),
          TerraWalletCard(
            label: 'MONEY COLLECTED FOR THE ESTATE',
            balance: _collections,
            accountLabel: 'Estate Treasury',
            accountDetail:
                'Outstanding invoices ${_money((_report['invoices'] as Map? ?? const {})['billed']?.toString())} • '
                '${_treasury?.pendingSettlements ?? 0} settlements awaiting clearing',
            actions: [
              TerraWalletAction(
                label: 'Record spending',
                icon: Icons.account_balance_wallet_outlined,
                onTap: _openEstateExpenses,
              ),
              TerraWalletAction(
                label: 'Approvals',
                icon: Icons.approval_outlined,
                onTap: _openResidentAccessReview,
              ),
              TerraWalletAction(
                label: 'Send bills',
                icon: Icons.autorenew_outlined,
                onTap: _sendBills,
              ),
            ],
          ),
        ],
      );

  Widget _rightColumn() => Column(
        children: [
          _treasuryCard(),
          const SizedBox(height: 18),
          _reportsCard(),
          const SizedBox(height: 18),
          _needsAttentionCard(),
          const SizedBox(height: 18),
          _auditCard(),
        ],
      );

  Widget _greetingCard() => TerraCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: TerraColors.sage,
                  child: Text(
                    _initials(_displayName),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TerraColors.forest),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TerraLabel('$_greeting • Estate Manager'),
                      const SizedBox(height: 3),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: TerraColors.ink,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Terra Crest Sanctuary • $_estateName • Cluster Alpha-A',
                        style: const TextStyle(
                            fontSize: 11, color: TerraColors.muted),
                      ),
                    ],
                  ),
                ),
                const TerraBadge(
                  label: 'Verified Estate Account',
                  icon: Icons.verified_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TerraBadge(
                    label: '${_household.length} household links',
                    tone: TerraBadgeTone.outline),
                TerraBadge(
                    label: '${_identity.where((row) => row.status == 'approved').length} verified IDs',
                    tone: TerraBadgeTone.outline),
                TerraBadge(
                    label: '${_locations.where((row) => row.verificationStatus == 'verified').length} mapped lots',
                    tone: TerraBadgeTone.outline),
                TerraBadge(
                    label: '${_serviceOrders.length} service orders',
                    tone: TerraBadgeTone.outline),
              ],
            ),
          ],
        ),
      );

  Widget _quickServices() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Quick Services',
              trailing: TerraLabel('Terra Crest Ecosystem'),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 560 ? 4 : 3;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    (
                      icon: Icons.apartment_outlined,
                      label: 'Properties',
                      onTap: _openOwnershipReview,
                    ),
                    (
                      icon: Icons.people_outline,
                      label: 'Residents',
                      onTap: _openResidents,
                    ),
                    (
                      icon: Icons.home_outlined,
                      label: 'Tenancies',
                      onTap: _openTenancyApprovals,
                    ),
                    (
                      icon: Icons.receipt_long_outlined,
                      label: 'Levies',
                      onTap: _openEstateCharges,
                    ),
                    (
                      icon: Icons.payments_outlined,
                      label: 'Payouts',
                      onTap: _openManagerPayouts,
                    ),
                    (
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Expenses',
                      onTap: _openEstateExpenses,
                    ),
                    (
                      icon: Icons.map_outlined,
                      label: 'Property map',
                      onTap: _openManagerPropertyMap,
                    ),
                    (
                      icon: Icons.storefront_outlined,
                      label: 'Services',
                      onTap: _openEstateFacilities,
                    ),
                    (
                      icon: Icons.shield_outlined,
                      label: 'Security',
                      onTap: _openSecurityIncidents,
                    ),
                    (
                      icon: Icons.campaign_outlined,
                      label: 'Notices',
                      onTap: _openEstateAnnouncements,
                    ),
                    (
                      icon: Icons.badge_outlined,
                      label: 'Staff',
                      onTap: _openStaffInvitations,
                    ),
                    (
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: _openEstateSettings,
                    ),
                  ].map(
                    (service) => TerraServiceTile(
                      icon: service.icon,
                      label: service.label,
                      onTap: service.onTap,
                    ),
                  ).toList(),
                );
              },
            ),
          ],
        ),
      );

  Widget _treasuryCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Treasury snapshot',
              trailing: TerraBadge(label: 'Estate Treasury'),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                TerraMetric(
                    label: 'Collections',
                    value: _collections,
                    icon: Icons.account_balance_outlined),
                TerraMetric(
                    label: 'Outstanding',
                    value: _money(_treasury?.outstandingInvoices),
                    icon: Icons.request_quote_outlined),
                TerraMetric(
                    label: 'Cleared',
                    value: _money(_treasury?.walletBalances),
                    icon: Icons.check_circle_outline),
                TerraMetric(
                    label: 'Payouts',
                    value: _reportValue('payouts', 'total'),
                    icon: Icons.payments_outlined),
                TerraMetric(
                    label: 'Exceptions',
                    value: '${_treasury?.reconciliationExceptions ?? 0}',
                    icon: Icons.report_problem_outlined),
                TerraMetric(
                    label: 'Pending settlements',
                    value: '${_treasury?.pendingSettlements ?? 0}',
                    icon: Icons.swap_horiz_outlined),
              ],
            ),
          ],
        ),
      );

  Widget _reportsCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Reports',
              trailing: TerraLabel('Estate records'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 150,
                  child: TerraMetric(
                      label: 'Invoices',
                      value: _reportValue('invoices', 'total')),
                ),
                SizedBox(
                  width: 150,
                  child: TerraMetric(
                      label: 'Billed',
                      value:
                          '${_report['currency'] ?? 'NGN'} ${_reportValue('invoices', 'billed')}'),
                ),
                SizedBox(
                  width: 150,
                  child: TerraMetric(
                      label: 'Rent outstanding',
                      value:
                          '${_report['currency'] ?? 'NGN'} ${_reportValue('rent', 'outstanding')}'),
                ),
                SizedBox(
                  width: 150,
                  child: TerraMetric(
                      label: 'Expenses',
                      value: _reportValue('expenses', 'total')),
                ),
                SizedBox(
                  width: 150,
                  child: TerraMetric(
                      label: 'Audit events', value: _reportValue('auditEvents', '')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _exportReport('wallet'),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Wallet CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportReport('ledger'),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Ledger CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportReport('audit'),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Audit CSV'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _needsAttentionCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Needs attention',
              trailing: TerraLabel('Review queue'),
            ),
            const SizedBox(height: 10),
            if (_summary == null)
              const TerraEmpty(message: 'Estate activity will appear here.')
            else
              ...[
                _attentionRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Resident access',
                  count: _summary!.pendingAccessRequests,
                  onTap: _openResidentAccessReview,
                ),
                _attentionRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Ownership checks',
                  count: _summary!.pendingOwnershipReviews,
                  onTap: _openOwnershipReview,
                ),
                _attentionRow(
                  icon: Icons.key_outlined,
                  label: 'Tenancy approvals',
                  count: _summary!.pendingTenancies,
                  onTap: _openTenancyApprovals,
                ),
              ],
          ],
        ),
      );

  Widget _attentionRow({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TerraColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: TerraColors.forest),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TerraColors.ink)),
                ),
                TerraBadge(
                  label: '$count pending',
                  tone: count > 0 ? TerraBadgeTone.amber : TerraBadgeTone.sage,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _auditCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerraSectionTitle(
              title: 'Audit trail',
              trailing: TerraBadge(
                  label: '${_audit.length} events', tone: TerraBadgeTone.outline),
            ),
            const SizedBox(height: 10),
            if (_audit.isEmpty)
              const TerraEmpty(message: 'No estate events have been recorded yet.')
            else
              ..._audit.take(5).map(_auditRow),
          ],
        ),
      );

  String _friendlyAuditAction(String raw) {
    return raw
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\bdemo\b'), 'preview')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _auditRow(dynamic entry) {
    final event = entry is Map<String, dynamic> ? entry : <String, dynamic>{};
    final action = _friendlyAuditAction(event['action']?.toString() ?? 'Estate event');
    final actor = event['actorDisplayName']?.toString() ??
        event['actor']?.toString() ??
        'Estate staff';
    final at = event['createdAt']?.toString() ??
        event['occurredAt']?.toString() ??
        '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_toggle_off_outlined,
              size: 17, color: TerraColors.forest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TerraColors.ink)),
                const SizedBox(height: 2),
                Text('$actor${at.isEmpty ? '' : ' • ${AppFormat.date(at)}'}',
                    style: const TextStyle(
                        fontSize: 10, color: TerraColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav() => BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.approval_outlined), label: 'Approvals'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined), label: 'Services'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assessment_outlined), label: 'Reports'),
        ],
      );

  Widget _signIn() {
    final email = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return Theme(
      data: TerraTheme.light(),
      child: Scaffold(
        backgroundColor: TerraColors.canvas,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TerraCard(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_outlined,
                          size: 40, color: TerraColors.forest),
                      const SizedBox(height: 12),
                      const Text('Welcome to Terra Crest',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('Sign in to open your estate workspace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: TerraColors.muted, fontSize: 12)),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(labelText: 'Email address'),
                        validator: (value) => value == null || !value.contains('@')
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: TerraColors.danger, fontSize: 12)),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            _account = await widget.repository.signIn(
                              email: email.text.trim(),
                              password: password.text,
                            );
                            await _load();
                            if (mounted) setState(() {});
                          } catch (error) {
                            if (!mounted) return;
                            setState(() => _error = '$error');
                          }
                        },
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0])
      .join()
      .toUpperCase();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}







