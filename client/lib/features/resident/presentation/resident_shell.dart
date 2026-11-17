import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../admin/data/estate_admin_repository.dart';
import '../../admin/presentation/estate_admin_shell.dart';
import '../data/resident_estate_repository.dart';
import 'maintenance_request_form.dart';
import 'resident_facilities_page.dart';
import 'resident_invoices_page.dart';
import 'resident_notices_page.dart';
import 'resident_visitor_passes_page.dart';
import 'resident_property_page.dart';
import 'resident_charges_page.dart';
import 'resident_rent_page.dart';
import 'resident_map_page.dart';

class ResidentShell extends StatefulWidget {
  const ResidentShell({super.key, required this.repository});

  final ResidentEstateRepository repository;

  @override
  State<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends State<ResidentShell> {
  static const _destinations = <_Destination>[
    _Destination('Home', Icons.home_rounded),
    _Destination('Requests', Icons.handyman_outlined),
    _Destination('Community', Icons.apartment_rounded),
    _Destination('Account', Icons.person_outline_rounded),
  ];

  int _selectedIndex = 0;
  late Future<ResidentOverview> _overview;
  late Future<List<ResidentMaintenanceRequest>> _requests;
  late Future<
    ({
      List<ResidentFacility> facilities,
      List<ResidentFacilityBooking> bookings,
    })
  >
  _facilityData;
  bool _showFacilities = false;
  late Future<List<ResidentVisitorPass>> _visitorPasses;
  bool _showVisitorPasses = false;
  late Future<List<ResidentAnnouncement>> _announcements;
  bool _showNotices = false;
  late Future<List<ResidentInvoice>> _invoices;
  bool _showInvoices = false;
  late Future<List<ResidentPropertyDetail>> _myProperties;
  bool _showProperty = false;
  late Future<List<ResidentEstateCharge>> _myCharges;
  bool _showCharges = false;
  late Future<ResidentRentSummary?> _myRent;
  bool _showRent = false;
  late Future<ResidentEstateMap> _estateMap;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _overview = widget.repository.loadOverview();
    _requests = widget.repository.loadMyMaintenanceRequests();
    _facilityData = _loadFacilityData();
    _visitorPasses = widget.repository.loadMyVisitorPasses();
    _announcements = widget.repository.loadMyAnnouncements();
    _invoices = widget.repository.loadMyInvoices();
    _myProperties = widget.repository.loadMyProperties();
    _myCharges = widget.repository.loadMyApplicableCharges();
    _myRent = widget.repository.loadMyRentSummary();
    _estateMap = widget.repository.loadMyEstateMap();
  }

  void _reloadOverview() =>
      setState(() => _overview = widget.repository.loadOverview());
  void _reloadRequests() =>
      setState(() => _requests = widget.repository.loadMyMaintenanceRequests());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResidentOverview>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _LoadFailure(onRetry: _reloadOverview);
        if (!snapshot.hasData) return const _LoadingState();
        final overview = snapshot.requireData;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        backgroundColor: Colors.white,
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) =>
                            setState(() => _selectedIndex = index),
                        labelType: NavigationRailLabelType.all,
                        destinations: _destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(overview: overview),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: _page(overview),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      destinations: _destinations
                          .map(
                            (item) => NavigationDestination(
                              icon: Icon(item.icon),
                              label: item.label,
                            ),
                          )
                          .toList(),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _page(ResidentOverview overview) {
    switch (_selectedIndex) {
      case 1:
        return FutureBuilder<List<ResidentMaintenanceRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _InlineFailure(onRetry: _reloadRequests);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _RequestsPage(
              requests: snapshot.requireData,
              onCreate: _openMaintenanceRequest,
              onOpen: _openMaintenanceDetails,
            );
          },
        );
      case 2:
        if (_showRent) {
          return FutureBuilder<ResidentRentSummary?>(
            future: _myRent,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadMyRent);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rent = snapshot.requireData;
              if (rent == null) {
                return _NoRentRelationship(
                  onBack: () => setState(() => _showRent = false),
                );
              }
              return ResidentRentPage(
                rent: rent,
                onBack: () => setState(() => _showRent = false),
                onOpenInvoices: _openInvoices,
              );
            },
          );
        }
        if (_showMap) {
          return FutureBuilder<ResidentEstateMap>(
            future: _estateMap,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadEstateMap);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentMapPage(
                map: snapshot.requireData,
                onBack: () => setState(() => _showMap = false),
              );
            },
          );
        }
        if (_showProperty) {
          return FutureBuilder<List<ResidentPropertyDetail>>(
            future: _myProperties,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadMyProperty);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentPropertyPage(
                properties: snapshot.requireData,
                onBack: () => setState(() => _showProperty = false),
              );
            },
          );
        }
        if (_showCharges) {
          return FutureBuilder<List<ResidentEstateCharge>>(
            future: _myCharges,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadMyCharges);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentChargesPage(
                charges: snapshot.requireData,
                onBack: () => setState(() => _showCharges = false),
              );
            },
          );
        }
        if (_showFacilities) {
          return FutureBuilder<
            ({
              List<ResidentFacility> facilities,
              List<ResidentFacilityBooking> bookings,
            })
          >(
            future: _facilityData,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadFacilityData);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentFacilitiesPage(
                facilities: snapshot.requireData.facilities,
                bookings: snapshot.requireData.bookings,
                onBack: () => setState(() => _showFacilities = false),
                repository: widget.repository,
                onBookingsChanged: _reloadFacilityData,
              );
            },
          );
        }
        if (_showVisitorPasses) {
          return FutureBuilder<List<ResidentVisitorPass>>(
            future: _visitorPasses,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadVisitorPasses);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentVisitorPassesPage(
                passes: snapshot.requireData,
                onBack: () => setState(() => _showVisitorPasses = false),
                repository: widget.repository,
                onPassesChanged: _reloadVisitorPasses,
                estateId: 'preview-estate',
              );
            },
          );
        }
        if (_showNotices) {
          return FutureBuilder<List<ResidentAnnouncement>>(
            future: _announcements,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadAnnouncements);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentNoticesPage(
                announcements: snapshot.requireData,
                onBack: () => setState(() => _showNotices = false),
                onAnnouncementOpened: _markAnnouncementRead,
              );
            },
          );
        }
        if (_showInvoices) {
          return FutureBuilder<List<ResidentInvoice>>(
            future: _invoices,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineFailure(onRetry: _reloadInvoices);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ResidentInvoicesPage(
                invoices: snapshot.requireData,
                onBack: () => setState(() => _showInvoices = false),
              );
            },
          );
        }
        return _CommunityPage(
          onOpenMap: () => setState(() => _showMap = true),
          onOpenRent: () => setState(() => _showRent = true),
          onOpenProperty: () => setState(() => _showProperty = true),
          onOpenCharges: () => setState(() => _showCharges = true),
          onOpenFacilities: () => setState(() => _showFacilities = true),
          onOpenVisitorPasses: () => setState(() => _showVisitorPasses = true),
          onOpenNotices: () => setState(() => _showNotices = true),
          onOpenInvoices: _openInvoices,
        );
      case 3:
        return FutureBuilder<List<ResidentMaintenanceRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _InlineFailure(onRetry: _reloadRequests);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<List<ResidentPropertyDetail>>(
              future: _myProperties,
              builder: (context, propertySnapshot) {
                if (propertySnapshot.hasError) {
                  return _InlineFailure(onRetry: _reloadMyProperty);
                }
                if (!propertySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _AccountPage(
                  overview: overview,
                  requests: snapshot.requireData,
                  properties: propertySnapshot.requireData,
                  onOpenRequests: () => setState(() => _selectedIndex = 1),
                  onOpenRequest: _openMaintenanceDetails,
                );
              },
            );
          },
        );
      default:
        return _HomePage(
          overview: overview,
          onOpen: (index) => setState(() => _selectedIndex = index),
          onOpenInvoices: _openInvoices,
          onOpenVisitorPasses: () => setState(() {
            _selectedIndex = 2;
            _showVisitorPasses = true;
          }),
          onOpenFacilities: () => setState(() {
            _selectedIndex = 2;
            _showFacilities = true;
          }),
        );
    }
  }

  Future<
    ({
      List<ResidentFacility> facilities,
      List<ResidentFacilityBooking> bookings,
    })
  >
  _loadFacilityData() async {
    final facilities = await widget.repository.loadResidentFacilities();
    final bookings = await widget.repository.loadMyFacilityBookings();
    return (facilities: facilities, bookings: bookings);
  }

  void _reloadFacilityData() =>
      setState(() => _facilityData = _loadFacilityData());

  void _reloadVisitorPasses() =>
      setState(() => _visitorPasses = widget.repository.loadMyVisitorPasses());

  void _reloadAnnouncements() =>
      setState(() => _announcements = widget.repository.loadMyAnnouncements());

  Future<void> _markAnnouncementRead(String announcementId) async {
    try {
      final current = await _announcements;
      await widget.repository.markAnnouncementRead(announcementId);
      if (!mounted) return;
      final refreshed = current
          .map((announcement) {
            if (announcement.id != announcementId || announcement.read) {
              return announcement;
            }
            return ResidentAnnouncement(
              id: announcement.id,
              title: announcement.title,
              category: announcement.category,
              publishedAt: announcement.publishedAt,
              body: announcement.body,
              audienceLabel: announcement.audienceLabel,
              emergency: announcement.emergency,
              read: true,
            );
          })
          .toList(growable: false);
      setState(() => _announcements = Future.value(refreshed));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Read status could not be updated.')),
      );
    }
  }

  void _reloadInvoices() =>
      setState(() => _invoices = widget.repository.loadMyInvoices());

  void _reloadMyProperty() =>
      setState(() => _myProperties = widget.repository.loadMyProperties());

  void _reloadMyCharges() =>
      setState(() => _myCharges = widget.repository.loadMyApplicableCharges());

  void _reloadMyRent() =>
      setState(() => _myRent = widget.repository.loadMyRentSummary());

  void _reloadEstateMap() =>
      setState(() => _estateMap = widget.repository.loadMyEstateMap());

  void _openInvoices() => setState(() {
    _invoices = widget.repository.loadMyInvoices();
    _selectedIndex = 2;
    _showInvoices = true;
  });

  Future<void> _openMaintenanceRequest() async {
    final created = await showModalBottomSheet<ResidentMaintenanceRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          MaintenanceRequestForm(repository: widget.repository),
    );
    if (created != null && mounted) {
      _reloadRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${created.reference} added to preview.'),
        ),
      );
    }
  }

  Future<void> _openMaintenanceDetails(ResidentMaintenanceRequest request) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _MaintenanceRequestDetails(request: request),
      );
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.overview});
  final ResidentOverview overview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EstateColors.forest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estate Management',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EstateColors.ink,
                  ),
                ),
                Text(
                  '${overview.estateName} · ${overview.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () =>
                _showMessage(context, 'Notifications will appear here.'),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFFE4EFE8),
            child: Text(
              'A',
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
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.overview,
    required this.onOpen,
    required this.onOpenInvoices,
    required this.onOpenVisitorPasses,
    required this.onOpenFacilities,
  });
  final ResidentOverview overview;
  final ValueChanged<int> onOpen;
  final VoidCallback onOpenInvoices;
  final VoidCallback onOpenVisitorPasses;
  final VoidCallback onOpenFacilities;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PreviewNotice(),
          const SizedBox(height: 20),
          Text(
            'Good morning, ${overview.residentName}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'Here’s what’s happening at home.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _HomeSummaryCard(overview: overview, onPay: onOpenInvoices),
          const SizedBox(height: 22),
          _SectionHeading(
            title: 'Quick services',
            action: 'See all',
            onTap: () => onOpen(2),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 620 ? 4 : 2;
              final spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (count - 1)) / count;
              final actions = [
                _ServiceAction(
                  'Maintenance',
                  Icons.handyman_outlined,
                  const Color(0xFFEAF3EE),
                  EstateColors.forest,
                  () => onOpen(1),
                ),
                _ServiceAction(
                  'Visitors',
                  Icons.qr_code_2_rounded,
                  const Color(0xFFFFF3E3),
                  EstateColors.amber,
                  onOpenVisitorPasses,
                ),
                _ServiceAction(
                  'Facilities',
                  Icons.sports_tennis_rounded,
                  const Color(0xFFEAF0FA),
                  const Color(0xFF3D6597),
                  onOpenFacilities,
                ),
                _ServiceAction(
                  'Bills',
                  Icons.receipt_long_outlined,
                  const Color(0xFFF1ECF8),
                  const Color(0xFF7653A3),
                  onOpenInvoices,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: actions
                    .map((action) => SizedBox(width: width, child: action))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 22),
          _SafetyCard(
            onTap: () => _showMessage(
              context,
              'For immediate danger, contact emergency services and your estate security desk directly.',
            ),
          ),
          const SizedBox(height: 22),
          _SectionHeading(
            title: 'Recent activity',
            action: 'View requests',
            onTap: () => onOpen(1),
          ),
          const SizedBox(height: 10),
          _ActivityCard(activities: overview.activities),
          const SizedBox(height: 22),
          _PropertyFooter(overview: overview),
        ],
      ),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: EstateColors.amberWash,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: EstateColors.amber, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sample estate information · Changes are not saved.',
            style: TextStyle(
              color: EstateColors.amber,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({required this.overview, required this.onPay});
  final ResidentOverview overview;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [EstateColors.forest, EstateColors.forestDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18093C2F),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFFBDE2CE),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${overview.estateName}  /  ${overview.propertyLabel}',
                  style: const TextStyle(
                    color: Color(0xFFE2F1E9),
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDE2CE)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'OUTSTANDING BALANCE',
            style: TextStyle(
              color: Color(0xFFBDE2CE),
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  overview.balanceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                overview.balanceDueLabel,
                style: const TextStyle(color: Color(0xFFE2F1E9), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.build_outlined,
                  value: '${overview.openRequests} open',
                  label: 'requests',
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0x44FFFFFF)),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.event_available_outlined,
                  value: overview.nextFacilityBooking.split(' · ').first,
                  label: 'next booking',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onPay,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: EstateColors.forest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text('View bill'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFFBDE2CE)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBDE2CE), fontSize: 10),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _ServiceAction extends StatelessWidget {
  const _ServiceAction(
    this.title,
    this.icon,
    this.background,
    this.foreground,
    this.onTap,
  );
  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: foreground, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: EstateColors.muted,
              size: 19,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shield_outlined, color: EstateColors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need urgent help?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: EstateColors.ink,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Contact emergency services and your security desk.',
                    style: TextStyle(fontSize: 11, color: EstateColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: EstateColors.forest,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities});
  final List<ResidentActivity> activities;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var index = 0; index < activities.length; index++) ...[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEAF3EE),
              child: Icon(
                _activityIcon(activities[index].iconKey),
                size: 19,
                color: EstateColors.forest,
              ),
            ),
            title: Text(
              activities[index].title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              activities[index].detail,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              activities[index].whenLabel,
              style: const TextStyle(fontSize: 10, color: EstateColors.muted),
            ),
          ),
          if (index != activities.length - 1)
            const Divider(height: 1, indent: 66, endIndent: 16),
        ],
      ],
    ),
  );
}

class _PropertyFooter extends StatelessWidget {
  const _PropertyFooter({required this.overview});
  final ResidentOverview overview;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded, color: EstateColors.forest),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overview.propertyLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${overview.estateName} · ${overview.location}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showMessage(
              context,
              'Property details are not available in this preview.',
            ),
            child: const Text('Details'),
          ),
        ],
      ),
    ),
  );
}

class _RequestsPage extends StatelessWidget {
  const _RequestsPage({
    required this.requests,
    required this.onCreate,
    required this.onOpen,
  });
  final List<ResidentMaintenanceRequest> requests;
  final VoidCallback onCreate;
  final ValueChanged<ResidentMaintenanceRequest> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      const _PreviewNotice(),
      const SizedBox(height: 20),
      Text(
        'Maintenance requests',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 5),
      const Text('Track repairs and updates shared by your estate team.'),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      const SizedBox(height: 18),
      for (final request in requests) ...[
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onOpen(request),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryLabel(request.category),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusPill(label: _statusLabel(request.status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.description,
                    style: const TextStyle(color: EstateColors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        request.reference,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EstateColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        request.updatedLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EstateColors.muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: EstateColors.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _MaintenanceRequestDetails extends StatelessWidget {
  const _MaintenanceRequestDetails({required this.request});

  final ResidentMaintenanceRequest request;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Request details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryLabel(request.category),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusPill(label: _statusLabel(request.status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(request.description),
                const SizedBox(height: 16),
                Text(
                  '${request.reference} · ${request.updatedLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EstateColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Updates', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (request.residentVisibleUpdates.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your estate team has not shared an update yet.',
                style: TextStyle(color: EstateColors.muted),
              ),
            ),
          )
        else
          for (final update in request.residentVisibleUpdates) ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF3EE),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: EstateColors.forest,
                  ),
                ),
                title: Text(update.body),
                subtitle: Text(update.whenLabel),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

String _categoryLabel(String value) => switch (value) {
  'plumbing' => 'Plumbing',
  'electrical' => 'Electrical',
  'security' => 'Security',
  'cleaning' => 'Cleaning',
  _ => 'Other',
};

String _statusLabel(String value) => switch (value) {
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3EE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: EstateColors.forest,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CommunityPage extends StatelessWidget {
  const _CommunityPage({
    required this.onOpenMap,
    required this.onOpenRent,
    required this.onOpenProperty,
    required this.onOpenCharges,
    required this.onOpenFacilities,
    required this.onOpenVisitorPasses,
    required this.onOpenNotices,
    required this.onOpenInvoices,
  });
  final VoidCallback onOpenMap;
  final VoidCallback onOpenFacilities;
  final VoidCallback onOpenRent;
  final VoidCallback onOpenProperty;
  final VoidCallback onOpenCharges;
  final VoidCallback onOpenVisitorPasses;
  final VoidCallback onOpenNotices;
  final VoidCallback onOpenInvoices;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      const _PreviewNotice(),
      const SizedBox(height: 20),
      Text(
        'Community services',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 5),
      const Text('Everyday services for your estate.'),
      const SizedBox(height: 18),
      _CommunityTile(
        icon: Icons.map_outlined,
        title: 'Estate map',
        detail: 'Find shared spaces and your mapped property.',
        onTap: onOpenMap,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.payments_outlined,
        title: 'My Rent',
        detail: 'View rent terms for an active tenancy.',
        onTap: onOpenRent,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.home_work_outlined,
        title: 'My property',
        detail: 'View your home and approved household relationships.',
        onTap: onOpenProperty,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.request_quote_outlined,
        title: 'Estate charges',
        detail: 'Review charge rules for your property.',
        onTap: onOpenCharges,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.qr_code_2_rounded,
        title: 'Visitor passes',
        detail: 'Invite guests and follow entry status.',
        onTap: onOpenVisitorPasses,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.sports_tennis_rounded,
        title: 'Facilities',
        detail: 'Check availability and manage bookings.',
        onTap: onOpenFacilities,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.campaign_outlined,
        title: 'Community notices',
        detail: 'Read updates from your estate team.',
        onTap: onOpenNotices,
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.receipt_long_outlined,
        title: 'Invoices and receipts',
        detail: 'Review charges and verified payments.',
        onTap: onOpenInvoices,
      ),
    ],
  );
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF3EE),
        child: Icon(icon, color: EstateColors.forest),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.overview,
    required this.requests,
    required this.properties,
    required this.onOpenRequests,
    required this.onOpenRequest,
  });

  final ResidentOverview overview;
  final List<ResidentMaintenanceRequest> requests;
  final List<ResidentPropertyDetail> properties;
  final VoidCallback onOpenRequests;
  final ValueChanged<ResidentMaintenanceRequest> onOpenRequest;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      const _PreviewNotice(),
      const SizedBox(height: 14),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 82,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE6F0E5), Color(0xFFF6F4E8)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.home_work_outlined,
                  size: 40,
                  color: EstateColors.forest,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  Transform.translate(
                    offset: const Offset(0, -23),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFE4EFE8),
                        child: Text(
                          overview.residentName.isEmpty
                              ? '?'
                              : overview.residentName[0].toUpperCase(),
                          style: const TextStyle(
                            color: EstateColors.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -15),
                    child: Column(
                      children: [
                        Text(
                          overview.residentName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Resident of ${overview.estateName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: EstateColors.muted),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _showMessage(
                            context,
                            'Estate switching is provided by your active memberships.',
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Switch estate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EstateColors.forest,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Community requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(onPressed: onOpenRequests, child: const Text('See all')),
        ],
      ),
      if (requests.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('You have no community requests yet.'),
          ),
        )
      else
        for (final request in requests.take(3)) ...[
          Card(
            child: ListTile(
              onTap: () => onOpenRequest(request),
              title: Text(overview.estateName),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_categoryLabel(request.category)} · ${request.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    request.updatedLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: EstateColors.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _StatusPill(label: _statusLabel(request.status)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 10),
      Text('Your home', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      _CommunityTile(
        icon: Icons.home_work_outlined,
        title: overview.propertyLabel,
        detail: '${overview.estateName} · ${overview.location}',
        onTap: () => _showMessage(
          context,
          'Estate and property context comes from your active membership.',
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Household members',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            '${_activeHouseholdMembers.length}',
            style: const TextStyle(
              color: EstateColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_activeHouseholdMembers.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.people_outline_rounded),
            title: Text('No household members listed'),
            subtitle: Text('Ask your estate team about household access.'),
          ),
        )
      else
        for (final member in _activeHouseholdMembers)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAF3EE),
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: EstateColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(member.displayName),
              subtitle: Text(_householdRelationshipLabel(member.relationship)),
              trailing: const Icon(Icons.verified_user_outlined, size: 18),
            ),
          ),
      const SizedBox(height: 16),
      Text('Account settings', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      _CommunityTile(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        detail: 'Manage estate update preferences.',
        onTap: () => _showMessage(
          context,
          'Notification settings are not available in this preview.',
        ),
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.help_outline_rounded,
        title: 'Help and support',
        detail: 'Get help with estate services.',
        onTap: () => _showMessage(
          context,
          'Support information is not available in this preview.',
        ),
      ),
      const SizedBox(height: 10),
      _CommunityTile(
        icon: Icons.dashboard_outlined,
        title: 'Estate team dashboard preview',
        detail: 'Open the separate estate administration web surface.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EstateAdminShell(repository: PreviewEstateAdminRepository()),
          ),
        ),
      ),
    ],
  );

  List<ResidentPropertyRelationship> get _activeHouseholdMembers {
    final property = properties
        .where(
          (item) =>
              item.estateName == overview.estateName &&
              item.propertyLabel == overview.propertyLabel,
        )
        .firstOrNull;
    if (property == null) return const [];
    return property.occupancyRecords
        .where(
          (record) =>
              record.status == 'active' &&
              record.relationship == 'household_member',
        )
        .toList(growable: false);
  }
}

String _householdRelationshipLabel(String relationship) =>
    switch (relationship) {
      'household_member' => 'Household member',
      'tenant' => 'Tenant',
      'owner' => 'Property owner',
      _ => relationship,
    };

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
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
            const Text('Estate information is unavailable.'),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Requests could not be loaded.'),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _NoRentRelationship extends StatelessWidget {
  const _NoRentRelationship({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.key_off_outlined,
            size: 38,
            color: EstateColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No active rent record',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'My Rent is available when an active tenancy is linked to your property.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EstateColors.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Back to community'),
          ),
        ],
      ),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

IconData _activityIcon(String key) => switch (key) {
  'visitor' => Icons.qr_code_2_rounded,
  'maintenance' => Icons.handyman_outlined,
  'facility' => Icons.sports_tennis_rounded,
  _ => Icons.notifications_none_rounded,
};
