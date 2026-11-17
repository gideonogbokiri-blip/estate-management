import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../admin/data/estate_admin_repository.dart';
import '../data/landlord_repository.dart';

class LandlordShell extends StatefulWidget {
  const LandlordShell({super.key, required this.repository});
  final LandlordRepository repository;

  @override
  State<LandlordShell> createState() => _LandlordShellState();
}

class _LandlordShellState extends State<LandlordShell> {
  late Future<List<LandlordPortfolioItem>> _properties;
  late Future<List<EstateInvoiceSummary>> _rentInvoices;
  late Future<List<EstateInvoiceSummary>> _propertyChargeInvoices;
  late Future<List<LandlordPropertyDocument>> _propertyDocuments;
  late Future<List<LandlordMaintenanceRequest>> _maintenanceRequests;
  bool _showDocuments = false;
  bool _showMaintenance = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _properties = widget.repository.loadMyProperties();
    _rentInvoices = widget.repository.loadMyRentInvoices();
    _propertyChargeInvoices = widget.repository.loadMyPropertyChargeInvoices();
    _propertyDocuments = widget.repository.loadMyPropertyDocuments();
    _maintenanceRequests = widget.repository.loadMyPropertyMaintenance();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<LandlordPortfolioItem>>(
        future: _properties,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _LoadFailure(onRetry: _reload);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final properties = snapshot.data!;
          final occupied = properties
              .where((p) => p.occupancyStatus == 'rented')
              .length;
          final pages = [
            _Overview(properties: properties, occupied: occupied),
            _Properties(
              properties: properties,
              onOpenDocuments: () => setState(() => _showDocuments = true),
              onOpenMaintenance: () => setState(() => _showMaintenance = true),
            ),
            _Tenancies(properties: properties),
            _RentInvoices(
              future: _rentInvoices,
              onRetry: () => setState(() {
                _rentInvoices = widget.repository.loadMyRentInvoices();
              }),
            ),
            _PropertyChargeInvoices(
              future: _propertyChargeInvoices,
              onRetry: () => setState(() {
                _propertyChargeInvoices = widget.repository
                    .loadMyPropertyChargeInvoices();
              }),
            ),
          ];
          return LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 900;
              final content = _showMaintenance
                  ? _MaintenanceRequests(
                      future: _maintenanceRequests,
                      onBack: () => setState(() => _showMaintenance = false),
                      onRetry: () => setState(() {
                        _maintenanceRequests = widget.repository
                            .loadMyPropertyMaintenance();
                      }),
                    )
                  : _showDocuments
                  ? _Documents(
                      future: _propertyDocuments,
                      onBack: () => setState(() => _showDocuments = false),
                      onRetry: () => setState(() {
                        _propertyDocuments = widget.repository
                            .loadMyPropertyDocuments();
                      }),
                    )
                  : pages[_tab];
              return Row(
                children: [
                  if (wide) _Rail(selected: _tab, onSelect: _select),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(wide: wide),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1080),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: SingleChildScrollView(
                                  key: ValueKey(_tab),
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 28 : 18,
                                    24,
                                    wide ? 28 : 18,
                                    100,
                                  ),
                                  child: content,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
    bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
        ? NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.apartment_rounded),
                label: 'Properties',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                label: 'Tenants',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Rent',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Charges',
              ),
            ],
          )
        : null,
  );

  void _select(int index) => setState(() {
    _tab = index;
    _showDocuments = false;
    _showMaintenance = false;
  });
  void _reload() => setState(() {
    _properties = widget.repository.loadMyProperties();
  });
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: EstateColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F2ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.domain_rounded, color: EstateColors.forest),
        ),
        const SizedBox(width: 11),
        const Text(
          'Estate',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 9),
        const Text(
          'LANDLORD',
          style: TextStyle(
            color: EstateColors.muted,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.location_on_outlined,
          size: 17,
          color: EstateColors.muted,
        ),
        if (wide) ...[
          const SizedBox(width: 5),
          const Text(
            'Oakwood Estate',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 15),
        ] else
          const SizedBox(width: 11),
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFEAF2ED),
          child: Text(
            'AO',
            style: TextStyle(
              color: EstateColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Rail extends StatelessWidget {
  const _Rail({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: selected,
    onDestinationSelected: onSelect,
    labelType: NavigationRailLabelType.all,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.grid_view_rounded),
        label: Text('Overview'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.apartment_rounded),
        label: Text('Properties'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_alt_outlined),
        label: Text('Tenancies'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: Text('Rent'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        label: Text('Charges'),
      ),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.properties, required this.occupied});
  final List<LandlordPortfolioItem> properties;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final rented = properties
        .where((p) => p.occupancyStatus == 'rented')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          eyebrow: 'LANDLORD PORTAL',
          title: 'Welcome back',
          subtitle: 'A clear view of your properties and current tenancies.',
        ),
        const SizedBox(height: 22),
        _WelcomeCard(properties: properties.length, occupied: occupied),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final count = box.maxWidth > 700 ? 3 : 1;
            final w = (box.maxWidth - 16 * (count - 1)) / count;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _Metric(
                  width: w,
                  label: 'My properties',
                  value: '${properties.length}',
                  icon: Icons.apartment_outlined,
                  color: EstateColors.forest,
                ),
                _Metric(
                  width: w,
                  label: 'Currently rented',
                  value: '$occupied',
                  icon: Icons.key_outlined,
                  color: const Color(0xFF47759A),
                ),
                _Metric(
                  width: w,
                  label: 'Not currently rented',
                  value: '${properties.length - occupied}',
                  icon: Icons.home_work_outlined,
                  color: EstateColors.amber,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Property activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${properties.length} properties',
              style: const TextStyle(color: EstateColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rented.isEmpty)
          const _EmptyCard(message: 'No current tenancy details are available.')
        else
          ...rented.take(4).map((p) => _PropertyCard(property: p)),
        const SizedBox(height: 12),
        const _InfoNote(
          icon: Icons.info_outline,
          text: 'Contract rent is shown from tenancy terms. This preview does not show rent paid, arrears or collection totals.',
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.properties, required this.occupied});
  final int properties;
  final int occupied;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [
          EstateColors.forestDeep,
          EstateColors.forest,
          EstateColors.leaf,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 520;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR PORTFOLIO',
              style: TextStyle(
                color: Color(0xFFC8E6D4),
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '$properties ${properties == 1 ? 'property' : 'properties'} in Oakwood Estate',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$occupied currently rented  ·  ${properties - occupied} not currently rented',
              style: const TextStyle(color: Color(0xFFE0EFE6), fontSize: 13),
            ),
          ],
        );
        return compact
            ? copy
            : Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.apartment_rounded,
                    size: 74,
                    color: Color(0x44FFFFFF),
                  ),
                ],
              );
      },
    ),
  );
}

class _Properties extends StatelessWidget {
  const _Properties({
    required this.properties,
    required this.onOpenDocuments,
    required this.onOpenMaintenance,
  });
  final List<LandlordPortfolioItem> properties;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenMaintenance;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageHeading(
        eyebrow: 'PORTFOLIO',
        title: 'My properties',
        subtitle:
            'Properties linked to your verified ownership in this estate.',
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE9F2ED),
            child: Icon(Icons.handyman_outlined, color: EstateColors.forest),
          ),
          title: const Text(
            'Maintenance & repairs',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Track work reported for your properties'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenMaintenance,
        ),
      ),
      const SizedBox(height: 12),
      _InfoNote(
        icon: Icons.verified_user_outlined,
        text:
            '${properties.length} verified ${properties.length == 1 ? 'property' : 'properties'} in Oakwood Estate',
      ),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE9F2ED),
            child: Icon(Icons.folder_outlined, color: EstateColors.forest),
          ),
          title: const Text(
            'Property documents',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Agreements, ownership and inspection files'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenDocuments,
        ),
      ),
      const SizedBox(height: 12),
      if (properties.isEmpty)
        const _EmptyCard(
          message: 'No verified properties are linked to this account yet.',
        )
      else
        ...properties.map((p) => _PropertyCard(property: p)),
    ],
  );
}

class _MaintenanceRequests extends StatelessWidget {
  const _MaintenanceRequests({
    required this.future,
    required this.onBack,
    required this.onRetry,
  });
  final Future<List<LandlordMaintenanceRequest>> future;
  final VoidCallback onBack, onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('My properties'),
      ),
      const _PageHeading(
        eyebrow: 'PROPERTY CARE',
        title: 'Maintenance & repairs',
        subtitle: 'Follow maintenance work linked to your verified properties.',
      ),
      const SizedBox(height: 16),
      const _InfoNote(
        icon: Icons.lock_outline,
        text: 'This view includes resident visible updates only. Private staff notes and file references are not shown.',
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<LandlordMaintenanceRequest>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _LoadFailure(onRetry: onRetry);
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const _EmptyCard(
              message: 'There are no maintenance requests for your properties.',
            );
          }
          return Column(
            children: requests
                .map((request) => _LandlordMaintenanceCard(request: request))
                .toList(),
          );
        },
      ),
    ],
  );
}

class _LandlordMaintenanceCard extends StatelessWidget {
  const _LandlordMaintenanceCard({required this.request});
  final LandlordMaintenanceRequest request;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, color: EstateColors.forest),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.reference,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(
                label: request.status.replaceAll('_', ' '),
                active:
                    request.status == 'resolved' || request.status == 'closed',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.propertyLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '${_documentCategory(request.category)} · ${request.priority} priority',
            style: const TextStyle(color: EstateColors.muted),
          ),
          const SizedBox(height: 9),
          Text(request.description),
          const SizedBox(height: 9),
          Text(
            'Reported ${_date(request.submittedAt.toIso8601String())}',
            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          if (request.updates.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'LATEST UPDATE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
                color: EstateColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(request.updates.last.body),
            const SizedBox(height: 5),
            Text(
              _date(request.updates.last.occurredAt.toIso8601String()),
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Tenancies extends StatelessWidget {
  const _Tenancies({required this.properties});
  final List<LandlordPortfolioItem> properties;

  @override
  Widget build(BuildContext context) {
    final rented = properties
        .where((p) => p.tenantDisplayName != null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          eyebrow: 'TENANCIES',
          title: 'Current tenants',
          subtitle: 'Tenant and rent terms for properties in your verified portfolio.',
        ),
        const SizedBox(height: 20),
        const _InfoNote(
          icon: Icons.lock_outline,
          text: 'Only the tenant name and current tenancy terms are available in this preview.',
        ),
        const SizedBox(height: 14),
        if (rented.isEmpty)
          const _EmptyCard(
            message:
                'No current tenancy details are available for your properties.',
          )
        else
          ...rented.map((p) => _TenantCard(property: p)),
      ],
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});
  final LandlordPortfolioItem property;

  @override
  Widget build(BuildContext context) {
    final rented = property.occupancyStatus == 'rented';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2ED),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: EstateColors.forest,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.propertyLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                          property.propertyType,
                          property.propertyAddress,
                          property.estateLocation,
                        ]
                        .whereType<String>()
                        .where((x) => x.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (rented && property.tenantDisplayName != null) ...[
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: EstateColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            property.tenantDisplayName!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(label: rented ? 'Rented' : 'Available', active: rented),
          ],
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.property});
  final LandlordPortfolioItem property;

  @override
  Widget build(BuildContext context) {
    final rent = property.rentAmount == null
        ? null
        : _formatMoney(property.rentAmount!, property.currency ?? 'NGN');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE9F2ED),
                  child: Icon(Icons.person_outline, color: EstateColors.forest),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.tenantDisplayName ?? 'Tenant',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        property.propertyLabel,
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (property.tenancyStatus != null)
                  _StatusPill(
                    label: _title(property.tenancyStatus!),
                    active: property.tenancyStatus == 'active',
                  ),
              ],
            ),
            const Divider(height: 26),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _Detail(
                  label: 'CONTRACT RENT',
                  value: rent == null
                      ? 'Not provided'
                      : '$rent / ${property.rentFrequency ?? 'period'}',
                ),
                _Detail(
                  label: 'START DATE',
                  value: _date(property.tenancyStartDate),
                ),
                _Detail(
                  label: 'END DATE',
                  value: _date(property.tenancyEndDate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Documents extends StatefulWidget {
  const _Documents({
    required this.future,
    required this.onBack,
    required this.onRetry,
  });
  final Future<List<LandlordPropertyDocument>> future;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  State<_Documents> createState() => _DocumentsState();
}

class _DocumentsState extends State<_Documents> {
  final _search = TextEditingController();
  String _category = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<LandlordPropertyDocument>>(
    future: widget.future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            const _PageHeading(
              eyebrow: 'PROPERTY LIBRARY',
              title: 'Documents',
              subtitle: 'Files associated with your verified properties.',
            ),
            const SizedBox(height: 18),
            _LoadFailure(onRetry: widget.onRetry),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.only(top: 90),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final documents = snapshot.requireData;
      final visible = documents.where((document) {
        final matchesCategory =
            _category == 'all' || document.category == _category;
        final query = _search.text.trim().toLowerCase();
        final matchesQuery =
            query.isEmpty ||
            '${document.name} ${document.propertyLabel} ${_documentCategory(document.category)}'
                .toLowerCase()
                .contains(query);
        return matchesCategory && matchesQuery;
      }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final categories = documents.map((item) => item.category).toSet().toList()
        ..sort();
      final properties = documents
          .map((item) => item.propertyLabel)
          .toSet()
          .length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _backButton(),
          const _PageHeading(
            eyebrow: 'PROPERTY LIBRARY',
            title: 'Documents',
            subtitle: 'Files associated with your verified properties.',
          ),
          const SizedBox(height: 17),
          const _InfoNote(
            icon: Icons.lock_outline,
            text: 'Documents stay in private storage. The live viewer requires a fresh permission check and a short-lived access grant.',
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 700 ? 2 : 1;
              final width = (box.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    label: 'Property files',
                    value: '${documents.length}',
                    icon: Icons.folder_outlined,
                    color: EstateColors.forest,
                  ),
                  _Metric(
                    width: width,
                    label: 'Properties represented',
                    value: '$properties',
                    icon: Icons.apartment_outlined,
                    color: const Color(0xFF47759A),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search document or property',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Document category',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All documents'),
              ),
              ...categories.map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(_documentCategory(category)),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'all'),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Property files',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${visible.length} files',
                style: const TextStyle(color: EstateColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (visible.isEmpty)
            const _EmptyCard(
              message: 'No property documents match this search.',
            )
          else
            ...visible.map(
              (document) => _DocumentCard(
                document: document,
                onTap: () => _showDetails(document),
              ),
            ),
          const SizedBox(height: 5),
          const Text(
            'Preview document entries are illustrative. File access is not available in this workspace.',
            style: TextStyle(color: EstateColors.muted, fontSize: 11),
          ),
        ],
      );
    },
  );

  Widget _backButton() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: widget.onBack,
      icon: const Icon(Icons.arrow_back),
      label: const Text('My properties'),
    ),
  );

  void _showDetails(LandlordPropertyDocument document) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _Detail(label: 'PROPERTY', value: document.propertyLabel),
            const SizedBox(height: 11),
            _Detail(
              label: 'CATEGORY',
              value: _documentCategory(document.category),
            ),
            const SizedBox(height: 11),
            _Detail(
              label: 'FILE TYPE',
              value: _contentType(document.contentType),
            ),
            const SizedBox(height: 11),
            _Detail(
              label: 'UPDATED',
              value: _date(document.updatedAt.toIso8601String()),
            ),
            const SizedBox(height: 17),
            const _InfoNote(
              icon: Icons.verified_user_outlined,
              text: 'Opening files will recheck your current property access and use a short-lived private link.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Secure viewer unavailable in preview'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onTap});
  final LandlordPropertyDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          document.contentType == 'application/pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.image_outlined,
          color: EstateColors.forest,
        ),
      ),
      title: Text(
        document.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${document.propertyLabel} · ${_documentCategory(document.category)}\nUpdated ${_date(document.updatedAt.toIso8601String())}',
          style: const TextStyle(fontSize: 10, height: 1.5),
        ),
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

String _documentCategory(String value) => switch (value) {
  'ownership' => 'Ownership',
  'tenancy_agreement' => 'Tenancy agreement',
  'inspection' => 'Inspection',
  'maintenance' => 'Maintenance',
  'insurance' => 'Insurance',
  _ => 'Other',
};

String _contentType(String value) => switch (value) {
  'application/pdf' => 'PDF document',
  'image/jpeg' => 'JPEG image',
  'image/png' => 'PNG image',
  'image/webp' => 'WebP image',
  _ => 'File',
};

class _RentInvoices extends StatefulWidget {
  const _RentInvoices({required this.future, required this.onRetry});
  final Future<List<EstateInvoiceSummary>> future;
  final VoidCallback onRetry;

  @override
  State<_RentInvoices> createState() => _RentInvoicesState();
}

class _RentInvoicesState extends State<_RentInvoices> {
  String _filter = 'all';

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<EstateInvoiceSummary>>(
    future: widget.future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageHeading(
              eyebrow: 'RENT',
              title: 'Rent invoices',
              subtitle:
                  'Invoice and verified payment status for your properties.',
            ),
            const SizedBox(height: 18),
            _LoadFailure(onRetry: widget.onRetry),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.only(top: 90),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final invoices = snapshot.requireData
          .where((invoice) => !['draft', 'cancelled'].contains(invoice.status))
          .toList();
      final outstanding = invoices
          .where((invoice) => _hasBalance(invoice))
          .length;
      final paid = invoices.where(_isPaid).length;
      final overdue = invoices.where((invoice) => invoice.overdue).length;
      final currencies = invoices.map((invoice) => invoice.currency).toSet();
      final balances = invoices
          .where((invoice) => _hasBalance(invoice) && invoice.balance != null)
          .toList();
      final totalOutstanding = currencies.length == 1 && balances.isNotEmpty
          ? _formatMoney(
              balances
                  .fold<BigInt>(
                    BigInt.zero,
                    (sum, invoice) => sum + _decimalMinor(invoice.balance!),
                  )
                  .toString(),
              currencies.single,
            )
          : null;
      final filtered = invoices.where((invoice) {
        switch (_filter) {
          case 'outstanding':
            return _hasBalance(invoice);
          case 'paid':
            return _isPaid(invoice);
          case 'overdue':
            return invoice.overdue;
          default:
            return true;
        }
      }).toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeading(
            eyebrow: 'RENT',
            title: 'Rent invoices',
            subtitle:
                'Invoice and verified payment status for your properties.',
          ),
          const SizedBox(height: 18),
          const _InfoNote(
            icon: Icons.verified_outlined,
            text: 'Payment status comes from verified invoice allocations. This view does not initiate rent payments.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 700 ? 3 : 1;
              final width = (box.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    label: 'Rent invoices',
                    value: '${invoices.length}',
                    icon: Icons.receipt_long_outlined,
                    color: EstateColors.forest,
                  ),
                  _Metric(
                    width: width,
                    label: 'Outstanding',
                    value: '$outstanding',
                    icon: Icons.pending_actions_outlined,
                    color: EstateColors.amber,
                  ),
                  _Metric(
                    width: width,
                    label: 'Overdue',
                    value: '$overdue',
                    icon: Icons.event_busy_outlined,
                    color: EstateColors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          if (totalOutstanding != null)
            Card(
              color: const Color(0xFFE9F2ED),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: EstateColors.forest,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Outstanding on listed invoices',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Combined balance across ${balances.length} unpaid invoice records on this page.',
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        totalOutstanding,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: EstateColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (totalOutstanding != null) const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invoice history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All invoices')),
                  DropdownMenuItem(
                    value: 'outstanding',
                    child: Text('Outstanding'),
                  ),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const _EmptyCard(message: 'No rent invoices match this filter.')
          else
            ...filtered.map((invoice) => _RentInvoiceCard(invoice: invoice)),
          const SizedBox(height: 4),
          Text(
            '$paid paid · $outstanding outstanding · ${snapshot.requireData.length} records returned by the authorized invoice view',
            style: const TextStyle(color: EstateColors.muted, fontSize: 11),
          ),
        ],
      );
    },
  );
}

class _RentInvoiceCard extends StatelessWidget {
  const _RentInvoiceCard({required this.invoice});
  final EstateInvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final paid = _isPaid(invoice);
    final badgeColor = invoice.disputed
        ? EstateColors.red
        : invoice.overdue
        ? EstateColors.red
        : paid
        ? EstateColors.forest
        : const Color(0xFF476B91);
    final badge = invoice.disputed
        ? 'Disputed'
        : invoice.overdue
        ? 'Overdue'
        : paid
        ? 'Paid'
        : _title(invoice.status);
    final total = _formatMoney(invoice.total, invoice.currency);
    final balance = invoice.balance == null
        ? null
        : _formatMoney(invoice.balance!, invoice.currency);
    final allocated = invoice.allocated == null
        ? null
        : _formatMoney(invoice.allocated!, invoice.currency);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.category,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          invoice.invoiceNumber,
                          if (invoice.propertyCode != null)
                            invoice.propertyCode!,
                          if (invoice.payerDisplayName != null)
                            invoice.payerDisplayName!,
                        ].join(' · '),
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 25,
              runSpacing: 10,
              children: [
                _Detail(label: 'INVOICE TOTAL', value: total),
                if (allocated != null)
                  _Detail(label: 'VERIFIED PAID', value: allocated),
                if (balance != null && _hasBalance(invoice))
                  _Detail(label: 'BALANCE', value: balance),
                _Detail(label: 'DUE DATE', value: _dateOnly(invoice.dueAt)),
              ],
            ),
            if (invoice.tenancyLabel != null) ...[
              const SizedBox(height: 10),
              Text(
                invoice.tenancyLabel!,
                style: const TextStyle(color: EstateColors.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertyChargeInvoices extends StatefulWidget {
  const _PropertyChargeInvoices({required this.future, required this.onRetry});
  final Future<List<EstateInvoiceSummary>> future;
  final VoidCallback onRetry;

  @override
  State<_PropertyChargeInvoices> createState() =>
      _PropertyChargeInvoicesState();
}

class _PropertyChargeInvoicesState extends State<_PropertyChargeInvoices> {
  String _filter = 'all';

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<EstateInvoiceSummary>>(
    future: widget.future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageHeading(
              eyebrow: 'PROPERTY CHARGES',
              title: 'Charges',
              subtitle:
                  'Property charge invoices linked to your landlord account.',
            ),
            const SizedBox(height: 18),
            _LoadFailure(onRetry: widget.onRetry),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.only(top: 90),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final invoices = snapshot.requireData
          .where((invoice) => !['draft', 'cancelled'].contains(invoice.status))
          .toList();
      final outstanding = invoices.where(_hasBalance).length;
      final paid = invoices.where(_isPaid).length;
      final overdue = invoices.where((invoice) => invoice.overdue).length;
      final visible = invoices.where((invoice) {
        switch (_filter) {
          case 'outstanding':
            return _hasBalance(invoice);
          case 'paid':
            return _isPaid(invoice);
          case 'overdue':
            return invoice.overdue;
          default:
            return true;
        }
      }).toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeading(
            eyebrow: 'PROPERTY CHARGES',
            title: 'Charges',
            subtitle:
                'Property charge invoices linked to your landlord account.',
          ),
          const SizedBox(height: 18),
          const _InfoNote(
            icon: Icons.verified_outlined,
            text: 'Only issued charge invoices in your authorized property scope appear here. Payment status comes from verified allocations.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 700 ? 3 : 1;
              final width = (box.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    label: 'Charge invoices',
                    value: '${invoices.length}',
                    icon: Icons.receipt_long_outlined,
                    color: EstateColors.forest,
                  ),
                  _Metric(
                    width: width,
                    label: 'Outstanding',
                    value: '$outstanding',
                    icon: Icons.pending_actions_outlined,
                    color: EstateColors.amber,
                  ),
                  _Metric(
                    width: width,
                    label: 'Overdue',
                    value: '$overdue',
                    icon: Icons.event_busy_outlined,
                    color: EstateColors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Charge history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All charges')),
                  DropdownMenuItem(
                    value: 'outstanding',
                    child: Text('Outstanding'),
                  ),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            const _EmptyCard(message: 'No property charges match this filter.')
          else
            ...visible.map((invoice) => _RentInvoiceCard(invoice: invoice)),
          const SizedBox(height: 4),
          Text(
            '$paid paid · $outstanding outstanding · ${snapshot.requireData.length} authorized invoice records',
            style: const TextStyle(color: EstateColors.muted, fontSize: 11),
          ),
        ],
      );
    },
  );
}

bool _isPaid(EstateInvoiceSummary invoice) =>
    invoice.status == 'paid' ||
    invoice.balance == '0' ||
    invoice.balance == '0.00';

bool _hasBalance(EstateInvoiceSummary invoice) => !_isPaid(invoice);

String _dateOnly(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
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
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: EstateColors.leaf,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        title,
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: EstateColors.ink,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(color: EstateColors.muted, fontSize: 13),
      ),
    ],
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF4EF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: EstateColors.forest),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: EstateColors.forestDeep,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(25),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: EstateColors.muted),
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? EstateColors.forest : EstateColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9F2ED) : EstateColors.amberWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
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
          fontSize: 9,
          letterSpacing: .8,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ],
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: EstateColors.muted,
        ),
        const SizedBox(height: 12),
        const Text('Could not load your properties'),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');
String _date(String? value) {
  if (value == null) return 'Not provided';
  final parts = value.split('-');
  if (parts.length != 3) return value;
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
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return value;
  return '${int.tryParse(parts[2]) ?? parts[2]} ${months[month - 1]} ${parts[0]}';
}

String _formatMoney(String amount, String currency) {
  final parts = amount.split('.');
  final whole = parts.first;
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$currency $grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

BigInt _decimalMinor(String amount) {
  final parts = amount.split('.');
  final fraction = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  return BigInt.parse('${parts.first}$fraction');
}
