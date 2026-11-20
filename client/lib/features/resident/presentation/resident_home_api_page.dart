import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../onboarding/data/estate_application_repository.dart';
import '../data/resident_estate_repository.dart';
import 'resident_visitor_passes_page.dart';
import 'gate_security_page.dart';
import 'resident_facilities_api_page.dart';
import 'resident_incidents_api_page.dart';
import '../../notifications/presentation/estate_notifications_page.dart';

class ResidentHomeApiPage extends StatefulWidget {
  const ResidentHomeApiPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;
  @override
  State<ResidentHomeApiPage> createState() => _ResidentHomeApiPageState();
}

class _ResidentHomeApiPageState extends State<ResidentHomeApiPage> {
  final _formKey = GlobalKey<FormState>();
  final _billingSectionKey = GlobalKey();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _note = TextEditingController();
  final _maintenanceDescription = TextEditingController();
  EstateAccount? _account;
  List<ManagedEstateChoice> _memberships = const [];
  List<ManagedEstateChoice> _availableEstates = const [];
  List<JoinRequestPropertyChoice> _properties = const [];
  List<ResidentJoinRequestStatusEntry> _requests = const [];
  List<TenantTenancyRecord> _tenancies = const [];
  List<ResidentAnnouncementRecord> _announcements = const [];
  bool _announcementLoadFailed = false;
  List<Map<String, dynamic>> _invoiceRecords = const [];
  List<EstateWalletRecord> _wallets = const [];
  List<RentScheduleRecord> _rentSchedule = const [];
  List<HouseholdMemberRecord> _household = const [];
  List<IdentityVerificationRecord> _identity = const [];
  List<EstateServiceRecord> _servicesCatalogue = const [];
  List<ResidentMaintenanceRecord> _maintenanceRequests = const [];
  String? _selectedMaintenancePropertyId;
  String? _maintenanceEstateId;
  String _maintenanceCategory = 'other';
  String _maintenancePriority = 'normal';
  String? _maintenanceIdempotencyKey;
  String? _estateId;
  String? _propertyId;
  String _relationship = 'tenant';
  bool _registering = false;
  bool _restoring = true;
  bool _busy = false;
  int _selectedTab = 0;
  String? _error;
  List<ResidentVisitorPassRecord> _visitorPasses = const [];
  List<ResidentVisitorPropertyRecord> _visitorProperties = const [];
  bool _showVisitorPasses = false;
  bool _showGateSecurity = false;
  bool _showIncidents = false;
  List<EstateGateRecord> _myGates = const [];
  String? _securityEstateId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _note.dispose();
    _maintenanceDescription.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      _account = await widget.repository.restoreSession();
      if (_account != null) await _loadWorkspace();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  String? get _visitorEstateId =>
      _maintenanceEstateId ??
      _tenancies.firstOrNull?.estateId ??
      _memberships
          .where(
            (estate) => estate.roles.any(
              (role) => role == 'resident' || role == 'landlord',
            ),
          )
          .firstOrNull
          ?.id;

  List<TenantTenancyRecord> get _maintenanceEstateChoices {
    final seen = <String>{};
    return _tenancies
        .where((tenancy) => seen.add(tenancy.estateId))
        .toList(growable: false);
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering)
        await widget.repository.register(
          email: _email.text.trim(),
          displayName: _name.text.trim(),
          password: _password.text,
        );
      _account = await widget.repository.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _loadWorkspace();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _invoiceSettlementSummary(Map<String, dynamic> invoice) {
    final payments = (invoice['verifiedPayments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final paymentSummary = payments
        .map(
          (payment) =>
              'Verified ${payment['currency'] ?? invoice['currency'] ?? 'NGN'} ${payment['amount'] ?? '0.00'} · receipt ${payment['receiptNumber'] ?? ''}',
        )
        .join('\n');
    if (invoice['status'] == 'paid' || invoice['status'] == 'partially_paid') {
      if (invoice['status'] == 'paid')
        return paymentSummary.isEmpty ? 'Paid' : paymentSummary;
    }
    final settlement =
        invoice['settlement'] as Map<String, dynamic>? ?? const {};
    if (invoice['status'] == 'partially_paid' && paymentSummary.isNotEmpty) {
      return '$paymentSummary\nTransfer to ${settlement['bankName'] ?? ''} | ${settlement['accountName'] ?? ''} | ${settlement['accountNumber'] ?? ''}\nReference: ${settlement['paymentReference'] ?? invoice['invoiceNumber'] ?? ''}';
    }
    if (settlement.isEmpty)
      return 'Settlement instructions are unavailable. Contact your estate office.';
    return 'Transfer to ${settlement['bankName'] ?? ''} · ${settlement['accountName'] ?? ''} · ${settlement['accountNumber'] ?? ''}\nReference: ${settlement['paymentReference'] ?? invoice['invoiceNumber'] ?? ''}';
  }

  Future<void> _loadWorkspace() async {
    final result = await Future.wait([
      widget.repository.loadMyEstates(),
      widget.repository.loadAvailableEstates(),
      widget.repository.loadMyJoinRequestHistory(),
      widget.repository.loadMyTenancies(),
    ]);
    _memberships = result[0] as List<ManagedEstateChoice>;
    _availableEstates = result[1] as List<ManagedEstateChoice>;
    _requests = result[2] as List<ResidentJoinRequestStatusEntry>;
    _tenancies = result[3] as List<TenantTenancyRecord>;
    try {
      _announcements = await widget.repository.loadMyAnnouncements();
      _announcementLoadFailed = false;
    } catch (_) {
      _announcements = const [];
      _announcementLoadFailed = true;
    }
    try {
      _invoiceRecords = await widget.repository.loadMyInvoiceRecords();
    } catch (_) {
      _invoiceRecords = const [];
    }
    try {
      _wallets = await widget.repository.loadMyWallets();
    } catch (_) {
      _wallets = const [];
    }
    try {
      final estateId = _memberships.firstOrNull?.id;
      _rentSchedule = estateId == null
          ? const []
          : await widget.repository.loadRentSchedule(estateId);
    } catch (_) {
      _rentSchedule = const [];
    }
    try {
      _household = await widget.repository.loadMyHousehold();
    } catch (_) {
      _household = const [];
    }
    try {
      final estateId = _memberships.firstOrNull?.id;
      _identity = estateId == null
          ? const []
          : await widget.repository.loadMyIdentityVerifications(estateId);
    } catch (_) {
      _identity = const [];
    }
    try {
      final estateId = _memberships.firstOrNull?.id;
      _servicesCatalogue = estateId == null
          ? const []
          : await widget.repository.loadEstateServices(estateId);
    } catch (_) {
      _servicesCatalogue = const [];
    }
    final securityMembership = _memberships
        .where((estate) => estate.roles.contains('security_officer'))
        .firstOrNull;
    if (securityMembership != null) {
      _securityEstateId = securityMembership.id;
      _myGates = await widget.repository.loadMyGates(securityMembership.id);
    } else {
      _securityEstateId = null;
      _myGates = const [];
    }
    final hostEstate = _memberships
        .where(
          (estate) => estate.roles.any(
            (role) => role == 'resident' || role == 'landlord',
          ),
        )
        .firstOrNull;
    final visitorEstateId =
        _maintenanceEstateId ??
        _tenancies.firstOrNull?.estateId ??
        hostEstate?.id;
    if (visitorEstateId != null) {
      try {
        final visitorData = await Future.wait([
          widget.repository.loadMyVisitorPasses(visitorEstateId),
          widget.repository.loadMyVisitorProperties(visitorEstateId),
        ]);
        _visitorPasses = visitorData[0] as List<ResidentVisitorPassRecord>;
        _visitorProperties =
            visitorData[1] as List<ResidentVisitorPropertyRecord>;
      } catch (_) {
        _visitorPasses = const [];
        _visitorProperties = const [];
      }
    } else {
      _visitorPasses = const [];
      _visitorProperties = const [];
    }
    _maintenanceEstateId = visitorEstateId;
    if (!_visitorProperties.any(
      (property) => property.id == _selectedMaintenancePropertyId,
    )) {
      _selectedMaintenancePropertyId = _visitorProperties.firstOrNull?.id;
    }
    _estateId ??= _availableEstates.firstOrNull?.id;
    await _loadProperties();
    await _loadMaintenanceRequests();
  }

  Future<void> _markAnnouncementRead(ResidentAnnouncementRecord item) async {
    if (item.read) return;
    try {
      await widget.repository.markMyAnnouncementRead(item.id);
      _announcements = await widget.repository.loadMyAnnouncements();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'This announcement could not be marked as read.',
        );
    }
  }

  Future<void> _refreshAnnouncements() async {
    try {
      final items = await widget.repository.loadMyAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = items;
        _announcementLoadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _announcementLoadFailed = true);
    }
  }

  void _openResidentBilling() {
    setState(() => _selectedTab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final section = _billingSectionKey.currentContext;
      if (section != null) {
        Scrollable.ensureVisible(
          section,
          duration: const Duration(milliseconds: 350),
          alignment: 0.08,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadProperties() async {
    final estateId = _estateId;
    if (estateId == null) {
      _properties = const [];
      _propertyId = null;
      return;
    }
    _properties = await widget.repository.loadJoinRequestProperties(estateId);
    if (!_properties.any((property) => property.id == _propertyId))
      _propertyId = null;
  }

  Future<void> _loadMaintenanceRequests() async {
    final estateId = _maintenanceEstateId ?? _visitorEstateId;
    if (estateId == null || estateId.isEmpty) {
      _maintenanceRequests = const [];
      return;
    }
    _maintenanceRequests = await widget.repository.loadMyMaintenanceRequests(
      estateId,
    );
  }

  void _selectMaintenanceProperty(String? propertyId) {
    if (propertyId == null) return;
    setState(() => _selectedMaintenancePropertyId = propertyId);
  }

  Future<void> _selectMaintenanceEstate(TenantTenancyRecord tenancy) async {
    setState(() {
      _maintenanceEstateId = tenancy.estateId;
      _selectedMaintenancePropertyId = tenancy.propertyId;
      _busy = true;
      _error = null;
    });
    try {
      final data = await Future.wait([
        widget.repository.loadMyVisitorPasses(tenancy.estateId),
        widget.repository.loadMyVisitorProperties(tenancy.estateId),
      ]);
      _visitorPasses = data[0] as List<ResidentVisitorPassRecord>;
      _visitorProperties = data[1] as List<ResidentVisitorPropertyRecord>;
      await _loadMaintenanceRequests();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newMaintenanceKey() {
    final random = math.Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  Future<void> _submitMaintenanceRequest() async {
    final estateId = _maintenanceEstateId ?? _visitorEstateId;
    final propertyId = _selectedMaintenancePropertyId;
    final description = _maintenanceDescription.text.trim();
    if (estateId == null ||
        estateId.isEmpty ||
        propertyId == null ||
        propertyId.isEmpty ||
        description.isEmpty) {
      setState(
        () => _error = 'Choose an active property and describe the issue.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _maintenanceIdempotencyKey ??= _newMaintenanceKey();
      await widget.repository.createMaintenanceRequest(
        estateId: estateId,
        propertyId: propertyId,
        category: _maintenanceCategory,
        priority: _maintenancePriority,
        description: description,
        idempotencyKey: _maintenanceIdempotencyKey!,
      );
      _maintenanceIdempotencyKey = null;
      _maintenanceDescription.clear();
      await _loadMaintenanceRequests();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance request submitted to your estate team.'),
          ),
        );
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadWorkspace();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadVisitorPasses() async {
    final estateId = _visitorEstateId;
    if (estateId == null) return;
    final items = await widget.repository.loadMyVisitorPasses(estateId);
    if (mounted) setState(() => _visitorPasses = items);
  }

  Future<void> _openFacilities() async {
    final estateId = _visitorEstateId;
    if (estateId == null || _busy) return;
    final estate = _memberships
        .where((item) => item.id == estateId)
        .firstOrNull;
    final tenancyProperties = _tenancies
        .where((item) => item.estateId == estateId)
        .map((item) => (id: item.propertyId, label: item.propertyCode))
        .toList(growable: false);
    final propertyChoices = tenancyProperties.isNotEmpty
        ? tenancyProperties
        : _visitorProperties
              .map((item) => (id: item.id, label: item.label))
              .toList(growable: false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResidentFacilitiesApiPage(
          repository: widget.repository,
          estateId: estateId,
          estateName:
              estate?.name ??
              _tenancies
                  .where((item) => item.estateId == estateId)
                  .firstOrNull
                  ?.estateName ??
              'Your estate',
          properties: propertyChoices,
        ),
      ),
    );
  }

  Future<void> _selectEstate(String? estateId) async {
    setState(() {
      _estateId = estateId;
      _busy = true;
      _error = null;
    });
    try {
      await _loadProperties();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitJoinRequest() async {
    final estateId = _estateId;
    if (estateId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.submitResidentJoinRequest(
        estateId: estateId,
        propertyId: _propertyId,
        relationship: _propertyId == null ? null : _relationship,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _note.clear();
      _requests = await widget.repository.loadMyJoinRequestHistory();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access request sent to the estate team.'),
          ),
        );
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _memberships = const [];
      _availableEstates = const [];
      _requests = const [];
      _tenancies = const [];
      _maintenanceRequests = const [];
      _selectedMaintenancePropertyId = null;
      _maintenanceEstateId = null;
    });
  }

  Future<void> _acceptStaffInvitation() async {
    final estateIdController = TextEditingController();
    final codeController = TextEditingController();
    final value = await showDialog<({String estateId, String code})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept staff invitation'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sign in with the email address invited by the estate administrator.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: estateIdController,
                decoration: const InputDecoration(labelText: 'Estate ID'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'One-time invitation code',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final id = estateIdController.text.trim();
              final code = codeController.text.trim();
              if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) &&
                  code.length >= 32)
                Navigator.pop(context, (estateId: id, code: code));
            },
            child: const Text('Accept invitation'),
          ),
        ],
      ),
    );
    estateIdController.dispose();
    codeController.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.acceptStaffInvitation(
        estateId: value.estateId,
        code: value.code,
      );
      await _loadWorkspace();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Staff access granted: ${(result['role'] as String? ?? '').replaceAll('_', ' ')}.',
            ),
          ),
        );
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is EstateApiException
      ? error.message
      : 'The estate service could not load your account.';

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  String? get _walletEstateId =>
      _maintenanceEstateId ??
      _memberships.firstOrNull?.id;

  Future<void> _provisionWallet() async {
    final estateId = _walletEstateId;
    if (estateId == null) return;
    try {
      final wallet = await widget.repository.provisionEstateWallet(estateId);
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wallet.accountNumber != null
                ? 'Fund account ready: ${wallet.accountNumber}'
                : 'Fund account is being prepared.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Future<void> _payRentFromWallet(EstateWalletRecord wallet) async {
    final payable = _invoiceRecords
        .where((invoice) => invoice['status'] != 'paid')
        .toList();
    if (payable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outstanding invoice to pay.')),
      );
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay from fund account'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: payable
                .map(
                  (invoice) => ListTile(
                    title: Text(
                      invoice['invoiceNumber']?.toString() ?? 'Estate charge',
                    ),
                    subtitle: Text(
                      'Balance ${invoice['currency'] ?? wallet.currency} ${invoice['balance'] ?? invoice['total'] ?? '0.00'}',
                    ),
                    onTap: () => Navigator.pop(context, invoice),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null) return;
    final amount = selected['balance']?.toString() ?? selected['total']?.toString() ?? '0.00';
    try {
      await widget.repository.payRentFromWallet(
        estateId: wallet.estateId,
        invoiceId: selected['id'] as String,
        amount: amount,
      );
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rent paid from your fund account.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return 'NGN ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }

  Future<void> _orderService(EstateServiceRecord service) async {
    final estateId = _memberships.firstOrNull?.id;
    if (estateId == null) return;
    final key = 'svc-order-${DateTime.now().microsecondsSinceEpoch}-'
        '${service.id.substring(service.id.length > 8 ? service.id.length - 8 : 0)}';
    try {
      final result = await widget.repository.orderEstateService(
        estateId: estateId,
        serviceId: service.id,
        idempotencyKey: key,
      );
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.demo
                ? 'Demo service fulfilled. Voucher: ${result.fulfilmentCode ?? 'demo'}'
                : 'Service ordered successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _submitDemoIdentity() async {
    final estateId = _memberships.firstOrNull?.id;
    if (estateId == null) return;
    try {
      await widget.repository.submitIdentityVerification(
        estateId: estateId,
        method: 'DEMO_DECLARATION',
        provider: 'LANCON Demo',
        level: 'BASIC',
        consentGiven: true,
      );
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo identity declaration submitted for review.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _addHouseholdMember() async {
    final estateId = _memberships.firstOrNull?.id;
    final propertyId = _propertyId ?? _properties.firstOrNull?.id;
    if (estateId == null || propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your property before adding a household member.')),
      );
      return;
    }
    final nameController = TextEditingController();
    var relationship = 'SPOUSE';
    var memberType = 'ADULT';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add household member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: const [
                    DropdownMenuItem(value: 'SPOUSE', child: Text('Spouse')),
                    DropdownMenuItem(value: 'CHILD', child: Text('Child')),
                    DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                    DropdownMenuItem(value: 'DEPENDENT', child: Text('Dependant')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => relationship = value ?? 'SPOUSE'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: memberType,
                  decoration: const InputDecoration(labelText: 'Member type'),
                  items: const [
                    DropdownMenuItem(value: 'ADULT', child: Text('Adult')),
                    DropdownMenuItem(value: 'CHILD', child: Text('Child / dependant')),
                    DropdownMenuItem(value: 'RESTRICTED', child: Text('Restricted member')),
                  ],
                  onChanged: (value) => setState(() => memberType = value ?? 'ADULT'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'New members are reviewed by estate management. Dependants and restricted members never receive wallet access.',
                  style: TextStyle(fontSize: 11, color: EstateColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;
    try {
      await widget.repository.addHouseholdMember(
        estateId: estateId,
        propertyId: propertyId,
        fullName: nameController.text.trim(),
        relationship: relationship,
        memberType: memberType,
        effectiveFrom: DateTime.now().toUtc().toIso8601String().substring(0, 10),
      );
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Household member submitted for review.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _payRentSchedule(RentScheduleRecord row) async {
    try {
      await widget.repository.payRentSchedule(
        scheduleId: row.id,
        amount: row.balance,
      );
      await _loadWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rent paid from your fund account.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Future<void> _startFunding(EstateWalletRecord wallet) async {
    final amount = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add money'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount to fund',
              prefixText: 'NGN ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(value) &&
                    double.tryParse(value) != null &&
                    double.parse(value) > 0) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (amount == null) return;
    try {
      final key = 'fund-${DateTime.now().microsecondsSinceEpoch}-'
          '${DateTime.now().millisecond}';
      final intent = await widget.repository.createWalletFundingIntent(
        estateId: wallet.estateId,
        amount: amount,
        idempotencyKey: key,
      );
      if (!mounted) return;
      final isDemo = intent['demo'] == true ||
          wallet.bankName?.toLowerCase().contains('demo') == true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isDemo ? 'Demo funding' : 'Transfer to fund your account'),
          content: Text(
            '${wallet.accountName ?? ''}\n'
            '${wallet.bankName ?? ''}\n'
            '${wallet.accountNumber ?? ''}\n\n'
            '${isDemo ? 'No real bank transfer is involved. Use the button below to simulate a verified demo credit.' : 'The balance updates only after the provider verifies your transfer.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (isDemo)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await widget.repository
                        .creditDemoWallet(intent['id'] as String);
                    await _loadWorkspace();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demo funding posted to your wallet.'),
                      ),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_message(error))),
                    );
                  }
                },
                child: const Text('Simulate demo credit'),
              ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Widget _bankHero() {
    final wallet = _wallets.firstOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2F27), Color(0xFF0D3B30), Color(0xFF176B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFCFE3D7), size: 18),
              const SizedBox(width: 8),
              const Text('My estate wallet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              IconButton(
                tooltip: 'Account settings',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Account settings'),
                    content: Text('${_account?.displayName ?? ''}\n${_account?.email ?? ''}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _signOut();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (wallet == null ||
              wallet.bankName?.toLowerCase().contains('demo') == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DEMO MODE · NO REAL MONEY',
                style: TextStyle(color: Color(0xFFDCECE3), fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 14),
          const Text('MY WALLET BALANCE',
              style: TextStyle(color: Color(0xFFBFD8C9), fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            wallet == null ? '—' : _money(wallet.balance),
            style: const TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1),
          ),
          const SizedBox(height: 10),
          Text(
            wallet == null
                ? 'No fund account yet'
                : '${wallet.accountNumber ?? 'Account pending'} · ${wallet.bankName ?? ''}',
            style: const TextStyle(color: Color(0xFFCFE3D7), fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Text('Quick Services',
              style: TextStyle(
                  color: Color(0xFFCFE3D7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuickService(
                icon: Icons.add_rounded,
                label: 'Fund',
                onTap: wallet == null ? _provisionWallet : () => _startFunding(wallet),
              ),
              _QuickService(
                icon: Icons.payments_outlined,
                label: 'Pay rent',
                onTap: wallet == null ? _provisionWallet : () => _payRentFromWallet(wallet),
              ),
              _QuickService(
                icon: Icons.receipt_long_outlined,
                label: 'Bills',
                onTap: _openResidentBilling,
              ),
              _QuickService(
                icon: Icons.miscellaneous_services_outlined,
                label: 'Services',
                onTap: () => setState(() => _selectedTab = 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyCard() {
    final wallet = _wallets.firstOrNull;
    var outstanding = 0.0;
    var verified = 0.0;
    for (final invoice in _invoiceRecords) {
      outstanding += double.tryParse(invoice['balance']?.toString() ?? '0') ?? 0;
      for (final payment in invoice['verifiedPayments'] as List? ?? const []) {
        if (payment is Map && payment['status'] == 'verified') {
          verified += double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
        }
      }
    }
    String ngn(dynamic value) {
      final amount = double.tryParse(value.toString()) ?? 0;
      return 'NGN ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.account_balance_wallet_outlined, color: EstateColors.forest),
                SizedBox(width: 9),
                Text('My fund account',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Account numbers are issued by Paystack. Transfers are credited only after provider verification.',
              style: TextStyle(color: EstateColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 14),
            if (wallet == null)
              OutlinedButton.icon(
                onPressed: _provisionWallet,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Activate fund account'),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D3B30), Color(0xFF176B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available balance',
                        style: TextStyle(color: Color(0xFFCFE3D7), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(ngn(wallet.balance),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text(
                      wallet.accountNumber ?? 'Account pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4),
                    ),
                    Text(
                      '${wallet.bankName ?? 'Bank'} · ${wallet.accountName ?? ''}',
                      style: const TextStyle(color: Color(0xFFCFE3D7), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _startFunding(wallet),
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: const Text('Fund account'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _payRentFromWallet(wallet),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pay rent'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openResidentBilling,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Invoices'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Recent activity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (wallet.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('No wallet transactions yet.',
                      style: TextStyle(color: EstateColors.muted, fontSize: 12)),
                )
              else
                ...wallet.transactions.take(4).map(
                      (tx) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          tx.type == 'credit'
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: tx.type == 'credit'
                              ? EstateColors.forest
                              : const Color(0xFF8A5B13),
                        ),
                        title: Text(tx.description),
                        subtitle: Text(
                          '${tx.reference} · ${_formatDate(tx.createdAt)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Text(ngn(tx.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MoneyFigure(
                    label: 'Outstanding',
                    value: ngn(outstanding),
                    color: const Color(0xFF8A5B13),
                  ),
                ),
                Expanded(
                  child: _MoneyFigure(
                    label: 'Verified receipts',
                    value: ngn(verified),
                    color: EstateColors.forest,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return _signIn();
    if (_showIncidents) {
      return ResidentIncidentsApiPage(
        repository: widget.repository,
        estates: _memberships,
        onBack: () => setState(() => _showIncidents = false),
      );
    }
    if (_showGateSecurity && _securityEstateId != null) {
      return Scaffold(
        body: SafeArea(
          child: GateSecurityPage(
            estateId: _securityEstateId!,
            gates: _myGates,
            repository: widget.repository,
            onBack: () => setState(() => _showGateSecurity = false),
          ),
        ),
      );
    }
    if (_showVisitorPasses) {
      final estateId = _visitorEstateId ?? '';
      final passProperties = _visitorProperties
          .map((p) => (id: p.id, label: p.label))
          .toList(growable: false);
      final repository = _ResidentVisitorApiAdapter(
        widget.repository,
        estateId,
        passProperties,
      );
      final passes = _visitorPasses
          .map(
            (p) => ResidentVisitorPass(
              reference: p.id,
              visitorName: p.visitorName,
              propertyId: p.propertyId,
              propertyLabel: p.propertyLabel,
              validFrom: p.validFrom,
              validUntil: p.validUntil,
              status: p.status,
              uses: p.uses,
              useLimit: p.useLimit,
              vehicleSummary: p.vehicleSummary,
            ),
          )
          .toList(growable: false);
      return Scaffold(
        body: SafeArea(
          child: ResidentVisitorPassesPage(
            passes: passes,
            estateId: estateId,
            repository: repository,
            onBack: () => setState(() => _showVisitorPasses = false),
            onPassesChanged: _reloadVisitorPasses,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home_work_outlined, color: EstateColors.forest),
            SizedBox(width: 9),
            Text('Estate Management'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EstateNotificationsPage(
                        repository: widget.repository,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => action == 'accept_invitation'
                ? _acceptStaffInvitation()
                : _signOut(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'accept_invitation',
                child: Text('Accept staff invitation'),
              ),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              _bankHero(),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${_account!.displayName}',
                style: const TextStyle(color: EstateColors.muted),
              ),
              const SizedBox(height: 5),
              Text(
                switch (_selectedTab) {
                  1 => 'Manage your access',
                  2 => 'Property maintenance',
                  3 => 'Community services',
                  _ => 'Your estate home',
                },
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: EstateColors.ink,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _MessageCard(message: _error!, error: true),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 18),
              if (_selectedTab == 3) ...[
                _moneyCard(),
                const SizedBox(height: 18),
                _sectionTitle('House rent'),
                if (_rentSchedule.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No rent installments scheduled yet.'),
                    ),
                  )
                else
                  ..._rentSchedule.take(6).map(
                        (row) => Card(
                          child: ListTile(
                            title: Text(
                              '${row.currency} ${row.amount} · ${row.status}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${row.periodStart} – ${row.periodEnd} · due ${row.dueDate}'
                              '${row.isOverdue ? ' · overdue' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: row.balance == '0'
                                ? const Icon(Icons.check_circle, color: EstateColors.forest)
                                : TextButton(
                                    onPressed: _wallets.firstOrNull == null
                                        ? null
                                        : () => _payRentSchedule(row),
                                    child: const Text('Pay'),
                                  ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Identity verification',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(
                          _identity.isEmpty
                              ? 'No verification submitted yet. Demo declarations are clearly labelled and are not provider-verified.'
                              : 'Latest: ${_identity.first.status}${_identity.first.demo ? ' (demo declaration)' : ''} · ${_identity.first.provider}',
                          style: const TextStyle(fontSize: 12, color: EstateColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _submitDemoIdentity,
                            icon: const Icon(Icons.badge_outlined, size: 18),
                            label: const Text('Submit demo declaration'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Household',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addHouseholdMember,
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('Add member'),
                    ),
                  ],
                ),
                if (_household.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No household members have been added yet.'),
                    ),
                  )
                else
                  ..._household.take(6).map(
                        (row) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE9F2ED),
                              child: Icon(
                                row.memberType == 'CHILD'
                                    ? Icons.child_care_outlined
                                    : Icons.person_outline,
                                color: EstateColors.forest,
                              ),
                            ),
                            title: Text(row.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${row.relationship.toLowerCase()} · ${row.propertyCode} · ${row.status}'
                              '${row.financialAccess ? ' · wallet access' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
              ],
              if (_selectedTab == 3) ...[
                _sectionTitle('Services catalogue'),
                if (_servicesCatalogue.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No services are configured for this estate yet.'),
                    ),
                  )
                else
                  ..._servicesCatalogue.where((row) => row.status == 'active').take(6).map(
                        (row) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE9F2ED),
                              child: Icon(
                                row.category.toLowerCase().contains('airtime') ||
                                        row.category.toLowerCase().contains('data')
                                    ? Icons.phone_android_outlined
                                    : Icons.bolt_outlined,
                                color: EstateColors.forest,
                              ),
                            ),
                            title: Text(row.name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${row.currency} ${row.amount} · ${row.provider}'
                              '${row.demo ? ' · demo service' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: _wallets.firstOrNull == null
                                  ? null
                                  : () => _orderService(row),
                              child: const Text('Order'),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
              ],
              if (_selectedTab == 3) ...[
                _sectionTitle('Your estate services'),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2ED),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    title: const Text(
                      'Bills and receipts',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _invoiceRecords.isEmpty
                          ? 'View issued estate charges and verified receipts.'
                          : '${_invoiceRecords.length} invoice${_invoiceRecords.length == 1 ? '' : 's'} and receipt records',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openResidentBilling,
                  ),
                ),
                if (_visitorProperties.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: const Text(
                        'Visitor passes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_visitorPasses.where((pass) => pass.status == 'active').length} active invitations',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _showVisitorPasses = true),
                    ),
                  ),
                if (_visitorEstateId != null)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.pool_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: const Text(
                        'Shared facilities',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Check availability, request a booking and follow staff confirmation.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _openFacilities,
                    ),
                  ),
                if (_securityEstateId != null)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.security_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: const Text(
                        'Gate security',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_myGates.length} assigned gates · visitor check-in and checkout',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _showGateSecurity = true),
                    ),
                  ),
                if (_memberships.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.health_and_safety_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: const Text(
                        'Safety and incidents',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Report a concern to estate staff and follow its status.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _showIncidents = true),
                    ),
                  ),
                if (_visitorProperties.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.handyman_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: const Text(
                        'Property maintenance',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${_maintenanceRequests.length} requests recorded',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ),
              ],
              if (_selectedTab == 0) ...[
                _ResidentHomeHero(
                  residentName: _account!.displayName,
                  estateName: _memberships.firstOrNull?.name,
                  roles: _memberships.firstOrNull?.roles ?? const [],
                  propertyLabel: _visitorProperties.firstOrNull?.label,
                  canRequestAccess: _availableEstates.isNotEmpty,
                  onRequestAccess: () => setState(() => _selectedTab = 1),
                ),
                const SizedBox(height: 20),
                _sectionTitle('My estates'),
                if (_memberships.isEmpty)
                  const _MessageCard(
                    message: 'No active estate membership is linked to your account yet.',
                  )
                else
                  ..._memberships.map(
                    (estate) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE9F2ED),
                          child: Icon(
                            Icons.apartment_outlined,
                            color: EstateColors.forest,
                          ),
                        ),
                        title: Text(
                          estate.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          estate.roles.map(_roleLabel).join(' · '),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _sectionTitle('Estate notices'),
                if (_announcementLoadFailed)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.cloud_off_outlined,
                        color: EstateColors.muted,
                      ),
                      title: const Text('Notices are temporarily unavailable'),
                      subtitle: const Text(
                        'Your other estate information is still available.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Retry loading notices',
                        onPressed: _refreshAnnouncements,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  )
                else if (_announcements.isEmpty)
                  const _MessageCard(
                    message: 'There are no published notices for your active estates.',
                  )
                else
                  ..._announcements.map(
                    (announcement) => Card(
                      child: ExpansionTile(
                        onExpansionChanged: (expanded) {
                          if (expanded) _markAnnouncementRead(announcement);
                        },
                        leading: Icon(
                          announcement.category == 'emergency'
                              ? Icons.warning_amber_rounded
                              : Icons.campaign_outlined,
                          color: announcement.category == 'emergency'
                              ? const Color(0xFF984B43)
                              : EstateColors.forest,
                        ),
                        title: Text(
                          announcement.title,
                          style: TextStyle(
                            fontWeight: announcement.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${announcement.estateName} • ${_announcementDate(announcement.publishedAt ?? announcement.createdAt)}',
                        ),
                        trailing: announcement.read
                            ? const Icon(
                                Icons.done_all,
                                color: EstateColors.muted,
                              )
                            : const Icon(
                                Icons.circle,
                                size: 10,
                                color: EstateColors.forest,
                              ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                announcement.body,
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: _billingSectionKey,
                  child: _sectionTitle('Outstanding Payments'),
                ),
                if (_invoiceRecords.isEmpty)
                  const _MessageCard(
                    message: 'There are no invoices or receipts linked to your active property relationships.',
                  )
                else
                  ..._invoiceRecords.map(
                    (invoice) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE9F2ED),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            color: EstateColors.forest,
                          ),
                        ),
                        title: Text(
                          invoice['description'] as String? ??
                              invoice['invoiceNumber'] as String? ??
                              'Estate charge',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${invoice['estateName'] ?? ''} · ${invoice['propertyCode'] ?? ''} · Due ${invoice['dueDate'] ?? ''}\n${_invoiceSettlementSummary(invoice)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${invoice['currency'] ?? 'NGN'} ${invoice['balance'] ?? invoice['total'] ?? '0.00'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              if (_selectedTab == 1 && _availableEstates.isEmpty)
                const _MessageCard(
                  message: 'There are no active estates available for access requests right now.',
                )
              else if (_selectedTab == 1) ...[
                _sectionTitle('Request estate access'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _estateId,
                          decoration: const InputDecoration(
                            labelText: 'Estate',
                          ),
                          items: _availableEstates
                              .map(
                                (estate) => DropdownMenuItem(
                                  value: estate.id,
                                  child: Text(estate.name),
                                ),
                              )
                              .toList(),
                          onChanged: _busy ? null : _selectEstate,
                        ),
                        if (_estateId != null) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: _propertyId,
                            decoration: const InputDecoration(
                              labelText: 'Property (optional)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Estate access only'),
                              ),
                              ..._properties.map(
                                (property) => DropdownMenuItem<String?>(
                                  value: property.id,
                                  child: Text(
                                    '${property.code} - ${property.type}',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _propertyId = value;
                            }),
                          ),
                          if (_propertyId != null) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _relationship,
                              decoration: const InputDecoration(
                                labelText: 'Your relationship to the property',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'tenant',
                                  child: Text('Tenant'),
                                ),
                                DropdownMenuItem(
                                  value: 'household_member',
                                  child: Text('Household member'),
                                ),
                                DropdownMenuItem(
                                  value: 'authorized_occupant',
                                  child: Text('Authorized occupant'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _relationship = value ?? 'tenant',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _note,
                            maxLines: 2,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Note for the estate team (optional)',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _submitJoinRequest,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Send request'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle('My access requests'),
                if (_requests.isEmpty)
                  const _MessageCard(
                    message: 'Access requests you send will appear here with their review status.',
                  )
                else
                  ..._requests.map(
                    (request) => Card(
                      child: ListTile(
                        leading: Icon(
                          _statusIcon(request.status),
                          color: _statusColor(request.status),
                        ),
                        title: Text(
                          request.estateName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (request.propertyCode != null)
                              request.propertyCode!,
                            if (request.relationship != null)
                              _roleLabel(request.relationship!),
                            request.decisionReason,
                          ].whereType<String>().join(' · '),
                        ),
                        trailing: Text(_roleLabel(request.status)),
                      ),
                    ),
                  ),
              ],
              if (_selectedTab == 0 && _visitorProperties.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionTitle(
                  _tenancies.isEmpty
                      ? 'My approved property access'
                      : 'My active tenancy',
                ),
                if (_tenancies.isNotEmpty)
                  ..._tenancies.map(
                    (record) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE9F2ED),
                          child: Icon(
                            Icons.key_outlined,
                            color: EstateColors.forest,
                          ),
                        ),
                        title: Text(
                          '${record.propertyCode} · ${record.estateName}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${record.currency} ${record.amount} / ${record.frequency} · ${record.landlordName}\nThis is agreed rent, not a payment balance.',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                if (_tenancies.isEmpty)
                  ..._visitorProperties.map(
                    (property) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE9F2ED),
                          child: Icon(
                            Icons.apartment_outlined,
                            color: EstateColors.forest,
                          ),
                        ),
                        title: Text(
                          property.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('Approved resident access'),
                      ),
                    ),
                  ),
              ],
              if (_selectedTab == 0 && _securityEstateId != null)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2ED),
                      child: Icon(
                        Icons.security_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    title: const Text(
                      'Gate security',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_myGates.length} assigned gates · visitor check-in and checkout',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _showGateSecurity = true),
                  ),
                ),
              if (_selectedTab == 0 && _visitorProperties.isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2ED),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: EstateColors.forest,
                      ),
                    ),
                    title: const Text(
                      'Visitor passes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_visitorPasses.where((pass) => pass.status == 'active').length} active invitations',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _showVisitorPasses = true),
                  ),
                ),
              ],
              if (_selectedTab == 0 && _visitorEstateId != null)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2ED),
                      child: Icon(
                        Icons.pool_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    title: const Text(
                      'Shared facilities',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Check available times, request a booking, and follow staff confirmation.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openFacilities,
                  ),
                ),
              if (_selectedTab == 0 && _memberships.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9F2ED),
                      child: Icon(
                        Icons.health_and_safety_outlined,
                        color: EstateColors.forest,
                      ),
                    ),
                    title: const Text(
                      'Safety and incidents',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Report a concern to estate staff and follow its status.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _showIncidents = true),
                  ),
                ),
              if (_selectedTab == 2 && _visitorProperties.isEmpty)
                const _MessageCard(
                  message: 'Property maintenance becomes available after your tenancy or property access is approved.',
                ),
              if (_selectedTab == 2 && _visitorProperties.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionTitle('Property maintenance'),
                if (_maintenanceEstateChoices.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: _maintenanceEstateId,
                    decoration: const InputDecoration(labelText: 'Estate'),
                    items: _maintenanceEstateChoices
                        .map(
                          (tenancy) => DropdownMenuItem(
                            value: tenancy.estateId,
                            child: Text(tenancy.estateName),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (estateId) {
                            final tenancy = _maintenanceEstateChoices
                                .where((item) => item.estateId == estateId)
                                .firstOrNull;
                            if (tenancy != null) {
                              _selectMaintenanceEstate(tenancy);
                            }
                          },
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMaintenancePropertyId,
                          decoration: const InputDecoration(
                            labelText: 'Property',
                          ),
                          items: _visitorProperties
                              .map(
                                (property) => DropdownMenuItem(
                                  value: property.id,
                                  child: Text(property.label),
                                ),
                              )
                              .toList(),
                          onChanged: _busy ? null : _selectMaintenanceProperty,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _maintenanceCategory,
                          decoration: const InputDecoration(
                            labelText: 'Issue type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'plumbing',
                              child: Text('Plumbing'),
                            ),
                            DropdownMenuItem(
                              value: 'electrical',
                              child: Text('Electrical'),
                            ),
                            DropdownMenuItem(
                              value: 'security',
                              child: Text('Security'),
                            ),
                            DropdownMenuItem(
                              value: 'cleaning',
                              child: Text('Cleaning'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _maintenanceCategory = value ?? 'other',
                                ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _maintenancePriority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () =>
                                      _maintenancePriority = value ?? 'normal',
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _maintenanceDescription,
                          maxLength: 700,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Describe the issue',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Text(
                          'For emergencies, contact your estate security desk directly.',
                          style: TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submitMaintenanceRequest,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            _busy ? 'Submitting...' : 'Submit request',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_maintenanceRequests.isEmpty)
                  const _MessageCard(
                    message: 'Maintenance requests for this property will appear here.',
                  ),
                ..._maintenanceRequests.map(
                  (request) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9F2ED),
                        child: Icon(
                          Icons.handyman_outlined,
                          color: EstateColors.forest,
                        ),
                      ),
                      title: Text(
                        '${request.reference} · ${_roleLabel(request.status)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${request.propertyLabel} · ${_roleLabel(request.category)} · ${request.description}\n${request.residentVisibleUpdates.isEmpty ? 'No team updates yet.' : request.residentVisibleUpdates.last.body}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_selectedTab == 0 && _invoiceRecords.isNotEmpty)
                const Text(
                  'Transfer instructions are attached to each issued invoice. Payments appear here only after your estate finance team verifies the bank record; verified amounts and receipt references update the invoice balance.',
                  style: TextStyle(color: EstateColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment_rounded),
            label: 'Access',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: 'Repairs',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Services',
          ),
        ],
      ),
    );
  }

  Widget _signIn() => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/onboarding_background.jpg',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x85111F18), Color(0xD509140F)],
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  color: Colors.white.withValues(alpha: .97),
                  child: Padding(
                    padding: const EdgeInsets.all(27),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.home_work_outlined,
                            size: 38,
                            color: EstateColors.forest,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _registering
                                ? 'Create your resident account'
                                : 'Sign in to your estate',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_registering) ...[
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 2
                                  ? 'Enter your name.'
                                  : null,
                            ),
                            const SizedBox(height: 11),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                            ),
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Enter a valid email address.'
                                : null,
                          ),
                          const SizedBox(height: 11),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            validator: (value) =>
                                value == null || value.length < 10
                                ? 'Use at least 10 characters.'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: EstateColors.red),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _authenticate,
                            child: Text(
                              _busy
                                  ? 'Please wait...'
                                  : _registering
                                  ? 'Create account and sign in'
                                  : 'Sign in',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _registering = !_registering;
                                    _error = null;
                                  }),
                            child: Text(
                              _registering
                                  ? 'Already have an account? Sign in'
                                  : 'New to the estate app? Create account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: EstateColors.ink,
      ),
    ),
  );
  String _announcementDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
  String _roleLabel(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
  IconData _statusIcon(String status) => switch (status) {
    'approved' => Icons.check_circle_outline,
    'rejected' => Icons.cancel_outlined,
    _ => Icons.hourglass_top_rounded,
  };
  Color _statusColor(String status) => switch (status) {
    'approved' => EstateColors.forest,
    'rejected' => EstateColors.red,
    _ => const Color(0xFF9A7538),
  };
}

class _ResidentHomeHero extends StatelessWidget {
  const _ResidentHomeHero({
    required this.residentName,
    required this.estateName,
    required this.roles,
    required this.propertyLabel,
    required this.canRequestAccess,
    required this.onRequestAccess,
  });

  final String residentName;
  final String? estateName;
  final List<String> roles;
  final String? propertyLabel;
  final bool canRequestAccess;
  final VoidCallback onRequestAccess;

  @override
  Widget build(BuildContext context) {
    final connected = estateName != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [EstateColors.forest, EstateColors.forestDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -48,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELCOME, ${residentName.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          connected ? estateName! : 'Your community, connected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          connected
                              ? propertyLabel ??
                                    'Estate access is active for your account.'
                              : 'Request access to your estate to see property services and community updates.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .86),
                            height: 1.45,
                          ),
                        ),
                        if (connected && roles.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .18),
                              ),
                            ),
                            child: Text(
                              roles
                                  .map((role) => role.replaceAll('_', ' '))
                                  .join(' · '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (!connected && canRequestAccess) ...[
                          const SizedBox(height: 15),
                          FilledButton.tonalIcon(
                            onPressed: onRequestAccess,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Request estate access'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      connected
                          ? Icons.apartment_rounded
                          : Icons.home_work_outlined,
                      color: Colors.white,
                      size: 27,
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
}

class _QuickService extends StatelessWidget {
  const _QuickService({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Color(0xFFDCECE3), fontSize: 11)),
        ],
      ),
    ),
  );
}

class _MoneyFigure extends StatelessWidget {
  const _MoneyFigure({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: EstateColors.muted, fontSize: 11)),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
    color: error ? const Color(0xFFFFF0EE) : null,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Text(
        message,
        style: TextStyle(
          color: error ? EstateColors.red : EstateColors.muted,
          height: 1.45,
        ),
      ),
    ),
  );
}

class _ResidentVisitorApiAdapter implements ResidentVisitorPassRepository {
  _ResidentVisitorApiAdapter(this.api, this.estateId, this.properties);
  final EstateApplicationApiRepository api;
  final String estateId;
  final List<({String id, String label})> properties;

  @override
  Future<List<ResidentVisitorPass>> loadMyVisitorPasses() async =>
      (await api.loadMyVisitorPasses(estateId))
          .map(
            (pass) => ResidentVisitorPass(
              reference: pass.id,
              visitorName: pass.visitorName,
              propertyId: pass.propertyId,
              propertyLabel: pass.propertyLabel,
              validFrom: pass.validFrom,
              validUntil: pass.validUntil,
              status: pass.status,
              uses: pass.uses,
              useLimit: pass.useLimit,
              vehicleSummary: pass.vehicleSummary,
            ),
          )
          .toList(growable: false);

  @override
  Future<List<({String id, String label})>> loadMyVisitorProperties(
    String estateId,
  ) async => properties;

  @override
  Future<ResidentVisitorPass> createVisitorPassDraft({
    required String estateId,
    required String propertyId,
    required String visitorName,
    required DateTime validFrom,
    required DateTime validUntil,
    required String vehicleSummary,
  }) async {
    final result = await api.createVisitorPass(
      estateId: estateId,
      propertyId: propertyId,
      visitorName: visitorName,
      validFrom: validFrom,
      validUntil: validUntil,
      vehicleSummary: vehicleSummary,
      idempotencyKey: List.generate(
        32,
        (i) => (DateTime.now().microsecondsSinceEpoch + i).toRadixString(16),
      ).join().substring(0, 32),
    );
    final property = properties
        .where((item) => item.id == propertyId)
        .firstOrNull;
    return ResidentVisitorPass(
      reference: result['passId'] as String? ?? '',
      visitorName: visitorName,
      propertyId: propertyId,
      propertyLabel: property?.label ?? '',
      validFrom: validFrom,
      validUntil: validUntil,
      status: 'active',
      uses: 0,
      useLimit: 1,
      vehicleSummary: vehicleSummary.trim().isEmpty
          ? null
          : vehicleSummary.trim(),
      credential: result['credential'] as String?,
    );
  }

  @override
  Future<void> revokeVisitorPass({
    required String estateId,
    required String passId,
    required String reason,
  }) =>
      api.revokeVisitorPass(estateId: estateId, passId: passId, reason: reason);

  Future<List<EstateGateRecord>> loadMyGates(String estateId) =>
      api.loadMyGates(estateId);
  Future<List<GateCurrentVisitorRecord>> loadCurrentGateVisitors({
    required String estateId,
    required String gateId,
  }) => api.loadCurrentGateVisitors(estateId: estateId, gateId: gateId);
  Future<Map<String, dynamic>> checkInGateVisitor({
    required String estateId,
    required String gateId,
    required String credential,
    required String idempotencyKey,
  }) => api.checkInGateVisitor(
    estateId: estateId,
    gateId: gateId,
    credential: credential,
    idempotencyKey: idempotencyKey,
  );
  Future<void> checkOutGateVisitor({
    required String estateId,
    required String gateId,
    required String visitId,
  }) => api.checkOutGateVisitor(
    estateId: estateId,
    gateId: gateId,
    visitId: visitId,
  );
}
