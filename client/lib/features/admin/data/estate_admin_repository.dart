enum AdminSection {
  overview,
  properties,
  structure,
  residents,
  landlords,
  tenancies,
  billing,
  rent,
  charges,
  visitors,
  security,
  maintenance,
  facilities,
  communications,
  finance,
  reports,
  team,
  settings,
}

enum DashboardDataStatus {
  available,
  incomplete,
  pendingReconciliation,
  unavailable,
}

enum DashboardFreshness { current, stale, delayed, unavailable }

sealed class DashboardMetrics {
  const DashboardMetrics();
}

class PropertyMetrics extends DashboardMetrics {
  const PropertyMetrics({
    required this.total,
    required this.occupied,
    required this.vacant,
  });
  final int total;
  final int occupied;
  final int vacant;
}

class ResidentMetrics extends DashboardMetrics {
  const ResidentMetrics({required this.registered, required this.landlords});
  final int registered;
  final int landlords;
}

class TenancyMetrics extends DashboardMetrics {
  const TenancyMetrics({required this.tenants, required this.activeTenancies});
  final int tenants;
  final int activeTenancies;
}

class VisitorMetrics extends DashboardMetrics {
  const VisitorMetrics({required this.activity, required this.checkedIn});
  final int activity;
  final int checkedIn;
}

class MaintenanceMetrics extends DashboardMetrics {
  const MaintenanceMetrics({required this.openRequests});
  final int openRequests;
}

class FinanceMetrics extends DashboardMetrics {
  const FinanceMetrics({
    required this.currency,
    required this.rentCollected,
    required this.estateFeesCollected,
    required this.otherChargesCollected,
    required this.expensesPaid,
    required this.netOperatingPosition,
  });
  final String currency;
  final String rentCollected;
  final String estateFeesCollected;
  final String otherChargesCollected;
  final String expensesPaid;
  final String netOperatingPosition;
}

class DashboardSectionResult {
  const DashboardSectionResult({required this.status, this.metrics});
  final DashboardDataStatus status;
  final DashboardMetrics? metrics;
}

class DashboardSourceInfo {
  const DashboardSourceInfo({required this.freshness, this.asOf});
  final DashboardFreshness freshness;
  final DateTime? asOf;
}

class EstateAdminDashboardSnapshot {
  const EstateAdminDashboardSnapshot({
    required this.estateName,
    required this.location,
    required this.periodLabel,
    required this.asOf,
    required this.availableSections,
    required this.sections,
    required this.sourceFreshness,
  });
  final String estateName;
  final String location;
  final String periodLabel;
  final DateTime asOf;
  final Set<AdminSection> availableSections;
  final Map<AdminSection, DashboardSectionResult> sections;
  final Map<AdminSection, DashboardSourceInfo> sourceFreshness;
}

class MaintenanceQueueEntry {
  const MaintenanceQueueEntry({
    required this.reference,
    required this.category,
    required this.priority,
    required this.status,
    required this.propertyLabel,
    required this.requesterName,
    required this.description,
    required this.submittedAt,
  });
  final String reference;
  final String category;
  final String priority;
  final String status;
  final String propertyLabel;
  final String requesterName;
  final String description;
  final String submittedAt;
}

class FinanceBudgetLine {
  const FinanceBudgetLine({
    required this.id,
    required this.name,
    required this.periodLabel,
    required this.allocatedLabel,
    required this.committedLabel,
    required this.paidLabel,
    required this.availableLabel,
    required this.currency,
    required this.committedRatio,
  });

  final String id;
  final String name;
  final String periodLabel;
  final String allocatedLabel;
  final String committedLabel;
  final String paidLabel;
  final String availableLabel;
  final String currency;
  final double committedRatio;
}

class EstateExpenseRequest {
  const EstateExpenseRequest({
    required this.id,
    required this.reference,
    required this.description,
    required this.category,
    required this.requesterName,
    required this.payeeName,
    required this.amountLabel,
    required this.status,
    required this.submittedAt,
    this.verifiedPaidLabel,
    this.decisionNote,
    this.allowedCommands = const [],
  });

  final String id;
  final String reference;
  final String description;
  final String category;
  final String requesterName;
  final String payeeName;
  final String amountLabel;
  final String status;
  final String submittedAt;
  final String? verifiedPaidLabel;
  final String? decisionNote;
  final List<String> allowedCommands;
}

class ExpenseApprovalHistoryEntry {
  const ExpenseApprovalHistoryEntry({
    required this.stageLabel,
    required this.decision,
    required this.actorName,
    required this.decidedAt,
    this.reason,
  });

  final String stageLabel;
  final String decision;
  final String actorName;
  final String decidedAt;
  final String? reason;
}

class EstateExpenseDetail {
  const EstateExpenseDetail({
    required this.approvalStageIndex,
    required this.approvalStageCount,
    required this.approvalHistory,
    this.currentStageLabel,
    this.approvalPolicyVersion,
    this.requesterNote,
  });

  final int approvalStageIndex;
  final int approvalStageCount;
  final List<ExpenseApprovalHistoryEntry> approvalHistory;
  final String? currentStageLabel;
  final String? approvalPolicyVersion;
  final String? requesterNote;
}

class FinanceActivityEntry {
  const FinanceActivityEntry({
    required this.id,
    required this.sourceId,
    required this.type,
    required this.reference,
    required this.description,
    required this.actorName,
    required this.amountLabel,
    required this.occurredAt,
    this.verifiedAt,
  });

  final String id;
  final String sourceId;
  final String type;
  final String reference;
  final String description;
  final String actorName;
  final String amountLabel;
  final DateTime occurredAt;
  final DateTime? verifiedAt;
}

class EstateFacilityBooking {
  const EstateFacilityBooking({
    required this.id,
    required this.reference,
    required this.facilityName,
    required this.propertyLabel,
    required this.requesterName,
    required this.startsAtLabel,
    required this.endsAtLabel,
    required this.attendeeCount,
    required this.status,
    required this.requestedAt,
    required this.paymentStatus,
    this.feeLabel,
    this.purpose,
    this.policyVersion,
    this.decisionNote,
  });

  final String id;
  final String reference;
  final String facilityName;
  final String propertyLabel;
  final String requesterName;
  final String startsAtLabel;
  final String endsAtLabel;
  final int attendeeCount;
  final String status;
  final String requestedAt;
  final String paymentStatus;
  final String? feeLabel;
  final String? purpose;
  final String? policyVersion;
  final String? decisionNote;

  EstateFacilityBooking copyWith({String? status, String? decisionNote}) =>
      EstateFacilityBooking(
        id: id,
        reference: reference,
        facilityName: facilityName,
        propertyLabel: propertyLabel,
        requesterName: requesterName,
        startsAtLabel: startsAtLabel,
        endsAtLabel: endsAtLabel,
        attendeeCount: attendeeCount,
        status: status ?? this.status,
        requestedAt: requestedAt,
        paymentStatus: paymentStatus,
        feeLabel: feeLabel,
        purpose: purpose,
        policyVersion: policyVersion,
        decisionNote: decisionNote ?? this.decisionNote,
      );
}

class EstateSecurityIncident {
  const EstateSecurityIncident({
    required this.id,
    required this.category,
    required this.priority,
    required this.status,
    required this.observedAt,
    required this.reportedAt,
    required this.reporterName,
    this.locationLabel,
    this.gateLabel,
  });

  final String id;
  final String category;
  final String priority;
  final String status;
  final String observedAt;
  final String reportedAt;
  final String reporterName;
  final String? locationLabel;
  final String? gateLabel;
}

class EstateSecurityIncidentPreviewEvent {
  const EstateSecurityIncidentPreviewEvent({
    required this.action,
    required this.occurredAt,
    this.reason,
  });
  final String action;
  final DateTime occurredAt;
  final String? reason;
}

class EstateSecurityIncidentPreviewDetails {
  const EstateSecurityIncidentPreviewDetails({
    required this.description,
    required this.history,
  });
  final String description;
  final List<EstateSecurityIncidentPreviewEvent> history;
}

class EstateTeamMember {
  const EstateTeamMember({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.status,
    this.email,
    this.roleLabel,
    this.accessScopeLabel,
    this.invitedAt,
    this.expiresAt,
    this.lastActiveAt,
  });

  final String id;
  final String kind;
  final String displayName;
  final String status;
  final String? email;
  final String? roleLabel;
  final String? accessScopeLabel;
  final String? invitedAt;
  final String? expiresAt;
  final String? lastActiveAt;
}

/// Actor-authorized tenancy list projection; excludes private lease documents.
class EstateTenancySummary {
  const EstateTenancySummary({
    required this.id,
    required this.propertyLabel,
    required this.tenantLabel,
    required this.rentAmount,
    required this.currency,
    required this.rentFrequency,
    required this.startDate,
    required this.status,
    this.landlordLabel,
    this.endDate,
    this.nextDueDate,
  });

  final String id;
  final String propertyLabel;
  final String tenantLabel;
  final String? landlordLabel;
  final String rentAmount;
  final String currency;
  final String rentFrequency;
  final String startDate;
  final String? endDate;
  final String? nextDueDate;
  final String status;
}

class EstateTenancyPartyOption {
  const EstateTenancyPartyOption({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

class EstateTenancyCreationOptions {
  const EstateTenancyCreationOptions({
    required this.properties,
    required this.tenants,
    required this.payees,
  });
  final List<EstatePropertyRecord> properties;
  final List<EstateTenancyPartyOption> tenants;
  final List<EstateTenancyPartyOption> payees;
}

/// Estate scoped, verified ownership portfolio item from the landlord read model.
class LandlordPortfolioItem {
  const LandlordPortfolioItem({
    required this.propertyId,
    required this.estateName,
    required this.propertyLabel,
    required this.operationalStatus,
    required this.occupancyStatus,
    this.estateLocation,
    this.propertyAddress,
    this.propertyType,
    this.tenantDisplayName,
    this.tenancyStatus,
    this.tenancyStartDate,
    this.tenancyEndDate,
    this.rentAmount,
    this.currency,
    this.rentFrequency,
  });

  final String propertyId;
  final String estateName;
  final String? estateLocation;
  final String propertyLabel;
  final String? propertyAddress;
  final String? propertyType;
  final String operationalStatus;
  final String occupancyStatus;
  final String? tenantDisplayName;
  final String? tenancyStatus;
  final String? tenancyStartDate;
  final String? tenancyEndDate;
  final String? rentAmount;
  final String? currency;
  final String? rentFrequency;
}

/// Safe invoice list summary with balance derived from verified allocations.
class EstateInvoiceSummary {
  const EstateInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.category,
    required this.status,
    required this.dueAt,
    required this.total,
    required this.currency,
    required this.overdue,
    required this.disputed,
    this.allocated,
    this.balance,
    this.payerDisplayName,
    this.propertyCode,
    this.tenancyLabel,
  });

  final String id;
  final String invoiceNumber;
  final String category;
  final String status;
  final String dueAt;
  final String total;
  final String? allocated;
  final String? balance;
  final String currency;
  final bool overdue;
  final bool disputed;
  final String? payerDisplayName;
  final String? propertyCode;
  final String? tenancyLabel;
}

class EstateAnnouncementSummary {
  const EstateAnnouncementSummary({
    required this.id,
    required this.title,
    required this.bodyPreview,
    required this.priority,
    required this.status,
    required this.audienceLabel,
    required this.channels,
    required this.createdAt,
    this.scheduledAt,
    this.publishedAt,
    this.failureCode,
  });

  final String id;
  final String title;
  final String bodyPreview;
  final String priority;
  final String status;
  final String audienceLabel;
  final List<String> channels;
  final String createdAt;
  final String? scheduledAt;
  final String? publishedAt;
  final String? failureCode;
}

class EstateChargeDefinition {
  const EstateChargeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.recurrence,
    required this.scopeLabel,
    required this.dueRule,
    required this.status,
    required this.effectiveFrom,
    this.effectiveTo,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String amount;
  final String currency;
  final String recurrence;
  final String scopeLabel;
  final String dueRule;
  final String status;
  final String effectiveFrom;
  final String? effectiveTo;
}

class EstateSettingsSummary {
  const EstateSettingsSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.code,
    required this.address,
    required this.state,
    required this.lga,
    required this.timezone,
    required this.currency,
  });

  final String id;
  final String name;
  final String type;
  final String status;
  final String? code;
  final String? address;
  final String? state;
  final String? lga;
  final String? timezone;
  final String? currency;
}

class VisitorPassSummary {
  const VisitorPassSummary({
    required this.id,
    required this.visitorName,
    required this.propertyLabel,
    required this.hostName,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    required this.uses,
    required this.useLimit,
    this.vehicleSummary,
  });

  final String id;
  final String visitorName;
  final String propertyLabel;
  final String hostName;
  final String validFrom;
  final String validUntil;
  final String status;
  final int uses;
  final int useLimit;
  final String? vehicleSummary;
}

class GateVisitorSummary {
  const GateVisitorSummary({
    required this.visitId,
    required this.visitorName,
    required this.propertyLabel,
    required this.hostName,
    required this.gateName,
    required this.checkedInAt,
    required this.admissionType,
    this.vehicleSummary,
  });

  final String visitId;
  final String visitorName;
  final String propertyLabel;
  final String hostName;
  final String gateName;
  final String checkedInAt;
  final String admissionType;
  final String? vehicleSummary;
}

class EstatePropertyRecord {
  const EstatePropertyRecord({
    required this.id,
    required this.code,
    required this.propertyType,
    required this.status,
    required this.unitNumber,
    required this.occupancyStatus,
    required this.structureLabel,
    this.address,
    this.description,
    this.occupancyLabel,
    this.ownershipLabel,
    this.tenancyLabel,
    this.ownershipReview,
    this.locationConfidence = 'unmapped',
    this.latitude,
    this.longitude,
    this.locationSource,
    this.accuracyMeters,
  });

  final String id;
  final String code;
  final String propertyType;
  final String status;
  final String? unitNumber;
  final String? occupancyStatus;
  final String? structureLabel;
  final String? address;
  final String? description;
  final String? occupancyLabel;
  final String? ownershipLabel;
  final String? tenancyLabel;
  final OwnershipReviewSummary? ownershipReview;
  final String locationConfidence;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final double? accuracyMeters;
}

class OwnershipReviewSummary {
  const OwnershipReviewSummary({
    required this.ownershipId,
    required this.ownerDisplayName,
    required this.verificationStatus,
    required this.ownershipStatus,
    required this.ownershipShare,
    required this.effectiveFrom,
    this.evidenceCategory,
  });

  final String ownershipId;
  final String ownerDisplayName;
  final String verificationStatus;
  final String ownershipStatus;
  final String ownershipShare;
  final String effectiveFrom;
  final String? evidenceCategory;
}

class EstateStructureNode {
  const EstateStructureNode({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    required this.linkedPropertyCount,
    this.code,
    this.parentId,
  });

  final String id;
  final String type;
  final String name;
  final String status;
  final int? linkedPropertyCount;
  final String? code;
  final String? parentId;
}

class ResidentJoinRequestSummary {
  const ResidentJoinRequestSummary({
    required this.id,
    required this.applicantName,
    required this.relationship,
    required this.submittedAt,
    required this.status,
    this.applicantEmail,
    this.propertyLabel,
  });

  final String id;
  final String applicantName;
  final String relationship;
  final String submittedAt;
  final String status;
  final String? applicantEmail;
  final String? propertyLabel;
}

class ResidentJoinRequestDetail {
  const ResidentJoinRequestDetail({
    required this.summary,
    required this.applicantNote,
    required this.documentCount,
    required this.pendingDocumentCount,
    required this.documentCategories,
    this.decisionReason,
    this.decidedAt,
  });

  final ResidentJoinRequestSummary summary;
  final String? applicantNote;
  final int documentCount;
  final int pendingDocumentCount;
  final List<String> documentCategories;
  final String? decisionReason;
  final String? decidedAt;
}

abstract interface class EstateAdminRepository {
  Future<EstateAdminDashboardSnapshot> loadDashboardSummary();
  Future<List<MaintenanceQueueEntry>> loadMaintenanceQueue();
  Future<List<EstatePropertyRecord>> loadProperties();
  Future<EstatePropertyRecord> createPropertyPreview({
    required String code,
    required String propertyType,
    required String status,
    required String? parentNodeId,
    String? unitNumber,
    String? address,
    String? description,
  });
  Future<EstatePropertyRecord> updatePropertyPreview({
    required String propertyId,
    required String code,
    required String propertyType,
    required String status,
    String? unitNumber,
    String? address,
    String? description,
  });
  Future<EstatePropertyRecord> archivePropertyPreview(String propertyId);
  Future<EstatePropertyRecord> previewUpdatePropertyMapLocation({
    required String propertyId,
    required double? latitude,
    required double? longitude,
    required String confidence,
    required String source,
    double? accuracyMeters,
    required String reason,
  });
  Future<List<EstateStructureNode>> loadEstateStructure();
  Future<EstateStructureNode> createStructureNodePreview({
    required String type,
    required String name,
    String? code,
    String? parentId,
  });
  Future<EstateStructureNode> updateStructureNodePreview({
    required String nodeId,
    required String name,
    String? code,
  });
  Future<EstateStructureNode> archiveStructureNodePreview(String nodeId);
  Future<List<ResidentJoinRequestSummary>> loadResidentJoinRequests();
  Future<ResidentJoinRequestDetail> readResidentJoinRequest(String requestId);
  Future<ResidentJoinRequestSummary> decideResidentJoinRequest({
    required String requestId,
    required String decision,
    required String reason,
  });
  Future<List<VisitorPassSummary>> loadVisitorPasses();
  Future<List<GateVisitorSummary>> loadCurrentGateVisitors();
  Future<List<FinanceBudgetLine>> loadFinanceBudgets();
  Future<List<EstateExpenseRequest>> loadExpenseRequests();
  Future<List<FinanceActivityEntry>> loadFinanceActivity();
  Future<EstateExpenseRequest> decideExpenseRequest({
    required String expenseId,
    required String decision,
    required String reason,
  });
  Future<EstateExpenseDetail> readExpenseRequestDetail(String expenseId);
  Future<List<EstateFacilityBooking>> loadFacilityBookings();
  Future<List<EstateSecurityIncident>> loadSecurityIncidents();
  Future<EstateSecurityIncident> createSecurityIncidentPreview({
    required String category,
    required String priority,
    required String description,
    required String location,
    required DateTime observedAt,
  });
  Future<EstateSecurityIncidentPreviewDetails>
  readSecurityIncidentPreviewDetails(String incidentId);
  Future<EstateSecurityIncident> transitionSecurityIncidentPreview({
    required String incidentId,
    required String command,
    required String reason,
  });
  Future<List<EstateTeamMember>> loadEstateTeam();
  Future<EstateTeamMember> createEstateStaffInvitationPreview({
    required String email,
    required String roleLabel,
  });
  Future<List<EstateTenancySummary>> loadEstateTenancies();
  Future<EstateTenancyCreationOptions> loadTenancyCreationOptions();
  Future<EstateTenancySummary> createTenancyDraftPreview({
    required String propertyId,
    required String tenantId,
    required String payeeId,
    required String rentAmount,
    required String rentFrequency,
    required DateTime startDate,
    DateTime? endDate,
  });
  Future<List<EstateTenancySummary>> previewRentInvoiceSchedules({
    required int year,
    required int month,
  });
  Future<List<LandlordPortfolioItem>> loadLandlordPortfolio();
  Future<List<EstateInvoiceSummary>> loadEstateInvoices();
  Future<List<EstateAnnouncementSummary>> loadEstateAnnouncements();
  Future<EstateAnnouncementSummary> createAnnouncementDraft({
    required String title,
    required String body,
    required String priority,
    required String audienceLabel,
    required List<String> channels,
  });
  Future<EstateAnnouncementSummary> scheduleAnnouncement({
    required String announcementId,
    required String scheduledAt,
    required String timeZone,
  });
  Future<EstateAnnouncementSummary> requestAnnouncementDispatch({
    required String announcementId,
    required bool confirmEmergency,
  });
  Future<EstateAnnouncementSummary> retryAnnouncementDispatch({
    required String announcementId,
  });
  Future<List<EstateChargeDefinition>> loadChargeDefinitions();
  Future<EstateSettingsSummary> loadEstateSettings();
  Future<List<EstatePropertyRecord>> loadOwnershipReviews();
}

/// Illustrative adapter only. A connected adapter must pass through the host
/// session and must never treat client-side visibility as authorization.
class PreviewEstateAdminRepository implements EstateAdminRepository {
  final List<EstateAnnouncementSummary> _previewAnnouncements = [
    ..._estateAnnouncements,
  ];
  final List<EstateExpenseRequest> _previewExpenses = [..._expenseRecords];

  static final _snapshot = EstateAdminDashboardSnapshot(
    estateName: 'Oakwood Estate',
    location: 'Lekki, Lagos',
    periodLabel: 'This month · 1–30 November 2026',
    asOf: DateTime.utc(2026, 11, 6, 9, 30),
    availableSections: Set.unmodifiable(AdminSection.values.toSet()),
    sections: {
      AdminSection.properties: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: PropertyMetrics(total: 248, occupied: 221, vacant: 27),
      ),
      AdminSection.residents: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: ResidentMetrics(registered: 386, landlords: 142),
      ),
      AdminSection.tenancies: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: TenancyMetrics(tenants: 164, activeTenancies: 151),
      ),
      AdminSection.visitors: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: VisitorMetrics(activity: 42, checkedIn: 3),
      ),
      AdminSection.maintenance: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: MaintenanceMetrics(openRequests: 12),
      ),
      AdminSection.finance: const DashboardSectionResult(
        status: DashboardDataStatus.available,
        metrics: FinanceMetrics(
          currency: 'NGN',
          rentCollected: '₦18,420,000',
          estateFeesCollected: '₦3,840,000',
          otherChargesCollected: '₦1,250,000',
          expensesPaid: '₦6,210,000',
          netOperatingPosition: '₦17,300,000',
        ),
      ),
    },
    sourceFreshness: {
      for (final section in [
        AdminSection.properties,
        AdminSection.residents,
        AdminSection.tenancies,
        AdminSection.visitors,
        AdminSection.maintenance,
        AdminSection.finance,
      ])
        section: DashboardSourceInfo(
          freshness: DashboardFreshness.current,
          asOf: DateTime.utc(2026, 11, 6, 9, 30),
        ),
    },
  );

  static const _queue = <MaintenanceQueueEntry>[
    MaintenanceQueueEntry(
      reference: 'REQ-00318',
      category: 'plumbing',
      priority: 'high',
      status: 'in_progress',
      propertyLabel: 'Block C · 12',
      requesterName: 'Amara Okafor',
      description: 'Low water pressure in the bathroom tap.',
      submittedAt: '5 Nov · 8:20 am',
    ),
    MaintenanceQueueEntry(
      reference: 'REQ-00317',
      category: 'electrical',
      priority: 'urgent',
      status: 'under_review',
      propertyLabel: 'Block A · 04',
      requesterName: 'Tunde Balogun',
      description: 'Burning smell from the corridor light fitting.',
      submittedAt: '5 Nov · 7:55 am',
    ),
    MaintenanceQueueEntry(
      reference: 'REQ-00315',
      category: 'cleaning',
      priority: 'normal',
      status: 'submitted',
      propertyLabel: 'Block D · 21',
      requesterName: 'Ngozi Eze',
      description: 'Please check the drainage near the front entrance.',
      submittedAt: '4 Nov · 4:10 pm',
    ),
  ];

  static final _properties = <EstatePropertyRecord>[
    EstatePropertyRecord(
      id: 'property-001',
      code: 'OAK-C-012',
      propertyType: 'Apartment',
      status: 'active',
      unitNumber: '12',
      occupancyStatus: 'occupied',
      structureLabel: 'North Gardens · Block C',
      occupancyLabel: 'Occupied',
      ownershipLabel: 'Verified owner',
      tenancyLabel: 'Active tenancy',
    ),
    EstatePropertyRecord(
      id: 'property-002',
      code: 'OAK-A-004',
      propertyType: 'Apartment',
      status: 'active',
      unitNumber: '04',
      occupancyStatus: 'occupied',
      structureLabel: 'North Gardens · Block A',
      occupancyLabel: 'Occupied',
      ownershipLabel: 'Verified owner',
      tenancyLabel: 'Active tenancy',
    ),
    EstatePropertyRecord(
      id: 'property-003',
      code: 'OAK-D-021',
      propertyType: 'Apartment',
      status: 'active',
      unitNumber: '21',
      occupancyStatus: 'vacant',
      structureLabel: 'North Gardens · Block D',
      occupancyLabel: 'Vacant',
      ownershipLabel: 'Verified owner',
      tenancyLabel: null,
    ),
    EstatePropertyRecord(
      id: 'property-004',
      code: 'OAK-SH-006',
      propertyType: 'Shop',
      status: 'reserved',
      unitNumber: '06',
      occupancyStatus: 'vacant',
      structureLabel: 'South Courts · Retail Block',
      occupancyLabel: 'Vacant',
      ownershipLabel: 'Owner review pending',
      tenancyLabel: null,
      ownershipReview: OwnershipReviewSummary(
        ownershipId: 'ownership-review-104',
        ownerDisplayName: 'Kehinde Adebayo',
        verificationStatus: 'pending_review',
        ownershipStatus: 'active',
        ownershipShare: '100%',
        effectiveFrom: '2026-10-28',
        evidenceCategory: 'Purchase document',
      ),
    ),
    EstatePropertyRecord(
      id: 'property-005',
      code: 'OAK-B-008',
      propertyType: 'Townhouse',
      status: 'active',
      unitNumber: '08',
      occupancyStatus: 'occupied',
      structureLabel: 'South Courts · Building B',
      occupancyLabel: 'Occupied',
      ownershipLabel: 'Verified owner',
      tenancyLabel: 'Owner occupied',
    ),
    EstatePropertyRecord(
      id: 'property-006',
      code: 'OAK-C-019',
      propertyType: 'Apartment',
      status: 'under_maintenance',
      unitNumber: '19',
      occupancyStatus: 'occupied',
      structureLabel: 'North Gardens · Block C',
      occupancyLabel: 'Occupied',
      ownershipLabel: 'Verified owner',
      tenancyLabel: 'Active tenancy',
    ),
    EstatePropertyRecord(
      id: 'property-007',
      code: 'OAK-V-002',
      propertyType: 'Villa',
      status: 'under_development',
      unitNumber: '02',
      occupancyStatus: 'vacant',
      structureLabel: 'West Villas',
      occupancyLabel: 'Vacant',
      ownershipLabel: null,
      tenancyLabel: null,
    ),
    EstatePropertyRecord(
      id: 'property-008',
      code: 'OAK-A-017',
      propertyType: 'Apartment',
      status: 'inactive',
      unitNumber: '17',
      occupancyStatus: 'vacant',
      structureLabel: 'North Gardens · Block A',
      occupancyLabel: 'Vacant',
      ownershipLabel: 'Verified owner',
      tenancyLabel: null,
    ),
  ];

  static final _structure = <EstateStructureNode>[
    EstateStructureNode(
      id: 'zone-north',
      type: 'zone',
      name: 'North Gardens',
      code: 'NORTH',
      status: 'active',
      linkedPropertyCount: 126,
    ),
    EstateStructureNode(
      id: 'street-jacaranda',
      type: 'street',
      name: 'Jacaranda Drive',
      code: 'JAC',
      parentId: 'zone-north',
      status: 'active',
      linkedPropertyCount: 82,
    ),
    EstateStructureNode(
      id: 'building-a',
      type: 'building',
      name: 'Block A',
      code: 'A',
      parentId: 'street-jacaranda',
      status: 'active',
      linkedPropertyCount: 40,
    ),
    EstateStructureNode(
      id: 'floor-a1',
      type: 'floor',
      name: 'Floor 1',
      code: 'A-1',
      parentId: 'building-a',
      status: 'active',
      linkedPropertyCount: 10,
    ),
    EstateStructureNode(
      id: 'building-c',
      type: 'building',
      name: 'Block C',
      code: 'C',
      parentId: 'street-jacaranda',
      status: 'active',
      linkedPropertyCount: 42,
    ),
    EstateStructureNode(
      id: 'street-palm',
      type: 'street',
      name: 'Palm Avenue',
      code: 'PALM',
      parentId: 'zone-north',
      status: 'active',
      linkedPropertyCount: 44,
    ),
    EstateStructureNode(
      id: 'zone-south',
      type: 'zone',
      name: 'South Courts',
      code: 'SOUTH',
      status: 'active',
      linkedPropertyCount: 78,
    ),
    EstateStructureNode(
      id: 'building-retail',
      type: 'building',
      name: 'Retail Block',
      code: 'RETAIL',
      parentId: 'zone-south',
      status: 'active',
      linkedPropertyCount: 14,
    ),
    EstateStructureNode(
      id: 'zone-old',
      type: 'zone',
      name: 'Old Phase',
      code: 'OLD',
      status: 'archived',
      linkedPropertyCount: 0,
    ),
  ];

  static final _joinRequests = <ResidentJoinRequestSummary>[
    ResidentJoinRequestSummary(
      id: 'join-101',
      applicantName: 'Mariam Adebayo',
      applicantEmail: 'mariam.adebayo@example.test',
      propertyLabel: 'Block C · Unit 08',
      relationship: 'tenant',
      submittedAt: '6 Nov · 8:42 am',
      status: 'submitted',
    ),
    ResidentJoinRequestSummary(
      id: 'join-100',
      applicantName: 'Emeka Okoro',
      applicantEmail: 'emeka.okoro@example.test',
      propertyLabel: 'Block A · Unit 14',
      relationship: 'owner',
      submittedAt: '5 Nov · 4:15 pm',
      status: 'submitted',
    ),
    ResidentJoinRequestSummary(
      id: 'join-099',
      applicantName: 'Fatima Bello',
      applicantEmail: 'fatima.bello@example.test',
      propertyLabel: 'Block D · Unit 02',
      relationship: 'household_member',
      submittedAt: '5 Nov · 11:30 am',
      status: 'submitted',
    ),
    ResidentJoinRequestSummary(
      id: 'join-098',
      applicantName: 'Chidi Nwosu',
      applicantEmail: 'chidi.nwosu@example.test',
      propertyLabel: 'South Courts · Unit 07',
      relationship: 'authorized_occupant',
      submittedAt: '4 Nov · 2:08 pm',
      status: 'submitted',
    ),
    ResidentJoinRequestSummary(
      id: 'join-097',
      applicantName: 'Bisi Ogunleye',
      applicantEmail: 'bisi.ogunleye@example.test',
      propertyLabel: 'Palm Avenue · House 11',
      relationship: 'tenant',
      submittedAt: '3 Nov · 9:50 am',
      status: 'approved',
    ),
    ResidentJoinRequestSummary(
      id: 'join-096',
      applicantName: 'Ibrahim Yusuf',
      applicantEmail: 'ibrahim.yusuf@example.test',
      propertyLabel: 'Block B · Unit 03',
      relationship: 'owner',
      submittedAt: '2 Nov · 3:22 pm',
      status: 'rejected',
    ),
  ];

  static const _visitorPasses = <VisitorPassSummary>[
    VisitorPassSummary(
      id: 'pass-301',
      visitorName: 'Kelechi Madu',
      propertyLabel: 'Block C · Unit 12',
      hostName: 'Amara Okafor',
      validFrom: 'Today · 10:00 am',
      validUntil: 'Today · 1:00 pm',
      status: 'active',
      uses: 0,
      useLimit: 1,
      vehicleSummary: 'Silver sedan · KJA 482 EF',
    ),
    VisitorPassSummary(
      id: 'pass-300',
      visitorName: 'Adaeze Nnadi',
      propertyLabel: 'Block A · Unit 04',
      hostName: 'Tunde Balogun',
      validFrom: 'Today · 8:30 am',
      validUntil: 'Today · 5:00 pm',
      status: 'checked_in',
      uses: 1,
      useLimit: 1,
    ),
    VisitorPassSummary(
      id: 'pass-299',
      visitorName: 'David Ojo',
      propertyLabel: 'Palm Avenue · House 11',
      hostName: 'Bisi Ogunleye',
      validFrom: 'Today · 9:00 am',
      validUntil: 'Today · 12:00 pm',
      status: 'expired',
      uses: 1,
      useLimit: 1,
    ),
    VisitorPassSummary(
      id: 'pass-298',
      visitorName: 'Zainab Musa',
      propertyLabel: 'Block D · Unit 02',
      hostName: 'Fatima Bello',
      validFrom: 'Yesterday · 2:00 pm',
      validUntil: 'Yesterday · 6:00 pm',
      status: 'revoked',
      uses: 0,
      useLimit: 1,
    ),
  ];

  static const _gateVisitors = <GateVisitorSummary>[
    GateVisitorSummary(
      visitId: 'visit-801',
      visitorName: 'Adaeze Nnadi',
      propertyLabel: 'Block A · Unit 04',
      hostName: 'Tunde Balogun',
      gateName: 'Main Gate',
      checkedInAt: 'Today · 9:42 am',
      admissionType: 'pass',
    ),
    GateVisitorSummary(
      visitId: 'visit-800',
      visitorName: 'Samuel Eze',
      propertyLabel: 'Block C · Unit 19',
      hostName: 'Manual admission',
      gateName: 'Main Gate',
      checkedInAt: 'Today · 9:16 am',
      admissionType: 'manual',
    ),
    GateVisitorSummary(
      visitId: 'visit-799',
      visitorName: 'Kemi Afolabi',
      propertyLabel: 'West Villas · House 02',
      hostName: 'Chika Afolabi',
      gateName: 'East Gate',
      checkedInAt: 'Today · 8:55 am',
      admissionType: 'pass',
      vehicleSummary: 'White SUV · LND 219 GK',
    ),
  ];

  static const _budgets = <FinanceBudgetLine>[
    FinanceBudgetLine(
      id: 'budget-line-maintenance',
      name: 'Repairs and maintenance',
      periodLabel: 'November 2026',
      allocatedLabel: '₦4,500,000',
      committedLabel: '₦1,860,000',
      paidLabel: '₦1,120,000',
      availableLabel: '₦2,640,000',
      currency: 'NGN',
      committedRatio: .41,
    ),
    FinanceBudgetLine(
      id: 'budget-line-security',
      name: 'Security operations',
      periodLabel: 'November 2026',
      allocatedLabel: '₦6,800,000',
      committedLabel: '₦5,200,000',
      paidLabel: '₦4,760,000',
      availableLabel: '₦1,600,000',
      currency: 'NGN',
      committedRatio: .76,
    ),
    FinanceBudgetLine(
      id: 'budget-line-utilities',
      name: 'Utilities',
      periodLabel: 'November 2026',
      allocatedLabel: '₦3,250,000',
      committedLabel: '₦2,740,000',
      paidLabel: '₦2,310,000',
      availableLabel: '₦510,000',
      currency: 'NGN',
      committedRatio: .84,
    ),
    FinanceBudgetLine(
      id: 'budget-line-community',
      name: 'Community and facilities',
      periodLabel: 'November 2026',
      allocatedLabel: '₦1,200,000',
      committedLabel: '₦480,000',
      paidLabel: '₦310,000',
      availableLabel: '₦720,000',
      currency: 'NGN',
      committedRatio: .40,
    ),
  ];

  static const _expenseRecords = <EstateExpenseRequest>[
    EstateExpenseRequest(
      id: 'expense-451',
      reference: 'EXP-00451',
      description: 'Replace damaged water pump control panel',
      category: 'Repairs and maintenance',
      requesterName: 'Chika Afolabi',
      payeeName: 'AquaFlow Services',
      amountLabel: '₦385,000',
      status: 'pending_approval',
      submittedAt: '6 Nov · 9:12 am',
      allowedCommands: ['approve', 'reject'],
    ),
    EstateExpenseRequest(
      id: 'expense-450',
      reference: 'EXP-00450',
      description: 'November gate security coverage',
      category: 'Security operations',
      requesterName: 'Musa Garba',
      payeeName: 'Gatewatch Nigeria Ltd',
      amountLabel: '₦1,200,000',
      status: 'approved',
      submittedAt: '4 Nov · 1:40 pm',
      decisionNote: 'Approved within the current security budget allocation.',
    ),
    EstateExpenseRequest(
      id: 'expense-449',
      reference: 'EXP-00449',
      description: 'Replace common-area lighting in Block B',
      category: 'Utilities',
      requesterName: 'Ada Obi',
      payeeName: 'Brightline Electrical',
      amountLabel: '₦210,000',
      status: 'partially_paid',
      submittedAt: '31 Oct · 11:05 am',
      verifiedPaidLabel: '₦150,000',
      decisionNote:
          'Initial invoice reconciled against a verified payment.',
    ),
    EstateExpenseRequest(
      id: 'expense-448',
      reference: 'EXP-00448',
      description: 'Quarterly pool filtration service',
      category: 'Community and facilities',
      requesterName: 'Ngozi Eze',
      payeeName: 'ClearWater Maintenance',
      amountLabel: '₦95,000',
      status: 'paid',
      submittedAt: '28 Oct · 3:25 pm',
      verifiedPaidLabel: '₦95,000',
      decisionNote: 'Paid amount is from the verified payment allocation.',
    ),
    EstateExpenseRequest(
      id: 'expense-447',
      reference: 'EXP-00447',
      description: 'Additional cleaning supplies',
      category: 'Community and facilities',
      requesterName: 'Tunde Balogun',
      payeeName: 'CleanHome Supplies',
      amountLabel: '₦72,500',
      status: 'rejected',
      submittedAt: '26 Oct · 10:18 am',
      decisionNote: 'Please attach the revised quotation before resubmitting.',
    ),
  ];

  static final _financeActivity = <FinanceActivityEntry>[
    FinanceActivityEntry(
      id: 'activity-001',
      sourceId: 'expense-450',
      type: 'expense_approved',
      reference: 'EXP-00450',
      description: 'November gate security coverage',
      actorName: 'Ifeoma Nwosu',
      amountLabel: '₦1,200,000',
      occurredAt: DateTime(2026, 11, 4, 13, 40),
    ),
    FinanceActivityEntry(
      id: 'activity-002',
      sourceId: 'allocation-772',
      type: 'payment_allocated',
      reference: 'EXP-00449',
      description: 'Verified payment allocated · Block B lighting',
      actorName: 'Payment service',
      amountLabel: '₦150,000',
      occurredAt: DateTime(2026, 10, 31, 12, 5),
      verifiedAt: DateTime(2026, 10, 31, 12, 4),
    ),
    FinanceActivityEntry(
      id: 'activity-003',
      sourceId: 'expense-447',
      type: 'expense_rejected',
      reference: 'EXP-00447',
      description: 'Additional cleaning supplies',
      actorName: 'Ifeoma Nwosu',
      amountLabel: '₦72,500',
      occurredAt: DateTime(2026, 10, 26, 10, 18),
    ),
  ];

  static const _facilityBookings = <EstateFacilityBooking>[
    EstateFacilityBooking(
      id: 'booking-701',
      reference: 'FAC-00701',
      facilityName: 'Community hall',
      propertyLabel: 'Block C · Unit 12',
      requesterName: 'Amara Okafor',
      startsAtLabel: '8 Nov 2026 · 2:00 pm',
      endsAtLabel: '8 Nov 2026 · 5:00 pm',
      attendeeCount: 35,
      status: 'pending_review',
      requestedAt: '6 Nov · 9:20 am',
      paymentStatus: 'not_due',
      feeLabel: '₦25,000',
      purpose: 'Family celebration',
      policyVersion: 'v3',
    ),
    EstateFacilityBooking(
      id: 'booking-700',
      reference: 'FAC-00700',
      facilityName: 'Tennis court',
      propertyLabel: 'Block A · Unit 04',
      requesterName: 'Tunde Balogun',
      startsAtLabel: '7 Nov 2026 · 10:00 am',
      endsAtLabel: '7 Nov 2026 · 11:00 am',
      attendeeCount: 2,
      status: 'pending_payment',
      requestedAt: '5 Nov · 4:14 pm',
      paymentStatus: 'pending',
      feeLabel: '₦5,000',
      purpose: 'Resident booking',
      policyVersion: 'v2',
    ),
    EstateFacilityBooking(
      id: 'booking-699',
      reference: 'FAC-00699',
      facilityName: 'Swimming pool',
      propertyLabel: 'West Villas · House 08',
      requesterName: 'Bisi Ogunleye',
      startsAtLabel: '7 Nov 2026 · 9:00 am',
      endsAtLabel: '7 Nov 2026 · 10:00 am',
      attendeeCount: 4,
      status: 'confirmed',
      requestedAt: '4 Nov · 11:35 am',
      paymentStatus: 'not_required',
      purpose: 'Family swim',
      policyVersion: 'v4',
    ),
    EstateFacilityBooking(
      id: 'booking-698',
      reference: 'FAC-00698',
      facilityName: 'Community hall',
      propertyLabel: 'Block D · Unit 02',
      requesterName: 'Fatima Bello',
      startsAtLabel: '2 Nov 2026 · 12:00 pm',
      endsAtLabel: '2 Nov 2026 · 3:00 pm',
      attendeeCount: 45,
      status: 'completed',
      requestedAt: '26 Oct · 10:10 am',
      paymentStatus: 'verified',
      feeLabel: '₦25,000',
      purpose: 'Residents association meeting',
      policyVersion: 'v3',
    ),
    EstateFacilityBooking(
      id: 'booking-697',
      reference: 'FAC-00697',
      facilityName: 'Tennis court',
      propertyLabel: 'North Gardens · Block A',
      requesterName: 'Emeka Okoro',
      startsAtLabel: '1 Nov 2026 · 8:00 am',
      endsAtLabel: '1 Nov 2026 · 9:00 am',
      attendeeCount: 6,
      status: 'declined',
      requestedAt: '31 Oct · 6:05 pm',
      paymentStatus: 'not_due',
      purpose: 'Group practice',
      policyVersion: 'v2',
      decisionNote: 'The requested group size exceeds the facility capacity.',
    ),
  ];

  static final _securityIncidents = <EstateSecurityIncident>[
    EstateSecurityIncident(
      id: 'INC-00241',
      category: 'Unauthorized access',
      priority: 'Urgent',
      status: 'investigating',
      observedAt: '6 Nov · 8:52 am',
      reportedAt: '6 Nov · 9:04 am',
      reporterName: 'Gate supervisor',
      gateLabel: 'East Gate',
      locationLabel: 'East Gate vehicle lane',
    ),
    EstateSecurityIncident(
      id: 'INC-00240',
      category: 'Property damage',
      priority: 'High',
      status: 'reported',
      observedAt: '5 Nov · 6:40 pm',
      reportedAt: '5 Nov · 7:02 pm',
      reporterName: 'Mariam Adebayo',
      locationLabel: 'North Gardens · Block C',
    ),
    EstateSecurityIncident(
      id: 'INC-00239',
      category: 'Noise disturbance',
      priority: 'Normal',
      status: 'acknowledged',
      observedAt: '5 Nov · 2:20 pm',
      reportedAt: '5 Nov · 2:36 pm',
      reporterName: 'Estate staff',
      locationLabel: 'Community hall',
    ),
    EstateSecurityIncident(
      id: 'INC-00237',
      category: 'Safety concern',
      priority: 'High',
      status: 'contained',
      observedAt: '4 Nov · 10:10 am',
      reportedAt: '4 Nov · 10:16 am',
      reporterName: 'Gate supervisor',
      gateLabel: 'Main Gate',
      locationLabel: 'Main Gate pedestrian entrance',
    ),
    EstateSecurityIncident(
      id: 'INC-00231',
      category: 'Noise disturbance',
      priority: 'Normal',
      status: 'resolved',
      observedAt: '1 Nov · 9:45 pm',
      reportedAt: '1 Nov · 9:55 pm',
      reporterName: 'Tunde Balogun',
      locationLabel: 'South Courts · Block A',
    ),
  ];

  static final _estateTeam = <EstateTeamMember>[
    EstateTeamMember(
      id: 'member-admin-01',
      kind: 'membership',
      displayName: 'Amina Yusuf',
      email: 'amina.yusuf@example.test',
      roleLabel: 'Estate administrator',
      accessScopeLabel: 'Full estate operations',
      status: 'active',
      invitedAt: '12 Jan 2025',
      lastActiveAt: 'Today · 9:14 am',
    ),
    EstateTeamMember(
      id: 'member-finance-02',
      kind: 'membership',
      displayName: 'David Nwosu',
      email: 'david.nwosu@example.test',
      roleLabel: 'Estate accountant',
      accessScopeLabel: 'Finance and reports',
      status: 'active',
      invitedAt: '3 Mar 2025',
      lastActiveAt: 'Today · 8:52 am',
    ),
    EstateTeamMember(
      id: 'member-security-03',
      kind: 'membership',
      displayName: 'Musa Garba',
      email: 'musa.garba@example.test',
      roleLabel: 'Security supervisor',
      accessScopeLabel: 'Gate operations and incidents',
      status: 'active',
      invitedAt: '17 May 2025',
      lastActiveAt: 'Yesterday · 7:36 pm',
    ),
    EstateTeamMember(
      id: 'member-facility-04',
      kind: 'membership',
      displayName: 'Ngozi Eze',
      email: 'ngozi.eze@example.test',
      roleLabel: 'Facility manager',
      accessScopeLabel: 'Facilities and bookings',
      status: 'active',
      invitedAt: '21 Aug 2025',
      lastActiveAt: '4 Nov · 2:18 pm',
    ),
    EstateTeamMember(
      id: 'invitation-901',
      kind: 'invitation',
      displayName: 'Chidi Okafor',
      email: 'chidi.okafor@example.test',
      roleLabel: 'Maintenance officer',
      accessScopeLabel: 'Maintenance requests',
      status: 'invited',
      invitedAt: '5 Nov 2026',
      expiresAt: '12 Nov 2026',
    ),
    EstateTeamMember(
      id: 'member-maint-05',
      kind: 'membership',
      displayName: 'Tunde Balogun',
      email: 'tunde.balogun@example.test',
      roleLabel: 'Maintenance officer',
      accessScopeLabel: 'Maintenance requests',
      status: 'suspended',
      invitedAt: '9 Jun 2025',
      lastActiveAt: '28 Oct · 11:02 am',
    ),
  ];

  static final _joinDetails = <String, ResidentJoinRequestDetail>{
    'join-101': ResidentJoinRequestDetail(
      summary: _joinRequests[0],
      applicantNote: 'I have moved into this unit and would like access to the resident services.',
      documentCount: 2,
      pendingDocumentCount: 1,
      documentCategories: ['tenancy_agreement', 'identity'],
    ),
    'join-100': ResidentJoinRequestDetail(
      summary: _joinRequests[1],
      applicantNote: 'I recently completed the purchase and have the ownership documents available for review.',
      documentCount: 3,
      pendingDocumentCount: 2,
      documentCategories: ['proof_of_ownership', 'identity'],
    ),
    'join-099': ResidentJoinRequestDetail(
      summary: _joinRequests[2],
      applicantNote: 'I live with the primary resident at this address.',
      documentCount: 1,
      pendingDocumentCount: 0,
      documentCategories: ['identity'],
    ),
    'join-098': ResidentJoinRequestDetail(
      summary: _joinRequests[3],
      applicantNote:
          'The property owner has authorized me to reside at this address.',
      documentCount: 2,
      pendingDocumentCount: 0,
      documentCategories: ['owner_authorization', 'identity'],
    ),
    'join-097': ResidentJoinRequestDetail(
      summary: _joinRequests[4],
      applicantNote:
          'Renewed tenancy information submitted for the new lease period.',
      documentCount: 2,
      pendingDocumentCount: 0,
      documentCategories: ['tenancy_agreement', 'identity'],
      decisionReason: 'Tenancy details verified.',
      decidedAt: '4 Nov · 10:05 am',
    ),
    'join-096': ResidentJoinRequestDetail(
      summary: _joinRequests[5],
      applicantNote: 'I am requesting owner access for this property.',
      documentCount: 1,
      pendingDocumentCount: 0,
      documentCategories: ['proof_of_ownership'],
      decisionReason: 'Ownership record could not be verified. Please contact the estate office.',
      decidedAt: '3 Nov · 1:45 pm',
    ),
  };

  @override
  Future<EstateAdminDashboardSnapshot> loadDashboardSummary() async =>
      _snapshot;

  @override
  Future<List<MaintenanceQueueEntry>> loadMaintenanceQueue() async =>
      List.unmodifiable(_queue);

  @override
  Future<List<EstatePropertyRecord>> loadProperties() async =>
      List.unmodifiable(_properties);

  @override
  Future<EstatePropertyRecord> createPropertyPreview({
    required String code,
    required String propertyType,
    required String status,
    required String? parentNodeId,
    String? unitNumber,
    String? address,
    String? description,
  }) async {
    const statuses = {
      'active',
      'under_development',
      'reserved',
      'under_maintenance',
      'inactive',
    };
    final cleanCode = code.trim();
    final cleanType = propertyType.trim();
    final cleanUnit = unitNumber?.trim();
    final cleanAddress = address?.trim();
    final cleanDescription = description?.trim();
    if (cleanCode.isEmpty || cleanCode.length > 80) {
      throw ArgumentError('Enter a property code from 1 to 80 characters.');
    }
    if (cleanType.isEmpty || cleanType.length > 80) {
      throw ArgumentError('Enter a property type from 1 to 80 characters.');
    }
    if (!statuses.contains(status)) {
      throw ArgumentError('Choose a supported property status.');
    }
    if (cleanUnit != null && cleanUnit.length > 80) {
      throw ArgumentError('Unit number must be 80 characters or fewer.');
    }
    if (cleanAddress != null && cleanAddress.length > 240) {
      throw ArgumentError('Address must be 240 characters or fewer.');
    }
    if (cleanDescription != null && cleanDescription.length > 700) {
      throw ArgumentError('Description must be 700 characters or fewer.');
    }
    if (_properties.any(
      (property) => property.code.toLowerCase() == cleanCode.toLowerCase(),
    )) {
      throw ArgumentError('That property code is already in use.');
    }
    EstateStructureNode? parent;
    if (parentNodeId != null) {
      parent = _structure.where((node) => node.id == parentNodeId).firstOrNull;
      if (parent == null || parent.status != 'active') {
        throw ArgumentError('Choose an active structure node in this estate.');
      }
    }
    final created = EstatePropertyRecord(
      id: 'preview-property-${DateTime.now().microsecondsSinceEpoch}',
      code: cleanCode,
      propertyType: cleanType,
      status: status,
      unitNumber: cleanUnit == null || cleanUnit.isEmpty ? null : cleanUnit,
      occupancyStatus: 'vacant',
      structureLabel: parent?.name,
      address: cleanAddress == null || cleanAddress.isEmpty
          ? null
          : cleanAddress,
      description: cleanDescription == null || cleanDescription.isEmpty
          ? null
          : cleanDescription,
      occupancyLabel: 'Vacant',
      ownershipLabel: null,
      tenancyLabel: null,
      locationConfidence: 'unmapped',
    );
    _properties.add(created);
    return created;
  }

  @override
  Future<EstatePropertyRecord> archivePropertyPreview(String propertyId) async {
    final index = _properties.indexWhere(
      (property) => property.id == propertyId,
    );
    if (index < 0) throw ArgumentError('Property was not found.');
    final property = _properties[index];
    if (!property.id.startsWith('preview-property-')) {
      throw ArgumentError(
        'The preview cannot verify relationships for this sample property.',
      );
    }
    if (property.status == 'archived') {
      throw ArgumentError('This property is already archived.');
    }
    if (property.occupancyStatus == 'occupied' ||
        property.ownershipLabel != null ||
        property.tenancyLabel != null) {
      throw ArgumentError(
        'Resolve active ownership, occupancy and tenancy relationships before archiving.',
      );
    }
    final archived = EstatePropertyRecord(
      id: property.id,
      code: property.code,
      propertyType: property.propertyType,
      status: 'archived',
      unitNumber: property.unitNumber,
      occupancyStatus: property.occupancyStatus,
      structureLabel: property.structureLabel,
      address: property.address,
      description: property.description,
      occupancyLabel: property.occupancyLabel,
      ownershipLabel: property.ownershipLabel,
      tenancyLabel: property.tenancyLabel,
      ownershipReview: property.ownershipReview,
      locationConfidence: property.locationConfidence,
      latitude: property.latitude,
      longitude: property.longitude,
      locationSource: property.locationSource,
      accuracyMeters: property.accuracyMeters,
    );
    _properties[index] = archived;
    return archived;
  }

  @override
  Future<EstatePropertyRecord> updatePropertyPreview({
    required String propertyId,
    required String code,
    required String propertyType,
    required String status,
    String? unitNumber,
    String? address,
    String? description,
  }) async {
    const statuses = {
      'active',
      'under_development',
      'reserved',
      'under_maintenance',
      'inactive',
    };
    final index = _properties.indexWhere(
      (property) => property.id == propertyId,
    );
    if (index < 0) throw ArgumentError('Property was not found.');
    final current = _properties[index];
    if (current.status == 'archived') {
      throw ArgumentError('Archived properties cannot be edited.');
    }
    final cleanCode = code.trim();
    final cleanType = propertyType.trim();
    final cleanUnit = unitNumber?.trim();
    final cleanAddress = address?.trim();
    final cleanDescription = description?.trim();
    if (cleanCode.isEmpty || cleanCode.length > 80) {
      throw ArgumentError('Enter a property code from 1 to 80 characters.');
    }
    if (cleanType.isEmpty || cleanType.length > 80) {
      throw ArgumentError('Enter a property type from 1 to 80 characters.');
    }
    if (!statuses.contains(status)) {
      throw ArgumentError('Choose a supported property status.');
    }
    if (cleanUnit != null && cleanUnit.length > 80) {
      throw ArgumentError('Unit number must be 80 characters or fewer.');
    }
    if (cleanAddress != null && cleanAddress.length > 240) {
      throw ArgumentError('Address must be 240 characters or fewer.');
    }
    if (cleanDescription != null && cleanDescription.length > 700) {
      throw ArgumentError('Description must be 700 characters or fewer.');
    }
    if (_properties.any(
      (property) =>
          property.id != propertyId &&
          property.code.toLowerCase() == cleanCode.toLowerCase(),
    )) {
      throw ArgumentError('That property code is already in use.');
    }
    final updated = EstatePropertyRecord(
      id: current.id,
      code: cleanCode,
      propertyType: cleanType,
      status: status,
      unitNumber: cleanUnit == null || cleanUnit.isEmpty ? null : cleanUnit,
      occupancyStatus: current.occupancyStatus,
      structureLabel: current.structureLabel,
      address: cleanAddress == null || cleanAddress.isEmpty
          ? null
          : cleanAddress,
      description: cleanDescription == null || cleanDescription.isEmpty
          ? null
          : cleanDescription,
      occupancyLabel: current.occupancyLabel,
      ownershipLabel: current.ownershipLabel,
      tenancyLabel: current.tenancyLabel,
      ownershipReview: current.ownershipReview,
      locationConfidence: current.locationConfidence,
      latitude: current.latitude,
      longitude: current.longitude,
      locationSource: current.locationSource,
      accuracyMeters: current.accuracyMeters,
    );
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<EstatePropertyRecord> previewUpdatePropertyMapLocation({
    required String propertyId,
    required double? latitude,
    required double? longitude,
    required String confidence,
    required String source,
    double? accuracyMeters,
    required String reason,
  }) async {
    const sources = {'estate_plan', 'on_site_survey', 'staff_observation'};
    final index = _properties.indexWhere(
      (property) => property.id == propertyId,
    );
    if (index < 0) throw ArgumentError('Property was not found.');
    final property = _properties[index];
    if (property.status == 'archived') {
      throw ArgumentError(
        'Archived properties cannot receive location updates.',
      );
    }
    if (!sources.contains(source)) {
      throw ArgumentError('Choose a configured preview location source.');
    }
    final unmapped = latitude == null && longitude == null;
    if (unmapped) {
      if (confidence != 'unmapped' || accuracyMeters != null) {
        throw ArgumentError(
          'Unmapped assets must not include coordinates or accuracy.',
        );
      }
    } else if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !{'verified', 'approximate', 'unverified'}.contains(confidence)) {
      throw ArgumentError(
        'Enter a complete WGS 84 coordinate pair and confidence.',
      );
    }
    if (accuracyMeters != null &&
        (!accuracyMeters.isFinite ||
            accuracyMeters < 0 ||
            accuracyMeters > 100000)) {
      throw ArgumentError('Accuracy must be between 0 and 100000 metres.');
    }
    if (reason.trim().length < 10 || reason.length > 500) {
      throw ArgumentError('Enter a reason from 10 to 500 characters.');
    }
    final updated = EstatePropertyRecord(
      id: property.id,
      code: property.code,
      propertyType: property.propertyType,
      status: property.status,
      unitNumber: property.unitNumber,
      occupancyStatus: property.occupancyStatus,
      structureLabel: property.structureLabel,
      address: property.address,
      description: property.description,
      occupancyLabel: property.occupancyLabel,
      ownershipLabel: property.ownershipLabel,
      tenancyLabel: property.tenancyLabel,
      ownershipReview: property.ownershipReview,
      locationConfidence: confidence,
      latitude: latitude,
      longitude: longitude,
      locationSource: source,
      accuracyMeters: accuracyMeters,
    );
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<List<EstateStructureNode>> loadEstateStructure() async =>
      List.unmodifiable(_structure);

  @override
  Future<EstateStructureNode> createStructureNodePreview({
    required String type,
    required String name,
    String? code,
    String? parentId,
  }) async {
    const allowedParents = <String, List<String>>{
      'zone': [],
      'street': ['zone'],
      'building': ['street'],
      'floor': ['building'],
    };
    if (!allowedParents.containsKey(type)) {
      throw ArgumentError('Choose a supported structure type.');
    }
    final cleanName = name.trim();
    final cleanCode = code?.trim();
    if (cleanName.isEmpty || cleanName.length > 120) {
      throw ArgumentError('Enter a name from 1 to 120 characters.');
    }
    if (cleanCode != null && cleanCode.length > 60) {
      throw ArgumentError('Structure codes must be 60 characters or fewer.');
    }
    final parentOptions = allowedParents[type]!;
    EstateStructureNode? parent;
    if (parentId != null) {
      parent = _structure.where((node) => node.id == parentId).firstOrNull;
      if (parent == null ||
          parent.status != 'active' ||
          !parentOptions.contains(parent.type)) {
        throw ArgumentError('Choose an active parent of the correct type.');
      }
    } else if (parentOptions.isNotEmpty) {
      throw ArgumentError('Choose a parent structure.');
    }
    if (cleanCode != null &&
        cleanCode.isNotEmpty &&
        _structure.any(
          (node) =>
              node.type == type &&
              node.code?.toLowerCase() == cleanCode.toLowerCase(),
        )) {
      throw ArgumentError('That code is already used by this structure type.');
    }
    final node = EstateStructureNode(
      id: 'preview-structure-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      name: cleanName,
      code: cleanCode == null || cleanCode.isEmpty ? null : cleanCode,
      parentId: parent?.id,
      status: 'active',
      linkedPropertyCount: 0,
    );
    _structure.add(node);
    return node;
  }

  @override
  Future<EstateStructureNode> updateStructureNodePreview({
    required String nodeId,
    required String name,
    String? code,
  }) async {
    final index = _structure.indexWhere((node) => node.id == nodeId);
    if (index < 0) throw ArgumentError('Structure node was not found.');
    final current = _structure[index];
    if (current.status != 'active') {
      throw ArgumentError('Only active structure nodes can be edited.');
    }
    final cleanName = name.trim();
    final cleanCode = code?.trim();
    if (cleanName.isEmpty || cleanName.length > 120) {
      throw ArgumentError('Enter a name from 1 to 120 characters.');
    }
    if (cleanCode != null && cleanCode.length > 60) {
      throw ArgumentError('Structure codes must be 60 characters or fewer.');
    }
    if (cleanCode != null &&
        cleanCode.isNotEmpty &&
        _structure.any(
          (node) =>
              node.id != nodeId &&
              node.type == current.type &&
              node.code?.toLowerCase() == cleanCode.toLowerCase(),
        )) {
      throw ArgumentError('That code is already used by this structure type.');
    }
    final updated = EstateStructureNode(
      id: current.id,
      type: current.type,
      name: cleanName,
      code: cleanCode == null || cleanCode.isEmpty ? null : cleanCode,
      parentId: current.parentId,
      status: current.status,
      linkedPropertyCount: current.linkedPropertyCount,
    );
    _structure[index] = updated;
    return updated;
  }

  @override
  Future<EstateStructureNode> archiveStructureNodePreview(String nodeId) async {
    final index = _structure.indexWhere((node) => node.id == nodeId);
    if (index < 0) throw ArgumentError('Structure node was not found.');
    final current = _structure[index];
    if (current.status != 'active') {
      throw ArgumentError('Only active structure nodes can be archived.');
    }
    final hasActiveChildren = _structure.any(
      (node) => node.parentId == nodeId && node.status == 'active',
    );
    if (hasActiveChildren || current.linkedPropertyCount != 0) {
      throw ArgumentError(
        'Move or archive child nodes and linked properties before archiving this node.',
      );
    }
    final archived = EstateStructureNode(
      id: current.id,
      type: current.type,
      name: current.name,
      code: current.code,
      parentId: current.parentId,
      status: 'archived',
      linkedPropertyCount: current.linkedPropertyCount,
    );
    _structure[index] = archived;
    return archived;
  }

  @override
  Future<List<ResidentJoinRequestSummary>> loadResidentJoinRequests() async =>
      List.unmodifiable(_joinRequests);

  @override
  Future<ResidentJoinRequestDetail> readResidentJoinRequest(
    String requestId,
  ) async {
    final detail = _joinDetails[requestId];
    if (detail == null) throw StateError('Request not found.');
    return detail;
  }

  @override
  Future<ResidentJoinRequestSummary> decideResidentJoinRequest({
    required String requestId,
    required String decision,
    required String reason,
  }) async {
    final index = _joinRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) throw StateError('Resident request not found.');
    final current = _joinRequests[index];
    final normalizedReason = reason.trim();
    if (current.status != 'submitted' ||
        !['approve', 'reject'].contains(decision) ||
        (decision == 'reject' && normalizedReason.isEmpty) ||
        normalizedReason.length > 500) {
      throw StateError(
        'This resident request decision is not available in the preview.',
      );
    }
    final updated = ResidentJoinRequestSummary(
      id: current.id,
      applicantName: current.applicantName,
      relationship: current.relationship,
      submittedAt: current.submittedAt,
      status: decision == 'approve' ? 'approved' : 'rejected',
      applicantEmail: current.applicantEmail,
      propertyLabel: current.propertyLabel,
    );
    _joinRequests[index] = updated;
    final detail = _joinDetails[requestId];
    if (detail != null) {
      _joinDetails[requestId] = ResidentJoinRequestDetail(
        summary: updated,
        applicantNote: detail.applicantNote,
        documentCount: detail.documentCount,
        pendingDocumentCount: detail.pendingDocumentCount,
        documentCategories: detail.documentCategories,
        decisionReason: normalizedReason.isEmpty
            ? (decision == 'approve' ? 'Approved in preview.' : null)
            : normalizedReason,
        decidedAt: 'Just now · preview',
      );
    }
    return updated;
  }

  @override
  Future<List<VisitorPassSummary>> loadVisitorPasses() async =>
      List.unmodifiable(_visitorPasses);

  @override
  Future<List<GateVisitorSummary>> loadCurrentGateVisitors() async =>
      List.unmodifiable(_gateVisitors);

  @override
  Future<List<FinanceBudgetLine>> loadFinanceBudgets() async =>
      List.unmodifiable(_budgets);

  @override
  Future<List<EstateExpenseRequest>> loadExpenseRequests() async =>
      List.unmodifiable(_previewExpenses);

  @override
  Future<List<FinanceActivityEntry>> loadFinanceActivity() async =>
      List.unmodifiable(_financeActivity);

  @override
  Future<EstateExpenseRequest> decideExpenseRequest({
    required String expenseId,
    required String decision,
    required String reason,
  }) async {
    final index = _previewExpenses.indexWhere(
      (expense) => expense.id == expenseId,
    );
    if (index < 0) throw StateError('Expense request not found.');
    final current = _previewExpenses[index];
    if (current.status != 'pending_approval' ||
        !current.allowedCommands.contains(decision) ||
        !['approve', 'reject'].contains(decision) ||
        (decision == 'reject' && reason.trim().isEmpty)) {
      throw StateError(
        'This expense decision is not available in the preview.',
      );
    }
    final updated = EstateExpenseRequest(
      id: current.id,
      reference: current.reference,
      description: current.description,
      category: current.category,
      requesterName: current.requesterName,
      payeeName: current.payeeName,
      amountLabel: current.amountLabel,
      status: decision == 'approve' ? 'approved' : 'rejected',
      submittedAt: current.submittedAt,
      verifiedPaidLabel: current.verifiedPaidLabel,
      decisionNote: decision == 'reject'
          ? reason.trim()
          : reason.trim().isEmpty
          ? 'Approved in this preview; payment has not been made.'
          : reason.trim(),
      allowedCommands: const [],
    );
    _previewExpenses[index] = updated;
    return updated;
  }

  @override
  Future<EstateExpenseDetail> readExpenseRequestDetail(String expenseId) async {
    final expenseIndex = _previewExpenses.indexWhere(
      (item) => item.id == expenseId,
    );
    if (expenseIndex < 0) throw StateError('Expense request not found.');
    final expense = _previewExpenses[expenseIndex];
    final history = <ExpenseApprovalHistoryEntry>[];
    if (expense.id == 'expense-450') {
      history.add(
        const ExpenseApprovalHistoryEntry(
          stageLabel: 'Estate manager',
          decision: 'approve',
          actorName: 'Ifeoma Nwosu',
          decidedAt: '4 Nov 2026 · 1:40 pm',
          reason: 'Approved within the current security budget allocation.',
        ),
      );
    } else if (expense.id == 'expense-447') {
      history.add(
        const ExpenseApprovalHistoryEntry(
          stageLabel: 'Finance manager',
          decision: 'reject',
          actorName: 'Ifeoma Nwosu',
          decidedAt: '26 Oct 2026 · 10:18 am',
          reason: 'Please attach the revised quotation before resubmitting.',
        ),
      );
    } else if (expense.id == 'expense-451' &&
        expense.status != 'pending_approval') {
      history.add(
        ExpenseApprovalHistoryEntry(
          stageLabel: 'Finance manager',
          decision: expense.status == 'approved' ? 'approve' : 'reject',
          actorName: 'Estate finance reviewer',
          decidedAt: DateTime.now().toIso8601String(),
          reason: expense.decisionNote,
        ),
      );
    }
    final pending = expense.status == 'pending_approval';
    return EstateExpenseDetail(
      approvalStageIndex: pending ? 0 : history.length,
      approvalStageCount: expense.id == 'expense-451' ? 2 : 1,
      approvalHistory: List.unmodifiable(history),
      currentStageLabel: pending ? 'Finance manager' : null,
      approvalPolicyVersion: 'preview-v1',
    );
  }

  @override
  Future<List<EstateFacilityBooking>> loadFacilityBookings() async =>
      List.unmodifiable(_facilityBookings);

  @override
  Future<List<EstateSecurityIncident>> loadSecurityIncidents() async =>
      List.unmodifiable(_securityIncidents);

  static final _securityIncidentPreviewDescriptions = <String, String>{};
  static final _securityIncidentPreviewHistory =
      <String, List<EstateSecurityIncidentPreviewEvent>>{};

  @override
  Future<EstateSecurityIncident> createSecurityIncidentPreview({
    required String category,
    required String priority,
    required String description,
    required String location,
    required DateTime observedAt,
  }) async {
    const categories = {
      'Unauthorized access',
      'Safety concern',
      'Property damage',
      'Noise disturbance',
      'Other',
    };
    const priorities = {'Normal', 'High', 'Urgent'};
    final normalizedDescription = description.trim();
    final normalizedLocation = location.trim();
    final now = DateTime.now();
    if (!categories.contains(category) ||
        !priorities.contains(priority) ||
        normalizedDescription.isEmpty ||
        normalizedDescription.length > 1000 ||
        normalizedLocation.isEmpty ||
        normalizedLocation.length > 120 ||
        observedAt.isAfter(now)) {
      throw ArgumentError('Check the incident details and observed time.');
    }
    final id = 'PREVIEW-${now.microsecondsSinceEpoch}';
    final incident = EstateSecurityIncident(
      id: id,
      category: category,
      priority: priority,
      status: 'reported',
      observedAt:
          '${observedAt.day}/${observedAt.month} · ${observedAt.hour.toString().padLeft(2, '0')}:${observedAt.minute.toString().padLeft(2, '0')}',
      reportedAt: 'Just now · preview',
      reporterName: 'Estate staff · preview',
      locationLabel: normalizedLocation,
    );
    _securityIncidentPreviewDescriptions[id] = normalizedDescription;
    _securityIncidentPreviewHistory[id] = [];
    _securityIncidents.insert(0, incident);
    return incident;
  }

  @override
  Future<EstateSecurityIncidentPreviewDetails>
  readSecurityIncidentPreviewDetails(String incidentId) async {
    final description = _securityIncidentPreviewDescriptions[incidentId];
    if (description == null) {
      throw StateError('Incident details are not available in this preview.');
    }
    return EstateSecurityIncidentPreviewDetails(
      description: description,
      history: List.unmodifiable(
        _securityIncidentPreviewHistory[incidentId] ?? const [],
      ),
    );
  }

  @override
  Future<EstateSecurityIncident> transitionSecurityIncidentPreview({
    required String incidentId,
    required String command,
    required String reason,
  }) async {
    if (!_securityIncidentPreviewDescriptions.containsKey(incidentId)) {
      throw StateError('Only reports created in this preview can be updated.');
    }
    final index = _securityIncidents.indexWhere(
      (item) => item.id == incidentId,
    );
    if (index < 0) throw StateError('Incident report is not available.');
    final current = _securityIncidents[index];
    final normalizedReason = reason.trim();
    final allowed = switch (command) {
      'acknowledge' =>
        current.status == 'reported' || current.status == 'reopened',
      'investigate' =>
        current.status == 'acknowledged' ||
            current.status == 'assigned' ||
            current.status == 'contained',
      'contain' => current.status == 'investigating',
      'resolve' =>
        current.status == 'investigating' || current.status == 'contained',
      'close' => current.status == 'resolved',
      'reopen' => current.status == 'resolved' || current.status == 'closed',
      _ => false,
    };
    final reasonRequired = const {
      'contain',
      'resolve',
      'close',
      'reopen',
    }.contains(command);
    if (!allowed ||
        (reasonRequired && normalizedReason.isEmpty) ||
        normalizedReason.length > 500) {
      throw StateError(
        'That incident action is not available for this preview report.',
      );
    }
    final nextStatus = switch (command) {
      'acknowledge' => 'acknowledged',
      'investigate' => 'investigating',
      'contain' => 'contained',
      'resolve' => 'resolved',
      'close' => 'closed',
      'reopen' => 'reopened',
      _ => current.status,
    };
    final updated = EstateSecurityIncident(
      id: current.id,
      category: current.category,
      priority: current.priority,
      status: nextStatus,
      observedAt: current.observedAt,
      reportedAt: current.reportedAt,
      reporterName: current.reporterName,
      locationLabel: current.locationLabel,
      gateLabel: current.gateLabel,
    );
    _securityIncidents[index] = updated;
    _securityIncidentPreviewHistory[incidentId]!.add(
      EstateSecurityIncidentPreviewEvent(
        action: command,
        reason: normalizedReason.isEmpty ? null : normalizedReason,
        occurredAt: DateTime.now(),
      ),
    );
    return updated;
  }

  @override
  Future<List<EstateTeamMember>> loadEstateTeam() async =>
      List.unmodifiable(_estateTeam);

  @override
  Future<EstateTeamMember> createEstateStaffInvitationPreview({
    required String email,
    required String roleLabel,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    const roles = {
      'Estate accountant': 'Preview scope · Finance and reports',
      'Security supervisor': 'Preview scope · Gate operations and incidents',
      'Facility manager': 'Preview scope · Facilities and bookings',
      'Maintenance officer': 'Preview scope · Maintenance requests',
    };
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail) ||
        !roles.containsKey(roleLabel)) {
      throw ArgumentError(
        'Provide a valid email and a supported preview role.',
      );
    }
    if (_estateTeam.any(
      (member) =>
          member.email?.toLowerCase() == normalizedEmail &&
          member.status != 'revoked' &&
          member.status != 'expired',
    )) {
      throw StateError('This account already has an estate team record.');
    }
    final now = DateTime.now();
    final invite = EstateTeamMember(
      id: 'preview-invitation-${now.microsecondsSinceEpoch}',
      kind: 'invitation_preview',
      displayName: normalizedEmail.split('@').first,
      email: normalizedEmail,
      roleLabel: roleLabel,
      accessScopeLabel: roles[roleLabel],
      status: 'invited',
      invitedAt: 'Just now · preview',
    );
    _estateTeam.insert(0, invite);
    return invite;
  }

  static final _tenancies = <EstateTenancySummary>[
    EstateTenancySummary(
      id: 'tn-1001',
      propertyLabel: 'Block A · 12B',
      tenantLabel: 'Ada Okafor',
      landlordLabel: 'Oakwood Property Co.',
      rentAmount: '1850000',
      currency: 'NGN',
      rentFrequency: 'monthly',
      startDate: '2026-03-01',
      endDate: '2026-12-20',
      nextDueDate: '2026-12-01',
      status: 'active',
    ),
    EstateTenancySummary(
      id: 'tn-1002',
      propertyLabel: 'Block C · 04A',
      tenantLabel: 'Tunde Bello',
      rentAmount: '2400000',
      currency: 'NGN',
      rentFrequency: 'monthly',
      startDate: '2026-08-15',
      endDate: '2027-08-14',
      nextDueDate: '2026-11-15',
      status: 'active',
    ),
    EstateTenancySummary(
      id: 'tn-1003',
      propertyLabel: 'Terrace 08',
      tenantLabel: 'Chika Nwosu',
      landlordLabel: 'M. Adebayo',
      rentAmount: '1200000',
      currency: 'NGN',
      rentFrequency: 'monthly',
      startDate: '2025-11-01',
      endDate: '2026-10-31',
      status: 'expired',
    ),
    EstateTenancySummary(
      id: 'tn-1004',
      propertyLabel: 'Block B · 19C',
      tenantLabel: 'Nneka Eze',
      rentAmount: '2100000',
      currency: 'NGN',
      rentFrequency: 'monthly',
      startDate: '2026-06-01',
      endDate: '2027-05-31',
      nextDueDate: '2026-12-01',
      status: 'pending',
    ),
  ];

  static const _landlordPortfolio = <LandlordPortfolioItem>[
    LandlordPortfolioItem(
      propertyId: 'prop-0182',
      estateName: 'Oakwood Estate',
      estateLocation: 'Lekki, Lagos',
      propertyLabel: 'Block A · 12B',
      propertyType: 'Apartment',
      operationalStatus: 'active',
      occupancyStatus: 'rented',
      tenantDisplayName: 'Ada Okafor',
      tenancyStatus: 'active',
      tenancyStartDate: '2026-03-01',
      tenancyEndDate: '2027-02-28',
      rentAmount: '1850000',
      currency: 'NGN',
      rentFrequency: 'monthly',
    ),
    LandlordPortfolioItem(
      propertyId: 'prop-0204',
      estateName: 'Oakwood Estate',
      estateLocation: 'Lekki, Lagos',
      propertyLabel: 'Terrace 08',
      propertyAddress: 'Jacaranda Drive',
      propertyType: 'Terrace',
      operationalStatus: 'active',
      occupancyStatus: 'not_currently_rented',
    ),
    LandlordPortfolioItem(
      propertyId: 'prop-0220',
      estateName: 'Oakwood Estate',
      estateLocation: 'Lekki, Lagos',
      propertyLabel: 'Block C · 04A',
      propertyType: 'Apartment',
      operationalStatus: 'active',
      occupancyStatus: 'rented',
      tenantDisplayName: 'Tunde Bello',
      tenancyStatus: 'expiring',
      tenancyStartDate: '2025-12-01',
      tenancyEndDate: '2026-11-30',
      rentAmount: '2400000',
      currency: 'NGN',
      rentFrequency: 'monthly',
    ),
    LandlordPortfolioItem(
      propertyId: 'prop-0301',
      estateName: 'Oakwood Estate',
      estateLocation: 'Lekki, Lagos',
      propertyLabel: 'Garden Flat 03',
      propertyType: 'Apartment',
      operationalStatus: 'under_maintenance',
      occupancyStatus: 'not_currently_rented',
    ),
  ];

  static const _estateInvoices = <EstateInvoiceSummary>[
    EstateInvoiceSummary(
      id: 'inv-2026-1108',
      invoiceNumber: 'OAK-INV-1108',
      category: 'Estate service charge',
      status: 'issued',
      dueAt: '2026-11-10T23:59:00+01:00',
      total: '85000',
      allocated: '35000',
      balance: '50000',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Ada Okafor',
      propertyCode: 'A-12B',
    ),
    EstateInvoiceSummary(
      id: 'inv-2026-1092',
      invoiceNumber: 'OAK-INV-1092',
      category: 'Water charge',
      status: 'overdue',
      dueAt: '2026-10-29T23:59:00+01:00',
      total: '18000',
      allocated: '0',
      balance: '18000',
      currency: 'NGN',
      overdue: true,
      disputed: true,
      payerDisplayName: 'Tunde Bello',
      propertyCode: 'C-04A',
    ),
    EstateInvoiceSummary(
      id: 'inv-2026-1080',
      invoiceNumber: 'OAK-INV-1080',
      category: 'Monthly rent',
      status: 'paid',
      dueAt: '2026-10-05T23:59:00+01:00',
      total: '1850000',
      allocated: '1850000',
      balance: '0',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Ada Okafor',
      propertyCode: 'A-12B',
      tenancyLabel: 'Monthly tenancy',
    ),
    EstateInvoiceSummary(
      id: 'inv-2026-1115',
      invoiceNumber: 'OAK-INV-1115',
      category: 'Waste collection',
      status: 'draft',
      dueAt: '2026-11-20T23:59:00+01:00',
      total: '12000',
      currency: 'NGN',
      overdue: false,
      disputed: false,
      payerDisplayName: 'Nneka Eze',
      propertyCode: 'B-19C',
    ),
  ];

  static const _estateAnnouncements = <EstateAnnouncementSummary>[
    EstateAnnouncementSummary(
      id: 'ann-0204',
      title: 'Water supply maintenance',
      bodyPreview: 'Water supply to Blocks C and D will pause while the pump is serviced. Please store what you need ahead of the maintenance window.',
      priority: 'normal',
      status: 'published',
      audienceLabel: 'Blocks C and D',
      channels: ['push', 'email'],
      createdAt: '2026-11-05T09:30:00+01:00',
      publishedAt: '2026-11-05T10:00:00+01:00',
    ),
    EstateAnnouncementSummary(
      id: 'ann-0202',
      title: 'November residents meeting',
      bodyPreview: 'The monthly residents meeting is planned for the community hall. The agenda and joining details will be shared through the resident portal.',
      priority: 'normal',
      status: 'scheduled',
      audienceLabel: 'All residents',
      channels: ['push'],
      createdAt: '2026-11-04T13:10:00+01:00',
      scheduledAt: '2026-11-08T17:00:00+01:00',
    ),
    EstateAnnouncementSummary(
      id: 'ann-0201',
      title: 'Draft: gate access update',
      bodyPreview: 'Draft notice about the updated gate access process.',
      priority: 'normal',
      status: 'draft',
      audienceLabel: 'All residents',
      channels: ['push', 'email'],
      createdAt: '2026-11-03T12:15:00+01:00',
    ),
    EstateAnnouncementSummary(
      id: 'ann-0199',
      title: 'Gate access update',
      bodyPreview: 'A previous notification attempt could not be queued. Review the delivery status before retrying.',
      priority: 'normal',
      status: 'failed',
      failureCode: 'PROVIDER_UNAVAILABLE',
      audienceLabel: 'All residents',
      channels: ['push'],
      createdAt: '2026-11-02T12:15:00+01:00',
    ),
    EstateAnnouncementSummary(
      id: 'ann-0198',
      title: 'Power interruption notice',
      bodyPreview: 'A planned maintenance window has been arranged for the estate backup power system.',
      priority: 'normal',
      status: 'published',
      audienceLabel: 'All residents',
      channels: ['push', 'sms'],
      createdAt: '2026-10-29T14:30:00+01:00',
      publishedAt: '2026-10-29T15:00:00+01:00',
    ),
  ];

  static const _chargeDefinitions = <EstateChargeDefinition>[
    EstateChargeDefinition(
      id: 'chg-001',
      name: 'Estate service charge',
      description: 'Shared area cleaning, landscaping and routine common-area operations.',
      category: 'estate_service',
      amount: '85000',
      currency: 'NGN',
      recurrence: 'annual',
      scopeLabel: 'All residential properties',
      dueRule: 'Due 30 days after issue',
      status: 'active',
      effectiveFrom: '2026-01-01',
    ),
    EstateChargeDefinition(
      id: 'chg-002',
      name: 'Water supply charge',
      description: 'Metered estate water service billed to residential units.',
      category: 'utilities',
      amount: '18000',
      currency: 'NGN',
      recurrence: 'monthly',
      scopeLabel: 'Residential properties · Blocks A–D',
      dueRule: 'Due on the 10th',
      status: 'active',
      effectiveFrom: '2026-02-01',
    ),
    EstateChargeDefinition(
      id: 'chg-003',
      name: 'Facility booking fee',
      description:
          'One-time fee applied to approved use of selected shared facilities.',
      category: 'facility',
      amount: '25000',
      currency: 'NGN',
      recurrence: 'one_time',
      scopeLabel: 'Facility bookings only',
      dueRule: 'Due before confirmed booking',
      status: 'active',
      effectiveFrom: '2026-01-01',
    ),
    EstateChargeDefinition(
      id: 'chg-004',
      name: 'Waste collection',
      description: 'Monthly waste collection contribution.',
      category: 'estate_service',
      amount: '12000',
      currency: 'NGN',
      recurrence: 'monthly',
      scopeLabel: 'All residential properties',
      dueRule: 'Due on the 5th',
      status: 'draft',
      effectiveFrom: '2026-12-01',
    ),
  ];

  static const _estateSettings = EstateSettingsSummary(
    id: 'estate-oakwood-001',
    name: 'Oakwood Estate',
    type: 'gated_community',
    status: 'active',
    code: 'OAK-LAG-0248',
    address: '18 Jacaranda Drive',
    state: 'Lagos',
    lga: 'Eti-Osa',
    timezone: 'Africa/Lagos',
    currency: 'NGN',
  );

  @override
  Future<List<EstateTenancySummary>> loadEstateTenancies() async =>
      List.unmodifiable(_tenancies);

  @override
  Future<List<EstateTenancySummary>> previewRentInvoiceSchedules({
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12 || year < 2000 || year > 2200) {
      throw ArgumentError('Choose a valid billing period.');
    }
    final periodStart = DateTime(year, month);
    final periodEnd = DateTime(year, month + 1);
    final schedules = _tenancies.where((tenancy) {
      if (tenancy.status != 'active' || tenancy.nextDueDate == null) {
        return false;
      }
      final dueDate = DateTime.tryParse(tenancy.nextDueDate!);
      return dueDate != null &&
          !dueDate.isBefore(periodStart) &&
          dueDate.isBefore(periodEnd);
    }).toList()..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    return List.unmodifiable(schedules);
  }

  static const _previewTenants = <EstateTenancyPartyOption>[
    EstateTenancyPartyOption(id: 'preview-tenant-1', displayName: 'Chioma Eze'),
    EstateTenancyPartyOption(
      id: 'preview-tenant-2',
      displayName: 'Daniel Obasi',
    ),
  ];
  static const _previewPayees = <EstateTenancyPartyOption>[
    EstateTenancyPartyOption(
      id: 'preview-payee-003',
      displayName: 'Verified owner on file',
    ),
  ];
  static final _previewTenancyPropertyIds = <String>{};

  @override
  Future<EstateTenancyCreationOptions> loadTenancyCreationOptions() async {
    final properties = _properties
        .where(
          (property) =>
              property.status == 'active' &&
              property.occupancyStatus == 'vacant' &&
              property.ownershipLabel == 'Verified owner' &&
              property.tenancyLabel == null &&
              !_previewTenancyPropertyIds.contains(property.id),
        )
        .toList();
    return EstateTenancyCreationOptions(
      properties: List.unmodifiable(properties),
      tenants: List.unmodifiable(_previewTenants),
      payees: List.unmodifiable(_previewPayees),
    );
  }

  @override
  Future<EstateTenancySummary> createTenancyDraftPreview({
    required String propertyId,
    required String tenantId,
    required String payeeId,
    required String rentAmount,
    required String rentFrequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final property = _properties
        .where((item) => item.id == propertyId)
        .firstOrNull;
    final tenant = _previewTenants
        .where((item) => item.id == tenantId)
        .firstOrNull;
    final payee = _previewPayees
        .where((item) => item.id == payeeId)
        .firstOrNull;
    final amount = rentAmount.trim();
    final frequency = rentFrequency.trim().toLowerCase();
    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(startDate);
    final end = endDate == null ? null : _dateOnly(endDate);
    if (property == null ||
        property.status != 'active' ||
        property.occupancyStatus != 'vacant' ||
        property.ownershipLabel != 'Verified owner' ||
        property.tenancyLabel != null ||
        _previewTenancyPropertyIds.contains(propertyId) ||
        tenant == null ||
        payee == null ||
        !RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,2})?$').hasMatch(amount) ||
        !_positiveMoneyAmount(amount) ||
        !const {'monthly', 'quarterly', 'annually'}.contains(frequency) ||
        start.isBefore(today) ||
        (end != null && !end.isAfter(start))) {
      throw StateError(
        'The tenancy draft does not match the available preview policy.',
      );
    }
    final normalizedAmount = amount.contains('.')
        ? '${amount.split('.').first}.${amount.split('.').last.padRight(2, '0')}'
        : '$amount.00';
    final createdAt = DateTime.now();
    final summary = EstateTenancySummary(
      id: 'PREVIEW-TN-${createdAt.microsecondsSinceEpoch}',
      propertyLabel:
          '${property.structureLabel ?? 'Estate property'} · ${property.code}',
      tenantLabel: tenant.displayName,
      landlordLabel: payee.displayName,
      rentAmount: normalizedAmount,
      currency: 'NGN',
      rentFrequency: frequency,
      startDate: _calendarDate(start),
      endDate: end == null ? null : _calendarDate(end),
      nextDueDate: _calendarDate(start),
      status: 'pending',
    );
    _previewTenancyPropertyIds.add(propertyId);
    _tenancies.insert(0, summary);
    return summary;
  }

  @override
  Future<List<LandlordPortfolioItem>> loadLandlordPortfolio() async =>
      List.unmodifiable(_landlordPortfolio);

  @override
  Future<List<EstateInvoiceSummary>> loadEstateInvoices() async =>
      List.unmodifiable(_estateInvoices);

  @override
  Future<List<EstateAnnouncementSummary>> loadEstateAnnouncements() async =>
      List.unmodifiable(_previewAnnouncements);

  @override
  Future<EstateAnnouncementSummary> createAnnouncementDraft({
    required String title,
    required String body,
    required String priority,
    required String audienceLabel,
    required List<String> channels,
  }) async {
    final now = DateTime.now().toIso8601String();
    final draft = EstateAnnouncementSummary(
      id: 'preview-${now.hashCode}',
      title: title,
      bodyPreview: body.length > 180 ? '${body.substring(0, 180)}…' : body,
      priority: priority,
      status: 'draft',
      audienceLabel: audienceLabel,
      channels: List.unmodifiable(channels),
      createdAt: now,
    );
    _previewAnnouncements.insert(0, draft);
    return draft;
  }

  @override
  Future<EstateAnnouncementSummary> scheduleAnnouncement({
    required String announcementId,
    required String scheduledAt,
    required String timeZone,
  }) async {
    final index = _previewAnnouncements.indexWhere(
      (announcement) => announcement.id == announcementId,
    );
    if (index < 0) throw StateError('Announcement not found.');
    final current = _previewAnnouncements[index];
    final sendTime = DateTime.tryParse(scheduledAt);
    if (current.status != 'draft' ||
        current.priority == 'emergency' ||
        sendTime == null ||
        !sendTime.isAfter(DateTime.now().toUtc()) ||
        timeZone != 'Africa/Lagos') {
      throw StateError(
        'This draft cannot be scheduled with the selected details.',
      );
    }
    final scheduled = EstateAnnouncementSummary(
      id: current.id,
      title: current.title,
      bodyPreview: current.bodyPreview,
      priority: current.priority,
      status: 'scheduled',
      audienceLabel: current.audienceLabel,
      channels: current.channels,
      createdAt: current.createdAt,
      scheduledAt: sendTime.toIso8601String(),
    );
    _previewAnnouncements[index] = scheduled;
    return scheduled;
  }

  @override
  Future<EstateAnnouncementSummary> requestAnnouncementDispatch({
    required String announcementId,
    required bool confirmEmergency,
  }) async {
    final index = _previewAnnouncements.indexWhere(
      (announcement) => announcement.id == announcementId,
    );
    if (index < 0) throw StateError('Announcement not found.');
    final current = _previewAnnouncements[index];
    final scheduledAt = current.scheduledAt == null
        ? null
        : DateTime.tryParse(current.scheduledAt!);
    final dispatchable =
        current.status == 'draft' ||
        (current.status == 'scheduled' &&
            scheduledAt != null &&
            !scheduledAt.isAfter(DateTime.now().toUtc()));
    if (!dispatchable ||
        (current.priority == 'emergency' && !confirmEmergency)) {
      throw StateError('This announcement cannot be dispatched yet.');
    }
    final sending = EstateAnnouncementSummary(
      id: current.id,
      title: current.title,
      bodyPreview: current.bodyPreview,
      priority: current.priority,
      status: 'sending',
      audienceLabel: current.audienceLabel,
      channels: current.channels,
      createdAt: current.createdAt,
      scheduledAt: current.scheduledAt,
    );
    _previewAnnouncements[index] = sending;
    return sending;
  }

  @override
  Future<EstateAnnouncementSummary> retryAnnouncementDispatch({
    required String announcementId,
  }) async {
    final index = _previewAnnouncements.indexWhere(
      (announcement) => announcement.id == announcementId,
    );
    if (index < 0) throw StateError('Announcement not found.');
    final current = _previewAnnouncements[index];
    if (current.status != 'failed') {
      throw StateError('Only failed announcements can be retried.');
    }
    final sending = EstateAnnouncementSummary(
      id: current.id,
      title: current.title,
      bodyPreview: current.bodyPreview,
      priority: current.priority,
      status: 'sending',
      audienceLabel: current.audienceLabel,
      channels: current.channels,
      createdAt: current.createdAt,
    );
    _previewAnnouncements[index] = sending;
    return sending;
  }

  @override
  Future<List<EstateChargeDefinition>> loadChargeDefinitions() async =>
      List.unmodifiable(_chargeDefinitions);

  @override
  Future<EstateSettingsSummary> loadEstateSettings() async => _estateSettings;

  @override
  Future<List<EstatePropertyRecord>> loadOwnershipReviews() async =>
      List.unmodifiable(
        _properties.where((property) => property.ownershipReview != null),
      );
}

bool _positiveMoneyAmount(String amount) {
  final parts = amount.split('.');
  try {
    final whole = BigInt.parse(parts.first);
    final fraction = BigInt.parse(
      (parts.length > 1 ? parts[1] : '').padRight(2, '0'),
    );
    return whole > BigInt.zero || fraction > BigInt.zero;
  } on FormatException {
    return false;
  }
}

String _calendarDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
