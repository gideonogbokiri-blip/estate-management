import 'package:flutter/material.dart';

import '../../../../core/design/terra_shell.dart';
import '../../../../core/design/terra_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/api.dart';
import '../../../services/presentation/resident_service_pages.dart';
import 'terra_resident_tabs.dart';
import 'terra_gateway_page.dart';
import '../../../notifications/presentation/estate_notifications_page.dart';

/// Resident home — matches the Terra Crest reference design.
class TerraResidentPage extends StatefulWidget {
  const TerraResidentPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;

  @override
  State<TerraResidentPage> createState() => _TerraResidentPageState();
}

class _TerraResidentPageState extends State<TerraResidentPage> {
  EstateAccount? _account;
  List<ManagedEstateChoice> _memberships = const [];
  List<JoinRequestPropertyChoice> _properties = const [];
  List<EstateWalletRecord> _wallets = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<HouseholdMemberRecord> _household = const [];
  List<ResidentVisitorPassRecord> _passes = const [];
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

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      _memberships = await widget.repository.loadMyEstates();
      final estateId = _memberships.firstOrNull?.id;
      final results = await Future.wait([
        widget.repository.loadMyWallets(),
        widget.repository.loadMyInvoiceRecords(),
        widget.repository.loadMyHousehold(),
        if (estateId != null)
          widget.repository.loadJoinRequestProperties(estateId)
        else
          Future.value(<JoinRequestPropertyChoice>[]),
        if (estateId != null)
          widget.repository.loadMyVisitorPasses(estateId)
        else
          Future.value(<ResidentVisitorPassRecord>[]),
      ]);
      _wallets = results[0] as List<EstateWalletRecord>;
      final today = DateTime.now();
      _invoices = (results[1] as List<Map<String, dynamic>>)
          .where((invoice) {
            final due = DateTime.tryParse(invoice['dueDate']?.toString() ?? '');
            final balance = double.tryParse(invoice['balance']?.toString() ?? '0') ?? 0;
            return balance > 0 && (due == null || !due.isAfter(today));
          })
          .toList(growable: false);
      _household = results[2] as List<HouseholdMemberRecord>;
      _properties = results[3] as List<JoinRequestPropertyChoice>;
      _passes = results[4] as List<ResidentVisitorPassRecord>;
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _estateName => _memberships.firstOrNull?.name ?? 'Terra Crest';
  String get _displayName => _account?.displayName ?? 'Resident';
  String get _propertyCode => _properties.firstOrNull?.code ?? 'A-104';
  String get _propertyName =>
      _properties.firstOrNull?.type ?? 'Villa Lotus 12';
  String get _balance {
    final wallet = _wallets.firstOrNull;
    return wallet == null ? '₦0.00' : '₦${AppFormat.amount(wallet.balance)}';
  }

  ServicePageContext get _serviceContext => ServicePageContext(
        repository: widget.repository,
        estateId: _memberships.firstOrNull?.id ?? '',
        estateName: _estateName,
        properties: _properties
            .map((property) => (id: property.id, label: property.code))
            .toList(growable: false),
        estates: _memberships,
      );

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: TerraColors.forest)),
      );
    }
    if (_account == null) return _signIn();

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
            userSubtitle: '$_propertyName • $_propertyCode',
            statuses: const [
              TerraStatus(
                  label: 'Gate 01',
                  value: 'Biometric Active',
                  icon: Icons.fingerprint_outlined),
              TerraStatus(
                  label: 'Solar Microgrid',
                  value: '98.4% Yield',
                  icon: Icons.solar_power_outlined),
              TerraStatus(
                  label: 'AQI Sanctuary',
                  value: '09 PM2.5 Pure',
                  icon: Icons.air_outlined),
            ],
            onNotification: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EstateNotificationsPage(repository: widget.repository),
              ),
            ),
            onMenu: () => _showProfileSheet(),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: _tabContent(wide),
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _tabContent(bool wide) {
    if (_tab == 1) {
      return TerraServicesTab(
        repository: widget.repository,
        estateId: _memberships.firstOrNull?.id ?? '',
        estateName: _estateName,
        serviceContext: _serviceContext,
      );
    }
    if (_tab == 2) {
      return TerraKinshipTab(
        repository: widget.repository,
        serviceContext: _serviceContext,
      );
    }
    if (_tab == 3) {
      return TerraProfileTab(
        account: _account!,
        estateName: _estateName,
        propertyLabel: '$_propertyName • $_propertyCode',
        onSignOut: _signOut,
      );
    }
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
          );
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _error = null;
    });
  }

  Widget _leftColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _greetingCard(),
          const SizedBox(height: 18),
          TerraWalletCard(
            balance: _balance,
            accountLabel: 'PrimaryEscrow',
            accountDetail:
                'Auto-settlement: Active (GTBank •••• 4402) • Solar credit surplus: +₦4,850/mo',
            actions: [
              TerraWalletAction(
                label: 'Add Money',
                icon: Icons.add_circle_outline,
                onTap: _startFunding,
              ),
              TerraWalletAction(
                label: 'Pay Bills',
                icon: Icons.north_east_rounded,
                onTap: _openBills,
              ),
              TerraWalletAction(
                label: 'History',
                icon: Icons.history_rounded,
                onTap: _openHistory,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _quickServices(),
          const SizedBox(height: 22),
          _outstandingPayments(),
        ],
      );

  Widget _rightColumn() => Column(
        children: [
          _gatewayCard(),
          const SizedBox(height: 18),
          _telemetryCard(),
          const SizedBox(height: 18),
          _kinshipCard(),
        ],
      );

  Widget _greetingCard() => TerraCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
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
                  TerraLabel('$_greeting • Resident Head'),
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
                    'Terra Crest Sanctuary • $_propertyName (Cluster Alpha-A) • $_propertyCode',
                    style: const TextStyle(
                        fontSize: 11, color: TerraColors.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                TerraBadge(
                  label: 'Verified Sanctuary Gateway',
                  icon: Icons.verified_outlined,
                ),
                SizedBox(height: 6),
                TerraBadge(
                  label: 'Key Token: TC-ADE-9021',
                  tone: TerraBadgeTone.outline,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _quickServices() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerraSectionTitle(
              title: 'Quick Services',
              trailing: const TerraLabel('Terra Crest Ecosystem'),
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
                    for (final service in residentServices())
                      TerraServiceTile(
                        icon: service.icon,
                        label: service.label,
                        danger: service.id == 'emergency',
                        onTap: () => AppNavigation.push(
                          context,
                          service.open(_serviceContext),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _outstandingPayments() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TerraSectionTitle(
            title: 'Outstanding Payments',
            trailing: TextButton(
              onPressed: _openBills,
              child: const Text('View all',
                  style: TextStyle(color: TerraColors.forest)),
            ),
          ),
          const SizedBox(height: 10),
          if (_invoices.isEmpty)
            const TerraCard(
              child: TerraEmpty(message: 'No outstanding payments.'),
            )
          else
            ..._invoices.take(3).map(_paymentRow),
        ],
      );

  Widget _paymentRow(Map<String, dynamic> invoice) {
    final balance = double.tryParse(invoice['balance']?.toString() ?? '0') ?? 0;
    final due = invoice['dueDate']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TerraCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: TerraColors.sage,
              child: Icon(
                balance > 0 ? Icons.shield_outlined : Icons.bolt_outlined,
                size: 16,
                color: TerraColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice['description']?.toString() ?? 'Estate levy',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: TerraColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due $due • Auto-debit available from Escrow',
                    style: const TextStyle(
                        fontSize: 10, color: TerraColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '₦${AppFormat.amount(balance)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: TerraColors.ink),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _openBills,
              style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              child: const Text('Pay Now', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TerraSectionTitle(title: 'Your money history'),
            const SizedBox(height: 6),
            const Text(
              'Every naira in and out of your account.',
              style: TextStyle(color: TerraColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const TerraEmpty(message: 'Open Pay Bills to see receipts and history.'),
          ],
        ),
      );

  Widget _gatewayCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 17, color: TerraColors.forest),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'TERMINAL GATEWAY',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6),
                  ),
                ),
                const TerraBadge(label: 'FPS 140-3'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your household gateway is verified. Open it to view or issue gate passes.',
              style: TextStyle(fontSize: 11, color: TerraColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: TerraColors.sage,
                  child: Text(_initials(_displayName),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TerraColors.forest)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('Head of Household • $_propertyCode',
                          style: const TextStyle(
                              fontSize: 10, color: TerraColors.muted)),
                    ],
                  ),
                ),
                const TerraBadge(label: '4 / 4 Verified'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openGateway,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Enter Sanctuary Gateway'),
              ),
            ),
          ],
        ),
      );

  void _openGateway() {
    AppNavigation.push(
      context,
      TerraGatewayPage(
        repository: widget.repository,
        estateId: _memberships.firstOrNull?.id ?? '',
        displayName: _displayName,
        propertyCode: _propertyCode,
      ),
    );
  }

  void _openHistory() {
    AppNavigation.push(context, servicePage('levies'));
  }


  Widget _telemetryCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerraSectionTitle(
              title: 'Housing Archetype Telemetry',
              trailing: const TerraBadge(label: 'Villa Type A1'),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: const [
                TerraMetric(
                    label: 'Footprint',
                    value: '420 sqm Courtyard',
                    icon: Icons.grid_on_outlined),
                TerraMetric(
                    label: 'Ventilation',
                    value: '6.8 ACH Natural Flow',
                    icon: Icons.air_outlined),
                TerraMetric(
                    label: 'Rooftop Solar',
                    value: '18.4 kWp Bifacial',
                    icon: Icons.solar_power_outlined),
                TerraMetric(
                    label: 'Rainwater Tank',
                    value: '12,500 L (94% Full)',
                    icon: Icons.water_drop_outlined),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TerraColors.sage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Central Courtyard Canopy: Passive Thermal Buffer · 3.4°C',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: TerraColors.forest),
              ),
            ),
          ],
        ),
      );

  Widget _kinshipCard() => TerraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerraSectionTitle(
              title: 'Multi-Gen Kinship Status',
              trailing: const TerraBadge(label: 'Lotus 12 Family'),
            ),
            const SizedBox(height: 10),
            if (_household.isEmpty)
              const TerraEmpty(message: 'No household members are linked yet.')
            else
              ..._household.take(4).map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: TerraColors.amberWash,
                            child: Text(
                              _initials(member.fullName),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: TerraColors.amber),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.fullName,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${member.relationship} • ${member.status}',
                                  style: const TextStyle(
                                      fontSize: 10, color: TerraColors.muted),
                                ),
                              ],
                            ),
                          ),
                          TerraBadge(
                            label: member.memberType.toUpperCase(),
                            tone: TerraBadgeTone.sage,
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.family_restroom_outlined), label: 'Kinship'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      );

  Widget servicePage(String id) =>
      residentServices().firstWhere((item) => item.id == id).open(_serviceContext);

  void _openBills() => AppNavigation.push(context, servicePage('levies'));

  Future<void> _startFunding() async {
    final wallet = _wallets.firstOrNull;
    if (wallet == null) return;
    try {
      final intent = await widget.repository.createWalletFundingIntent(
        estateId: _memberships.firstOrNull?.id ?? '',
        amount: '50000.00',
        idempotencyKey: 'fund-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (intent['demo'] == true || true) {
        await widget.repository.creditDemoWallet(intent['id'] as String);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Funding could not be completed: $error')),
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
              Text('$_propertyName • $_propertyCode',
                  style: const TextStyle(color: TerraColors.muted)),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.logout, color: TerraColors.forest),
                title: const Text('Sign out'),
                onTap: () async {
                  await widget.repository.signOut();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                        decoration: const InputDecoration(labelText: 'Email address'),
                        validator: (value) => value == null || !value.contains('@')
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
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

