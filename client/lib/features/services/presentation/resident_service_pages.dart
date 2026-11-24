import 'package:flutter/material.dart';

import '../../../core/config/report_download.dart';
import '../../../core/design/dashboard_design.dart';
import '../../../core/design/service_page_scaffold.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/api.dart';
import '../../resident/presentation/resident_facilities_api_page.dart';
import '../../resident/presentation/resident_incidents_api_page.dart';

/// Everything a service page needs, passed explicitly instead of reached for
/// through global/inherited state.
class ServicePageContext {
  const ServicePageContext({
    required this.repository,
    required this.estateId,
    required this.estateName,
    this.properties = const [],
    this.estates = const [],
  });

  final EstateApplicationApiRepository repository;
  final String estateId;
  final String estateName;
  final List<({String id, String label})> properties;
  final List<ManagedEstateChoice> estates;
}

/// Single source of truth for the resident Quick Services grid.
class ResidentService {
  const ResidentService({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.open,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Widget Function(ServicePageContext context) open;
}

List<ResidentService> residentServices() => [
      ResidentService(
        id: 'levies',
        label: 'Pay Levies',
        description: 'Pay the bills your estate has billed you for, and see what you still owe.',
        icon: Icons.receipt_long_outlined,
        open: (c) => PayLeviesPage(context: c),
      ),
      ResidentService(
        id: 'rent',
        label: 'House Rent',
        description: 'See and pay the rent installments for the home you rent.',
        icon: Icons.home_outlined,
        open: (c) => HouseRentPage(context: c),
      ),
      ResidentService(
        id: 'electricity',
        label: 'Electricity',
        description: 'Buy electricity or pay for shared power using your estate wallet.',
        icon: Icons.bolt_outlined,
        open: (c) => ElectricityPage(serviceContext: c),
      ),
      ResidentService(
        id: 'airtime',
        label: 'Airtime',
        description: 'Buy phone airtime and see your past purchases.',
        icon: Icons.phone_android_outlined,
        open: (c) => AirtimePage(serviceContext: c),
      ),
      ResidentService(
        id: 'gate-pass',
        label: 'Gate Pass',
        description: 'Invite a visitor and see the passes that let them through the gate.',
        icon: Icons.qr_code_2_outlined,
        open: (c) => GatePassPage(context: c),
      ),
      ResidentService(
        id: 'water',
        label: 'Water',
        description: 'Pay for water and view your water orders.',
        icon: Icons.water_drop_outlined,
        open: (c) => WaterPage(serviceContext: c),
      ),
      ResidentService(
        id: 'waste',
        label: 'Waste',
        description: 'Pay for waste collection and view your orders.',
        icon: Icons.delete_outline,
        open: (c) => WastePage(serviceContext: c),
      ),
      ResidentService(
        id: 'maintenance',
        label: 'Maintenance',
        description: 'Tell us something is broken and follow the repair status.',
        icon: Icons.build_outlined,
        open: (c) => MaintenancePage(context: c),
      ),
      ResidentService(
        id: 'facilities',
        label: 'Facilities',
        description: 'See shared spaces you can book and request a time.',
        icon: Icons.calendar_month_outlined,
        open: (c) => FacilitiesServicePage(serviceContext: c),
      ),
      ResidentService(
        id: 'emergency',
        label: 'Emergency',
        description: 'Tell estate staff about an emergency or safety problem.',
        icon: Icons.warning_amber_outlined,
        open: (c) => EmergencyPage(serviceContext: c),
      ),
      ResidentService(
        id: 'documents',
        label: 'Documents',
        description: 'Find and download the documents and receipts for your account.',
        icon: Icons.description_outlined,
        open: (c) => DocumentsPage(context: c),
      ),
      ResidentService(
        id: 'more',
        label: 'More Services',
        description: 'All the services you can use, listed in one place.',
        icon: Icons.apps_outlined,
        open: (c) => MoreServicesPage(serviceContext: c),
      ),
    ];

/// Opens a service page as a real route.
Future<T?> openServicePage<T extends Object?>(BuildContext context, Widget page) =>
    AppNavigation.push<T>(context, page);

// ---------------------------------------------------------------------------
// Pay Levies
// ---------------------------------------------------------------------------

class PayLeviesPage extends StatefulWidget {
  const PayLeviesPage({super.key, required this.context});
  final ServicePageContext context;

  @override
  State<PayLeviesPage> createState() => _PayLeviesPageState();
}

class _PayLeviesPageState extends State<PayLeviesPage> {
  List<Map<String, dynamic>> _invoices = const [];
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
      _invoices = await widget.context.repository.loadMyInvoiceRecords();
    } catch (error) {
      _error = 'Invoices could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'levies');
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _invoices.isEmpty
                  ? const ServiceStateMessage(message: 'No invoices have been issued for your property yet.')
                  : Column(
                      children: [
                        DashboardSectionTitle(title: 'Outstanding Payments'),
                        ..._invoices.map(
                          (invoice) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined, color: DashboardTokens.greenLeaf),
                              title: Text(
                                invoice['description']?.toString() ?? invoice['invoiceNumber']?.toString() ?? 'Invoice',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${invoice['propertyCode'] ?? ''} · due ${invoice['dueDate'] ?? '—'} · ${invoice['status'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                AppFormat.money(invoice['balance'] ?? invoice['total'] ?? '0'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// House Rent
// ---------------------------------------------------------------------------

class HouseRentPage extends StatefulWidget {
  const HouseRentPage({super.key, required this.context});
  final ServicePageContext context;

  @override
  State<HouseRentPage> createState() => _HouseRentPageState();
}

class _HouseRentPageState extends State<HouseRentPage> {
  List<RentScheduleRecord> _rows = const [];
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
      _rows = await widget.context.repository.loadRentSchedule(widget.context.estateId);
    } catch (_) {
      _error = 'Rent installments could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(RentScheduleRecord row) async {
    try {
      await widget.context.repository.payRentSchedule(scheduleId: row.id, amount: row.balance);
      await _load();
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment could not be completed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'rent');
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _rows.isEmpty
                  ? const ServiceStateMessage(message: 'No rent installments are scheduled yet.')
                  : Column(
                      children: _rows.map(
                        (row) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.home_outlined, color: DashboardTokens.greenLeaf),
                            title: Text('${row.currency} ${row.amount} · ${row.status}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${row.periodStart} – ${row.periodEnd} · due ${row.dueDate}'
                              '${row.isOverdue ? ' · overdue' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: row.balance == '0'
                                ? const Icon(Icons.check_circle, color: DashboardTokens.greenLeaf)
                                : TextButton(
                                    onPressed: () => _pay(row),
                                    child: const Text('Pay'),
                                  ),
                          ),
                        ),
                      ).toList(),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utility services (Electricity / Airtime / Water / Waste)
// ---------------------------------------------------------------------------

class ElectricityPage extends StatelessWidget {
  const ElectricityPage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;
  @override
  Widget build(BuildContext context) => UtilityServicePage(
        serviceId: 'electricity', context: serviceContext, categoryKeyword: 'electric',
      );
}

class AirtimePage extends StatelessWidget {
  const AirtimePage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;
  @override
  Widget build(BuildContext context) => UtilityServicePage(
        serviceId: 'airtime', context: serviceContext, categoryKeyword: 'airtime',
      );
}

class WaterPage extends StatelessWidget {
  const WaterPage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;
  @override
  Widget build(BuildContext context) => UtilityServicePage(
        serviceId: 'water', context: serviceContext, categoryKeyword: 'water',
      );
}

class WastePage extends StatelessWidget {
  const WastePage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;
  @override
  Widget build(BuildContext context) => UtilityServicePage(
        serviceId: 'waste', context: serviceContext, categoryKeyword: 'waste',
      );
}

class UtilityServicePage extends StatefulWidget {
  const UtilityServicePage({
    super.key,
    required this.serviceId,
    required this.context,
    required this.categoryKeyword,
  });

  final String serviceId;
  final ServicePageContext context;
  final String categoryKeyword;

  @override
  State<UtilityServicePage> createState() => _UtilityServicePageState();
}

class _UtilityServicePageState extends State<UtilityServicePage> {
  List<EstateServiceRecord> _services = const [];
  List<EstateServiceOrderRecord> _orders = const [];
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
      final all = await widget.context.repository.loadEstateServices(widget.context.estateId);
      _services = all.where((item) {
        if (item.status != 'active') return false;
        final haystack = '${item.category} ${item.name} ${item.code}'.toLowerCase();
        return haystack.contains(widget.categoryKeyword);
      }).toList();
      _orders = await widget.context.repository.loadEstateServiceOrders(widget.context.estateId);
    } catch (_) {
      _error = 'Services could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _order(EstateServiceRecord service) async {
    final key = 'svc-${widget.serviceId}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await widget.context.repository.orderEstateService(
        estateId: widget.context.estateId,
        serviceId: service.id,
        idempotencyKey: key,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.demo
                ? 'Demo order fulfilled · ${result.fulfilmentCode ?? 'voucher'}'
                : 'Service ordered successfully.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order could not be completed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == widget.serviceId);
    final relevantOrders = _orders.where((order) {
      final haystack = order.provider.toLowerCase();
      return haystack.contains(widget.categoryKeyword);
    }).toList();
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardSectionTitle(title: 'Available ${service.label} services'),
                    const SizedBox(height: 6),
                    if (_services.isEmpty)
                      ServiceStateMessage(
                        message: 'No ${service.label.toLowerCase()} service is enabled for this estate yet.',
                      )
                    else
                      ..._services.map(
                        (item) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: DashboardTokens.surfaceRaised,
                              child: Icon(service.icon, color: DashboardTokens.greenLeaf, size: 18),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${item.currency} ${item.amount} · ${item.provider}${item.demo ? ' · demo service' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: FilledButton(
                              onPressed: () => _order(item),
                              child: const Text('Order'),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    DashboardSectionTitle(title: 'Order history'),
                    if (relevantOrders.isEmpty)
                      const ServiceStateMessage(message: 'No orders in this category yet.')
                    else
                      ...relevantOrders.take(8).map(
                            (order) => Card(
                              child: ListTile(
                                title: Text('${order.currency} ${order.amount} · ${order.status}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${order.provider}${order.demo ? ' · demo' : ''} · ${order.fulfilmentCode ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gate Pass
// ---------------------------------------------------------------------------

class GatePassPage extends StatefulWidget {
  const GatePassPage({super.key, required this.context});
  final ServicePageContext context;

  @override
  State<GatePassPage> createState() => _GatePassPageState();
}

class _GatePassPageState extends State<GatePassPage> {
  List<ResidentVisitorPassRecord> _passes = const [];
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
      _passes = await widget.context.repository.loadMyVisitorPasses(widget.context.estateId);
    } catch (_) {
      _error = 'Visitor passes could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'gate-pass');
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _passes.isEmpty
                  ? const ServiceStateMessage(message: 'No visitor passes have been created yet.')
                  : Column(
                      children: _passes.map(
                        (pass) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_2_outlined, color: DashboardTokens.greenLeaf),
                            title: Text(pass.visitorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${pass.propertyLabel} · ${pass.validFrom} – ${pass.validUntil} · ${pass.status}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Maintenance
// ---------------------------------------------------------------------------

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key, required this.context});
  final ServicePageContext context;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  List<ResidentMaintenanceRecord> _requests = const [];
  bool _loading = true;
  String? _error;
  final _description = TextEditingController();
  String _category = 'plumbing';
  String _priority = 'normal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _requests = await widget.context.repository.loadMyMaintenanceRequests(widget.context.estateId);
    } catch (_) {
      _error = 'Maintenance requests could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final propertyId = widget.context.properties.firstOrNull?.id;
    if (propertyId == null || _description.text.trim().isEmpty) return;
    try {
      await widget.context.repository.createMaintenanceRequest(
        estateId: widget.context.estateId,
        propertyId: propertyId,
        category: _category,
        priority: _priority,
        description: _description.text.trim(),
        idempotencyKey: 'maint-${DateTime.now().microsecondsSinceEpoch}',
      );
      _description.clear();
      await _load();
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request could not be submitted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'maintenance');
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const ['plumbing', 'electrical', 'structural', 'other']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _category = value ?? 'plumbing'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const ['low', 'normal', 'high', 'emergency']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Describe the issue'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(onPressed: _submit, child: const Text('Submit request')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          DashboardSectionTitle(title: 'My requests'),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            ServiceStateMessage(message: _error!, error: true, onRetry: _load)
          else if (_requests.isEmpty)
            const ServiceStateMessage(message: 'No maintenance requests yet.')
          else
            ..._requests.map(
              (request) => Card(
                child: ListTile(
                  leading: const Icon(Icons.build_outlined, color: DashboardTokens.greenLeaf),
                  title: Text(request.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${request.description} · ${request.status}',
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Facilities / Emergency / Documents / More
// ---------------------------------------------------------------------------

class FacilitiesServicePage extends StatelessWidget {
  const FacilitiesServicePage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;

  @override
  Widget build(BuildContext context) {
    return ResidentFacilitiesApiPage(
      repository: serviceContext.repository,
      estateId: serviceContext.estateId,
      estateName: serviceContext.estateName,
      properties: serviceContext.properties,
    );
  }
}

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;

  @override
  Widget build(BuildContext context) {
    return ResidentIncidentsApiPage(
      repository: serviceContext.repository,
      estates: serviceContext.estates,
      onBack: () => Navigator.of(context).pop(),
    );
  }
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.context});
  final ServicePageContext context;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<EstateApplicationDocumentRecord> _documents = const [];
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
      _documents = await widget.context.repository.loadMyApplicationDocuments();
    } catch (_) {
      _error = 'Documents could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(EstateApplicationDocumentRecord document) async {
    try {
      final bytes = await widget.context.repository.downloadMyApplicationDocument(document.id);
      downloadReportBytes('${document.category}-${document.displayName}', bytes);
    } catch (_) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document could not be downloaded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = residentServices().firstWhere((item) => item.id == 'documents');
    return ServicePageScaffold(
      title: service.label,
      description: '${widget.context.estateName} · ${service.description}',
      icon: service.icon,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ServiceStateMessage(message: _error!, error: true, onRetry: _load)
              : _documents.isEmpty
                  ? const ServiceStateMessage(message: 'No documents have been uploaded yet.')
                  : Column(
                      children: _documents.map(
                        (document) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.description_outlined, color: DashboardTokens.greenLeaf),
                            title: Text(document.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${document.category} · ${document.status}',
                                style: const TextStyle(fontSize: 11)),
                            trailing: IconButton(
                              tooltip: 'Download',
                              onPressed: () => _download(document),
                              icon: const Icon(Icons.download_outlined),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
    );
  }
}

class MoreServicesPage extends StatelessWidget {
  const MoreServicesPage({super.key, required this.serviceContext});
  final ServicePageContext serviceContext;

  @override
  Widget build(BuildContext context) {
    final services = residentServices().where((item) => item.id != 'more').toList();
    return ServicePageScaffold(
      title: 'More Services',
      description: '${serviceContext.estateName} · Every service available to you.',
      icon: Icons.apps_outlined,
      child: DashboardQuickServices(
        services: services
            .map(
              (service) => DashboardService(
                icon: service.icon,
                label: service.label,
                onTap: () => openServicePage(context, service.open(serviceContext)),
              ),
            )
            .toList(),
      ),
    );
  }
}




