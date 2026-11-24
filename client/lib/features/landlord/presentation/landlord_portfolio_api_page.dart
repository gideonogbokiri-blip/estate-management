import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../../core/design/dashboard_design.dart';
import 'landlord_service_pages.dart';
import '../../../data/api.dart';

class LandlordPortfolioApiPage extends StatefulWidget {
  const LandlordPortfolioApiPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;
  @override
  State<LandlordPortfolioApiPage> createState() => _LandlordPortfolioApiPageState();
}

class _LandlordPortfolioApiPageState extends State<LandlordPortfolioApiPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _propertiesKey = GlobalKey();
  final _maintenanceKey = GlobalKey();
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  List<LandlordPortfolioRecord> _portfolio = const [];
  List<LandlordMaintenanceRecord> _maintenance = const [];
  List<LandlordRentSummaryRecord> _rentSummary = const [];
  List<RentScheduleRecord> _rentSchedule = const [];
  ManagedEstateChoice? _estate;
  bool _restoring = true;
  bool _busy = false;
  String? _error;
  String? _maintenanceError;

  @override
  void initState() { super.initState(); _restore(); }
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _restore() async {
    try { _account = await widget.repository.restoreSession(); if (_account != null) await _loadPortfolio(); }
    catch (error) { _error = _message(error); }
    finally { if (mounted) setState(() => _restoring = false); }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try { _account = await widget.repository.signIn(email: _email.text, password: _password.text); await _loadPortfolio(); }
    catch (error) { _error = _message(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _loadPortfolio() async {
    _estates = await widget.repository.loadMyLandlordEstates();
    _estate = _estates.where((estate) => estate.id == _estate?.id).firstOrNull ?? (_estates.isEmpty ? null : _estates.first);
    await _loadProperties();
    if (_estates.isEmpty) {
      _maintenance = const [];
      _maintenanceError = null;
    } else {
      try {
        _maintenance = await widget.repository.loadMyLandlordPropertyMaintenance();
        _maintenanceError = null;
      } catch (error) {
        _maintenance = const [];
        _maintenanceError = _message(error);
      }
    }
  }

  Future<void> _loadProperties() async {
    final estate = _estate;
    _portfolio = estate == null ? const [] : await widget.repository.loadLandlordPortfolio(estate.id);
    if (estate == null) {
      _rentSummary = const [];
      _rentSchedule = const [];
      return;
    }
    try {
      _rentSummary = await widget.repository.loadLandlordRentSummary(estate.id);
    } catch (_) {
      _rentSummary = const [];
    }
    try {
      _rentSchedule = await widget.repository.loadRentSchedule(estate.id);
    } catch (_) {
      _rentSchedule = const [];
    }
  }

  Future<void> _refresh() async {
    setState(() { _busy = true; _error = null; });
    try { await _loadPortfolio(); } catch (error) { _error = _message(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() { _account = null; _estates = const []; _portfolio = const []; _maintenance = const []; _estate = null; _maintenanceError = null; });
  }

  String _message(Object error) => error is EstateApiException ? error.message : 'The estate service could not load this portfolio.';

  LandlordServiceContext _landlordServiceContext() => LandlordServiceContext(
        repository: widget.repository,
        estateId: _estate?.id ?? '',
        estateName: _estate?.name ?? 'Your estate',
      );

  List<DashboardService> _landlordServiceTiles() {
    final serviceContext = _landlordServiceContext();
    return landlordServices().map((service) {
      return DashboardService(
        icon: service.icon,
        label: service.label,
        onTap: () {
          final page = service.id == 'more'
              ? LandlordMoreServicesPage(serviceContext: serviceContext)
              : LandlordServicePage(service: service, serviceContext: serviceContext);
          openLandlordPage(context, page);
        },
      );
    }).toList(growable: false);
  }

  void _openLandlordService(String id) {
    final serviceContext = _landlordServiceContext();
    final service = landlordServices().firstWhere((item) => item.id == id);
    final page = service.id == 'more'
        ? LandlordMoreServicesPage(serviceContext: serviceContext)
        : LandlordServicePage(service: service, serviceContext: serviceContext);
    openLandlordPage(context, page);
  }

  Widget _referenceHeader() {
    final entitlement = _rentSummary.firstOrNull;
    final occupied = _portfolio.where((item) => item.occupancyCount > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGreeting(
          period: _greetingPeriod(),
          title: 'Welcome, ${_account?.displayName.split(' ').first ?? 'Landlord'}',
          subtitle: '${_estate?.name ?? 'Your estate'} · ${_portfolio.length} verified propert${_portfolio.length == 1 ? 'y' : 'ies'}',
          trailing: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded,
                  color: DashboardTokens.text, size: 20),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _signOut(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'out', child: Text('Sign out')),
              ],
              child: const Icon(Icons.more_vert, color: DashboardTokens.text),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashboardHero(
          label: 'RENT YOU SHOULD RECEIVE',
          amount: entitlement == null
              ? 'NGN —'
              : 'NGN ${_formatMoney(entitlement.entitlement)}',
          caption: entitlement == null
              ? 'No rent schedule has been generated yet'
              : 'Collected NGN ${_formatMoney(entitlement.collected)} · '
                  'Outstanding NGN ${_formatMoney(entitlement.outstanding)}',
          badge: 'DEMO MODE · NO REAL MONEY',
          cardIcon: Icons.home_outlined,
          actions: [
            DashboardHeroAction(
              icon: Icons.calendar_month_outlined,
              label: 'Rent schedule',
              onTap: () => _openLandlordService('rent-schedule'),
            ),
            DashboardHeroAction(
              icon: Icons.receipt_long_outlined,
              label: 'Payments received',
              onTap: () => _openLandlordService('receipts'),
            ),
            DashboardHeroAction(
              icon: Icons.description_outlined,
              label: 'Statements',
              onTap: () => _openLandlordService('statements'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        DashboardQuickServices(
          services: _landlordServiceTiles(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _MetricCard(label: 'Verified properties', value: '${_portfolio.length}', icon: Icons.home_work_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(label: 'With current occupants', value: '$occupied', icon: Icons.people_outline_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(label: 'Rent installments', value: '${_rentSchedule.length}', icon: Icons.calendar_month_outlined)),
          ],
        ),
      ],
    );
  }

  String _greetingPeriod() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatMoney(String value) {
    final amount = double.tryParse(value) ?? 0;
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return _signInView();
    return Theme(
      data: DashboardTokens.darkShell,
      child: Scaffold(
        backgroundColor: DashboardTokens.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _referenceHeader(),
                if (_error != null) _ErrorCard(message: _error!),
                const SizedBox(height: 8),
                if (_estates.isEmpty)
                  const _EmptyCard(
                    title: 'No verified properties yet',
                    detail: 'Your estate will appear here after your ownership interest is recorded and approved.',
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<ManagedEstateChoice>(
                        initialValue: _estate,
                        decoration: const InputDecoration(
                          labelText: 'Estate',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                        items: _estates
                            .map((item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.name),
                                ))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (estate) async {
                                setState(() {
                                  _estate = estate;
                                  _busy = true;
                                  _error = null;
                                });
                                try {
                                  await _loadProperties();
                                } catch (error) {
                                  _error = _message(error);
                                }
                                if (mounted) setState(() => _busy = false);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  KeyedSubtree(
                    key: _propertiesKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DashboardSectionTitle(title: 'Your properties'),
                        const SizedBox(height: 6),
                        const Text(
                          'Properties are listed here after the estate verifies your ownership.',
                          style: TextStyle(
                            color: DashboardTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_portfolio.isEmpty)
                          const _EmptyCard(
                            title: 'No properties in this portfolio',
                            detail: 'Only active ownership records verified by the estate team are shown.',
                          )
                        else
                          ..._portfolio.map(
                            (record) => _PropertyCard(record: record),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: _maintenanceKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DashboardSectionTitle(title: 'Maintenance & repairs'),
                        const SizedBox(height: 6),
                        const Text(
                          'Resident requests for your verified properties. Only resident-visible updates are shown.',
                          style: TextStyle(
                            color: DashboardTokens.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_maintenanceError != null)
                          _ErrorCard(
                            message: 'Maintenance requests could not be loaded: $_maintenanceError',
                          )
                        else if (_maintenance.isEmpty)
                          const _EmptyCard(
                            title: 'No maintenance requests',
                            detail: 'There are no resident maintenance requests linked to your verified properties.',
                          )
                        else
                          ..._maintenance.map(
                            (request) => _LandlordMaintenanceCard(record: request),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Rent entitlement and installments are generated from approved tenancies by estate management. '
                  'Payments, arrears and collection totals update after finance verifies the ledger.',
                  style: TextStyle(
                    color: DashboardTokens.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInView() => Scaffold(body: Stack(fit: StackFit.expand, children: [
    Image.asset('assets/images/onboarding_background.jpg', fit: BoxFit.cover),
    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x85111F18), Color(0xD509140F)]))),
    SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Card(color: Colors.white.withValues(alpha: .97), child: Padding(padding: const EdgeInsets.all(28), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.real_estate_agent_outlined, size: 36, color: EstateColors.forest),
      const SizedBox(height: 14),
      const Text('Landlord sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: EstateColors.ink, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      const Text('Use the account associated with your verified ownership.', textAlign: TextAlign.center, style: TextStyle(color: EstateColors.muted)),
      const SizedBox(height: 20),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address.' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)), validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null),
      if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: EstateColors.red))],
      const SizedBox(height: 18),
      FilledButton(onPressed: _busy ? null : _signIn, child: Text(_busy ? 'Signing in…' : 'Sign in')),
    ])))))))),
  ]));
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.record});
  final LandlordPortfolioRecord record;
  @override
  Widget build(BuildContext context) {
    final tenancy = record.currentTenancy;
    final rent = tenancy?['rent'] as Map<String, dynamic>?;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    leading: const CircleAvatar(backgroundColor: DashboardTokens.surfaceRaised, child: Icon(Icons.home_work_outlined, color: DashboardTokens.greenLeaf)),
    title: Text('${record.propertyCode} · ${record.propertyType}', style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text([
      if (record.unitNumber != null) record.unitNumber!,
      if (record.address != null) record.address!,
      '${record.ownershipShare}% ownership',
      record.occupancyCount == 0 ? 'No current occupants recorded' : '${record.occupancyCount} current occupant${record.occupancyCount == 1 ? '' : 's'}',
      if (tenancy != null) 'Tenant: ${tenancy['tenantDisplayName'] ?? 'Current tenant'}',
      if (rent != null) 'Agreed rent: ${rent['currency']} ${rent['amount']} / ${rent['frequency']}',
    ].join(' · '))),
    trailing: const Icon(Icons.chevron_right_rounded, color: EstateColors.muted),
    ));
  }
}

class _LandlordMaintenanceCard extends StatelessWidget {
  const _LandlordMaintenanceCard({required this.record});
  final LandlordMaintenanceRecord record;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.handyman_outlined, color: DashboardTokens.greenLeaf),
            const SizedBox(width: 10),
            Expanded(child: Text(record.reference, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(record.status.replaceAll('_', ' '), style: const TextStyle(color: DashboardTokens.greenLeaf, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(record.propertyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${record.category} · ${record.priority} · ${_dateLabel(record.submittedAt)}', style: const TextStyle(color: EstateColors.muted, fontSize: 12)),
          const SizedBox(height: 9),
          Text(record.description, style: const TextStyle(height: 1.45)),
          if (record.residentVisibleUpdates.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Updates for the resident', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 5),
            ...record.residentVisibleUpdates.map((update) => Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('${_dateLabel(update.occurredAt)} · ${update.body}', style: const TextStyle(color: EstateColors.muted, height: 1.4, fontSize: 12)),
            )),
          ],
        ],
      ),
    ),
  );

  static String _dateLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(children: [Icon(icon, color: DashboardTokens.greenLeaf), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), Text(label, style: const TextStyle(fontSize: 11, color: DashboardTokens.muted))]))])));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.apartment_outlined, color: DashboardTokens.greenLeaf, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: DashboardTokens.muted, height: 1.45))])));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFFFFF0EE), child: Padding(padding: const EdgeInsets.all(14), child: Text(message, style: const TextStyle(color: EstateColors.red))));
}



