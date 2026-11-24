import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/estate_theme.dart';
import '../../../core/design/dashboard_design.dart';
import '../../../core/config/report_download.dart';
import 'manager_service_pages.dart';
import '../../../data/api.dart';
import '../../resident_access/presentation/resident_access_review_page.dart';
import 'ownership_review_api_page.dart';
import 'tenancy_approval_api_page.dart';
import 'estate_charges_page.dart';
import 'estate_expenses_api_page.dart';
import 'estate_facilities_admin_page.dart';
import 'rent_schedule_preview_page.dart';
import 'estate_announcements_api_page.dart';
import 'estate_security_incidents_api_page.dart';
import 'estate_tenancy_create_api_page.dart';
import 'estate_staff_invitations_api_page.dart';
import 'estate_settings_api_page.dart';
import '../../notifications/presentation/estate_notifications_page.dart';

class EstateManagerDashboardApiPage extends StatefulWidget {
  const EstateManagerDashboardApiPage({super.key, required this.repository});
  final EstateApplicationApiRepository repository;
  @override
  State<EstateManagerDashboardApiPage> createState() =>
      _EstateManagerDashboardApiPageState();
}

class _EstateManagerDashboardApiPageState
    extends State<EstateManagerDashboardApiPage> {
  final _dashboardScrollController = ScrollController();
  final _maintenanceSectionKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  EstateAccount? _account;
  List<ManagedEstateChoice> _estates = const [];
  ManagedEstateChoice? _estate;
  EstateManagerDashboardSummary? _summary;
  EstateTreasurySummary? _treasury;
  List<EstatePayoutBeneficiaryRecord> _beneficiaries = const [];
  List<EstatePayoutRecord> _payouts = const [];
  List<RentScheduleRecord> _rentSchedule = const [];
  List<LandlordRentSummaryRecord> _landlordRent = const [];
  List<HouseholdMemberRecord> _household = const [];
  List<PropertyLocationRecord> _locations = const [];
  List<IdentityVerificationRecord> _identity = const [];
  List<EstateServiceRecord> _services = const [];
  List<EstateServiceOrderRecord> _serviceOrders = const [];
  Map<String, dynamic> _walletStatement = const {};
  Map<String, dynamic> _reportSummary = const {};
  List<dynamic> _auditLog = const [];
  EstateMaintenanceQueue _maintenanceQueue = const EstateMaintenanceQueue(
    items: [],
    assignableStaff: [],
    total: 0,
  );
  List<EstateFacilityBookingRecord> _facilityBookings = const [];
  List<EstateGateRecord> _estateGates = const [];
  List<EstateStaffChoice> _securityOfficers = const [];
  List<EstateStructureRecord> _estateStructure = const [];
  final _gateCode = TextEditingController();
  final _gateName = TextEditingController();
  final _structureName = TextEditingController();
  final _structureCode = TextEditingController();
  final _maintenanceSearch = TextEditingController();
  Timer? _maintenanceSearchTimer;
  String _structureType = 'zone';
  String _maintenanceStatusFilter = 'open';
  int _maintenancePage = 1;
  bool _maintenanceQueueLoading = false;
  String? _structureParentId;
  String? _selectedGateId;
  String? _selectedOfficerId;
  bool _restoring = true;
  bool _busy = false;
  String? _error;

  bool get _canManageEstateOperations =>
      _estate?.roles.any(
        (role) => role == 'estate_administrator' || role == 'estate_manager',
      ) ??
      false;
  bool get _canReviewIncidents =>
      _estate?.roles.any(
        (role) =>
            role == 'estate_administrator' ||
            role == 'estate_manager' ||
            role == 'security_officer',
      ) ??
      false;
  bool get _canAdministerEstate =>
      _estate?.roles.contains('estate_administrator') ?? false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _gateCode.dispose();
    _gateName.dispose();
    _structureName.dispose();
    _structureCode.dispose();
    _maintenanceSearch.dispose();
    _maintenanceSearchTimer?.cancel();
    _dashboardScrollController.dispose();
    super.dispose();
  }

  void _jumpToMaintenance() {
    final section = _maintenanceSectionKey.currentContext;
    if (section != null) {
      Scrollable.ensureVisible(
        section,
        duration: const Duration(milliseconds: 350),
        alignment: 0.08,
        curve: Curves.easeOutCubic,
      );
    }
  }

  int get _pendingFacilityBookings => _facilityBookings
      .where((booking) => booking.status == 'pending_review')
      .length;

  int get _confirmedFacilityBookings => _facilityBookings
      .where((booking) => booking.status == 'confirmed')
      .length;

  List<EstateMaintenanceQueueItem> get _filteredMaintenanceRequests {
    final query = _maintenanceSearch.text.trim().toLowerCase();
    return _maintenanceQueue.items
        .where((request) {
          final status = request.status.toLowerCase();
          final matchesStatus = switch (_maintenanceStatusFilter) {
            'open' => !{'resolved', 'closed', 'rejected'}.contains(status),
            'all' => true,
            _ => status == _maintenanceStatusFilter,
          };
          final searchable = [
            request.reference,
            request.propertyLabel,
            request.category,
            request.priority,
            request.status,
            request.requesterDisplayName,
            request.assigneeDisplayName ?? '',
            request.description,
          ].join(' ').toLowerCase();
          return matchesStatus && (query.isEmpty || searchable.contains(query));
        })
        .toList(growable: false);
  }

  bool get _canViewEstateFinance =>
      _estate?.roles.any(
        (role) =>
            role == 'estate_administrator' ||
            role == 'estate_manager' ||
            role == 'finance_manager',
      ) ??
      false;

  Future<void> _restore() async {
    try {
      _account = await widget.repository.restoreSession();
      if (_account != null) await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _account = await widget.repository.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadEstates() async {
    _estates = await widget.repository.loadManagedEstates();
    _estate =
        _estates.where((estate) => estate.id == _estate?.id).firstOrNull ??
        (_estates.isEmpty ? null : _estates.first);
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    final estate = _estate;
    if (estate == null) {
      _summary = null;
      _maintenanceQueue = const EstateMaintenanceQueue(
        items: [],
        assignableStaff: [],
        total: 0,
      );
      _facilityBookings = const [];
      return;
    }
    if (!_canManageEstateOperations) {
      _summary = await widget.repository.loadManagerDashboard(estate.id);
      _maintenanceQueue = const EstateMaintenanceQueue(
        items: [],
        assignableStaff: [],
        total: 0,
      );
      _facilityBookings = const [];
      _estateGates = const [];
      _securityOfficers = const [];
      _estateStructure = const [];
      return;
    }
    final result = await Future.wait([
      widget.repository.loadManagerDashboard(estate.id),
      widget.repository.loadMaintenanceQueue(
        estate.id,
        page: _maintenancePage,
        pageSize: 50,
        status: _maintenanceStatusFilter == 'all'
            ? null
            : _maintenanceStatusFilter,
        search: _maintenanceSearch.text,
      ),
      widget.repository.loadEstateGates(estate.id),
      widget.repository.loadSecurityOfficers(estate.id),
      widget.repository.loadEstateStructure(estate.id),
      widget.repository.loadEstateFacilityBookings(estate.id),
      widget.repository.loadTreasurySummary(estate.id),
      widget.repository.loadPayoutBeneficiaries(estate.id),
      widget.repository.loadPayouts(estate.id),
      widget.repository.loadRentSchedule(estate.id),
      widget.repository.loadLandlordRentSummary(estate.id),
      widget.repository.loadEstateHousehold(estate.id),
      widget.repository.loadPropertyLocations(estate.id),
      widget.repository.loadEstateIdentityVerifications(estate.id),
      widget.repository.loadEstateServices(estate.id),
      widget.repository.loadEstateServiceOrders(estate.id),
      widget.repository.loadWalletStatement(estate.id),
      widget.repository.loadAuditLog(estate.id),
      widget.repository.loadManagerReportSummary(estate.id),
    ]);
    _summary = result[0] as EstateManagerDashboardSummary;
    _maintenanceQueue = result[1] as EstateMaintenanceQueue;
    _estateGates = result[2] as List<EstateGateRecord>;
    _securityOfficers = result[3] as List<EstateStaffChoice>;
    _estateStructure = result[4] as List<EstateStructureRecord>;
    _facilityBookings = result[5] as List<EstateFacilityBookingRecord>;
    _treasury = result.length > 6 ? result[6] as EstateTreasurySummary? : null;
    _beneficiaries = result.length > 7 ? result[7] as List<EstatePayoutBeneficiaryRecord> : const [];
    _payouts = result.length > 8 ? result[8] as List<EstatePayoutRecord> : const [];
    _rentSchedule = result.length > 9 ? result[9] as List<RentScheduleRecord> : const [];
    _landlordRent = result.length > 10 ? result[10] as List<LandlordRentSummaryRecord> : const [];
    _household = result.length > 11 ? result[11] as List<HouseholdMemberRecord> : const [];
    _locations = result.length > 12 ? result[12] as List<PropertyLocationRecord> : const [];
    _identity = result.length > 13 ? result[13] as List<IdentityVerificationRecord> : const [];
    _services = result.length > 14 ? result[14] as List<EstateServiceRecord> : const [];
    _serviceOrders = result.length > 15 ? result[15] as List<EstateServiceOrderRecord> : const [];
    _walletStatement = result.length > 16 ? result[16] as Map<String, dynamic> : const {};
    _auditLog = result.length > 17
        ? (result[17] as Map<String, dynamic>)['items'] as List<dynamic>? ?? const []
        : const [];
    _reportSummary = result.length > 18
        ? result[18] as Map<String, dynamic>
        : const {};
    _selectedGateId = _estateGates.any((gate) => gate.id == _selectedGateId)
        ? _selectedGateId
        : (_estateGates.isEmpty ? null : _estateGates.first.id);
    _selectedOfficerId =
        _securityOfficers.any((staff) => staff.userId == _selectedOfficerId)
        ? _selectedOfficerId
        : (_securityOfficers.isEmpty ? null : _securityOfficers.first.userId);
    final parentChoices = _structureParentChoices();
    _structureParentId =
        parentChoices.any((node) => node.id == _structureParentId)
        ? _structureParentId
        : (parentChoices.isEmpty ? null : parentChoices.first.id);
  }

  void _scheduleMaintenanceSearch(String _) {
    _maintenanceSearchTimer?.cancel();
    _maintenanceSearchTimer = Timer(const Duration(milliseconds: 350), () {
      _reloadMaintenanceQueue(resetPage: true);
    });
  }

  Future<void> _reloadMaintenanceQueue({bool resetPage = false}) async {
    final estate = _estate;
    if (estate == null) return;
    if (resetPage) _maintenancePage = 1;
    setState(() => _maintenanceQueueLoading = true);
    try {
      var queue = await widget.repository.loadMaintenanceQueue(
        estate.id,
        page: _maintenancePage,
        pageSize: 50,
        status: _maintenanceStatusFilter == 'all'
            ? null
            : _maintenanceStatusFilter,
        search: _maintenanceSearch.text,
      );
      if (queue.totalPages > 0 && _maintenancePage > queue.totalPages) {
        _maintenancePage = queue.totalPages;
        queue = await widget.repository.loadMaintenanceQueue(
          estate.id,
          page: _maintenancePage,
          pageSize: 50,
          status: _maintenanceStatusFilter == 'all'
              ? null
              : _maintenanceStatusFilter,
          search: _maintenanceSearch.text,
        );
      }
      _maintenanceQueue = queue;
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _maintenanceQueueLoading = false);
    }
  }

  Future<void> _selectMaintenancePage(int page) async {
    if (page < 1 ||
        (_maintenanceQueue.totalPages > 0 &&
            page > _maintenanceQueue.totalPages)) {
      return;
    }
    _maintenancePage = page;
    await _reloadMaintenanceQueue();
  }

  List<EstateStructureRecord> _structureParentChoices() {
    final types = switch (_structureType) {
      'street' => ['zone'],
      'building' => ['zone', 'street'],
      'floor' => ['building'],
      _ => <String>[],
    };
    return _estateStructure
        .where((node) => node.status == 'active' && types.contains(node.type))
        .toList(growable: false);
  }

  Future<void> _createStructureNode() async {
    final estate = _estate;
    if (estate == null ||
        _structureName.text.trim().length < 2 ||
        (_structureType == 'floor' && _structureParentId == null))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createStructureNode(
        estateId: estate.id,
        type: _structureType,
        name: _structureName.text.trim(),
        code: _structureCode.text.trim(),
        parentIds: _structureParentId == null
            ? const []
            : [_structureParentId!],
      );
      _structureName.clear();
      _structureCode.clear();
      await _loadSummary();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estate structure node created.')),
        );
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveStructureNode(EstateStructureRecord node) async {
    final estate = _estate;
    if (estate == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${node.name}?'),
        content: const Text(
          'The structure history is kept. Nodes with active child nodes or linked properties cannot be archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.archiveStructureNode(
        estateId: estate.id,
        nodeId: node.id,
      );
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGate() async {
    final estate = _estate;
    if (estate == null ||
        _gateCode.text.trim().length < 2 ||
        _gateName.text.trim().length < 2)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createEstateGate(
        estateId: estate.id,
        code: _gateCode.text.trim(),
        name: _gateName.text.trim(),
      );
      _gateCode.clear();
      _gateName.clear();
      await _loadSummary();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gate created.')));
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignGateOfficer() async {
    final estate = _estate;
    final gateId = _selectedGateId;
    final officerId = _selectedOfficerId;
    if (estate == null || gateId == null || officerId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.assignGateOfficer(
        estateId: estate.id,
        gateId: gateId,
        userId: officerId,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security officer assigned to gate.')),
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
      await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectEstate(ManagedEstateChoice? estate) async {
    setState(() {
      _estate = estate;
      _maintenancePage = 1;
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewMaintenanceRequest(
    EstateMaintenanceQueueItem request,
  ) async {
    final result = await showDialog<_MaintenanceReviewResult>(
      context: context,
      builder: (context) => _MaintenanceReviewDialog(
        request: request,
        assignableStaff: _maintenanceQueue.assignableStaff,
      ),
    );
    if (result == null || _estate == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reviewMaintenanceRequest(
        estateId: _estate!.id,
        requestId: request.id,
        command: result.command,
        assigneeUserId: result.assigneeUserId,
        reason: result.reason,
        resolutionSummary: result.resolutionSummary,
        residentUpdate: result.residentUpdate,
        internalNote: result.internalNote,
      );
      await _reloadMaintenanceQueue();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance request updated.')),
        );
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openResidentAccessReview() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResidentAccessReviewPage(
          repository: widget.repository,
          initialEstateId: estate.id,
          showSignOutAction: false,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOwnershipReview() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OwnershipReviewApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTenancyApprovals() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TenancyApprovalApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTenancy() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EstateTenancyCreateApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
    if (!mounted || created != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStaffInvitations() async {
    final estate = _estate;
    if (estate == null || _busy || !_canAdministerEstate) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateStaffInvitationsApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
  }

  Future<void> _openEstateSettings() async {
    final estate = _estate;
    if (estate == null || _busy || !_canAdministerEstate) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateSettingsApiPage(
          repository: widget.repository,
          estateId: estate.id,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _loadEstates();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEstateCharges() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateChargesPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
          canReconcileSettlements: estate.roles.any(
            (role) =>
                role == 'finance_manager' || role == 'estate_administrator',
          ),
        ),
      ),
    );
  }

  Future<void> _openEstateExpenses() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateExpensesApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
          roles: estate.roles,
        ),
      ),
    );
  }

  Future<void> _openEstateFacilities() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateFacilitiesAdminPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _loadSummary();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRentSchedulePreview() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RentSchedulePreviewPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
  }

  Future<void> _openEstateAnnouncements() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateAnnouncementsApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
  }

  Future<void> _openSecurityIncidents() async {
    final estate = _estate;
    if (estate == null || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EstateSecurityIncidentsApiPage(
          repository: widget.repository,
          estateId: estate.id,
          estateName: estate.name,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _estates = const [];
      _estate = null;
      _summary = null;
      _maintenanceQueue = const EstateMaintenanceQueue(
        items: [],
        assignableStaff: [],
        total: 0,
      );
    });
  }

  String _message(Object error) => error is EstateApiException
      ? error.message
      : 'The estate dashboard could not be loaded.';

  Widget _gateManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gate security',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EstateColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create estate gates and assign active security officers.',
              style: TextStyle(color: EstateColors.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _gateCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Gate code',
                      hintText: 'NORTH',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _gateName,
                    decoration: const InputDecoration(
                      labelText: 'Gate name',
                      hintText: 'North entrance',
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _createGate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create gate'),
                ),
              ],
            ),
            if (_estateGates.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGateId,
                      decoration: const InputDecoration(labelText: 'Gate'),
                      items: _estateGates
                          .map(
                            (gate) => DropdownMenuItem(
                              value: gate.id,
                              child: Text(
                                '${gate.code} · ${gate.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _selectedGateId = value),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedOfficerId,
                      decoration: const InputDecoration(
                        labelText: 'Security officer',
                      ),
                      items: _securityOfficers
                          .map(
                            (staff) => DropdownMenuItem(
                              value: staff.userId,
                              child: Text(
                                staff.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || _securityOfficers.isEmpty
                          ? null
                          : (value) =>
                                setState(() => _selectedOfficerId = value),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _securityOfficers.isEmpty
                        ? null
                        : _assignGateOfficer,
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Assign officer'),
                  ),
                ],
              ),
              if (_securityOfficers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Add an active security officer membership to this estate before assigning a gate.',
                    style: TextStyle(color: EstateColors.muted, fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (_estateGates.isEmpty)
              const Text(
                'No gates have been configured yet.',
                style: TextStyle(color: EstateColors.muted, fontSize: 13),
              )
            else
              ..._estateGates.map(
                (gate) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.door_front_door_outlined,
                    color: EstateColors.forest,
                  ),
                  title: Text(gate.name),
                  subtitle: Text('Gate ${gate.code}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _structureManagementCard() {
    final parents = _structureParentChoices();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estate structure',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EstateColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Organize the estate into zones, streets, buildings and floors. Changes are saved to the estate.',
              style: TextStyle(color: EstateColors.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _structureType,
                    decoration: const InputDecoration(
                      labelText: 'Structure type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'zone',
                        child: Text('Zone / phase'),
                      ),
                      DropdownMenuItem(value: 'street', child: Text('Street')),
                      DropdownMenuItem(
                        value: 'building',
                        child: Text('Building'),
                      ),
                      DropdownMenuItem(value: 'floor', child: Text('Floor')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _structureType = value ?? 'zone';
                            _structureParentId = null;
                            final available = _structureParentChoices();
                            _structureParentId = available.isEmpty
                                ? null
                                : available.first.id;
                          }),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _structureName,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _structureCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Code (optional)',
                    ),
                  ),
                ),
                if (parents.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _structureParentId,
                      decoration: const InputDecoration(
                        labelText: 'Parent (optional)',
                      ),
                      items: parents
                          .map(
                            (node) => DropdownMenuItem(
                              value: node.id,
                              child: Text(
                                '${node.type}: ${node.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _structureParentId = value),
                    ),
                  ),
                FilledButton.icon(
                  onPressed:
                      _busy ||
                          (_structureType == 'floor' &&
                              _structureParentId == null)
                      ? null
                      : _createStructureNode,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add structure'),
                ),
              ],
            ),
            if (_structureType == 'floor' && parents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Create a building before adding floors.',
                  style: TextStyle(color: EstateColors.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (_estateStructure.isEmpty)
              const Text(
                'No zones, streets or buildings have been added yet.',
                style: TextStyle(color: EstateColors.muted, fontSize: 13),
              )
            else
              ..._estateStructure.map(
                (node) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (node.type) {
                    'zone' => Icons.map_outlined,
                    'street' => Icons.route_outlined,
                    'building' => Icons.apartment_outlined,
                    _ => Icons.stairs_outlined,
                  }, color: EstateColors.forest),
                  title: Text(node.name),
                  subtitle: Text(
                    '${node.type} · ${node.code ?? 'No code'} · ${node.linkedPropertyCount} properties${node.parentNames.isEmpty ? '' : ' · under ${node.parentNames.join(', ')}'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Archive structure node',
                    onPressed: _busy || node.linkedPropertyCount > 0
                        ? null
                        : () => _archiveStructureNode(node),
                    icon: const Icon(Icons.archive_outlined),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateRentSchedule() async {
    final estate = _estate;
    if (estate == null) return;
    try {
      final result = await widget.repository.generateRentSchedule(estate.id);
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rent schedule: ${result['created']} added, ${result['skipped']} already present.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate rent schedule: $error')),
      );
    }
  }

  Future<void> _createService() async {
    final estate = _estate;
    if (estate == null) return;
    final code = TextEditingController();
    final name = TextEditingController();
    final category = TextEditingController(text: 'utilities');
    final provider = TextEditingController(text: 'demo');
    final amount = TextEditingController(text: '1000.00');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add demo service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Code (e.g. AIRTIME)')),
              const SizedBox(height: 10),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              TextField(controller: provider, decoration: const InputDecoration(labelText: 'Provider')),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (NGN)')),
              const SizedBox(height: 10),
              const Text('Services are created in demo mode; no real vending provider is contacted.',
                  style: TextStyle(fontSize: 11, color: EstateColors.muted)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await widget.repository.createEstateService(
        estateId: estate.id,
        code: code.text.trim().toUpperCase(),
        name: name.text.trim(),
        category: category.text.trim(),
        provider: provider.text.trim(),
        amount: amount.text.trim(),
        currency: 'NGN',
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo service created.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create service: $error')),
      );
    }
  }

  Future<void> _decideIdentity(IdentityVerificationRecord row, String decision) async {
    final estate = _estate;
    if (estate == null) return;
    try {
      await widget.repository.decideIdentityVerification(
        estateId: estate.id,
        verificationId: row.id,
        decision: decision,
        reason: decision == 'reject' ? 'Unable to confirm the submitted evidence.' : null,
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identity verification $decision.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update verification: $error')),
      );
    }
  }

  Future<void> _captureLocation(PropertyLocationRecord property) async {
    final estate = _estate;
    if (estate == null) return;
    final latitude = TextEditingController(text: property.latitude ?? '');
    final longitude = TextEditingController(text: property.longitude ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Capture location for ${property.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitude,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Latitude (-90 to 90)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: longitude,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Longitude (-180 to 180)'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Coordinates are stored as pending until verified. Residents cannot see unverified pins.',
              style: TextStyle(fontSize: 11, color: EstateColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save pin')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await widget.repository.capturePropertyLocation(
        estateId: estate.id,
        propertyId: property.id,
        latitude: latitude.text.trim(),
        longitude: longitude.text.trim(),
        captureMethod: 'MAP_PIN',
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property pin saved for verification.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save pin: $error')),
      );
    }
  }

  Future<void> _verifyLocation(PropertyLocationRecord property, String decision) async {
    final estate = _estate;
    if (estate == null) return;
    try {
      await widget.repository.verifyPropertyLocation(
        estateId: estate.id,
        propertyId: property.id,
        decision: decision,
        reason: decision == 'reject' ? 'Pin does not match the property.' : null,
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Property location $decision.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update location: $error')),
      );
    }
  }

  Future<void> _decideHousehold(String memberId, String decision) async {
    final estate = _estate;
    if (estate == null) return;
    try {
      await widget.repository.decideHouseholdMember(
        estateId: estate.id,
        memberId: memberId,
        decision: decision,
        note: decision == 'approve' ? 'Reviewed by estate management.' : 'Does not meet household policy.',
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Household member $decision.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update household member: $error')),
      );
    }
  }

  Future<void> _generateRecurringLevies() async {
    final estate = _estate;
    if (estate == null) return;
    try {
      final result = await widget.repository.generateRecurringLevies(estate.id);
      await _loadSummary();
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
        SnackBar(content: Text('Could not generate levies: $error')),
      );
    }
  }

  Future<void> _requestPayout() async {
    final estate = _estate;
    if (estate == null) return;
    if (_beneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verified beneficiary is configured for this estate.'),
        ),
      );
      return;
    }
    EstatePayoutBeneficiaryRecord? beneficiary;
    final amount = TextEditingController();
    final purpose = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a payout'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<EstatePayoutBeneficiaryRecord>(
                initialValue: _beneficiaries.firstOrNull,
                decoration: const InputDecoration(labelText: 'Beneficiary'),
                items: _beneficiaries
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item.displayName} · ${item.accountNumber}'),
                        ))
                    .toList(),
                onChanged: (value) => beneficiary = value,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (NGN)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
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
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final selected = beneficiary ?? _beneficiaries.first;
    final value = amount.text.trim();
    if (!RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(value) ||
        purpose.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and purpose.')),
      );
      return;
    }
    try {
      await widget.repository.createPayout(
        estateId: estate.id,
        beneficiaryId: selected.id,
        amount: value,
        purpose: purpose.text.trim(),
        idempotencyKey: 'payout-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted for approval.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout request failed: $error')),
      );
    }
  }

  Future<void> _decidePayout(EstatePayoutRecord payout, String decision) async {
    final estate = _estate;
    if (estate == null) return;
    try {
      await widget.repository.decidePayout(
        estateId: estate.id,
        payoutId: payout.id,
        decision: decision,
      );
      await _loadSummary();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update payout: $error')),
      );
    }
  }

  Drawer _buildMenuDrawer() {
    final estate = _estate;
    Widget item(IconData icon, String label, VoidCallback? onTap) => ListTile(
      leading: Icon(icon, color: EstateColors.forest),
      title: Text(label),
      onTap: onTap,
    );
    Widget open(String label, IconData icon, Widget Function(ManagedEstateChoice current) page) =>
        item(icon, label, estate == null ? null : () async {
          final current = estate;
          Navigator.of(context).pop();
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => page(current)),
          );
          if (mounted) _refresh();
        });
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              color: EstateColors.forest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.apartment_outlined, color: Colors.white, size: 28),
                  const SizedBox(height: 10),
                  const Text(
                    'Estate Management',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    estate?.name ?? 'Select an estate',
                    style: const TextStyle(color: Color(0xFFCFE3D7), fontSize: 12),
                  ),
                ],
              ),
            ),
            item(Icons.dashboard_outlined, 'Overview', () => Navigator.of(context).pop()),
            const Divider(height: 1),
            if (_canManageEstateOperations)
              item(Icons.how_to_reg_outlined, 'Resident access',
                  estate == null ? null : _openResidentAccessReview),
            if (_canManageEstateOperations)
              open('Ownership verification', Icons.verified_user_outlined,
                  (e) => OwnershipReviewApiPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            open('Tenancy approvals', Icons.key_outlined,
                (e) => TenancyApprovalApiPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            const Divider(height: 1),
            open('Charges & invoice policy', Icons.receipt_long_outlined,
                (e) => EstateChargesPage(repository: widget.repository, estateId: e.id, estateName: e.name, canReconcileSettlements: e.roles.any((role) => role == 'finance_manager' || role == 'estate_administrator'))),
            open('Expenses & budgets', Icons.account_balance_wallet_outlined,
                (e) => EstateExpensesApiPage(repository: widget.repository, estateId: e.id, estateName: e.name, roles: e.roles)),
            open('Facilities & bookings', Icons.event_available_outlined,
                (e) => EstateFacilitiesAdminPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            open('Security incidents', Icons.shield_outlined,
                (e) => EstateSecurityIncidentsApiPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            open('Resident notices', Icons.campaign_outlined,
                (e) => EstateAnnouncementsApiPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            const Divider(height: 1),
            open('Staff invitations', Icons.person_add_alt_1_outlined,
                (e) => EstateStaffInvitationsApiPage(repository: widget.repository, estateId: e.id, estateName: e.name)),
            open('Estate settings', Icons.settings_outlined,
                (e) => EstateSettingsApiPage(repository: widget.repository, estateId: estate!.id)),
            const Divider(height: 1),
            item(Icons.notifications_outlined, 'Notifications', () {
              Navigator.of(context).pop();
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => EstateNotificationsPage(repository: widget.repository),
                ),
              );
            }),
            item(Icons.logout_outlined, 'Sign out', _signOut),
          ],
        ),
      ),
    );
  }

  ManagerServiceContext _managerServiceContext() => ManagerServiceContext(
        repository: widget.repository,
        estateId: _estate?.id ?? '',
        estateName: _estate?.name ?? 'Your estate',
      );

  Future<void> _openManagerPage(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _exportReport(String type) async {
    final estate = _estate;
    if (estate == null) return;
    try {
      final csv = await widget.repository.fetchReportCsv(estate.id, type);
      final slug = estate.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase();
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

  String _reportValue(String section, String key) {
    if (section == 'auditEvents') return _reportSummary['auditEvents']?.toString() ?? '0';
    return (_reportSummary[section] as Map? ?? const {})[key]?.toString() ?? '0';
  }

  Widget _referenceHeader() {
    final estate = _estate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardGreeting(
          period: _greetingPeriod(),
          title: 'Welcome, ${_account?.displayName.split(' ').first ?? 'Manager'}',
          subtitle: '${estate?.name ?? 'Estate management'} · Estate manager',
          trailing: [
            IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: DashboardTokens.text, size: 21),
            ),
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
              icon: const Icon(Icons.notifications_none_outlined,
                  color: DashboardTokens.text, size: 20),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded,
                  color: DashboardTokens.text, size: 20),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _signOut(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
              child: const Icon(Icons.more_vert, color: DashboardTokens.text),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashboardHero(
          label: 'MONEY COLLECTED FOR THE ESTATE',
          amount: 'NGN ${_formatMoney(_treasury?.collections ?? '0')}',
          caption: 'Outstanding invoices NGN ${_formatMoney(_treasury?.outstandingInvoices ?? '0')} · '
              '${_treasury?.pendingSettlements ?? 0} pending settlements',
          badge: 'DEMO MODE · NO REAL MONEY',
          cardIcon: Icons.account_balance_outlined,
          onSettings: _openEstateSettings,
          actions: [
            DashboardHeroAction(
              icon: Icons.receipt_long_outlined,
              label: 'Record spending',
              onTap: _openEstateExpenses,
            ),
            DashboardHeroAction(
              icon: Icons.approval_outlined,
              label: 'Approvals',
              onTap: _openResidentAccessReview,
            ),
            DashboardHeroAction(
              icon: Icons.autorenew_outlined,
              label: 'Send bills',
              onTap: _generateRecurringLevies,
            ),
          ],
        ),
        const SizedBox(height: 22),
        DashboardQuickServices(
          services: [
            DashboardService(icon: Icons.apartment_outlined, label: 'Properties', onTap: _openOwnershipReview),
            DashboardService(icon: Icons.people_outline, label: 'Residents', onTap: _openResidentAccessReview),
            DashboardService(icon: Icons.home_outlined, label: 'Tenancies', onTap: _openTenancyApprovals),
            DashboardService(icon: Icons.receipt_long_outlined, label: 'Levies', onTap: _openEstateCharges),
            DashboardService(
              icon: Icons.payments_outlined,
              label: 'Payouts',
              onTap: () => _openManagerPage(
                ManagerPayoutsPage(
                  serviceContext: _managerServiceContext(),
                ),
              ),
            ),
            DashboardService(icon: Icons.account_balance_wallet_outlined, label: 'Expenses', onTap: _openEstateExpenses),
            DashboardService(
              icon: Icons.map_outlined,
              label: 'Property map',
              onTap: () => _openManagerPage(
                ManagerPropertyMapPage(
                  serviceContext: _managerServiceContext(),
                ),
              ),
            ),
            DashboardService(icon: Icons.storefront_outlined, label: 'Services', onTap: _openEstateFacilities),
            DashboardService(icon: Icons.shield_outlined, label: 'Security', onTap: _openSecurityIncidents),
            DashboardService(icon: Icons.campaign_outlined, label: 'Notices', onTap: _openEstateAnnouncements),
            DashboardService(icon: Icons.badge_outlined, label: 'Staff', onTap: _openStaffInvitations),
            DashboardService(icon: Icons.settings_outlined, label: 'Settings', onTap: _openEstateSettings),
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
    if (_restoring)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_account == null) return _signInView();
    final summary = _summary;
    return Theme(
      data: DashboardTokens.darkShell,
      child: Scaffold(
      backgroundColor: DashboardTokens.background,
      drawer: _buildMenuDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            controller: _dashboardScrollController,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _Notice(message: _error!, error: true),
                ),
              _referenceHeader(),
              const SizedBox(height: 22),
              if (_estates.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This account is for an applicant or resident',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Estate operations require a manager account. Sign out here, then use the estate manager demo login.',
                          style: TextStyle(color: EstateColors.muted),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _busy ? null : _signOut,
                          icon: const Icon(Icons.switch_account_outlined),
                          label: const Text('Switch to manager account'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 7,
                    ),
                    child: DropdownButtonFormField<ManagedEstateChoice>(
                      initialValue: _estate,
                      decoration: const InputDecoration(
                        labelText: 'Estate',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: _estates
                          .map(
                            (estate) => DropdownMenuItem(
                              value: estate,
                              child: Text(estate.name),
                            ),
                          )
                          .toList(),
                      onChanged: _busy ? null : _selectEstate,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy && summary == null)
                  const LinearProgressIndicator(minHeight: 2),
                if (summary != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 17,
                        color: EstateColors.forest,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live estate data • refreshed ${_formatDate(summary.asOf)}',
                        style: const TextStyle(
                          color: EstateColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetricsGrid(summary: summary),
                  const SizedBox(height: 16),
                  if (_canManageEstateOperations) ...[
                    const Text(
                      'Needs attention',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: EstateColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_canManageEstateOperations)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760;
                        final cards = [
                          _ActivityCard(
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Resident access',
                            count: summary.pendingAccessRequests,
                            detail: summary.pendingAccessRequests == 0
                                ? 'No requests are awaiting review.'
                                : 'Review membership and property access requests.',
                            color: const Color(0xFF9A7538),
                            onTap: _busy ? null : _openResidentAccessReview,
                          ),
                          _ActivityCard(
                            icon: Icons.verified_user_outlined,
                            title: 'Ownership checks',
                            count: summary.pendingOwnershipReviews,
                            detail: summary.pendingOwnershipReviews == 0
                                ? 'No ownership claims are awaiting review.'
                                : 'Verify the evidence your estate team checked.',
                            color: EstateColors.forest,
                            onTap: _busy ? null : _openOwnershipReview,
                          ),
                          _ActivityCard(
                            icon: Icons.key_outlined,
                            title: 'Tenancy approvals',
                            count: summary.pendingTenancies,
                            detail: summary.pendingTenancies == 0
                                ? 'No tenancy terms are awaiting approval.'
                                : 'Review pending tenancy terms and activate occupancy.',
                            color: const Color(0xFF486D91),
                            onTap: _busy ? null : _openTenancyApprovals,
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: cards
                              .map(
                                (card) => SizedBox(
                                  width: columns
                                      ? (constraints.maxWidth - 24) / 3
                                      : constraints.maxWidth,
                                  child: card,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  if (_canManageEstateOperations &&
                      _maintenanceQueue.total > 0) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _jumpToMaintenance,
                        icon: const Icon(Icons.handyman_outlined),
                        label: Text(
                          'Review maintenance (${_maintenanceQueue.total})',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.summarize_outlined, color: DashboardTokens.greenLeaf),
                            SizedBox(width: 9),
                            Text('Reports',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              _ReportMetric(label: 'Invoices', value: _reportValue('invoices', 'total')),
                              _ReportMetric(label: 'Billed', value: '${_reportSummary['currency'] ?? 'NGN'} ${_reportValue('invoices', 'billed')}'),
                              _ReportMetric(label: 'Rent outstanding', value: '${_reportSummary['currency'] ?? 'NGN'} ${_reportValue('rent', 'outstanding')}'),
                              _ReportMetric(label: 'Expenses', value: _reportValue('expenses', 'total')),
                              _ReportMetric(label: 'Payouts', value: _reportValue('payouts', 'total')),
                              _ReportMetric(label: 'Audit events', value: _reportValue('auditEvents', '')),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
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
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.assessment_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Statements & audit trail',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            'Wallet closing balance ${_walletStatement['summary']?['closing'] ?? '0'} · '
                            '${(_walletStatement['items'] as List? ?? const []).length} entries. '
                            'CSV exports are available from the statements API.',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          ..._auditLog.take(5).map(
                                (entry) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${entry['action']} · ${entry['outcome']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${entry['actorName'] ?? 'System'} · ${entry['occurredAt']}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.storefront_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Services catalogue (demo)',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            '${_services.length} services · ${_serviceOrders.length} demo orders. '
                            'Orders are paid from resident wallets and fulfil with labelled demo vouchers.',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _createService,
                              icon: const Icon(Icons.add),
                              label: const Text('Add demo service'),
                            ),
                          ),
                          ..._serviceOrders.take(4).map(
                                (row) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${row.currency} ${row.amount} · ${row.status}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(
                                    '${row.provider}${row.demo ? ' · demo' : ''} · ${row.fulfilmentCode ?? ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.badge_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Identity verification',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            '${_identity.where((row) => row.status == 'pending').length} pending review'
                            '${_identity.any((row) => row.demo) ? ' · demo declarations included' : ''}',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          ..._identity
                              .where((row) => row.status == 'pending')
                              .take(5)
                              .map(
                                (row) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${row.userName ?? 'Resident'} · ${row.provider}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${row.method}${row.demo ? ' · demo (not provider-verified)' : ''} · ${row.level}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () => _decideIdentity(row, 'reject'),
                                        child: const Text('Reject'),
                                      ),
                                      FilledButton(
                                        onPressed: () => _decideIdentity(row, 'verify'),
                                        child: const Text('Verify'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.place_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Property GPS & verification',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            '${_locations.where((row) => row.verificationStatus == 'verified').length} verified · '
                            '${_locations.where((row) => row.verificationStatus == 'pending_verification').length} pending',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          ..._locations.take(6).map(
                                (row) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.location_on_outlined, size: 18),
                                  title: Text('${row.code} · ${row.verificationStatus}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(
                                    row.latitude == null
                                        ? 'No pin captured'
                                        : '${row.latitude}, ${row.longitude}'
                                            '${row.captureMethod != null ? ' · ${row.captureMethod}' : ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () => _captureLocation(row),
                                        child: const Text('Pin'),
                                      ),
                                      if (row.verificationStatus == 'pending_verification')
                                        TextButton(
                                          onPressed: () => _verifyLocation(row, 'verify'),
                                          child: const Text('Verify'),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.family_restroom_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Household review',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            '${_household.where((row) => row.status == 'pending_approval').length} pending review · '
                            '${_household.length} total members',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          ..._household
                              .where((row) => row.status == 'pending_approval')
                              .take(5)
                              .map(
                                (row) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(row.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${row.relationship.toLowerCase()} · ${row.propertyCode} · added by ${row.primaryUserName}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () => _decideHousehold(row.id, 'reject'),
                                        child: const Text('Reject'),
                                      ),
                                      FilledButton(
                                        onPressed: () => _decideHousehold(row.id, 'approve'),
                                        child: const Text('Approve'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.receipt_long_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Recurring estate levies',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate and issue the next 3 months of invoices for active '
                            'recurring charges. Re-running is safe and will not duplicate invoices.',
                            style: TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _generateRecurringLevies,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Generate levies'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.calendar_month_outlined, color: EstateColors.forest),
                            SizedBox(width: 9),
                            Text('Rent schedule & landlord entitlement',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            '${_rentSchedule.length} scheduled installments · '
                            '${_rentSchedule.where((row) => row.isOverdue).length} overdue',
                            style: const TextStyle(color: EstateColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _generateRentSchedule,
                              icon: const Icon(Icons.autorenew_outlined),
                              label: const Text('Generate next 3 months'),
                            ),
                          ),
                          if (_landlordRent.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._landlordRent.take(4).map(
                                  (row) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(row.payeeName,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      'Collected ${row.currency} ${row.collected} · Outstanding ${row.currency} ${row.outstanding}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_treasury != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: const [
                              Icon(Icons.account_balance_outlined, color: EstateColors.forest),
                              SizedBox(width: 9),
                              Text('Estate treasury',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ]),
                            const SizedBox(height: 10),
                            Wrap(spacing: 20, runSpacing: 12, children: [
                              _TreasuryFigure(label: 'Collections', value: _treasury!.collections),
                              _TreasuryFigure(label: 'Wallet balances', value: _treasury!.walletBalances),
                              _TreasuryFigure(label: 'Outstanding invoices', value: _treasury!.outstandingInvoices),
                              _TreasuryFigure(label: 'Pending settlements', value: '${_treasury!.pendingSettlements}'),
                              _TreasuryFigure(label: 'Reconciliation exceptions', value: '${_treasury!.reconciliationExceptions}'),
                            ]),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _requestPayout,
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Request payout'),
                              ),
                            ),
                            if (_payouts.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('Payout requests',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ..._payouts.take(5).map(
                                    (payout) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${payout.currency} ${payout.amount} · ${payout.status}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        '${payout.beneficiaryName} · ${payout.purpose}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: payout.status == 'pending_approval'
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Approve',
                                                  onPressed: () => _decidePayout(payout, 'approve'),
                                                  icon: const Icon(Icons.check_circle_outline, color: EstateColors.forest),
                                                ),
                                                IconButton(
                                                  tooltip: 'Reject',
                                                  onPressed: () => _decidePayout(payout, 'reject'),
                                                  icon: const Icon(Icons.cancel_outlined, color: EstateColors.red),
                                                ),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _WalletCard(
                    summary: summary,
                    onOpenCharges: _estate == null
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => EstateChargesPage(
                                  repository: widget.repository,
                                  estateId: _estate!.id,
                                  estateName: _estate!.name,
                                  canReconcileSettlements: _estate!.roles.any(
                                    (role) =>
                                        role == 'finance_manager' ||
                                        role == 'estate_administrator',
                                  ),
                                ),
                              ),
                            );
                            if (mounted) _refresh();
                          },
                    onOpenExpenses: _estate == null
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => EstateExpensesApiPage(
                                  repository: widget.repository,
                                  estateId: _estate!.id,
                                  estateName: _estate!.name,
                                  roles: _estate!.roles,
                                ),
                              ),
                            );
                            if (mounted) _refresh();
                          },
                  ),
                  const SizedBox(height: 18),
                  _IssuedInvoicesCard(summary: summary),
                  const SizedBox(height: 18),
                  if (_canReviewIncidents)
                    _dashboardGroup(
                      icon: Icons.campaign_outlined,
                      title: 'Community operations',
                      description:
                          'Incidents, resident notices and shared facilities.',
                      initiallyExpanded: true,
                      children: [
                        _dashboardActionTile(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Security incidents',
                          description: _canManageEstateOperations
                              ? 'Record reports and review the estate incident queue.'
                              : 'Review incident reports for your assigned estate.',
                          onTap: _busy ? null : _openSecurityIncidents,
                        ),
                        if (_canManageEstateOperations) ...[
                          const Divider(height: 1),
                          _dashboardActionTile(
                            icon: Icons.campaign_outlined,
                            title: 'Estate announcements',
                            description: 'Publish community notices to resident and landlord feeds.',
                            onTap: _busy ? null : _openEstateAnnouncements,
                          ),
                          const Divider(height: 1),
                          _dashboardActionTile(
                            icon: Icons.pool_outlined,
                            title: 'Facilities and bookings',
                            description: _facilityBookings.isEmpty
                                ? 'Configure shared spaces and review resident booking requests.'
                                : '$_pendingFacilityBookings booking requests pending · $_confirmedFacilityBookings confirmed.',
                            onTap: _busy ? null : _openEstateFacilities,
                          ),
                        ],
                      ],
                    ),
                  if (_canManageEstateOperations)
                    _dashboardGroup(
                      icon: Icons.apartment_outlined,
                      title: 'People and property',
                      description:
                          'Tenancies, estate structure and team access.',
                      children: [
                        _dashboardActionTile(
                          icon: Icons.key_outlined,
                          title: 'Add tenancy',
                          description: 'Record a tenant, verified landlord and rent terms.',
                          onTap: _busy ? null : _createTenancy,
                        ),
                        const SizedBox(height: 10),
                        _gateManagementCard(),
                        const SizedBox(height: 10),
                        _structureManagementCard(),
                        if (_canAdministerEstate) ...[
                          const SizedBox(height: 10),
                          _dashboardActionTile(
                            icon: Icons.group_add_outlined,
                            title: 'Staff access',
                            description: 'Invite managers, finance managers and security officers.',
                            onTap: _busy ? null : _openStaffInvitations,
                          ),
                          const Divider(height: 1),
                          _dashboardActionTile(
                            icon: Icons.tune_outlined,
                            title: 'Estate profile',
                            description: 'Update the estate name, type and location details.',
                            onTap: _busy ? null : _openEstateSettings,
                          ),
                        ],
                      ],
                    ),
                  if (_canViewEstateFinance)
                    _dashboardGroup(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Finance and billing',
                      description:
                          'Estate charges and upcoming tenancy rent dates.',
                      children: [
                        _dashboardActionTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'Estate charges',
                          description:
                              'Configure versioned fees for future invoices.',
                          onTap: _busy ? null : _openEstateCharges,
                        ),
                        const Divider(height: 1),
                        _dashboardActionTile(
                          icon: Icons.request_quote_outlined,
                          title: 'Expense requests',
                          description: 'Set approval rules, record payees and review spend requests.',
                          onTap: _busy ? null : _openEstateExpenses,
                        ),
                        const Divider(height: 1),
                        _dashboardActionTile(
                          icon: Icons.event_outlined,
                          title: 'Rent schedule preview',
                          description: 'Review upcoming rent dates and named landlord payees.',
                          onTap: _busy ? null : _openRentSchedulePreview,
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  if (_canManageEstateOperations)
                    Row(
                      key: _maintenanceSectionKey,
                      children: [
                        const Expanded(
                          child: Text(
                            'Maintenance requests',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: EstateColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${_maintenanceQueue.total} total',
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  if (_canManageEstateOperations) const SizedBox(height: 8),
                  if (_canManageEstateOperations &&
                      _maintenanceQueue.items.isNotEmpty) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final searchWidth = constraints.maxWidth < 560
                            ? constraints.maxWidth
                            : constraints.maxWidth - 210;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: searchWidth,
                              child: TextField(
                                controller: _maintenanceSearch,
                                onChanged: _scheduleMaintenanceSearch,
                                decoration: InputDecoration(
                                  labelText: 'Search requests',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _maintenanceSearch.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _maintenanceSearch.clear();
                                            _scheduleMaintenanceSearch('');
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 190,
                              child: DropdownButtonFormField<String>(
                                initialValue: _maintenanceStatusFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'open',
                                    child: Text('Open requests'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All statuses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'submitted',
                                    child: Text('Submitted'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'under_review',
                                    child: Text('Under review'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'assigned',
                                    child: Text('Assigned'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('In progress'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'awaiting_parts',
                                    child: Text('Awaiting parts'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'reopened',
                                    child: Text('Reopened'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'resolved',
                                    child: Text('Resolved'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'closed',
                                    child: Text('Closed'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rejected',
                                    child: Text('Rejected'),
                                  ),
                                ],
                                onChanged: _busy || _maintenanceQueueLoading
                                    ? null
                                    : (value) {
                                        setState(
                                          () => _maintenanceStatusFilter =
                                              value ?? 'open',
                                        );
                                        _reloadMaintenanceQueue(
                                          resetPage: true,
                                        );
                                      },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _maintenanceQueue.total == 0
                                ? 'No matching requests.'
                                : 'Showing ${(_maintenanceQueue.page - 1) * _maintenanceQueue.pageSize + 1}–${(_maintenanceQueue.page - 1) * _maintenanceQueue.pageSize + _maintenanceQueue.items.length} of ${_maintenanceQueue.total} matching requests.',
                            style: const TextStyle(
                              color: EstateColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_maintenanceQueueLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_canManageEstateOperations &&
                      _maintenanceQueue.items.isEmpty)
                    const _Notice(
                      message: 'No maintenance requests are recorded for this estate yet.',
                    )
                  else if (_canManageEstateOperations &&
                      _filteredMaintenanceRequests.isEmpty)
                    const _Notice(
                      message: 'No maintenance requests match these filters.',
                    )
                  else if (_canManageEstateOperations)
                    ..._filteredMaintenanceRequests.map(
                      (request) => _MaintenanceRequestCard(
                        request: request,
                        onReview: _busy
                            ? null
                            : () => _reviewMaintenanceRequest(request),
                      ),
                    ),
                  if (_canManageEstateOperations &&
                      _maintenanceQueue.totalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed:
                              _maintenanceQueueLoading ||
                                  _maintenanceQueue.page <= 1
                              ? null
                              : () => _selectMaintenancePage(
                                  _maintenanceQueue.page - 1,
                                ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          'Page ${_maintenanceQueue.page} of ${_maintenanceQueue.totalPages}',
                          style: const TextStyle(
                            color: EstateColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed:
                              _maintenanceQueueLoading ||
                                  _maintenanceQueue.page >=
                                      _maintenanceQueue.totalPages
                              ? null
                              : () => _selectMaintenancePage(
                                  _maintenanceQueue.page + 1,
                                ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: EstateColors.forest,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Live data coverage',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Counts are scoped to ${_estate?.name ?? 'this estate'} and calculated as of ${_formatDate(summary.asOf)}. Invoice balances use verified settlement records; they are not a collections total. Gate staff can review visitor activity in Gate security. Maintenance history and review are live.',
                                  style: const TextStyle(
                                    color: EstateColors.muted,
                                    height: 1.5,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _dashboardGroup({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) => Card(
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: Icon(icon, color: EstateColors.forest),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(description),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: children,
    ),
  );

  Widget _dashboardActionTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: EstateColors.forest),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(description),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
    onTap: onTap,
  );

  Widget _signInView() {
    return Scaffold(
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
                              Icons.domain_outlined,
                              size: 36,
                              color: EstateColors.forest,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Estate team sign in',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                color: EstateColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'For authorized estate administrators and managers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EstateColors.muted),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter your password.'
                                  : null,
                              onFieldSubmitted: (_) => _signIn(),
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
                              onPressed: _busy ? null : _signIn,
                              child: Text(_busy ? 'Signing in…' : 'Sign in'),
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
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'today';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});
  final EstateManagerDashboardSummary summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760
          ? 4
          : constraints.maxWidth >= 500
          ? 2
          : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final metrics = [
        _MetricCard(
          label: 'Properties',
          value: summary.propertyTotal,
          detail: '${summary.vacantProperties} unoccupied',
          icon: Icons.home_work_outlined,
          color: EstateColors.forest,
        ),
        _MetricCard(
          label: 'Occupied homes',
          value: summary.occupiedProperties,
          detail: 'Current occupancy',
          icon: Icons.people_alt_outlined,
          color: const Color(0xFF486D91),
        ),
        _MetricCard(
          label: 'Residents',
          value: summary.residentMemberships,
          detail: 'Active memberships',
          icon: Icons.groups_outlined,
          color: const Color(0xFF9A7538),
        ),
        _MetricCard(
          label: 'Active tenancies',
          value: summary.activeTenancies,
          detail: '${summary.pendingTenancies} awaiting approval',
          icon: Icons.key_outlined,
          color: const Color(0xFF725793),
        ),
      ];
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: metrics
            .map((metric) => SizedBox(width: width, child: metric))
            .toList(),
      );
    },
  );
}

class _TreasuryFigure extends StatelessWidget {
  const _TreasuryFigure({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: EstateColors.muted, fontSize: 11)),
    ],
  );
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.summary,
    required this.onOpenCharges,
    required this.onOpenExpenses,
  });
  final EstateManagerDashboardSummary summary;
  final VoidCallback? onOpenCharges;
  final VoidCallback? onOpenExpenses;

  @override
  Widget build(BuildContext context) {
    final totals = summary.outstandingIssuedInvoices;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: EstateColors.forest),
                const SizedBox(width: 9),
                Text('Estate wallet & finance',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'No payment provider wallet is connected. Amounts below are derived from verified estate records, not money held by the platform.',
              style: TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (totals.isEmpty)
              const Text('No issued invoice balances or verified receipts recorded yet.',
                  style: TextStyle(color: EstateColors.muted))
            else
              ...totals.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE4EFE8),
                    child: Text(item.currency,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(
                    '${item.currency} ${item.total}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.count} ${item.count == 1 ? 'invoice' : 'invoices'} with outstanding balance',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenCharges,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Charge rules'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenExpenses,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Expenses & budgets'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssuedInvoicesCard extends StatelessWidget {
  const _IssuedInvoicesCard({required this.summary});
  final EstateManagerDashboardSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issued invoices awaiting payment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Outstanding balances on issued invoices, including partial payments. This is not money collected.',
            style: TextStyle(color: EstateColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (summary.outstandingIssuedInvoices.isEmpty)
            const Text(
              'No outstanding invoice balances.',
              style: TextStyle(color: EstateColors.muted),
            )
          else
            ...summary.outstandingIssuedInvoices.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  color: EstateColors.forest,
                ),
                title: Text(
                  '${item.currency} ${_formatAmount(item.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${item.count} ${item.count == 1 ? 'invoice' : 'invoices'} · issued, no verified payment recorded',
                ),
                dense: true,
              ),
            ),
        ],
      ),
    ),
  );

  static String _formatAmount(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final String detail;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const Spacer(),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: EstateColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(fontSize: 11, color: EstateColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.detail,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final int count;
  final String detail;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail,
                    style: const TextStyle(
                      color: EstateColors.muted,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: EstateColors.muted,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Card(
    color: error ? const Color(0xFFFFF0EE) : null,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Text(
        message,
        style: TextStyle(color: error ? EstateColors.red : EstateColors.muted),
      ),
    ),
  );
}

class _MaintenanceRequestCard extends StatelessWidget {
  const _MaintenanceRequestCard({
    required this.request,
    required this.onReview,
  });
  final EstateMaintenanceQueueItem request;
  final VoidCallback? onReview;

  String _label(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final submitted = DateTime.tryParse(request.submittedAt)?.toLocal();
    final dateLabel = submitted == null
        ? ''
        : '${submitted.day}/${submitted.month}/${submitted.year}';
    final update = request.residentVisibleUpdates.isEmpty
        ? null
        : request.residentVisibleUpdates.last.body;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  request.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: EstateColors.ink,
                  ),
                ),
                _StatusPill(label: _label(request.status)),
                _StatusPill(label: _label(request.priority)),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${request.propertyLabel} · ${_label(request.category)} · $dateLabel',
              style: const TextStyle(fontSize: 12, color: EstateColors.muted),
            ),
            const SizedBox(height: 5),
            Text(
              'Reported by ${request.requesterDisplayName}${request.assigneeDisplayName == null ? '' : ' · Assigned to ${request.assigneeDisplayName}'}',
              style: const TextStyle(fontSize: 12, color: EstateColors.muted),
            ),
            const SizedBox(height: 10),
            Text(
              request.description,
              style: const TextStyle(color: EstateColors.ink, height: 1.45),
            ),
            if (update != null) ...[
              const SizedBox(height: 9),
              Text(
                'Resident update: $update',
                style: const TextStyle(
                  color: EstateColors.forest,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Review request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9F2ED),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: EstateColors.forest,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MaintenanceReviewResult {
  const _MaintenanceReviewResult({
    this.command,
    this.assigneeUserId,
    this.reason,
    this.resolutionSummary,
    this.residentUpdate,
    this.internalNote,
  });
  final String? command;
  final String? assigneeUserId;
  final String? reason;
  final String? resolutionSummary;
  final String? residentUpdate;
  final String? internalNote;
}

class _MaintenanceReviewDialog extends StatefulWidget {
  const _MaintenanceReviewDialog({
    required this.request,
    required this.assignableStaff,
  });
  final EstateMaintenanceQueueItem request;
  final List<EstateStaffChoice> assignableStaff;
  @override
  State<_MaintenanceReviewDialog> createState() =>
      _MaintenanceReviewDialogState();
}

class _MaintenanceReviewDialogState extends State<_MaintenanceReviewDialog> {
  final _reason = TextEditingController();
  final _resolution = TextEditingController();
  final _residentUpdate = TextEditingController();
  final _internalNote = TextEditingController();
  String? _command;
  String? _assigneeUserId;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _command = widget.request.allowedCommands.firstOrNull;
    _assigneeUserId =
        widget.assignableStaff.any(
          (staff) => staff.userId == widget.request.assigneeUserId,
        )
        ? widget.request.assigneeUserId
        : null;
  }

  @override
  void dispose() {
    _reason.dispose();
    _resolution.dispose();
    _residentUpdate.dispose();
    _internalNote.dispose();
    super.dispose();
  }

  String _label(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  void _save() {
    if (_command == 'assign' && _assigneeUserId == null) {
      setState(
        () => _validationMessage =
            'Select an active estate manager to assign this request.',
      );
      return;
    }
    if (['reject', 'close', 'reopen'].contains(_command) &&
        _reason.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Enter a reason for this decision.');
      return;
    }
    if (_command == 'resolve' && _resolution.text.trim().isEmpty) {
      setState(
        () => _validationMessage = 'Add a resolution summary for the resident.',
      );
      return;
    }
    if (_command == null &&
        _residentUpdate.text.trim().isEmpty &&
        _internalNote.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Choose an action or add an update.');
      return;
    }
    Navigator.of(context).pop(
      _MaintenanceReviewResult(
        command: _command,
        assigneeUserId: _command == 'assign' ? _assigneeUserId : null,
        reason: _reason.text.trim(),
        resolutionSummary: _resolution.text.trim(),
        residentUpdate: _residentUpdate.text.trim(),
        internalNote: _internalNote.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Review ${widget.request.reference}'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.request.propertyLabel} · ${widget.request.requesterDisplayName}',
              style: const TextStyle(color: EstateColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: _command,
              decoration: const InputDecoration(labelText: 'Action'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Add an update only'),
                ),
                ...widget.request.allowedCommands.map(
                  (command) => DropdownMenuItem<String?>(
                    value: command,
                    child: Text(_label(command)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _command = value;
                _validationMessage = null;
              }),
            ),
            if (_command == 'assign') ...[
              const SizedBox(height: 12),
              if (widget.assignableStaff.isEmpty)
                const _Notice(
                  message:
                      'No active estate managers are available for assignment.',
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _assigneeUserId,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: widget.assignableStaff
                      .map(
                        (staff) => DropdownMenuItem(
                          value: staff.userId,
                          child: Text(staff.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _assigneeUserId = value;
                    _validationMessage = null;
                  }),
                ),
            ],
            if (['reject', 'close', 'reopen'].contains(_command)) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
            if (_command == 'resolve') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _resolution,
                maxLength: 700,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Resolution summary for resident',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _residentUpdate,
              maxLength: 700,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Resident-visible update (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _internalNote,
              maxLength: 700,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Internal team note (optional)',
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                style: const TextStyle(color: EstateColors.red),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save review')),
    ],
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: DashboardTokens.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: DashboardTokens.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}



