import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../data/estate_admin_repository.dart';
import 'visitor_access_page.dart';
import 'estate_finance_page.dart';
import 'facility_booking_review_page.dart';
import 'security_incidents_page.dart';
import 'estate_team_page.dart';
import 'estate_reports_page.dart';
import 'estate_tenancies_page.dart';
import 'landlord_portfolio_page.dart';
import 'estate_billing_page.dart';
import 'estate_communications_page.dart';
import 'estate_rent_management_page.dart';
import 'estate_settings_page.dart';
import 'ownership_review_page.dart';

class EstateAdminShell extends StatefulWidget {
  const EstateAdminShell({super.key, required this.repository});

  final EstateAdminRepository repository;

  @override
  State<EstateAdminShell> createState() => _EstateAdminShellState();
}

class _EstateAdminShellState extends State<EstateAdminShell> {
  AdminSection _section = AdminSection.overview;
  late Future<EstateAdminDashboardSnapshot> _dashboard;
  late Future<List<MaintenanceQueueEntry>> _queue;
  late Future<List<EstatePropertyRecord>> _properties;
  late Future<List<EstateStructureNode>> _structure;
  late Future<List<ResidentJoinRequestSummary>> _joinRequests;
  late Future<
    ({List<VisitorPassSummary> passes, List<GateVisitorSummary> current})
  >
  _visitorAccess;
  late Future<
    ({List<FinanceBudgetLine> budgets, List<EstateExpenseRequest> expenses})
  >
  _financeData;
  late Future<List<EstateFacilityBooking>> _facilityBookings;
  late Future<List<EstateSecurityIncident>> _securityIncidents;
  late Future<List<EstateTeamMember>> _teamMembers;
  late Future<List<EstateTenancySummary>> _tenancies;
  late Future<List<LandlordPortfolioItem>> _landlordPortfolio;
  late Future<List<EstateInvoiceSummary>> _estateInvoices;
  late Future<List<EstateAnnouncementSummary>> _announcements;
  late Future<EstateSettingsSummary> _estateSettings;
  late Future<List<EstatePropertyRecord>> _ownershipReviews;
  bool _showOwnershipReviews = false;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repository.loadDashboardSummary();
    _queue = Future.value(const []);
    _properties = Future.value(const []);
    _structure = Future.value(const []);
    _joinRequests = Future.value(const []);
    _visitorAccess = _loadVisitorAccess();
    _financeData = _loadFinanceData();
    _facilityBookings = widget.repository.loadFacilityBookings();
    _securityIncidents = widget.repository.loadSecurityIncidents();
    _teamMembers = widget.repository.loadEstateTeam();
    _tenancies = widget.repository.loadEstateTenancies();
    _landlordPortfolio = widget.repository.loadLandlordPortfolio();
    _estateInvoices = widget.repository.loadEstateInvoices();
    _announcements = widget.repository.loadEstateAnnouncements();
    _estateSettings = widget.repository.loadEstateSettings();
    _ownershipReviews = widget.repository.loadOwnershipReviews();
  }

  void _refresh() {
    setState(() {
      _dashboard = widget.repository.loadDashboardSummary();
      _loadSelectedModule();
    });
  }

  void _refreshJoinRequests() => setState(
    () => _joinRequests = widget.repository.loadResidentJoinRequests(),
  );

  void _reloadSecurityIncidents() => setState(
    () => _securityIncidents = widget.repository.loadSecurityIncidents(),
  );

  void _reloadTenancies() =>
      setState(() => _tenancies = widget.repository.loadEstateTenancies());

  void _selectSection(AdminSection section, {bool closeDrawer = false}) {
    setState(() {
      _section = section;
      _loadSelectedModule();
    });
    if (closeDrawer) Navigator.of(context).pop();
  }

  void _loadSelectedModule() {
    switch (_section) {
      case AdminSection.maintenance:
        _queue = widget.repository.loadMaintenanceQueue();
      case AdminSection.properties:
        _properties = widget.repository.loadProperties();
        _showOwnershipReviews = false;
      case AdminSection.structure:
        _structure = widget.repository.loadEstateStructure();
      case AdminSection.residents:
        _joinRequests = widget.repository.loadResidentJoinRequests();
      case AdminSection.visitors:
        _visitorAccess = _loadVisitorAccess();
      case AdminSection.finance:
        _financeData = _loadFinanceData();
      case AdminSection.facilities:
        _facilityBookings = widget.repository.loadFacilityBookings();
      case AdminSection.security:
        _securityIncidents = widget.repository.loadSecurityIncidents();
      case AdminSection.team:
        _teamMembers = widget.repository.loadEstateTeam();
      case AdminSection.tenancies:
        _tenancies = widget.repository.loadEstateTenancies();
      case AdminSection.landlords:
        _landlordPortfolio = widget.repository.loadLandlordPortfolio();
      case AdminSection.billing:
        _estateInvoices = widget.repository.loadEstateInvoices();
      case AdminSection.communications:
        _announcements = widget.repository.loadEstateAnnouncements();
      case AdminSection.charges:
      case AdminSection.settings:
        _estateSettings = widget.repository.loadEstateSettings();
      default:
        break;
    }
  }

  Future<({List<VisitorPassSummary> passes, List<GateVisitorSummary> current})>
  _loadVisitorAccess() async {
    final results = await Future.wait([
      widget.repository.loadVisitorPasses(),
      widget.repository.loadCurrentGateVisitors(),
    ]);
    return (
      passes: results[0] as List<VisitorPassSummary>,
      current: results[1] as List<GateVisitorSummary>,
    );
  }

  Future<
    ({List<FinanceBudgetLine> budgets, List<EstateExpenseRequest> expenses})
  >
  _loadFinanceData() async {
    final budgets = await widget.repository.loadFinanceBudgets();
    final expenses = await widget.repository.loadExpenseRequests();
    return (budgets: budgets, expenses: expenses);
  }

  void _reloadFinanceData() {
    setState(() => _financeData = _loadFinanceData());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: Drawer(
      child: SafeArea(
        child: FutureBuilder<EstateAdminDashboardSnapshot>(
          future: _dashboard,
          builder: (context, snapshot) => _AdminNavigation(
            selected: _section,
            availableSections: snapshot.data?.availableSections ?? const {},
            maintenanceCount: _maintenanceCount(snapshot.data),
            onSelect: (section) => _selectSection(section, closeDrawer: true),
            extended: true,
          ),
        ),
      ),
    ),
    appBar: AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: EstateColors.forest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estate Management',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  _sectionLabel(_section),
                  style: const TextStyle(
                    fontSize: 11,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh estate overview',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16, left: 4),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFE4EFE8),
            child: Text(
              'A',
              style: TextStyle(
                color: EstateColors.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
    body: FutureBuilder<EstateAdminDashboardSnapshot>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _AdminLoadError(onRetry: _refresh);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dashboard = snapshot.requireData;
        if (_section != AdminSection.overview &&
            !dashboard.availableSections.contains(_section)) {
          return const _AccessUnavailable();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1000;
            return Row(
              children: [
                if (desktop)
                  _AdminNavigation(
                    selected: _section,
                    availableSections: dashboard.availableSections,
                    maintenanceCount: _maintenanceCount(dashboard),
                    onSelect: _selectSection,
                    extended: true,
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: _page(dashboard),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _page(EstateAdminDashboardSnapshot dashboard) {
    if (_section == AdminSection.overview) {
      return _AdminOverviewPage(
        dashboard: dashboard,
        onOpenMaintenance: () => _selectSection(AdminSection.maintenance),
        onSelectSection: _selectSection,
      );
    }
    if (_section == AdminSection.maintenance) {
      return FutureBuilder<List<MaintenanceQueueEntry>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'The maintenance queue is unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _MaintenanceQueuePage(entries: snapshot.requireData);
        },
      );
    }
    if (_section == AdminSection.properties) {
      if (_showOwnershipReviews) {
        return FutureBuilder<List<EstatePropertyRecord>>(
          future: _ownershipReviews,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AdminLoadError(
                message: 'Ownership reviews are unavailable.',
                onRetry: _refresh,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return OwnershipReviewPage(
              records: snapshot.requireData,
              onBack: () => setState(() => _showOwnershipReviews = false),
            );
          },
        );
      }
      return FutureBuilder<List<EstatePropertyRecord>>(
        future: _properties,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'The property register is unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _PropertyRegisterPage(
            properties: snapshot.requireData,
            metrics: dashboard.sections[AdminSection.properties]?.metrics,
            asOf: dashboard.asOf,
            ownershipReviews: _ownershipReviews,
            repository: widget.repository,
            onOpenOwnershipReviews: () =>
                setState(() => _showOwnershipReviews = true),
            onCreateProperty:
                ({
                  required code,
                  required propertyType,
                  required status,
                  required parentNodeId,
                  unitNumber,
                  address,
                  description,
                }) async {
                  final created = await widget.repository.createPropertyPreview(
                    code: code,
                    propertyType: propertyType,
                    status: status,
                    parentNodeId: parentNodeId,
                    unitNumber: unitNumber,
                    address: address,
                    description: description,
                  );
                  if (!context.mounted) return;
                  setState(
                    () => _properties = widget.repository.loadProperties(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${created.code} added to this preview.'),
                    ),
                  );
                },
            onUpdateProperty:
                ({
                  required propertyId,
                  required code,
                  required propertyType,
                  required status,
                  unitNumber,
                  address,
                  description,
                }) async {
                  final updated = await widget.repository.updatePropertyPreview(
                    propertyId: propertyId,
                    code: code,
                    propertyType: propertyType,
                    status: status,
                    unitNumber: unitNumber,
                    address: address,
                    description: description,
                  );
                  if (!context.mounted) return;
                  setState(
                    () => _properties = widget.repository.loadProperties(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${updated.code} updated in this preview.'),
                    ),
                  );
                },
            onArchiveProperty: (propertyId) async {
              final archived = await widget.repository.archivePropertyPreview(
                propertyId,
              );
              if (!context.mounted) return;
              setState(() => _properties = widget.repository.loadProperties());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${archived.code} archived in this preview.'),
                ),
              );
            },
            onPreviewUpdateLocation:
                ({
                  required propertyId,
                  required latitude,
                  required longitude,
                  required confidence,
                  required source,
                  accuracyMeters,
                  required reason,
                }) async {
                  final updated = await widget.repository
                      .previewUpdatePropertyMapLocation(
                        propertyId: propertyId,
                        latitude: latitude,
                        longitude: longitude,
                        confidence: confidence,
                        source: source,
                        accuracyMeters: accuracyMeters,
                        reason: reason,
                      );
                  if (!context.mounted) return updated;
                  setState(
                    () => _properties = widget.repository.loadProperties(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${updated.code} location updated in this preview.',
                      ),
                    ),
                  );
                  return updated;
                },
          );
        },
      );
    }
    if (_section == AdminSection.structure) {
      return FutureBuilder<List<EstateStructureNode>>(
        future: _structure,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Estate structure is unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _EstateStructurePage(
            nodes: snapshot.requireData,
            asOf: dashboard.asOf,
            onCreateNode:
                ({required type, required name, code, parentId}) async {
                  final created = await widget.repository
                      .createStructureNodePreview(
                        type: type,
                        name: name,
                        code: code,
                        parentId: parentId,
                      );
                  if (!context.mounted) return;
                  setState(
                    () => _structure = widget.repository.loadEstateStructure(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${created.name} added to this preview.'),
                    ),
                  );
                },
            onEditNode: ({required nodeId, required name, code}) async {
              final updated = await widget.repository
                  .updateStructureNodePreview(
                    nodeId: nodeId,
                    name: name,
                    code: code,
                  );
              if (!context.mounted) return;
              setState(
                () => _structure = widget.repository.loadEstateStructure(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${updated.name} updated in this preview.'),
                ),
              );
            },
            onArchiveNode: (nodeId) async {
              final archived = await widget.repository
                  .archiveStructureNodePreview(nodeId);
              if (!context.mounted) return;
              setState(
                () => _structure = widget.repository.loadEstateStructure(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${archived.name} archived in this preview.'),
                ),
              );
            },
          );
        },
      );
    }
    if (_section == AdminSection.residents) {
      return FutureBuilder<List<ResidentJoinRequestSummary>>(
        future: _joinRequests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Resident requests are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ResidentJoinRequestsPage(
            repository: widget.repository,
            requests: snapshot.requireData,
            asOf: dashboard.asOf,
            onRequestsChanged: _refreshJoinRequests,
          );
        },
      );
    }
    if (_section == AdminSection.visitors) {
      return FutureBuilder<
        ({List<VisitorPassSummary> passes, List<GateVisitorSummary> current})
      >(
        future: _visitorAccess,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Visitor access records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return VisitorAccessPage(
            passes: snapshot.requireData.passes,
            currentVisitors: snapshot.requireData.current,
          );
        },
      );
    }
    if (_section == AdminSection.finance) {
      return FutureBuilder<
        ({List<FinanceBudgetLine> budgets, List<EstateExpenseRequest> expenses})
      >(
        future: _financeData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Finance records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateFinancePage(
            budgets: snapshot.requireData.budgets,
            expenses: snapshot.requireData.expenses,
            metrics:
                dashboard.sections[AdminSection.finance]?.metrics
                    is FinanceMetrics
                ? dashboard.sections[AdminSection.finance]!.metrics
                      as FinanceMetrics
                : null,
            repository: widget.repository,
            onExpensesChanged: _reloadFinanceData,
          );
        },
      );
    }
    if (_section == AdminSection.facilities) {
      return FutureBuilder<List<EstateFacilityBooking>>(
        future: _facilityBookings,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Facility bookings are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FacilityBookingReviewPage(bookings: snapshot.requireData);
        },
      );
    }
    if (_section == AdminSection.security) {
      return FutureBuilder<List<EstateSecurityIncident>>(
        future: _securityIncidents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Security incidents are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SecurityIncidentsPage(
            incidents: snapshot.requireData,
            repository: widget.repository,
            onIncidentsChanged: _reloadSecurityIncidents,
          );
        },
      );
    }
    if (_section == AdminSection.team) {
      return FutureBuilder<List<EstateTeamMember>>(
        future: _teamMembers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Estate team records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateTeamPage(
            members: snapshot.requireData,
            repository: widget.repository,
          );
        },
      );
    }
    if (_section == AdminSection.tenancies) {
      return FutureBuilder<List<EstateTenancySummary>>(
        future: _tenancies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Tenancy records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateTenanciesPage(
            tenancies: snapshot.requireData,
            repository: widget.repository,
            onTenanciesChanged: _reloadTenancies,
          );
        },
      );
    }
    if (_section == AdminSection.rent) {
      return FutureBuilder<List<EstateTenancySummary>>(
        future: _tenancies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Rent schedule records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateRentManagementPage(
            tenancies: snapshot.requireData,
            repository: widget.repository,
          );
        },
      );
    }
    if (_section == AdminSection.landlords) {
      return FutureBuilder<List<LandlordPortfolioItem>>(
        future: _landlordPortfolio,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Landlord portfolio records are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return LandlordPortfolioPage(properties: snapshot.requireData);
        },
      );
    }
    if (_section == AdminSection.billing) {
      return FutureBuilder<List<EstateInvoiceSummary>>(
        future: _estateInvoices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Estate invoices are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateBillingPage(invoices: snapshot.requireData);
        },
      );
    }
    if (_section == AdminSection.communications) {
      return FutureBuilder<List<EstateAnnouncementSummary>>(
        future: _announcements,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Estate announcements are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateCommunicationsPage(
            announcements: snapshot.requireData,
            repository: widget.repository,
            onDraftSaved: () {
              setState(() {
                _announcements = widget.repository.loadEstateAnnouncements();
              });
            },
          );
        },
      );
    }
    if (_section == AdminSection.charges) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Live charge configuration is available in the connected Estate Admin dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_section == AdminSection.settings) {
      return FutureBuilder<EstateSettingsSummary>(
        future: _estateSettings,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminLoadError(
              message: 'Estate settings are unavailable.',
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return EstateSettingsPage(settings: snapshot.requireData);
        },
      );
    }
    if (_section == AdminSection.reports) {
      return EstateReportsPage(dashboard: dashboard);
    }
    return _ModulePlaceholder(section: _section);
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.selected,
    required this.availableSections,
    required this.maintenanceCount,
    required this.onSelect,
    required this.extended,
  });

  final AdminSection selected;
  final Set<AdminSection> availableSections;
  final int? maintenanceCount;
  final ValueChanged<AdminSection> onSelect;
  final bool extended;

  static const _sections = <AdminSection>[
    AdminSection.overview,
    AdminSection.properties,
    AdminSection.structure,
    AdminSection.residents,
    AdminSection.landlords,
    AdminSection.tenancies,
    AdminSection.billing,
    AdminSection.rent,
    AdminSection.charges,
    AdminSection.visitors,
    AdminSection.security,
    AdminSection.maintenance,
    AdminSection.facilities,
    AdminSection.communications,
    AdminSection.finance,
    AdminSection.reports,
    AdminSection.team,
    AdminSection.settings,
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: extended ? 248 : 80,
    color: Colors.white,
    child: Column(
      children: [
        if (extended)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Row(
              children: [
                Icon(Icons.apartment_rounded, color: EstateColors.forest),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oakwood Estate',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Lekki, Lagos',
                        style: TextStyle(
                          fontSize: 11,
                          color: EstateColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 18),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            children: [
              for (final section in _sections.where(
                (section) =>
                    section == AdminSection.overview ||
                    availableSections.contains(section),
              ))
                _NavigationItem(
                  section: section,
                  selected: section == selected,
                  extended: extended,
                  count: section == AdminSection.maintenance
                      ? maintenanceCount
                      : null,
                  onTap: () => onSelect(section),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (extended)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFE4EFE8),
                  child: Text(
                    'A',
                    style: TextStyle(color: EstateColors.forest),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ada Williams',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Estate administrator',
                        style: TextStyle(
                          fontSize: 10,
                          color: EstateColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded),
              ],
            ),
          ),
      ],
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.section,
    required this.selected,
    required this.extended,
    required this.count,
    required this.onTap,
  });

  final AdminSection section;
  final bool selected;
  final bool extended;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? EstateColors.forest : EstateColors.muted;
    return Tooltip(
      message: _sectionLabel(section),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? const Color(0xFFEAF3EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Icon(_sectionIcon(section), size: 19, color: color),
                  ),
                  if (extended)
                    Expanded(
                      child: Text(
                        _sectionLabel(section),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? EstateColors.forest
                              : EstateColors.ink,
                        ),
                      ),
                    ),
                  if (section == AdminSection.maintenance &&
                      extended &&
                      count != null)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? EstateColors.forest
                            : const Color(0xFFF0F3F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? Colors.white : EstateColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminOverviewPage extends StatelessWidget {
  const _AdminOverviewPage({
    required this.dashboard,
    required this.onOpenMaintenance,
    required this.onSelectSection,
  });

  final EstateAdminDashboardSnapshot dashboard;
  final VoidCallback onOpenMaintenance;
  final ValueChanged<AdminSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    DashboardSectionResult? sectionFor(AdminSection section) =>
        dashboard.availableSections.contains(section)
        ? dashboard.sections[section]
        : null;

    final propertySection = sectionFor(AdminSection.properties);
    final residentSection = sectionFor(AdminSection.residents);
    final tenancySection = sectionFor(AdminSection.tenancies);
    final visitorSection = sectionFor(AdminSection.visitors);
    final maintenanceSection = sectionFor(AdminSection.maintenance);
    final financeSection = sectionFor(AdminSection.finance);
    final property = _metricsWhenAvailable(propertySection);
    final residents = _metricsWhenAvailable(residentSection);
    final tenancies = _metricsWhenAvailable(tenancySection);
    final visitors = _metricsWhenAvailable(visitorSection);
    final maintenance = _metricsWhenAvailable(maintenanceSection);
    final finance = _metricsWhenAvailable(financeSection);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _SampleDataBanner(asOf: dashboard.asOf),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, Ada',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${dashboard.estateName} · ${dashboard.location}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.calendar_month_outlined, size: 17),
              label: Text(
                dashboard.periodLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 460
                ? 2
                : 1;
            final gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final cards = <Widget>[
              if (propertySection != null && property is PropertyMetrics)
                _MetricCard(
                  label: 'Properties',
                  value: '${property.total}',
                  detail:
                      '${property.occupied} occupied · ${property.vacant} vacant',
                  icon: Icons.apartment_rounded,
                  tone: EstateColors.forest,
                  onTap: () => onSelectSection(AdminSection.properties),
                ),
              if (residentSection != null && residents is ResidentMetrics)
                _MetricCard(
                  label: 'Registered residents',
                  value: '${residents.registered}',
                  detail: '${residents.landlords} active landlords',
                  icon: Icons.people_alt_outlined,
                  tone: const Color(0xFF3E6C9B),
                  onTap: () => onSelectSection(AdminSection.residents),
                ),
              if (maintenanceSection != null &&
                  maintenance is MaintenanceMetrics)
                _MetricCard(
                  label: 'Open maintenance',
                  value: '${maintenance.openRequests}',
                  detail: 'Across your estate',
                  icon: Icons.handyman_outlined,
                  tone: EstateColors.amber,
                  onTap: onOpenMaintenance,
                ),
              if (visitorSection != null && visitors is VisitorMetrics)
                _MetricCard(
                  label: 'Visitor activity',
                  value: '${visitors.activity}',
                  detail: '${visitors.checkedIn} currently checked in',
                  icon: Icons.qr_code_2_rounded,
                  tone: const Color(0xFF7653A3),
                  onTap: () => onSelectSection(AdminSection.visitors),
                ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        _DashboardDataCoverage(dashboard: dashboard),
        const SizedBox(height: 20),
        if (propertySection != null || financeSection != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 850;
              final panels = <Widget>[
                if (propertySection != null)
                  _OccupancyCard(metrics: property, tenancies: tenancies),
                if (financeSection != null)
                  _FinanceCard(
                    metrics: finance,
                    status: financeSection.status,
                    freshness: dashboard.sourceFreshness[AdminSection.finance],
                  ),
              ];
              if (panels.length == 1) return panels.single;
              if (stack) {
                return Column(
                  children: [
                    panels.first,
                    const SizedBox(height: 14),
                    panels.last,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: panels.first),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: panels.last),
                ],
              );
            },
          ),
        const SizedBox(height: 24),
        if (maintenanceSection != null &&
            maintenanceSection.status != DashboardDataStatus.unavailable)
          _SectionHeading(
            title: 'Needs attention',
            actionLabel: 'View maintenance queue',
            onTap: onOpenMaintenance,
          ),
        if (maintenanceSection != null &&
            maintenanceSection.status != DashboardDataStatus.unavailable)
          const SizedBox(height: 12),
        if (maintenanceSection != null &&
            maintenanceSection.status != DashboardDataStatus.unavailable)
          _AttentionCard(
            icon: Icons.handyman_outlined,
            title:
                '${maintenance is MaintenanceMetrics ? maintenance.openRequests : 0} maintenance requests are open',
            detail: 'Review resident reports and follow the current status.',
            badge:
                '${maintenance is MaintenanceMetrics ? maintenance.openRequests : '—'} open',
            onTap: onOpenMaintenance,
          ),
        if (maintenanceSection != null &&
            maintenanceSection.status != DashboardDataStatus.unavailable)
          const SizedBox(height: 9),
      ],
    );
  }
}

class _DashboardDataCoverage extends StatelessWidget {
  const _DashboardDataCoverage({required this.dashboard});
  final EstateAdminDashboardSnapshot dashboard;

  @override
  Widget build(BuildContext context) {
    final sections = dashboard.availableSections.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final available = sections
        .where(
          (section) =>
              dashboard.sections[section]?.status ==
              DashboardDataStatus.available,
        )
        .length;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.storage_outlined, color: EstateColors.forest),
        title: const Text(
          'Data coverage',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$available of ${sections.length} sections report complete data',
          style: const TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Times are supplied by each data source. Preview timestamps are illustrative.',
                style: TextStyle(fontSize: 10, color: EstateColors.muted),
              ),
            ),
          ),
          for (var index = 0; index < sections.length; index++) ...[
            _DashboardSourceRow(
              section: sections[index],
              result: dashboard.sections[sections[index]],
              source: dashboard.sourceFreshness[sections[index]],
            ),
            if (index < sections.length - 1) const Divider(height: 14),
          ],
        ],
      ),
    );
  }
}

class _DashboardSourceRow extends StatelessWidget {
  const _DashboardSourceRow({
    required this.section,
    required this.result,
    required this.source,
  });
  final AdminSection section;
  final DashboardSectionResult? result;
  final DashboardSourceInfo? source;

  @override
  Widget build(BuildContext context) {
    final status = result?.status ?? DashboardDataStatus.unavailable;
    final freshness = source?.freshness ?? DashboardFreshness.unavailable;
    final asOf = source?.asOf;
    final detail = switch (status) {
      DashboardDataStatus.available => 'Complete',
      DashboardDataStatus.incomplete => 'Partial data',
      DashboardDataStatus.pendingReconciliation => 'Reconciliation pending',
      DashboardDataStatus.unavailable => 'Unavailable',
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sectionLabel(section),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$detail${asOf == null ? '' : ' · As of ${_dateTime(asOf)}'}',
                style: const TextStyle(fontSize: 10, color: EstateColors.muted),
              ),
            ],
          ),
        ),
        _FreshnessPill(freshness: freshness),
      ],
    );
  }
}

String _dateTime(DateTime date) {
  final local = date.toLocal();
  final month = const [
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
  ][local.month - 1];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year}, $hour:$minute ${local.hour >= 12 ? 'pm' : 'am'}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.onTap,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: EstateColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: tone),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: EstateColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.metrics, required this.tenancies});
  final DashboardMetrics? metrics;
  final DashboardMetrics? tenancies;

  @override
  Widget build(BuildContext context) {
    final property = metrics is PropertyMetrics
        ? metrics as PropertyMetrics
        : null;
    final ratio = property == null || property.total == 0
        ? 0.0
        : property.occupied / property.total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property occupancy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              tenancies is TenancyMetrics
                  ? 'Current occupancy · ${(tenancies as TenancyMetrics).activeTenancies} active tenancies'
                  : 'Current registered occupancy',
              style: const TextStyle(fontSize: 11, color: EstateColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  property == null ? '—' : '${(ratio * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    property == null
                        ? 'Data unavailable'
                        : '${property.occupied} of ${property.total} properties',
                    style: const TextStyle(
                      fontSize: 11,
                      color: EstateColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: const Color(0xFFE9EEEA),
                color: EstateColors.leaf,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const _LegendDot(color: EstateColors.leaf),
                const SizedBox(width: 6),
                Text(
                  '${property?.occupied ?? '—'} occupied',
                  style: const TextStyle(
                    fontSize: 11,
                    color: EstateColors.muted,
                  ),
                ),
                const SizedBox(width: 16),
                const _LegendDot(color: Color(0xFFDDE4DF)),
                const SizedBox(width: 6),
                Text(
                  '${property?.vacant ?? '—'} vacant',
                  style: const TextStyle(
                    fontSize: 11,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.metrics,
    required this.status,
    required this.freshness,
  });
  final DashboardMetrics? metrics;
  final DashboardDataStatus status;
  final DashboardSourceInfo? freshness;

  @override
  Widget build(BuildContext context) {
    final finance = metrics is FinanceMetrics
        ? metrics as FinanceMetrics
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Financial snapshot',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _FreshnessPill(
                  freshness:
                      freshness?.freshness ?? DashboardFreshness.unavailable,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(switch (status) {
              DashboardDataStatus.available =>
                'Verified amounts for this reporting period',
              DashboardDataStatus.incomplete =>
                'Partial totals for this reporting period',
              DashboardDataStatus.pendingReconciliation =>
                'Amounts may change while reconciliation is pending',
              DashboardDataStatus.unavailable =>
                'Finance source is temporarily unavailable',
            }, style: TextStyle(fontSize: 11, color: EstateColors.muted)),
            const SizedBox(height: 16),
            if (finance == null)
              const Text(
                'Financial summary is unavailable for this account.',
                style: TextStyle(color: EstateColors.muted),
              )
            else ...[
              _FinanceLine(
                label: 'Rent collected',
                value: finance.rentCollected,
              ),
              _FinanceLine(
                label: 'Estate fees',
                value: finance.estateFeesCollected,
              ),
              _FinanceLine(
                label: 'Other charges',
                value: finance.otherChargesCollected,
              ),
              const Divider(height: 22),
              _FinanceLine(label: 'Expenses paid', value: finance.expensesPaid),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Net operating position',
                        style: TextStyle(
                          fontSize: 11,
                          color: EstateColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      finance.netOperatingPosition,
                      style: const TextStyle(
                        fontSize: 14,
                        color: EstateColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinanceLine extends StatelessWidget {
  const _FinanceLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _FreshnessPill extends StatelessWidget {
  const _FreshnessPill({required this.freshness});
  final DashboardFreshness freshness;
  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (freshness) {
      DashboardFreshness.current => (
        'Current',
        EstateColors.forest,
        const Color(0xFFEAF3EE),
      ),
      DashboardFreshness.stale => (
        'Stale',
        EstateColors.amber,
        EstateColors.amberWash,
      ),
      DashboardFreshness.delayed => (
        'Delayed',
        EstateColors.amber,
        EstateColors.amberWash,
      ),
      DashboardFreshness.unavailable => (
        'Unavailable',
        EstateColors.muted,
        const Color(0xFFF0F3F1),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: Text(actionLabel)),
    ],
  );
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.badge,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEAF3EE),
              child: Icon(icon, size: 18, color: EstateColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 11,
                      color: EstateColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              badge,
              style: const TextStyle(fontSize: 10, color: EstateColors.muted),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: EstateColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _SampleDataBanner extends StatelessWidget {
  const _SampleDataBanner({required this.asOf});
  final DateTime asOf;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: constraints.maxWidth < 600
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: EstateColors.amber,
                      size: 18,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Sample estate information · Actions are not saved.',
                        style: TextStyle(fontSize: 11, color: EstateColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 27),
                  child: Text(
                    'Snapshot date · ${_formatDate(asOf)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: EstateColors.muted,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: EstateColors.amber,
                  size: 18,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Sample estate information · Actions are not saved.',
                    style: TextStyle(fontSize: 11, color: EstateColors.ink),
                  ),
                ),
                Text(
                  'Snapshot date · ${_formatDate(asOf)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _MaintenanceQueuePage extends StatelessWidget {
  const _MaintenanceQueuePage({required this.entries});
  final List<MaintenanceQueueEntry> entries;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    children: [
      _SampleDataBanner(asOf: DateTime.utc(2026, 11, 6, 9, 30)),
      const SizedBox(height: 24),
      Text(
        'Maintenance and complaints',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 5),
      const Text('Review resident requests and track their progress.'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _QueueFilter(label: 'All requests', selected: true),
          _QueueFilter(label: 'Submitted', selected: false),
          _QueueFilter(label: 'Under review', selected: false),
          _QueueFilter(label: 'In progress', selected: false),
        ],
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              _QueueRow(entry: entries[index]),
              if (index < entries.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${entries.length} preview requests',
        textAlign: TextAlign.end,
        style: const TextStyle(fontSize: 11, color: EstateColors.muted),
      ),
    ],
  );
}

class _QueueFilter extends StatelessWidget {
  const _QueueFilter({required this.label, required this.selected});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: null,
    labelStyle: TextStyle(
      fontSize: 11,
      color: selected ? EstateColors.forest : EstateColors.muted,
    ),
  );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.entry});
  final MaintenanceQueueEntry entry;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFEAF3EE),
      child: Icon(
        _categoryIcon(entry.category),
        color: EstateColors.forest,
        size: 19,
      ),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            _categoryTitle(entry.category),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        _PriorityPill(priority: entry.priority),
      ],
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        '${entry.reference} · ${entry.propertyLabel} · ${entry.requesterName}\n${entry.description}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          height: 1.5,
          fontSize: 11,
          color: EstateColors.muted,
        ),
      ),
    ),
    isThreeLine: true,
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _QueueStatusPill(status: entry.status),
        const SizedBox(height: 5),
        Text(
          entry.submittedAt,
          style: const TextStyle(fontSize: 9, color: EstateColors.muted),
        ),
      ],
    ),
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => _RequestReviewDialog(entry: entry),
    ),
  );
}

class _RequestReviewDialog extends StatelessWidget {
  const _RequestReviewDialog({required this.entry});
  final MaintenanceQueueEntry entry;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${_categoryTitle(entry.category)} request'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${entry.reference} · ${entry.propertyLabel}',
          style: const TextStyle(fontSize: 12, color: EstateColors.muted),
        ),
        const SizedBox(height: 10),
        Text(entry.description),
        const SizedBox(height: 12),
        Text(
          'Submitted by ${entry.requesterName} · ${entry.submittedAt}',
          style: const TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
        const SizedBox(height: 10),
        _QueueStatusPill(status: entry.status),
        const SizedBox(height: 14),
        const Text(
          'Review actions will be available when connected to the estate service.',
          style: TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});
  final String priority;
  @override
  Widget build(BuildContext context) {
    final urgent = priority == 'urgent';
    final high = priority == 'high';
    final color = urgent
        ? EstateColors.red
        : high
        ? EstateColors.amber
        : EstateColors.muted;
    final background = urgent
        ? const Color(0xFFFFEFED)
        : high
        ? EstateColors.amberWash
        : const Color(0xFFF0F3F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _QueueStatusPill extends StatelessWidget {
  const _QueueStatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3EE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _statusTitle(status),
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: EstateColors.forest,
      ),
    ),
  );
}

class _ResidentJoinRequestsPage extends StatefulWidget {
  const _ResidentJoinRequestsPage({
    required this.repository,
    required this.requests,
    required this.asOf,
    required this.onRequestsChanged,
  });

  final EstateAdminRepository repository;
  final List<ResidentJoinRequestSummary> requests;
  final DateTime asOf;
  final VoidCallback onRequestsChanged;

  @override
  State<_ResidentJoinRequestsPage> createState() =>
      _ResidentJoinRequestsPageState();
}

class _ResidentJoinRequestsPageState extends State<_ResidentJoinRequestsPage> {
  final _searchController = TextEditingController();
  String _status = 'submitted';
  String _relationship = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.requests.where((request) {
      final matchesStatus = _status == 'all' || request.status == _status;
      final matchesRelationship =
          _relationship == 'all' || request.relationship == _relationship;
      final matchesSearch =
          query.isEmpty ||
          '${request.applicantName} ${request.applicantEmail ?? ''} ${request.propertyLabel ?? ''}'
              .toLowerCase()
              .contains(query);
      return matchesStatus && matchesRelationship && matchesSearch;
    }).toList();
    final submittedCount = widget.requests
        .where((request) => request.status == 'submitted')
        .length;
    final decidedCount = widget.requests.length - submittedCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _SampleDataBanner(asOf: widget.asOf),
        const SizedBox(height: 24),
        Text(
          'Resident requests',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Review requests to join the estate or associate a property.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            final cards = [
              _ReviewCountCard(
                label: 'Requests awaiting review',
                count: submittedCount,
                tone: EstateColors.amber,
              ),
              _ReviewCountCard(
                label: 'Decision recorded',
                count: decidedCount,
                tone: EstateColors.forest,
              ),
              _ReviewCountCard(
                label: 'Request records',
                count: widget.requests.length,
                tone: const Color(0xFF3E6C9B),
              ),
            ];
            final gap = 10.0;
            final width = compact
                ? (constraints.maxWidth - gap) / 2
                : (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;
            final search = TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search name, email or property',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            );
            final status = DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Request status'),
              items: const [
                DropdownMenuItem(
                  value: 'submitted',
                  child: Text('Awaiting review'),
                ),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn')),
                DropdownMenuItem(value: 'all', child: Text('All requests')),
              ],
              onChanged: (value) =>
                  setState(() => _status = value ?? 'submitted'),
            );
            final relationship = DropdownButtonFormField<String>(
              initialValue: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All relationships'),
                ),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
                DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                DropdownMenuItem(
                  value: 'household_member',
                  child: Text('Household member'),
                ),
                DropdownMenuItem(
                  value: 'authorized_occupant',
                  child: Text('Authorized occupant'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _relationship = value ?? 'all'),
            );
            if (compact) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 10),
                      Expanded(child: relationship),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: search),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: status),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: relationship),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${filtered.length} requests shown · $submittedCount awaiting review',
          style: const TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const _EmptyAdminState(
            icon: Icons.person_search_outlined,
            title: 'No resident requests match this view',
            detail: 'Try a different status, relationship or search term.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < filtered.length; index++) ...[
                  _JoinRequestRow(
                    request: filtered[index],
                    onTap: () => _openDetail(context, filtered[index]),
                  ),
                  if (index < filtered.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    ResidentJoinRequestSummary request,
  ) async {
    final decided = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _JoinRequestDetailSheet(
        repository: widget.repository,
        request: request,
      ),
    );
    if (decided == true && mounted) widget.onRequestsChanged();
  }
}

class _ReviewCountCard extends StatelessWidget {
  const _ReviewCountCard({
    required this.label,
    required this.count,
    required this.tone,
  });
  final String label;
  final int count;
  final Color tone;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: tone.withValues(alpha: .10),
            child: Icon(Icons.person_outline_rounded, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _JoinRequestRow extends StatelessWidget {
  const _JoinRequestRow({required this.request, required this.onTap});
  final ResidentJoinRequestSummary request;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFEAF3EE),
      child: Text(
        _initials(request.applicantName),
        style: const TextStyle(
          color: EstateColors.forest,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    ),
    title: Text(
      request.applicantName,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${_relationshipLabel(request.relationship)} · ${request.propertyLabel ?? 'No property selected'}\n${request.applicantEmail ?? 'Email unavailable'} · ${request.submittedAt}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          height: 1.5,
          color: EstateColors.muted,
        ),
      ),
    ),
    isThreeLine: true,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _JoinStatusPill(status: request.status),
        const SizedBox(width: 4),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: EstateColors.muted,
        ),
      ],
    ),
    onTap: onTap,
  );
}

class _JoinRequestDetailSheet extends StatefulWidget {
  const _JoinRequestDetailSheet({
    required this.repository,
    required this.request,
  });
  final EstateAdminRepository repository;
  final ResidentJoinRequestSummary request;

  @override
  State<_JoinRequestDetailSheet> createState() =>
      _JoinRequestDetailSheetState();
}

class _JoinRequestDetailSheetState extends State<_JoinRequestDetailSheet> {
  late Future<ResidentJoinRequestDetail> _detail;
  bool _deciding = false;
  String? _decisionError;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.readResidentJoinRequest(widget.request.id);
  }

  Future<void> _decide(String decision) async {
    var reason = '';
    if (decision == 'reject') {
      final suppliedReason = await showDialog<String>(
        context: context,
        builder: (context) => const _JoinRejectionReasonDialog(),
      );
      if (suppliedReason == null || !mounted) return;
      reason = suppliedReason;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve resident request?'),
          content: const Text(
            'This changes the sample review state only. In the connected service, approval grants estate membership and may create property occupancy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve preview'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _deciding = true;
      _decisionError = null;
    });
    try {
      await widget.repository.decideResidentJoinRequest(
        requestId: widget.request.id,
        decision: decision,
        reason: reason,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deciding = false;
        _decisionError = 'The request could not be updated in this preview.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: FutureBuilder<ResidentJoinRequestDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Text('Request details are unavailable. Try again later.'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final detail = snapshot.requireData;
        final request = widget.request;
        final submitted = request.status == 'submitted';
        final documentsPending = detail.pendingDocumentCount > 0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Resident request',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _JoinStatusPill(status: request.status),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Request ${request.id} · Submitted ${request.submittedAt}',
                style: const TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      _DetailLine(
                        label: 'Applicant',
                        value: request.applicantName,
                      ),
                      _DetailLine(
                        label: 'Email',
                        value: request.applicantEmail,
                      ),
                      _DetailLine(
                        label: 'Relationship',
                        value: _relationshipLabel(request.relationship),
                      ),
                      _DetailLine(
                        label: 'Requested property',
                        value: request.propertyLabel,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Applicant note',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    detail.applicantNote?.trim().isNotEmpty == true
                        ? detail.applicantNote!
                        : 'No note provided.',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Supporting documents',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${detail.documentCount} documents · ${detail.pendingDocumentCount} pending review',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: documentsPending
                              ? EstateColors.amberWash
                              : const Color(0xFFEAF3EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              documentsPending
                                  ? Icons.pending_actions_rounded
                                  : Icons.task_alt_rounded,
                              size: 15,
                              color: documentsPending
                                  ? EstateColors.amber
                                  : EstateColors.forest,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                documentsPending
                                    ? '${detail.pendingDocumentCount} file${detail.pendingDocumentCount == 1 ? '' : 's'} need review'
                                    : detail.documentCount == 0
                                    ? 'No supporting files submitted'
                                    : 'All submitted files reviewed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: documentsPending
                                      ? EstateColors.amber
                                      : EstateColors.forest,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (detail.documentCategories.isEmpty)
                        const Text(
                          'No documents provided.',
                          style: TextStyle(
                            fontSize: 11,
                            color: EstateColors.muted,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: detail.documentCategories
                              .map(
                                (category) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_documentCategoryLabel(category)),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 5),
                      const Text(
                        'Documents open only through the authorized private-file review service.',
                        style: TextStyle(
                          fontSize: 10,
                          color: EstateColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!submitted && detail.decisionReason != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Decision history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 7),
                Card(
                  child: ListTile(
                    leading: Icon(
                      request.status == 'approved'
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: request.status == 'approved'
                          ? EstateColors.forest
                          : EstateColors.amber,
                    ),
                    title: Text(_joinStatusLabel(request.status)),
                    subtitle: Text(
                      '${detail.decisionReason}${detail.decidedAt == null ? '' : '\n${detail.decidedAt}'}',
                    ),
                  ),
                ),
              ],
              if (submitted) ...[
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deciding ? null : () => _decide('reject'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deciding ? null : () => _decide('approve'),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
                if (_deciding) ...[
                  const SizedBox(height: 8),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_decisionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _decisionError!,
                    style: const TextStyle(
                      color: EstateColors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                const Center(
                  child: Text(
                    'Preview decisions are local. The connected service must authorize reviewers and atomically update membership, occupancy and audit history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: EstateColors.muted),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}

class _JoinRejectionReasonDialog extends StatefulWidget {
  const _JoinRejectionReasonDialog();

  @override
  State<_JoinRejectionReasonDialog> createState() =>
      _JoinRejectionReasonDialogState();
}

class _JoinRejectionReasonDialogState
    extends State<_JoinRejectionReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject resident request'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _reason,
        autofocus: true,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Reason required',
          hintText: 'This reason will be included in the applicant update.',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a reason for the applicant.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop(_reason.text.trim());
        },
        child: const Text('Continue'),
      ),
    ],
  );
}

class _JoinStatusPill extends StatelessWidget {
  const _JoinStatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final submitted = status == 'submitted';
    final approved = status == 'approved';
    final color = approved
        ? EstateColors.forest
        : submitted
        ? EstateColors.amber
        : EstateColors.muted;
    final background = approved
        ? const Color(0xFFEAF3EE)
        : submitted
        ? EstateColors.amberWash
        : const Color(0xFFF0F3F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _joinStatusLabel(status),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

String _joinStatusLabel(String status) => switch (status) {
  'submitted' => 'Awaiting review',
  'approved' => 'Approved',
  'rejected' => 'Rejected',
  'withdrawn' => 'Withdrawn',
  _ => status,
};

String _relationshipLabel(String relationship) => switch (relationship) {
  'owner' => 'Owner',
  'tenant' => 'Tenant',
  'household_member' => 'Household member',
  'authorized_occupant' => 'Authorized occupant',
  _ => relationship,
};

String _documentCategoryLabel(String category) => switch (category) {
  'tenancy_agreement' => 'Tenancy agreement',
  'proof_of_ownership' => 'Proof of ownership',
  'owner_authorization' => 'Owner authorization',
  'identity' => 'Identity',
  _ => category.replaceAll('_', ' '),
};

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  return words
      .take(2)
      .map((word) => word.isEmpty ? '' : word[0])
      .join()
      .toUpperCase();
}

class _PropertyRegisterPage extends StatefulWidget {
  const _PropertyRegisterPage({
    required this.properties,
    required this.metrics,
    required this.asOf,
    required this.ownershipReviews,
    required this.repository,
    required this.onOpenOwnershipReviews,
    required this.onCreateProperty,
    required this.onUpdateProperty,
    required this.onArchiveProperty,
    required this.onPreviewUpdateLocation,
  });

  final List<EstatePropertyRecord> properties;
  final DashboardMetrics? metrics;
  final DateTime asOf;
  final Future<List<EstatePropertyRecord>> ownershipReviews;
  final EstateAdminRepository repository;
  final VoidCallback onOpenOwnershipReviews;
  final Future<void> Function({
    required String code,
    required String propertyType,
    required String status,
    required String? parentNodeId,
    String? unitNumber,
    String? address,
    String? description,
  })
  onCreateProperty;
  final Future<void> Function({
    required String propertyId,
    required String code,
    required String propertyType,
    required String status,
    String? unitNumber,
    String? address,
    String? description,
  })
  onUpdateProperty;
  final Future<void> Function(String propertyId) onArchiveProperty;
  final Future<EstatePropertyRecord> Function({
    required String propertyId,
    required double? latitude,
    required double? longitude,
    required String confidence,
    required String source,
    double? accuracyMeters,
    required String reason,
  })
  onPreviewUpdateLocation;

  @override
  State<_PropertyRegisterPage> createState() => _PropertyRegisterPageState();
}

class _PropertyRegisterPageState extends State<_PropertyRegisterPage> {
  final _searchController = TextEditingController();
  String _occupancy = 'all';
  String _status = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final results = widget.properties.where((property) {
      final matchesSearch =
          query.isEmpty ||
          <String?>[
            property.code,
            property.propertyType,
            property.unitNumber,
            property.structureLabel,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
      final matchesOccupancy =
          _occupancy == 'all' || property.occupancyStatus == _occupancy;
      final matchesStatus = _status == 'all' || property.status == _status;
      return matchesSearch && matchesOccupancy && matchesStatus;
    }).toList();
    final summary = widget.metrics is PropertyMetrics
        ? widget.metrics as PropertyMetrics
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _SampleDataBanner(asOf: widget.asOf),
        const SizedBox(height: 24),
        Text(
          'Property register',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Estate assets, with operational status kept separate from occupancy.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _showAddProperty,
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Add property'),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FutureBuilder<List<EstatePropertyRecord>>(
            future: widget.ownershipReviews,
            builder: (context, snapshot) => OutlinedButton.icon(
              onPressed: widget.onOpenOwnershipReviews,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                'Ownership verification${snapshot.hasData ? ' · ${snapshot.requireData.length}' : ''}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 640;
            final search = TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search code, unit or structure',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            );
            final occupancy = DropdownButtonFormField<String>(
              initialValue: _occupancy,
              decoration: const InputDecoration(labelText: 'Occupancy'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All occupancy')),
                DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
                DropdownMenuItem(value: 'vacant', child: Text('Vacant')),
              ],
              onChanged: (value) => setState(() => _occupancy = value ?? 'all'),
            );
            final status = DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Property status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(
                  value: 'under_development',
                  child: Text('Under development'),
                ),
                DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                DropdownMenuItem(
                  value: 'under_maintenance',
                  child: Text('Under maintenance'),
                ),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'all'),
            );
            if (stacked) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: occupancy),
                      const SizedBox(width: 10),
                      Expanded(child: status),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: search),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: occupancy),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: status),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${results.length} preview records · ${summary?.total ?? '—'} properties in the estate summary',
          style: const TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
        const SizedBox(height: 10),
        if (results.isEmpty)
          const _EmptyAdminState(
            icon: Icons.search_off_rounded,
            title: 'No properties match these filters',
            detail: 'Try a different code, occupancy or status.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 740) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Property')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Occupancy')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Tenancy')),
                      ],
                      rows: results
                          .map(
                            (property) => DataRow(
                              onSelectChanged: (_) =>
                                  _showPropertyDetails(context, property),
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        property.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        property.structureLabel ??
                                            'No structure label',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: EstateColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(property.propertyType)),
                                DataCell(
                                  _OccupancyBadge(
                                    status: property.occupancyStatus,
                                  ),
                                ),
                                DataCell(
                                  _PropertyStatusBadge(status: property.status),
                                ),
                                DataCell(Text(property.tenancyLabel ?? '—')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              }
              return Column(
                children: results
                    .map(
                      (property) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _PropertyCard(
                          property: property,
                          onTap: () => _showPropertyDetails(context, property),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  void _showPropertyDetails(
    BuildContext context,
    EstatePropertyRecord property,
  ) {
    final pageContext = context;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PropertyDetailsDialog(
        property: property,
        onEdit: property.status == 'archived'
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _showEditProperty(pageContext, property);
              },
        onArchive:
            property.id.startsWith('preview-property-') &&
                property.status != 'archived'
            ? () {
                Navigator.of(dialogContext).pop();
                _archiveProperty(pageContext, property);
              }
            : null,
        onUpdateLocation: property.status == 'archived'
            ? null
            : () {
                Navigator.of(dialogContext).pop();
                _showPropertyLocationDialog(pageContext, property);
              },
      ),
    );
  }

  Future<void> _archiveProperty(
    BuildContext context,
    EstatePropertyRecord property,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive property?'),
        content: Text(
          '${property.code} will be marked archived in this preview. The property record stays in the register; no history is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive preview property'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.onArchiveProperty(property.id);
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not archive property.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAddProperty() async {
    final nodes = await widget.repository.loadEstateStructure();
    if (!mounted) return;
    final draft =
        await showDialog<
          ({
            String code,
            String propertyType,
            String status,
            String? parentNodeId,
            String? unitNumber,
            String? address,
            String? description,
          })
        >(
          context: context,
          builder: (context) => _PropertyDraftDialog(nodes: nodes),
        );
    if (draft == null || !mounted) return;
    try {
      await widget.onCreateProperty(
        code: draft.code,
        propertyType: draft.propertyType,
        status: draft.status,
        parentNodeId: draft.parentNodeId,
        unitNumber: draft.unitNumber,
        address: draft.address,
        description: draft.description,
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not add property.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditProperty(
    BuildContext context,
    EstatePropertyRecord property,
  ) async {
    final draft =
        await showDialog<
          ({
            String code,
            String propertyType,
            String status,
            String? parentNodeId,
            String? unitNumber,
            String? address,
            String? description,
          })
        >(
          context: context,
          builder: (context) =>
              _PropertyDraftDialog(nodes: const [], property: property),
        );
    if (draft == null || !context.mounted) return;
    try {
      await widget.onUpdateProperty(
        propertyId: property.id,
        code: draft.code,
        propertyType: draft.propertyType,
        status: draft.status,
        unitNumber: draft.unitNumber,
        address: draft.address,
        description: draft.description,
      );
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not update property.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showPropertyLocationDialog(
    BuildContext context,
    EstatePropertyRecord property,
  ) async {
    final draft =
        await showDialog<
          ({
            double? latitude,
            double? longitude,
            String confidence,
            String source,
            double? accuracyMeters,
            String reason,
          })
        >(
          context: context,
          builder: (context) => _PropertyMapLocationDialog(property: property),
        );
    if (draft == null || !context.mounted) return;
    try {
      await widget.onPreviewUpdateLocation(
        propertyId: property.id,
        latitude: draft.latitude,
        longitude: draft.longitude,
        confidence: draft.confidence,
        source: draft.source,
        accuracyMeters: draft.accuracyMeters,
        reason: draft.reason,
      );
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not update map location.',
            ),
          ),
        );
      }
    }
  }
}

class _PropertyDraftDialog extends StatefulWidget {
  const _PropertyDraftDialog({required this.nodes, this.property});
  final List<EstateStructureNode> nodes;
  final EstatePropertyRecord? property;

  @override
  State<_PropertyDraftDialog> createState() => _PropertyDraftDialogState();
}

class _PropertyDraftDialogState extends State<_PropertyDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _propertyType = TextEditingController();
  final _unitNumber = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  String _status = 'active';
  String? _parentNodeId;

  @override
  void initState() {
    super.initState();
    final property = widget.property;
    if (property == null) return;
    _code.text = property.code;
    _propertyType.text = property.propertyType;
    _unitNumber.text = property.unitNumber ?? '';
    _address.text = property.address ?? '';
    _description.text = property.description ?? '';
    _status = property.status;
  }

  @override
  void dispose() {
    _code.dispose();
    _propertyType.dispose();
    _unitNumber.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeNodes = widget.nodes.where((node) => node.status == 'active');
    return AlertDialog(
      title: Text(widget.property == null ? 'Add property' : 'Edit property'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.property == null
                        ? 'Preview only. This adds a sample property record; no owner, resident, tenancy, map location or live estate record is created.'
                        : 'Preview only. Property details are session-local; ownership, occupancy, tenancy and map location are preserved.',
                    style: TextStyle(
                      color: Color(0xFF795416),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _code,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Property code',
                    hintText: 'For example OAK-C-014',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a property code.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _propertyType,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Property type',
                    hintText: 'Apartment, townhouse, shop…',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a property type.'
                      : null,
                ),
                TextFormField(
                  controller: _unitNumber,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Unit or house number (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _address,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    hintText: 'Street, estate or landmark details',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  maxLength: 700,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Operational status',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'under_development',
                      child: Text('Under development'),
                    ),
                    DropdownMenuItem(
                      value: 'reserved',
                      child: Text('Reserved'),
                    ),
                    DropdownMenuItem(
                      value: 'under_maintenance',
                      child: Text('Under maintenance'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'active'),
                ),
                if (widget.property == null) const SizedBox(height: 10),
                if (widget.property == null)
                  DropdownButtonFormField<String>(
                    initialValue: _parentNodeId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Estate structure (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No structure link'),
                      ),
                      for (final node in activeNodes)
                        DropdownMenuItem(
                          value: node.id,
                          child: Text(
                            '${_structureTypeLabel(node.type)} · ${node.name}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () =>
                          _parentNodeId = value?.isEmpty == true ? null : value,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              code: _code.text,
              propertyType: _propertyType.text,
              status: _status,
              parentNodeId: _parentNodeId,
              unitNumber: _unitNumber.text,
              address: _address.text,
              description: _description.text,
            ));
          },
          child: Text(
            widget.property == null
                ? 'Add preview property'
                : 'Save preview changes',
          ),
        ),
      ],
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.onTap});
  final EstatePropertyRecord property;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    property.code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _PropertyStatusBadge(status: property.status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${property.propertyType}${property.unitNumber == null ? '' : ' · Unit ${property.unitNumber}'}',
              style: const TextStyle(fontSize: 11, color: EstateColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  size: 15,
                  color: EstateColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    property.structureLabel ?? 'No structure label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: EstateColors.ink,
                    ),
                  ),
                ),
                _OccupancyBadge(status: property.occupancyStatus),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PropertyDetailsDialog extends StatelessWidget {
  const _PropertyDetailsDialog({
    required this.property,
    required this.onEdit,
    required this.onArchive,
    required this.onUpdateLocation,
  });
  final EstatePropertyRecord property;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onUpdateLocation;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(property.code),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${property.propertyType}${property.unitNumber == null ? '' : ' · Unit ${property.unitNumber}'}',
        ),
        const SizedBox(height: 12),
        _DetailLine(label: 'Structure', value: property.structureLabel),
        _DetailLine(label: 'Address', value: property.address),
        _DetailLine(label: 'Description', value: property.description),
        _DetailLine(
          label: 'Operational status',
          value: _propertyStatusLabel(property.status),
        ),
        _DetailLine(
          label: 'Occupancy',
          value:
              property.occupancyLabel ??
              _occupancyLabel(property.occupancyStatus),
        ),
        _DetailLine(label: 'Ownership', value: property.ownershipLabel),
        _DetailLine(label: 'Tenancy', value: property.tenancyLabel),
        _DetailLine(
          label: 'Map location',
          value: _locationConfidenceLabel(property.locationConfidence),
        ),
        _DetailLine(label: 'Location source', value: property.locationSource),
        if (property.accuracyMeters != null)
          _DetailLine(
            label: 'Accuracy',
            value: '${property.accuracyMeters!.toStringAsFixed(0)} m',
          ),
        const SizedBox(height: 10),
        const Text(
          'Relationship labels are illustrative and depend on estate permissions.',
          style: TextStyle(fontSize: 10, color: EstateColors.muted),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (onEdit != null)
        FilledButton.tonalIcon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit details'),
        ),
      if (onUpdateLocation != null)
        FilledButton.tonalIcon(
          onPressed: onUpdateLocation,
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('Update map location'),
        ),
      if (onArchive != null)
        FilledButton.tonalIcon(
          onPressed: onArchive,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive preview property'),
        ),
    ],
  );
}

class _PropertyMapLocationDialog extends StatefulWidget {
  const _PropertyMapLocationDialog({required this.property});
  final EstatePropertyRecord property;

  @override
  State<_PropertyMapLocationDialog> createState() =>
      _PropertyMapLocationDialogState();
}

class _PropertyMapLocationDialogState
    extends State<_PropertyMapLocationDialog> {
  static const _sources = <String, String>{
    'estate_plan': 'Estate plan (sample)',
    'on_site_survey': 'On-site survey (sample)',
    'staff_observation': 'Staff observation (sample)',
  };
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _accuracy;
  final _reason = TextEditingController();
  late String _confidence;
  late String _source;

  @override
  void initState() {
    super.initState();
    _latitude = TextEditingController(
      text: widget.property.latitude?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: widget.property.longitude?.toString() ?? '',
    );
    _accuracy = TextEditingController(
      text: widget.property.accuracyMeters?.toString() ?? '',
    );
    _confidence = widget.property.locationConfidence;
    if (!_sources.containsKey(_confidence)) _confidence = 'unmapped';
    _source = _sources.containsKey(widget.property.locationSource)
        ? widget.property.locationSource!
        : 'estate_plan';
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _accuracy.dispose();
    _reason.dispose();
    super.dispose();
  }

  String? _coordinateError(
    String? value, {
    required double min,
    required double max,
  }) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || !number.isFinite || number < min || number > max) {
      return 'Enter a value from $min to $max.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Map location · ${widget.property.code}'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Preview only. Coordinates and source options are illustrative; this does not update a live map or record an audit event.',
                  style: TextStyle(
                    color: Color(0xFF795416),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _confidence,
                decoration: const InputDecoration(
                  labelText: 'Location confidence',
                ),
                items: const [
                  DropdownMenuItem(value: 'unmapped', child: Text('Unmapped')),
                  DropdownMenuItem(
                    value: 'approximate',
                    child: Text('Approximate'),
                  ),
                  DropdownMenuItem(
                    value: 'unverified',
                    child: Text('Unverified'),
                  ),
                  DropdownMenuItem(value: 'verified', child: Text('Verified')),
                ],
                onChanged: (value) => setState(() {
                  _confidence = value ?? 'unmapped';
                  if (_confidence == 'unmapped') {
                    _latitude.clear();
                    _longitude.clear();
                    _accuracy.clear();
                  }
                }),
              ),
              if (_confidence != 'unmapped') ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final width = (box.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: _latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (WGS 84)',
                            ),
                            validator: (value) =>
                                _coordinateError(value, min: -90, max: 90),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: _longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (WGS 84)',
                            ),
                            validator: (value) =>
                                _coordinateError(value, min: -180, max: 180),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _accuracy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Known accuracy in metres (optional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null ||
                        !parsed.isFinite ||
                        parsed < 0 ||
                        parsed > 100000) {
                      return 'Enter a value from 0 to 100000.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(
                  labelText: 'Source (sample options)',
                ),
                items: [
                  for (final entry in _sources.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _source = value ?? 'estate_plan'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason for this location update',
                ),
                validator: (value) => value == null || value.trim().length < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final isUnmapped = _confidence == 'unmapped';
          Navigator.pop(context, (
            latitude: isUnmapped ? null : double.parse(_latitude.text.trim()),
            longitude: isUnmapped ? null : double.parse(_longitude.text.trim()),
            confidence: _confidence,
            source: _source,
            accuracyMeters: isUnmapped || _accuracy.text.trim().isEmpty
                ? null
                : double.parse(_accuracy.text.trim()),
            reason: _reason.text,
          ));
        },
        child: const Text('Save preview location'),
      ),
    ],
  );
}

String _locationConfidenceLabel(String value) => switch (value) {
  'verified' => 'Verified',
  'approximate' => 'Approximate',
  'unverified' => 'Unverified',
  _ => 'Unmapped',
};

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'Not available',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.status});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final occupied = status == 'occupied';
    final known = status == 'occupied' || status == 'vacant';
    final color = occupied ? EstateColors.forest : EstateColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: occupied ? const Color(0xFFEAF3EE) : const Color(0xFFF0F3F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        known
            ? occupied
                  ? 'Occupied'
                  : 'Vacant'
            : 'Unknown',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PropertyStatusBadge extends StatelessWidget {
  const _PropertyStatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final issue =
        status == 'under_maintenance' ||
        status == 'inactive' ||
        status == 'archived';
    final color = issue ? EstateColors.amber : EstateColors.forest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: issue ? EstateColors.amberWash : const Color(0xFFEAF3EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _propertyStatusLabel(status),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EstateStructurePage extends StatefulWidget {
  const _EstateStructurePage({
    required this.nodes,
    required this.asOf,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onArchiveNode,
  });
  final List<EstateStructureNode> nodes;
  final DateTime asOf;
  final Future<void> Function({
    required String type,
    required String name,
    String? code,
    String? parentId,
  })
  onCreateNode;
  final Future<void> Function({
    required String nodeId,
    required String name,
    String? code,
  })
  onEditNode;
  final Future<void> Function(String nodeId) onArchiveNode;
  @override
  State<_EstateStructurePage> createState() => _EstateStructurePageState();
}

class _EstateStructurePageState extends State<_EstateStructurePage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final visible = widget.nodes
        .where((node) => _showArchived || node.status != 'archived')
        .toList();
    final roots = visible
        .where(
          (node) =>
              node.parentId == null ||
              !visible.any((parent) => parent.id == node.parentId),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _SampleDataBanner(asOf: widget.asOf),
        const SizedBox(height: 24),
        Text(
          'Zones and buildings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Explore the estate hierarchy and its linked property counts.',
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _showAddStructureNode(context),
            icon: const Icon(Icons.add),
            label: const Text('Add structure node'),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Preview only. Nothing is saved to the estate service.',
          style: TextStyle(fontSize: 11, color: EstateColors.muted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${visible.length} structure nodes in preview',
                style: const TextStyle(fontSize: 11, color: EstateColors.muted),
              ),
            ),
            FilterChip(
              label: const Text('Show archived'),
              selected: _showArchived,
              onSelected: (value) => setState(() => _showArchived = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (roots.isEmpty)
          const _EmptyAdminState(
            icon: Icons.account_tree_outlined,
            title: 'No structure configured',
            detail: 'Structure nodes will appear here when the estate hierarchy is set up.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < roots.length; index++) ...[
                  _StructureTreeNode(
                    node: roots[index],
                    nodes: visible,
                    depth: 0,
                    onEditNode: widget.onEditNode,
                    onArchiveNode: widget.onArchiveNode,
                    onEditRequest: (node) =>
                        _showEditStructureNode(context, node),
                    onArchiveRequest: (node) =>
                        _archiveStructureNode(context, node),
                  ),
                  if (index < roots.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showAddStructureNode(BuildContext context) async {
    final result =
        await showDialog<
          ({String type, String name, String? code, String? parentId})
        >(
          context: context,
          builder: (context) => _StructureNodeDraftDialog(nodes: widget.nodes),
        );
    if (result == null || !context.mounted) return;
    try {
      await widget.onCreateNode(
        type: result.type,
        name: result.name,
        code: result.code,
        parentId: result.parentId,
      );
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not add structure.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditStructureNode(
    BuildContext context,
    EstateStructureNode node,
  ) async {
    final result = await showDialog<({String name, String? code})>(
      context: context,
      builder: (context) => _EditStructureNodeDialog(node: node),
    );
    if (result == null || !context.mounted) return;
    try {
      await widget.onEditNode(
        nodeId: node.id,
        name: result.name,
        code: result.code,
      );
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not update structure.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _archiveStructureNode(
    BuildContext context,
    EstateStructureNode node,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive structure node?'),
        content: Text(
          '${node.name} will be marked archived in this preview. Its history is retained; no properties or tenancy records are deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive preview node'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.onArchiveNode(node.id);
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message?.toString() ?? 'Could not archive structure.',
            ),
          ),
        );
      }
    }
  }
}

class _EditStructureNodeDialog extends StatefulWidget {
  const _EditStructureNodeDialog({required this.node});
  final EstateStructureNode node;

  @override
  State<_EditStructureNodeDialog> createState() =>
      _EditStructureNodeDialogState();
}

class _EditStructureNodeDialogState extends State<_EditStructureNodeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.node.name);
    _code = TextEditingController(text: widget.node.code ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit structure node'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            TextFormField(
              controller: _code,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Code (optional)'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type and parent are fixed here to protect existing hierarchy links.',
              style: TextStyle(fontSize: 12, color: EstateColors.muted),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (name: _name.text, code: _code.text));
        },
        child: const Text('Save preview changes'),
      ),
    ],
  );
}

class _StructureNodeDraftDialog extends StatefulWidget {
  const _StructureNodeDraftDialog({required this.nodes});
  final List<EstateStructureNode> nodes;

  @override
  State<_StructureNodeDraftDialog> createState() =>
      _StructureNodeDraftDialogState();
}

class _StructureNodeDraftDialogState extends State<_StructureNodeDraftDialog> {
  static const _parentTypes = <String, List<String>>{
    'zone': [],
    'street': ['zone'],
    'building': ['street'],
    'floor': ['building'],
  };
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  String _type = 'zone';
  String? _parentId;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentTypes = _parentTypes[_type]!;
    final parents = widget.nodes
        .where(
          (node) => node.status == 'active' && parentTypes.contains(node.type),
        )
        .toList();
    return AlertDialog(
      title: const Text('Add structure node'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Structure type'),
                items: [
                  for (final type in _parentTypes.keys)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_structureTypeLabel(type)),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _type = value!;
                  _parentId = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              TextFormField(
                controller: _code,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Code (optional)'),
              ),
              if (parentTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _parentId,
                  decoration: InputDecoration(
                    labelText:
                        '${_structureTypeLabel(parentTypes.first)} parent',
                  ),
                  items: [
                    for (final parent in parents)
                      DropdownMenuItem(
                        value: parent.id,
                        child: Text(
                          '${parent.name}${parent.code == null ? '' : ' · ${parent.code}'}',
                        ),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Choose a parent.' : null,
                  onChanged: (value) => setState(() => _parentId = value),
                ),
                if (parents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Add an active parent node first.',
                      style: TextStyle(color: EstateColors.muted, fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              type: _type,
              name: _name.text,
              code: _code.text,
              parentId: _parentId,
            ));
          },
          child: const Text('Add preview node'),
        ),
      ],
    );
  }
}

class _StructureTreeNode extends StatelessWidget {
  const _StructureTreeNode({
    required this.node,
    required this.nodes,
    required this.depth,
    required this.onEditNode,
    required this.onArchiveNode,
    required this.onEditRequest,
    required this.onArchiveRequest,
  });
  final EstateStructureNode node;
  final List<EstateStructureNode> nodes;
  final int depth;
  final Future<void> Function({
    required String nodeId,
    required String name,
    String? code,
  })
  onEditNode;
  final Future<void> Function(String nodeId) onArchiveNode;
  final Future<void> Function(EstateStructureNode node) onEditRequest;
  final Future<void> Function(EstateStructureNode node) onArchiveRequest;

  @override
  Widget build(BuildContext context) {
    final children = nodes.where((item) => item.parentId == node.id).toList();
    return ExpansionTile(
      key: PageStorageKey<String>('structure-${node.id}'),
      initiallyExpanded: depth == 0,
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: node.status == 'archived'
            ? const Color(0xFFF0F3F1)
            : const Color(0xFFEAF3EE),
        child: Icon(
          _structureIcon(node.type),
          size: 17,
          color: node.status == 'archived'
              ? EstateColors.muted
              : EstateColors.forest,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              node.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (node.status == 'archived') const _ArchivedPill(),
        ],
      ),
      trailing: node.status == 'active'
          ? PopupMenuButton<String>(
              tooltip: 'Structure actions',
              onSelected: (action) {
                if (action == 'edit') {
                  onEditRequest(node);
                } else if (action == 'archive') {
                  onArchiveRequest(node);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit name/code'),
                ),
                PopupMenuItem(
                  value: 'archive',
                  enabled:
                      node.linkedPropertyCount == 0 &&
                      !children.any((child) => child.status == 'active'),
                  child: const Text('Archive'),
                ),
              ],
            )
          : null,
      subtitle: Text(
        '${_structureTypeLabel(node.type)}${node.code == null ? '' : ' · ${node.code}'}${node.linkedPropertyCount == null ? '' : ' · ${node.linkedPropertyCount} properties'}',
        style: const TextStyle(fontSize: 10, color: EstateColors.muted),
      ),
      children: children.isEmpty
          ? [
              const ListTile(
                dense: true,
                title: Text(
                  'No child nodes in this preview',
                  style: TextStyle(fontSize: 10, color: EstateColors.muted),
                ),
              ),
            ]
          : children
                .map(
                  (child) => _StructureTreeNode(
                    node: child,
                    nodes: nodes,
                    depth: depth + 1,
                    onEditNode: onEditNode,
                    onArchiveNode: onArchiveNode,
                    onEditRequest: onEditRequest,
                    onArchiveRequest: onArchiveRequest,
                  ),
                )
                .toList(),
    );
  }
}

class _ArchivedPill extends StatelessWidget {
  const _ArchivedPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F3F1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Archived',
      style: TextStyle(fontSize: 9, color: EstateColors.muted),
    ),
  );
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 30, color: EstateColors.muted),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
        ],
      ),
    ),
  );
}

String _occupancyLabel(String? status) => switch (status) {
  'occupied' => 'Occupied',
  'vacant' => 'Vacant',
  _ => 'Unknown',
};

String _propertyStatusLabel(String status) => switch (status) {
  'active' => 'Active',
  'under_development' => 'Under development',
  'reserved' => 'Reserved',
  'under_maintenance' => 'Under maintenance',
  'inactive' => 'Inactive',
  'archived' => 'Archived',
  _ => status,
};

String _structureTypeLabel(String type) => switch (type) {
  'zone' => 'Zone',
  'street' => 'Street',
  'building' => 'Building',
  'floor' => 'Floor',
  _ => type,
};

IconData _structureIcon(String type) => switch (type) {
  'zone' => Icons.map_outlined,
  'street' => Icons.route_outlined,
  'building' => Icons.apartment_rounded,
  'floor' => Icons.layers_outlined,
  _ => Icons.location_on_outlined,
};

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.section});
  final AdminSection section;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    children: [
      _SampleDataBanner(asOf: DateTime.utc(2026, 11, 6, 9, 30)),
      const SizedBox(height: 24),
      Text(
        _sectionLabel(section),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 7),
      Text(
        _moduleDescription(section),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_sectionIcon(section), size: 30, color: EstateColors.forest),
              const SizedBox(height: 14),
              const Text(
                'Module preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              const Text(
                'This workspace has no connected estate service for this area yet. Sample records are not presented as live data.',
                style: TextStyle(color: EstateColors.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              const _FreshnessPill(freshness: DashboardFreshness.unavailable),
            ],
          ),
        ),
      ),
    ],
  );
}

class _AdminLoadError extends StatelessWidget {
  const _AdminLoadError({
    required this.onRetry,
    this.message = 'Estate dashboard data is unavailable.',
  });
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _AccessUnavailable extends StatelessWidget {
  const _AccessUnavailable();

  @override
  Widget build(BuildContext context) => const _EmptyAdminState(
    icon: Icons.lock_outline_rounded,
    title: 'This area is not available for your account',
    detail: 'Estate access is managed by your estate administrator.',
  );
}

DashboardMetrics? _metricsWhenAvailable(DashboardSectionResult? section) =>
    section == null || section.status == DashboardDataStatus.unavailable
    ? null
    : section.metrics;

int? _maintenanceCount(EstateAdminDashboardSnapshot? dashboard) {
  if (dashboard == null ||
      !dashboard.availableSections.contains(AdminSection.maintenance)) {
    return null;
  }
  final section = dashboard.sections[AdminSection.maintenance];
  final metrics = _metricsWhenAvailable(section);
  return metrics is MaintenanceMetrics ? metrics.openRequests : null;
}

String _sectionLabel(AdminSection section) => switch (section) {
  AdminSection.overview => 'Overview',
  AdminSection.properties => 'Properties',
  AdminSection.structure => 'Zones and buildings',
  AdminSection.residents => 'Residents',
  AdminSection.landlords => 'Landlords',
  AdminSection.tenancies => 'Tenants and tenancies',
  AdminSection.billing => 'Billing and notices',
  AdminSection.rent => 'Rent management',
  AdminSection.charges => 'Administrative charges',
  AdminSection.visitors => 'Visitors',
  AdminSection.security => 'Security and incidents',
  AdminSection.maintenance => 'Maintenance',
  AdminSection.facilities => 'Facilities and bookings',
  AdminSection.communications => 'Announcements',
  AdminSection.finance => 'Finance and expenses',
  AdminSection.reports => 'Reports and analytics',
  AdminSection.team => 'Staff and permissions',
  AdminSection.settings => 'Estate settings',
};

IconData _sectionIcon(AdminSection section) => switch (section) {
  AdminSection.overview => Icons.grid_view_rounded,
  AdminSection.properties => Icons.apartment_rounded,
  AdminSection.structure => Icons.account_tree_outlined,
  AdminSection.residents => Icons.people_alt_outlined,
  AdminSection.landlords => Icons.real_estate_agent_outlined,
  AdminSection.tenancies => Icons.key_outlined,
  AdminSection.billing => Icons.receipt_long_outlined,
  AdminSection.rent => Icons.payments_outlined,
  AdminSection.charges => Icons.request_quote_outlined,
  AdminSection.visitors => Icons.qr_code_2_rounded,
  AdminSection.security => Icons.shield_outlined,
  AdminSection.maintenance => Icons.handyman_outlined,
  AdminSection.facilities => Icons.sports_tennis_rounded,
  AdminSection.communications => Icons.campaign_outlined,
  AdminSection.finance => Icons.account_balance_wallet_outlined,
  AdminSection.reports => Icons.bar_chart_rounded,
  AdminSection.team => Icons.badge_outlined,
  AdminSection.settings => Icons.settings_outlined,
};

String _moduleDescription(AdminSection section) => switch (section) {
  AdminSection.properties =>
    'Manage the estate property register and ownership records.',
  AdminSection.structure =>
    'Organize zones, streets, buildings and property groupings.',
  AdminSection.residents =>
    'Review resident profiles and estate membership requests.',
  AdminSection.landlords =>
    'Review landlord relationships and property portfolios.',
  AdminSection.tenancies => 'Track tenant occupancy and tenancy lifecycle.',
  AdminSection.billing =>
    'Issue and review estate invoices and demand notices.',
  AdminSection.rent =>
    'Track rent schedules, collection and verified payment history.',
  AdminSection.charges =>
    'Configure estate charges through authorized finance workflows.',
  AdminSection.visitors => 'Review visitor passes and estate access activity.',
  AdminSection.security =>
    'Review incidents and security activity for this estate.',
  AdminSection.maintenance =>
    'Review maintenance requests, assignments and updates.',
  AdminSection.facilities =>
    'Manage amenities, policies and facility bookings.',
  AdminSection.communications =>
    'Prepare estate announcements and resident updates.',
  AdminSection.finance =>
    'Review verified receipts, expenses and operating position.',
  AdminSection.reports =>
    'Review estate activity and authorized reporting summaries.',
  AdminSection.team =>
    'Manage estate team memberships and delegated permissions.',
  AdminSection.settings =>
    'Review estate settings, documents and service configuration.',
  AdminSection.overview => 'Monitor estate operations.',
};

String _categoryTitle(String value) => switch (value) {
  'plumbing' => 'Plumbing',
  'electrical' => 'Electrical',
  'security' => 'Security',
  'cleaning' => 'Cleaning',
  _ => 'Other',
};

IconData _categoryIcon(String value) => switch (value) {
  'plumbing' => Icons.water_drop_outlined,
  'electrical' => Icons.bolt_outlined,
  'security' => Icons.shield_outlined,
  'cleaning' => Icons.cleaning_services_outlined,
  _ => Icons.handyman_outlined,
};

String _statusTitle(String value) => switch (value) {
  'submitted' => 'Submitted',
  'under_review' => 'Under review',
  'assigned' => 'Assigned',
  'in_progress' => 'In progress',
  'awaiting_parts' => 'Awaiting parts',
  'resolved' => 'Resolved',
  'closed' => 'Closed',
  'reopened' => 'Reopened',
  'rejected' => 'Rejected',
  _ => value,
};

String _formatDate(DateTime date) => '${date.day} Nov ${date.year}';
