import 'package:flutter/material.dart';

import '../../../core/design/terra_theme.dart';
import '../../../core/design/service_page_scaffold.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/api.dart';

class LandlordServiceContext {
  const LandlordServiceContext({
    required this.repository,
    required this.estateId,
    required this.estateName,
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
}

class LandlordRow {
  const LandlordRow({required this.title, required this.subtitle, this.trailing = '', this.icon = Icons.article_outlined});
  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
}

typedef LandlordRowLoader = Future<List<LandlordRow>> Function(LandlordServiceContext context);

class LandlordService {
  const LandlordService({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.loader,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final LandlordRowLoader loader;
}

List<LandlordService> landlordServices() => [
      LandlordService(
        id: 'portfolio',
        label: 'My properties',
        description: 'The properties the estate has confirmed you own.',
        icon: Icons.apartment_outlined,
        loader: (c) async {
          final rows = await c.repository.loadLandlordPortfolio(c.estateId);
          return rows.map((row) => LandlordRow(
                title: '${row.propertyCode} · ${row.propertyType}',
                subtitle: '${row.ownershipShare}% ownership · ${row.occupancyCount} occupant(s)',
                trailing: row.unitNumber ?? '',
                icon: Icons.home_work_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'occupancy',
        label: 'Who lives there',
        description: 'See which of your properties are occupied right now.',
        icon: Icons.people_outline,
        loader: (c) async {
          final rows = await c.repository.loadLandlordPortfolio(c.estateId);
          return rows.map((row) => LandlordRow(
                title: '${row.propertyCode} · ${row.occupancyCount == 0 ? 'Vacant' : 'Occupied'}',
                subtitle: row.occupancyCount == 0
                    ? 'No current occupants recorded'
                    : '${row.occupancyCount} current occupant(s)',
                icon: Icons.people_outline,
              )).toList();
        },
      ),
      LandlordService(
        id: 'tenancies',
        label: 'Tenants & leases',
        description: 'Your tenants, their lease terms, and the rent you agreed.',
        icon: Icons.home_outlined,
        loader: (c) async {
          final rows = await c.repository.loadLandlordPortfolio(c.estateId);
          return rows.where((row) => row.currentTenancy != null).map((row) {
            final tenancy = row.currentTenancy!;
            final rent = tenancy['rent'] as Map<String, dynamic>?;
            return LandlordRow(
              title: '${row.propertyCode} · ${tenancy['tenantDisplayName'] ?? 'Tenant'}',
              subtitle: rent == null
                  ? 'Agreed rent not available'
                  : 'Agreed ${rent['currency']} ${rent['amount']} / ${rent['frequency']}',
              icon: Icons.home_outlined,
            );
          }).toList();
        },
      ),
      LandlordService(
        id: 'rent-schedule',
        label: 'Rent dates',
        description: 'The dates rent is due and how much is expected.',
        icon: Icons.calendar_month_outlined,
        loader: (c) async {
          final rows = await c.repository.loadRentSchedule(c.estateId);
          return rows.map((row) => LandlordRow(
                title: '${row.currency} ${row.amount} · ${row.status}',
                subtitle: '${row.periodStart} – ${row.periodEnd} · due ${row.dueDate}',
                trailing: row.balance,
                icon: Icons.calendar_month_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'arrears',
        label: 'Unpaid rent',
        description: 'Rent that is still unpaid, including anything overdue.',
        icon: Icons.warning_amber_outlined,
        loader: (c) async {
          final rows = await c.repository.loadRentSchedule(c.estateId);
          return rows.where((row) => row.balance != '0' && double.tryParse(row.balance) != 0).map((row) => LandlordRow(
                title: '${row.currency} ${row.balance} outstanding',
                subtitle: 'Due ${row.dueDate}${row.isOverdue ? ' · overdue' : ''}',
                icon: Icons.warning_amber_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'receipts',
        label: 'Payment receipts',
        description: 'Proof of rent that has already been collected.',
        icon: Icons.receipt_long_outlined,
        loader: (c) async {
          final rows = await c.repository.loadRentSchedule(c.estateId);
          final receipts = rows.expand((row) => row.receipts).toList();
          return receipts.map((receipt) {
            final map = receipt as Map<String, dynamic>;
            return LandlordRow(
              title: '${map['receipt'] ?? 'Receipt'} · ${map['amount'] ?? ''}',
              subtitle: 'Reference ${map['reference'] ?? ''}',
              icon: Icons.receipt_long_outlined,
            );
          }).toList();
        },
      ),
      LandlordService(
        id: 'statements',
        label: 'Rent statement',
        description: 'A simple summary of rent owed, collected and still due.',
        icon: Icons.description_outlined,
        loader: (c) async {
          final rows = await c.repository.loadLandlordRentSummary(c.estateId);
          return rows.map((row) => LandlordRow(
                title: row.payeeName,
                subtitle: 'You should receive ${AppFormat.money(row.entitlement)} · '
                    'Already collected ${AppFormat.money(row.collected)}',
                trailing: '${AppFormat.money(row.outstanding)} due',
                icon: Icons.description_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'maintenance',
        label: 'Repairs',
        description: 'Repair requests from residents in your properties.',
        icon: Icons.handyman_outlined,
        loader: (c) async {
          final rows = await c.repository.loadMyLandlordPropertyMaintenance();
          return rows.map((row) => LandlordRow(
                title: row.reference,
                subtitle: '${row.propertyLabel} · ${row.category} · ${row.status}',
                icon: Icons.handyman_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'documents',
        label: 'Documents',
        description: 'Where to find or request your property papers.',
        icon: Icons.folder_outlined,
        loader: (c) async => [
              const LandlordRow(
                title: 'Property documents',
                subtitle: 'Ownership evidence is held by estate administration and is available on request.',
                icon: Icons.folder_outlined,
              ),
              const LandlordRow(
                title: 'Rent receipts',
                subtitle: 'Use the Receipts service to view receipt references for collected rent.',
                icon: Icons.receipt_long_outlined,
              ),
            ],
      ),
      LandlordService(
        id: 'notices',
        label: 'Estate notices',
        description: 'News and notices from your estate.',
        icon: Icons.campaign_outlined,
        loader: (c) async {
          final rows = await c.repository.loadEstateAnnouncements(c.estateId);
          return rows.map((row) => LandlordRow(
                title: row.title,
                subtitle: row.body,
                icon: Icons.campaign_outlined,
              )).toList();
        },
      ),
      LandlordService(
        id: 'safety',
        label: 'Safety reports',
        description: 'Reports about safety issues in your properties.',
        icon: Icons.health_and_safety_outlined,
        loader: (c) async {
          final rows = await c.repository.loadSecurityIncidents(c.estateId);
          return rows.map((row) => LandlordRow(
                title: row.reference,
                subtitle: '${row.category} · ${row.status}',
                icon: Icons.health_and_safety_outlined,
              )).toList();
        },
      ),
      const LandlordService(
        id: 'more',
        label: 'More Services',
        description: 'Every landlord service in one place.',
        icon: Icons.apps_outlined,
        loader: _moreLoader,
      ),
    ];

Future<List<LandlordRow>> _moreLoader(LandlordServiceContext context) async =>
    landlordServices()
        .where((service) => service.id != 'more')
        .map(
          (service) => LandlordRow(
            title: service.label,
            subtitle: service.description,
            icon: service.icon,
          ),
        )
        .toList();

Future<T?> openLandlordPage<T extends Object?>(BuildContext context, Widget page) =>
    AppNavigation.push<T>(context, page);

class LandlordServicePage extends StatefulWidget {
  const LandlordServicePage({
    super.key,
    required this.service,
    required this.serviceContext,
  });

  final LandlordService service;
  final LandlordServiceContext serviceContext;

  @override
  State<LandlordServicePage> createState() => _LandlordServicePageState();
}

class _LandlordServicePageState extends State<LandlordServicePage> {
  List<LandlordRow> _rows = const [];
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
      _rows = await widget.service.loader(widget.serviceContext);
    } catch (_) {
      _error = '${widget.service.label} could not be loaded for this estate.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ServicePageScaffold(
      title: widget.service.label,
      description: '${widget.serviceContext.estateName} · ${widget.service.description}',
      icon: widget.service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _rows.isEmpty
                  ? const ServiceStateMessage(message: 'Nothing to show here yet.')
                  : Column(
                      children: _rows.map(
                        (row) => Card(
                          child: ListTile(
                            leading: Icon(row.icon, color: TerraColors.forest),
                            title: Text(row.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(row.subtitle, style: const TextStyle(fontSize: 11)),
                            trailing: row.trailing.isEmpty
                                ? null
                                : Text(row.trailing,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                      ).toList(),
                    ),
    );
  }
}

class LandlordMoreServicesPage extends StatelessWidget {
  const LandlordMoreServicesPage({super.key, required this.serviceContext});
  final LandlordServiceContext serviceContext;

  @override
  Widget build(BuildContext context) {
    return ServicePageScaffold(
      title: 'More Services',
      description: '${serviceContext.estateName} · Every landlord service in one place.',
      icon: Icons.apps_outlined,
      child: TerraQuickServicesGrid(
        services: landlordServices()
            .map(
              (service) => TerraServiceAction(
                icon: service.icon,
                label: service.label,
                onTap: () => openLandlordPage(
                  context,
                  LandlordServicePage(service: service, serviceContext: serviceContext),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}







