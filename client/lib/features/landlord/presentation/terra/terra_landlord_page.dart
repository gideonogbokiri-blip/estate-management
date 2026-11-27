import 'package:flutter/material.dart';

import '../../../../core/design/terra_shell.dart';
import '../../../../core/design/terra_theme.dart';
import '../../../../core/design/terra_navigation_rail.dart';
import '../../../../core/design/terra_service_drawer.dart';
import '../../../../core/navigation/auth_redirect.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../notifications/presentation/estate_notifications_page.dart';
import '../../../onboarding/data/estate_application_repository.dart';
import '../landlord_service_pages.dart';

/// Property owner home in the Terra Crest visual language.
class TerraLandlordPage extends StatefulWidget {
  const TerraLandlordPage({super.key, required this.repository});

  final EstateApplicationApiRepository repository;

  @override
  State<TerraLandlordPage> createState() => _TerraLandlordPageState();
}

class _TerraLandlordPageState extends State<TerraLandlordPage> {
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  List<LandlordPortfolioRecord> _portfolio = const [];
  List<LandlordMaintenanceRecord> _maintenance = const [];
  List<LandlordRentSummaryRecord> _rent = const [];
  List<RentScheduleRecord> _schedule = const [];
  List<EstateSecurityIncidentRecord> _incidents = const [];
  List<EstateAnnouncementRecord> _notices = const [];
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
  Future<T?> _attempt<T extends Object>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      _estates = await widget.repository.loadMyLandlordEstates();
      final estateId = _estates.firstOrNull?.id;
      if (estateId == null) return;
      final results = await Future.wait<dynamic>([
        _attempt<List<LandlordPortfolioRecord>>(
          () => widget.repository.loadLandlordPortfolio(estateId),
        ),
        _attempt<List<LandlordMaintenanceRecord>>(
          () => widget.repository.loadMyLandlordPropertyMaintenance(),
        ),
        _attempt<List<LandlordRentSummaryRecord>>(
          () => widget.repository.loadLandlordRentSummary(estateId),
        ),
        _attempt<List<RentScheduleRecord>>(
          () => widget.repository.loadRentSchedule(estateId),
        ),
        _attempt<List<EstateSecurityIncidentRecord>>(
          () => widget.repository.loadMySecurityIncidents(estateId),
        ),
        _attempt<List<EstateAnnouncementRecord>>(
          () => widget.repository.loadEstateAnnouncements(estateId),
        ),
      ]);
      _portfolio = (results[0] as List<LandlordPortfolioRecord>?) ?? const [];
      _maintenance =
          (results[1] as List<LandlordMaintenanceRecord>?) ?? const [];
      _rent = (results[2] as List<LandlordRentSummaryRecord>?) ?? const [];
      _schedule = (results[3] as List<RentScheduleRecord>?) ?? const [];
      _incidents =
          (results[4] as List<EstateSecurityIncidentRecord>?) ?? const [];
      _notices = (results[5] as List<EstateAnnouncementRecord>?) ?? const [];
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _displayName => _account?.displayName ?? 'Property Owner';
  String get _estateName => _estates.firstOrNull?.name ?? 'Terra Crest';
  String get _estateId => _estates.firstOrNull?.id ?? '';

  double _sumRent(String field) => _rent.fold<double>(
        0,
        (total, row) => total +
            (double.tryParse(field == 'entitlement'
                    ? row.entitlement
                    : field == 'collected'
                        ? row.collected
                        : row.outstanding) ??
                0),
      );

  String get _entitlement => _money(_sumRent('entitlement'));
  String get _collected => _money(_sumRent('collected'));
  String get _outstanding => _money(_sumRent('outstanding'));
  int get _occupied => _portfolio.where((row) => row.occupancyCount > 0).length;

  String _money(num value) => '₦${AppFormat.amount(value)}';

  LandlordServiceContext get _serviceContext => LandlordServiceContext(
        repository: widget.repository,
        estateId: _estateId,
        estateName: _estateName,
      );

  LandlordService _service(String id) =>
      landlordServices().firstWhere((service) => service.id == id);

  void _openService(String id) => openLandlordPage(
        context,
        LandlordServicePage(
          service: _service(id),
          serviceContext: _serviceContext,
        ),
      );

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _section = 'home';

  void _selectSection(String id) => setState(() => _section = id);

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    goToSingleSignIn();
  }

  List<TerraNavItem> _navigationItems() => [
        const TerraNavItem(id: 'home', icon: Icons.home_outlined, label: 'Overview', section: 'WORKSPACE'),
        ...landlordServices().map(
          (service) => TerraNavItem(
            id: service.id,
            icon: service.icon,
            label: service.label,
            section: 'MY ESTATE',
            danger: service.id == 'emergency',
          ),
        ),
      ];

  Widget _sectionPage() => LandlordServicePage(
        service: _service(_section),
        serviceContext: _serviceContext,
      );

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
              trailing: TerraBadge(label: '${landlordServices().length}'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Open any service from here. Each one has its own page.',
              style: TextStyle(color: TerraColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...landlordServices().map(
              (service) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(service.icon, color: TerraColors.forest, size: 20),
                title: Text(service.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(service.description,
                    style: const TextStyle(fontSize: 10, color: TerraColors.muted)),
                trailing: const Icon(Icons.chevron_right,
                    size: 16, color: TerraColors.muted),
                onTap: () {
                  Navigator.of(context).pop();
                  _openService(service.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
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
        key: _scaffoldKey,
        backgroundColor: TerraColors.canvas,
        drawer: TerraServiceDrawer(
          estateName: 'Terra Crest',
          userName: _displayName,
          services: _navigationItems()
              .where((item) => item.id != 'home')
              .map(
                (item) => TerraMenuService(
                  label: item.label,
                  icon: item.icon,
                  section: item.section,
                  danger: item.danger,
                  onTap: () => _selectSection(item.id),
                ),
              )
              .toList(),
          onSignOut: _signOut,
        ),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: TerraTopBar(
            estateName: 'Terra Crest',
            estateDescriptor: 'Emerald Living Sanctuary • Cluster Alpha-A',
            userName: _displayName,
            userSubtitle: 'Property Owner • $_estateName',
            tier: 'Property Owner',
            statuses: [
              TerraStatus(
                label: 'Verified properties',
                value: '${_portfolio.length} on record',
                icon: Icons.verified_outlined,
              ),
              TerraStatus(
                label: 'Rent due',
                value: _outstanding,
                icon: Icons.calendar_month_outlined,
              ),
              TerraStatus(
                label: 'Occupancy',
                value: '$_occupied / ${_portfolio.length} occupied',
                icon: Icons.people_outline,
              ),
            ],
            onNotification: () => AppNavigation.push(
              context,
              EstateNotificationsPage(repository: widget.repository),
            ),
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final twoColumns = constraints.maxWidth >= 1100;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    TerraNavigationRail(
                      items: _navigationItems(),
                      selectedId: _section,
                      onSelect: _selectSection,
                      width: 244,
                      header: TerraRailHeader(
                        estateName: 'Terra Crest',
                        subtitle: 'Property Owner',
                      ),
                      footer: ListTile(
                        leading: const Icon(Icons.logout_outlined,
                            color: TerraColors.danger, size: 19),
                        title: const Text('Sign out',
                            style: TextStyle(
                                color: TerraColors.danger, fontSize: 12)),
                        onTap: _signOut,
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
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                  minHeight: 2, color: TerraColors.forest),
            ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: TerraLabel('Rent you should receive'),
              ),
              TerraWalletCard(
                label: 'RENT YOU SHOULD RECEIVE',
                balance: _entitlement,
                accountLabel: 'Rent ledger',
                accountDetail:
                    '$_collected collected • $_outstanding outstanding across ${_schedule.length} installments',
                badge: 'Rent entitlement',
                actions: [
                  TerraWalletAction(
                    label: 'Rent schedule',
                    icon: Icons.calendar_month_outlined,
                    onTap: () => _openService('rent-schedule'),
                  ),
                  TerraWalletAction(
                    label: 'Receipts',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => _openService('receipts'),
                  ),
                  TerraWalletAction(
                    label: 'Statement',
                    icon: Icons.description_outlined,
                    onTap: () => _openService('statements'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  Widget _rightColumn() => Column(
        children: [
          _portfolioCard(),
          const SizedBox(height: 18),
          _rentPositionCard(),
          const SizedBox(height: 18),
          _maintenanceCard(),
          const SizedBox(height: 18),
          _noticesCard(),
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
                      TerraLabel('$_greeting • Property Owner'),
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
                  label: 'Verified Property Owner',
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
                    label: '${_portfolio.length} properties',
                    tone: TerraBadgeTone.outline),
                TerraBadge(
                    label: '${_incidents.length} safety reports',
                    tone: TerraBadgeTone.outline),
                TerraBadge(
                    label: '${_notices.length} estate notices',
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
                    for (final service in landlordServices())
                      TerraServiceTile(
                        icon: service.icon,
                        label: service.label,
                        onTap: () => openLandlordPage(
                          context,
                          LandlordServicePage(
                            service: service,
                            serviceContext: _serviceContext,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _portfolioCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Portfolio at a glance',
              trailing: TerraBadge(label: 'Verified'),
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
                    label: 'Verified properties',
                    value: '${_portfolio.length}',
                    icon: Icons.apartment_outlined),
                TerraMetric(
                    label: 'Occupied',
                    value: '$_occupied',
                    icon: Icons.people_outline),
                TerraMetric(
                    label: 'Rent installments',
                    value: '${_schedule.length}',
                    icon: Icons.calendar_month_outlined),
                TerraMetric(
                    label: 'Vacant',
                    value: '${_portfolio.length - _occupied}',
                    icon: Icons.home_outlined),
              ],
            ),
          ],
        ),
      );

  Widget _rentPositionCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Rent position',
              trailing: TerraLabel('Across all properties'),
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
                    label: 'Entitlement',
                    value: _entitlement,
                    icon: Icons.account_balance_outlined),
                TerraMetric(
                    label: 'Collected',
                    value: _collected,
                    icon: Icons.check_circle_outline),
                TerraMetric(
                    label: 'Outstanding',
                    value: _outstanding,
                    icon: Icons.schedule_outlined),
              ],
            ),
            if (_rent.isEmpty)
              const TerraEmpty(message: 'No rent summary is available yet.')
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: () => _openService('statements'),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('View full statement'),
                ),
              ),
          ],
        ),
      );

  Widget _maintenanceCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Maintenance',
              trailing: TerraLabel('Recent requests'),
            ),
            const SizedBox(height: 10),
            if (_maintenance.isEmpty)
              const TerraEmpty(message: 'No repair requests have been filed.')
            else
              ..._maintenance.take(3).map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.handyman_outlined,
                              size: 17, color: TerraColors.forest),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${request.reference} · ${request.category}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: TerraColors.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${request.propertyLabel} • ${request.status}',
                                  style: const TextStyle(
                                      fontSize: 10, color: TerraColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      );

  Widget _noticesCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(
              title: 'Estate notices',
              trailing: TerraLabel('From management'),
            ),
            const SizedBox(height: 10),
            if (_notices.isEmpty)
              const TerraEmpty(message: 'No estate notices have been published.')
            else
              ..._notices.take(3).map(
                    (notice) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.campaign_outlined,
                              size: 17, color: TerraColors.forest),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.title,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: TerraColors.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notice.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10, color: TerraColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      );

  Widget _bottomNav() => BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'Rent'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined), label: 'Services'),
          BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined), label: 'Notices'),
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
                      const Text('Sign in to open your property workspace.',
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







