class ResidentOverview {
  const ResidentOverview({
    required this.residentName,
    required this.estateName,
    required this.location,
    required this.propertyLabel,
    required this.balanceLabel,
    required this.balanceDueLabel,
    required this.openRequests,
    required this.nextFacilityBooking,
    required this.activities,
  });

  final String residentName;
  final String estateName;
  final String location;
  final String propertyLabel;
  final String balanceLabel;
  final String balanceDueLabel;
  final int openRequests;
  final String nextFacilityBooking;
  final List<ResidentActivity> activities;
}

class ResidentActivity {
  const ResidentActivity({
    required this.title,
    required this.detail,
    required this.whenLabel,
    required this.iconKey,
  });

  final String title;
  final String detail;
  final String whenLabel;
  final String iconKey;
}

class ResidentEstateMapAsset {
  const ResidentEstateMapAsset({
    required this.id,
    required this.label,
    required this.layer,
    required this.locationConfidence,
    this.diagramX,
    this.diagramY,
    this.isHome = false,
    this.detail,
    this.locationSource,
    this.accuracyMeters,
  });

  final String id;
  final String label;
  final String layer;
  final String locationConfidence;
  final double? diagramX;
  final double? diagramY;
  final bool isHome;
  final String? detail;
  final String? locationSource;
  final double? accuracyMeters;
}

class ResidentEstateMap {
  const ResidentEstateMap({
    required this.estateName,
    required this.location,
    required this.assets,
    required this.asOf,
  });

  final String estateName;
  final String location;
  final List<ResidentEstateMapAsset> assets;
  final DateTime asOf;
}

class ResidentMaintenanceRequest {
  const ResidentMaintenanceRequest({
    required this.reference,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    required this.updatedLabel,
    this.residentVisibleUpdates = const [],
  });

  final String reference;
  final String category;
  final String priority;
  final String description;
  final String status;
  final String updatedLabel;
  final List<ResidentMaintenanceUpdate> residentVisibleUpdates;
}

class ResidentMaintenanceUpdate {
  const ResidentMaintenanceUpdate({
    required this.body,
    required this.whenLabel,
  });

  final String body;
  final String whenLabel;
}

class ResidentFacility {
  const ResidentFacility({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.location,
    required this.capacity,
    required this.durationMinutes,
    required this.openingHours,
    required this.approvalMode,
    this.policyVersion,
    this.feeLabel,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String location;
  final int capacity;
  final int durationMinutes;
  final String openingHours;
  final String approvalMode;
  final String? policyVersion;
  final String? feeLabel;
}

class ResidentFacilityBooking {
  const ResidentFacilityBooking({
    required this.reference,
    required this.facilityName,
    required this.startsAt,
    required this.endsAt,
    required this.attendeeCount,
    required this.status,
    this.feeLabel,
    this.purpose,
  });

  final String reference;
  final String facilityName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int attendeeCount;
  final String status;
  final String? feeLabel;
  final String? purpose;
}

class ResidentVisitorPass {
  const ResidentVisitorPass({
    required this.reference,
    required this.visitorName,
    required this.propertyId,
    required this.propertyLabel,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    required this.uses,
    required this.useLimit,
    this.vehicleSummary,
    this.credential,
  });

  final String reference;
  final String visitorName;
  final String propertyId;
  final String propertyLabel;
  final DateTime validFrom;
  final DateTime validUntil;
  final String status;
  final int uses;
  final int useLimit;
  final String? vehicleSummary;
  final String? credential;
}

class ResidentAnnouncement {
  const ResidentAnnouncement({
    required this.id,
    required this.title,
    required this.category,
    required this.publishedAt,
    required this.body,
    required this.audienceLabel,
    this.emergency = false,
    this.read = false,
  });

  final String id;
  final String title;
  final String category;
  final DateTime publishedAt;
  final String body;
  final String audienceLabel;
  final bool emergency;
  final bool read;
}

class ResidentInvoiceLine {
  const ResidentInvoiceLine({
    required this.description,
    required this.amountLabel,
  });
  final String description;
  final String amountLabel;
}

class ResidentVerifiedPayment {
  const ResidentVerifiedPayment({
    required this.amountLabel,
    required this.paidAt,
    required this.status,
    this.receiptNumber,
  });
  final String amountLabel;
  final DateTime paidAt;
  final String status;
  final String? receiptNumber;
}

class ResidentInvoice {
  const ResidentInvoice({
    required this.id,
    this.estateId = '',
    this.estateName = '',
    required this.invoiceNumber,
    required this.category,
    required this.propertyLabel,
    required this.issuedAt,
    required this.dueAt,
    required this.totalLabel,
    required this.balanceLabel,
    required this.status,
    required this.lines,
    this.verifiedPayments = const [],
  });

  final String id;
  final String estateId;
  final String estateName;
  final String invoiceNumber;
  final String category;
  final String propertyLabel;
  final DateTime issuedAt;
  final DateTime dueAt;
  final String totalLabel;
  final String balanceLabel;
  final String status;
  final List<ResidentInvoiceLine> lines;
  final List<ResidentVerifiedPayment> verifiedPayments;
}

class ResidentPropertyDetail {
  const ResidentPropertyDetail({
    required this.propertyId,
    required this.propertyLabel,
    required this.propertyType,
    required this.status,
    required this.address,
    required this.estateName,
    required this.estateLocation,
    required this.ownershipRecords,
    required this.occupancyRecords,
  });

  final String propertyId;
  final String propertyLabel;
  final String propertyType;
  final String status;
  final String address;
  final String estateName;
  final String estateLocation;
  final List<ResidentPropertyRelationship> ownershipRecords;
  final List<ResidentPropertyRelationship> occupancyRecords;
}

class ResidentPropertyRelationship {
  const ResidentPropertyRelationship({
    required this.displayName,
    required this.relationship,
    required this.status,
    required this.effectiveFrom,
    this.effectiveTo,
    this.share,
    this.verificationStatus,
  });

  final String displayName;
  final String relationship;
  final String status;
  final String effectiveFrom;
  final String? effectiveTo;
  final String? share;
  final String? verificationStatus;
}

class ResidentEstateCharge {
  const ResidentEstateCharge({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.currency,
    required this.recurrence,
    required this.dueRule,
    required this.effectiveFrom,
    required this.appliesToCurrentResident,
  });

  final String id;
  final String name;
  final String category;
  final String amount;
  final String currency;
  final String recurrence;
  final String dueRule;
  final String effectiveFrom;
  final bool appliesToCurrentResident;
}

class ResidentRentSummary {
  const ResidentRentSummary({
    required this.propertyLabel,
    required this.landlordLabel,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.startDate,
    required this.status,
    this.endDate,
    this.nextDueDate,
  });

  final String propertyLabel;
  final String landlordLabel;
  final String amount;
  final String currency;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextDueDate;
  final String status;
}

abstract interface class ResidentVisitorPassRepository {
  Future<List<ResidentVisitorPass>> loadMyVisitorPasses();
  Future<List<({String id, String label})>> loadMyVisitorProperties(
    String estateId,
  );
  Future<ResidentVisitorPass> createVisitorPassDraft({
    required String estateId,
    required String propertyId,
    required String visitorName,
    required DateTime validFrom,
    required DateTime validUntil,
    required String vehicleSummary,
  });
  Future<void> revokeVisitorPass({
    required String estateId,
    required String passId,
    required String reason,
  });
}

abstract interface class ResidentEstateRepository
    implements ResidentVisitorPassRepository {
  Future<ResidentOverview> loadOverview();
  Future<List<ResidentMaintenanceRequest>> loadMyMaintenanceRequests();
  Future<ResidentMaintenanceRequest> submitMaintenanceRequest({
    required String category,
    required String priority,
    required String description,
    required String idempotencyKey,
  });
  Future<List<ResidentFacility>> loadResidentFacilities();
  Future<List<ResidentFacilityBooking>> loadMyFacilityBookings();
  Future<ResidentFacilityBooking> createFacilityBookingDraft({
    required String facilityId,
    required DateTime startsAt,
    required int attendeeCount,
    required String purpose,
    required String acceptedPolicyVersion,
  });
  Future<List<ResidentAnnouncement>> loadMyAnnouncements();
  Future<void> markAnnouncementRead(String announcementId);
  Future<List<ResidentInvoice>> loadMyInvoices();
  Future<List<ResidentPropertyDetail>> loadMyProperties();
  Future<List<ResidentEstateCharge>> loadMyApplicableCharges();
  Future<ResidentRentSummary?> loadMyRentSummary();
  Future<ResidentEstateMap> loadMyEstateMap();
}

/// Static preview adapter. Replace with this product's authenticated API adapter
/// once the host application's API and identity conventions are available.
class PreviewResidentEstateRepository implements ResidentEstateRepository {
  static final _estateMap = ResidentEstateMap(
    estateName: 'Oakwood Estate',
    location: 'Lekki, Lagos',
    asOf: DateTime(2026, 11, 6, 9, 30),
    assets: const [
      ResidentEstateMapAsset(
        id: 'gate-main',
        label: 'Main gate',
        layer: 'gate',
        locationConfidence: 'verified',
        locationSource: 'Estate plan (sample)',
        accuracyMeters: 18,
        diagramX: .13,
        diagramY: .51,
        detail: 'Estate entrance',
      ),
      ResidentEstateMapAsset(
        id: 'block-a',
        label: 'Block A',
        layer: 'building',
        locationConfidence: 'approximate',
        locationSource: 'Estate plan (sample)',
        accuracyMeters: 35,
        diagramX: .35,
        diagramY: .26,
        detail: 'Residential building',
      ),
      ResidentEstateMapAsset(
        id: 'block-b',
        label: 'Block B',
        layer: 'building',
        locationConfidence: 'approximate',
        locationSource: 'Estate plan (sample)',
        accuracyMeters: 42,
        diagramX: .69,
        diagramY: .25,
        detail: 'Residential building',
      ),
      ResidentEstateMapAsset(
        id: 'block-c-home',
        label: 'Block C · Unit 12',
        layer: 'home',
        locationConfidence: 'approximate',
        locationSource: 'Estate plan (sample)',
        accuracyMeters: 35,
        diagramX: .69,
        diagramY: .64,
        isHome: true,
        detail: 'Your property',
      ),
      ResidentEstateMapAsset(
        id: 'clubhouse',
        label: 'Clubhouse',
        layer: 'facility',
        locationConfidence: 'verified',
        locationSource: 'Estate plan (sample)',
        accuracyMeters: 16,
        diagramX: .42,
        diagramY: .77,
        detail: 'Community facility',
      ),
      ResidentEstateMapAsset(
        id: 'park',
        label: 'Central green',
        layer: 'facility',
        locationConfidence: 'approximate',
        diagramX: .49,
        diagramY: .48,
        detail: 'Shared outdoor space',
      ),
      ResidentEstateMapAsset(
        id: 'block-d',
        label: 'Block D',
        layer: 'building',
        locationConfidence: 'unmapped',
        detail: 'Location has not been provided',
      ),
    ],
  );
  static const _myProperty = ResidentPropertyDetail(
    propertyId: 'property-oakwood-c12',
    propertyLabel: 'Block C · Unit 12',
    propertyType: 'Apartment',
    status: 'active',
    address: '18 Jacaranda Drive, Block C, Unit 12',
    estateName: 'Oakwood Estate',
    estateLocation: 'Lekki, Lagos',
    ownershipRecords: [
      ResidentPropertyRelationship(
        displayName: 'Chidi Okafor',
        relationship: 'owner',
        status: 'active',
        effectiveFrom: '2023-06-01',
        share: '100%',
        verificationStatus: 'verified',
      ),
    ],
    occupancyRecords: [
      ResidentPropertyRelationship(
        displayName: 'Amara Okafor',
        relationship: 'tenant',
        status: 'active',
        effectiveFrom: '2025-10-01',
        effectiveTo: '2027-09-30',
      ),
      ResidentPropertyRelationship(
        displayName: 'Kelechi Okafor',
        relationship: 'household_member',
        status: 'active',
        effectiveFrom: '2025-10-01',
      ),
    ],
  );
  static const _otherProperty = ResidentPropertyDetail(
    propertyId: 'property-cedar-a04',
    propertyLabel: 'Cedar House · Unit 04',
    propertyType: 'Townhouse',
    status: 'active',
    address: '4 Garden Close, Cedar House, Unit 04',
    estateName: 'Cedar Gardens',
    estateLocation: 'Ikeja, Lagos',
    ownershipRecords: [
      ResidentPropertyRelationship(
        displayName: 'Amara Okafor',
        relationship: 'owner',
        status: 'active',
        effectiveFrom: '2024-05-12',
        share: '100%',
        verificationStatus: 'verified',
      ),
    ],
    occupancyRecords: [],
  );

  static const _myCharges = <ResidentEstateCharge>[
    ResidentEstateCharge(
      id: 'resident-charge-01',
      name: 'Estate service charge',
      category: 'estate_service',
      amount: '85000',
      currency: 'NGN',
      recurrence: 'annual',
      dueRule: 'Due 30 days after invoice issue',
      effectiveFrom: '2026-01-01',
      appliesToCurrentResident: true,
    ),
    ResidentEstateCharge(
      id: 'resident-charge-02',
      name: 'Water supply charge',
      category: 'utilities',
      amount: '18000',
      currency: 'NGN',
      recurrence: 'monthly',
      dueRule: 'Due on the 10th',
      effectiveFrom: '2026-02-01',
      appliesToCurrentResident: true,
    ),
    ResidentEstateCharge(
      id: 'resident-charge-03',
      name: 'Facility booking fee',
      category: 'facility',
      amount: '25000',
      currency: 'NGN',
      recurrence: 'one_time',
      dueRule: 'Due before a confirmed booking',
      effectiveFrom: '2026-01-01',
      appliesToCurrentResident: false,
    ),
  ];

  static final _myRent = ResidentRentSummary(
    propertyLabel: 'Block C · Unit 12',
    landlordLabel: 'Chidi Okafor',
    amount: '1850000',
    currency: 'NGN',
    frequency: 'monthly',
    startDate: DateTime(2025, 10, 1),
    endDate: DateTime(2026, 9, 30),
    nextDueDate: DateTime.now().add(const Duration(days: 5)),
    status: 'active',
  );

  static final _invoices = <ResidentInvoice>[
    ResidentInvoice(
      id: 'invoice-901',
      invoiceNumber: 'OAK-INV-2026-1182',
      category: 'Estate service charge',
      propertyLabel: 'Block C · Unit 12',
      issuedAt: DateTime.now().subtract(const Duration(days: 10)),
      dueAt: DateTime.now().add(const Duration(days: 4)),
      totalLabel: '₦45,000',
      balanceLabel: '₦45,000',
      status: 'issued',
      lines: const [
        ResidentInvoiceLine(
          description: 'Monthly estate service charge',
          amountLabel: '₦40,000',
        ),
        ResidentInvoiceLine(
          description: 'Waste collection',
          amountLabel: '₦5,000',
        ),
      ],
    ),
    ResidentInvoice(
      id: 'invoice-900',
      invoiceNumber: 'OAK-INV-2026-1124',
      category: 'Estate service charge',
      propertyLabel: 'Block C · Unit 12',
      issuedAt: DateTime.now().subtract(const Duration(days: 40)),
      dueAt: DateTime.now().subtract(const Duration(days: 10)),
      totalLabel: '₦45,000',
      balanceLabel: '₦15,000',
      status: 'partially_paid',
      lines: const [
        ResidentInvoiceLine(
          description: 'Monthly estate service charge',
          amountLabel: '₦40,000',
        ),
        ResidentInvoiceLine(
          description: 'Waste collection',
          amountLabel: '₦5,000',
        ),
      ],
      verifiedPayments: [
        ResidentVerifiedPayment(
          amountLabel: '₦30,000',
          paidAt: DateTime.now().subtract(const Duration(days: 32)),
          status: 'verified',
          receiptNumber: 'RCT-2026-7721',
        ),
      ],
    ),
    ResidentInvoice(
      id: 'invoice-899',
      invoiceNumber: 'OAK-INV-2026-1088',
      category: 'Facility booking',
      propertyLabel: 'Block C · Unit 12',
      issuedAt: DateTime.now().subtract(const Duration(days: 18)),
      dueAt: DateTime.now().subtract(const Duration(days: 14)),
      totalLabel: '₦5,000',
      balanceLabel: '₦0',
      status: 'paid',
      lines: const [
        ResidentInvoiceLine(
          description: 'Tennis court · 1 hour',
          amountLabel: '₦5,000',
        ),
      ],
      verifiedPayments: [
        ResidentVerifiedPayment(
          amountLabel: '₦5,000',
          paidAt: DateTime.now().subtract(const Duration(days: 16)),
          status: 'verified',
          receiptNumber: 'RCT-2026-7604',
        ),
      ],
    ),
  ];

  static final _announcements = <ResidentAnnouncement>[
    ResidentAnnouncement(
      id: 'notice-501',
      title: 'Water supply maintenance',
      category: 'Utilities',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      body: 'The estate water team will service the main pump on Saturday from 9:00 am to 11:30 am. Some homes may have reduced pressure during this period. Please store water ahead of the work. Contact the estate office if the supply has not returned by noon.',
      audienceLabel: 'All residents',
      emergency: true,
    ),
    ResidentAnnouncement(
      id: 'notice-500',
      title: 'Pool opening hours this weekend',
      category: 'Facilities',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      body: 'The pool will open at 8:00 am on Saturday and Sunday. Children must be accompanied by an adult. Please follow the posted pool rules and leave the area clear after your session.',
      audienceLabel: 'All residents',
      read: true,
    ),
    ResidentAnnouncement(
      id: 'notice-499',
      title: 'Community clean-up morning',
      category: 'Community',
      publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      body: 'Residents are invited to join the monthly clean-up around North Gardens this Sunday at 8:00 am. Gloves and collection bags will be available at the main gate.',
      audienceLabel: 'North Gardens',
      read: true,
    ),
  ];

  static final _visitorPasses = <ResidentVisitorPass>[
    ResidentVisitorPass(
      reference: 'PASS-00821',
      visitorName: 'Daniel Adewale',
      propertyId: 'preview-property',
      propertyLabel: 'Oakwood · 01',
      validFrom: DateTime.now().subtract(const Duration(minutes: 20)),
      validUntil: DateTime.now().add(const Duration(hours: 3)),
      status: 'exhausted',
      uses: 1,
      useLimit: 1,
    ),
    ResidentVisitorPass(
      reference: 'PASS-00820',
      visitorName: 'Kelechi Madu',
      propertyId: 'preview-property',
      propertyLabel: 'Oakwood · 01',
      validFrom: DateTime.now().add(const Duration(hours: 2)),
      validUntil: DateTime.now().add(const Duration(hours: 5)),
      status: 'active',
      uses: 0,
      useLimit: 1,
      vehicleSummary: 'Silver sedan · KJA 482 EF',
    ),
    ResidentVisitorPass(
      reference: 'PASS-00819',
      visitorName: 'Adaeze Nnadi',
      propertyId: 'preview-property',
      propertyLabel: 'Oakwood · 01',
      validFrom: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      validUntil: DateTime.now().subtract(const Duration(days: 1)),
      status: 'expired',
      uses: 1,
      useLimit: 1,
    ),
  ];

  static final _facilities = <ResidentFacility>[
    const ResidentFacility(
      id: 'facility-pool',
      name: 'Swimming pool',
      category: 'Recreation',
      description: 'Heated pool with a shallow section for families.',
      location: 'North Gardens · Clubhouse',
      capacity: 24,
      durationMinutes: 60,
      openingHours: 'Daily · 7:00 am – 8:00 pm',
      approvalMode: 'automatic',
      policyVersion: 'pool-v4',
    ),
    const ResidentFacility(
      id: 'facility-court',
      name: 'Tennis court',
      category: 'Sports',
      description: 'Outdoor court. Bring your own rackets and balls.',
      location: 'South Courts · Recreation area',
      capacity: 4,
      durationMinutes: 60,
      openingHours: 'Daily · 6:00 am – 9:00 pm',
      approvalMode: 'manual',
      policyVersion: 'court-v2',
      feeLabel: '₦5,000 / hour',
    ),
    const ResidentFacility(
      id: 'facility-hall',
      name: 'Community hall',
      category: 'Events',
      description: 'Indoor hall for resident meetings and small gatherings.',
      location: 'Main entrance · Ground floor',
      capacity: 80,
      durationMinutes: 180,
      openingHours: 'Mon–Sat · 9:00 am – 10:00 pm',
      approvalMode: 'manual',
      policyVersion: 'hall-v3',
      feeLabel: '₦25,000 / session',
    ),
  ];

  static final _bookings = <ResidentFacilityBooking>[
    ResidentFacilityBooking(
      reference: 'FAC-00124',
      facilityName: 'Tennis court',
      startsAt: DateTime.now().add(const Duration(days: 2, hours: 2)),
      endsAt: DateTime.now().add(const Duration(days: 2, hours: 3)),
      attendeeCount: 2,
      status: 'confirmed',
      feeLabel: '₦5,000',
    ),
    ResidentFacilityBooking(
      reference: 'FAC-00125',
      facilityName: 'Community hall',
      startsAt: DateTime.now().add(const Duration(days: 8, hours: 4)),
      endsAt: DateTime.now().add(const Duration(days: 8, hours: 7)),
      attendeeCount: 30,
      status: 'pending_review',
      feeLabel: '₦25,000',
    ),
    ResidentFacilityBooking(
      reference: 'FAC-00126',
      facilityName: 'Swimming pool private session',
      startsAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
      endsAt: DateTime.now().add(const Duration(days: 1, hours: 3)),
      attendeeCount: 6,
      status: 'pending_payment',
      feeLabel: '₦5,000',
    ),
    ResidentFacilityBooking(
      reference: 'FAC-00119',
      facilityName: 'Tennis court',
      startsAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      endsAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
      attendeeCount: 2,
      status: 'completed',
      feeLabel: '₦5,000',
    ),
  ];

  final List<ResidentMaintenanceRequest> _requests = [
    const ResidentMaintenanceRequest(
      reference: 'REQ-00318',
      category: 'plumbing',
      priority: 'normal',
      description: 'Low water pressure in the bathroom tap.',
      status: 'in_progress',
      updatedLabel: 'Updated today',
      residentVisibleUpdates: [
        ResidentMaintenanceUpdate(
          body:
              'A maintenance team member has started checking the water line.',
          whenLabel: 'Today · 10:30 am',
        ),
      ],
    ),
    const ResidentMaintenanceRequest(
      reference: 'REQ-00304',
      category: 'electrical',
      priority: 'normal',
      description: 'Porch light needs a replacement.',
      status: 'under_review',
      updatedLabel: 'Submitted 1 Nov',
    ),
  ];
  final Map<String, (String payload, ResidentMaintenanceRequest request)>
  _idempotency = {};

  @override
  Future<ResidentOverview> loadOverview() async => const ResidentOverview(
    residentName: 'Amara',
    estateName: 'Oakwood Estate',
    location: 'Lekki, Lagos',
    propertyLabel: 'Block C · 12',
    balanceLabel: '₦45,000',
    balanceDueLabel: 'Due 12 Nov',
    openRequests: 2,
    nextFacilityBooking: 'Saturday · 10:00 am',
    activities: [
      ResidentActivity(
        title: 'Visitor pass approved',
        detail: 'For Daniel Adewale',
        whenLabel: 'Today · 9:20 am',
        iconKey: 'visitor',
      ),
      ResidentActivity(
        title: 'Maintenance update',
        detail: 'Water pressure · Work started',
        whenLabel: 'Yesterday · 4:45 pm',
        iconKey: 'maintenance',
      ),
      ResidentActivity(
        title: 'Facility booking',
        detail: 'Tennis court · Confirmed',
        whenLabel: 'Yesterday · 11:10 am',
        iconKey: 'facility',
      ),
    ],
  );

  @override
  Future<List<ResidentMaintenanceRequest>> loadMyMaintenanceRequests() async =>
      List.unmodifiable(_requests);

  @override
  Future<ResidentMaintenanceRequest> submitMaintenanceRequest({
    required String category,
    required String priority,
    required String description,
    required String idempotencyKey,
  }) async {
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedPriority = priority.trim().toLowerCase();
    final normalizedDescription = description.trim();
    if (!const [
      'plumbing',
      'electrical',
      'security',
      'cleaning',
      'other',
    ].contains(normalizedCategory)) {
      throw ArgumentError.value(category, 'category', 'Unsupported category');
    }
    if (!const ['normal', 'high', 'urgent'].contains(normalizedPriority)) {
      throw ArgumentError.value(priority, 'priority', 'Unsupported priority');
    }
    if (normalizedDescription.isEmpty || normalizedDescription.length > 700) {
      throw ArgumentError.value(
        description,
        'description',
        'Describe the issue in no more than 700 characters.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._~-]{24,128}$').hasMatch(idempotencyKey)) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    final payload =
        '$normalizedCategory|$normalizedPriority|$normalizedDescription';
    final previous = _idempotency[idempotencyKey];
    if (previous != null) {
      if (previous.$1 != payload) {
        throw StateError('This request key is already in use.');
      }
      return previous.$2;
    }
    final request = ResidentMaintenanceRequest(
      reference: 'REQ-${318 + _requests.length}',
      category: normalizedCategory,
      priority: normalizedPriority,
      description: normalizedDescription,
      status: 'submitted',
      updatedLabel: 'Submitted just now',
    );
    _requests.insert(0, request);
    _idempotency[idempotencyKey] = (payload, request);
    return request;
  }

  @override
  Future<List<ResidentFacility>> loadResidentFacilities() async =>
      List.unmodifiable(_facilities);

  @override
  Future<List<ResidentFacilityBooking>> loadMyFacilityBookings() async =>
      List.unmodifiable(_bookings);

  @override
  Future<ResidentFacilityBooking> createFacilityBookingDraft({
    required String facilityId,
    required DateTime startsAt,
    required int attendeeCount,
    required String purpose,
    required String acceptedPolicyVersion,
  }) async {
    ResidentFacility? facility;
    for (final item in _facilities) {
      if (item.id == facilityId) {
        facility = item;
        break;
      }
    }
    if (facility == null) {
      throw StateError('The facility is not available in this preview.');
    }
    if (!startsAt.isAfter(DateTime.now()) ||
        attendeeCount < 1 ||
        attendeeCount > facility.capacity) {
      throw StateError(
        'Choose a future time and an attendee count within capacity.',
      );
    }
    if (facility.policyVersion == null ||
        acceptedPolicyVersion != facility.policyVersion) {
      throw StateError('Accept the current facility policy before continuing.');
    }
    if (purpose.length > 250) {
      throw StateError('Purpose must be 250 characters or fewer.');
    }
    final reference =
        'DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final booking = ResidentFacilityBooking(
      reference: reference,
      facilityName: facility.name,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: facility.durationMinutes)),
      attendeeCount: attendeeCount,
      status: 'preview_draft',
      feeLabel: facility.feeLabel,
      purpose: purpose.trim().isEmpty ? null : purpose.trim(),
    );
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<List<ResidentVisitorPass>> loadMyVisitorPasses() async =>
      List.unmodifiable(_visitorPasses);

  @override
  Future<List<({String id, String label})>> loadMyVisitorProperties(
    String estateId,
  ) async => const [(id: 'preview-property', label: 'Oakwood · 01')];

  @override
  Future<ResidentVisitorPass> createVisitorPassDraft({
    required String estateId,
    required String propertyId,
    required String visitorName,
    required DateTime validFrom,
    required DateTime validUntil,
    required String vehicleSummary,
  }) async {
    final name = visitorName.trim();
    final vehicle = vehicleSummary.trim();
    if (name.isEmpty || name.length > 100) {
      throw StateError('Enter a visitor name of 100 characters or fewer.');
    }
    if (vehicle.length > 80) {
      throw StateError('Vehicle details must be 80 characters or fewer.');
    }
    final now = DateTime.now();
    if (validFrom.isBefore(now) || !validUntil.isAfter(validFrom)) {
      throw StateError('Choose a future validity window.');
    }
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(
      8,
    );
    final pass = ResidentVisitorPass(
      reference: 'DRAFT-$suffix',
      visitorName: name,
      propertyId: propertyId,
      propertyLabel: 'Oakwood · 01',
      validFrom: validFrom,
      validUntil: validUntil,
      status: 'preview_draft',
      uses: 0,
      useLimit: 1,
      vehicleSummary: vehicle.isEmpty ? null : vehicle,
    );
    _visitorPasses.insert(0, pass);
    return pass;
  }

  @override
  Future<void> revokeVisitorPass({
    required String estateId,
    required String passId,
    required String reason,
  }) async {
    final index = _visitorPasses.indexWhere((pass) => pass.reference == passId);
    if (index < 0) throw StateError('Visitor pass not found.');
    final old = _visitorPasses[index];
    _visitorPasses[index] = ResidentVisitorPass(
      reference: old.reference,
      visitorName: old.visitorName,
      propertyId: old.propertyId,
      propertyLabel: old.propertyLabel,
      validFrom: old.validFrom,
      validUntil: old.validUntil,
      status: 'revoked',
      uses: old.uses,
      useLimit: old.useLimit,
      vehicleSummary: old.vehicleSummary,
    );
  }

  @override
  Future<List<ResidentAnnouncement>> loadMyAnnouncements() async =>
      List.unmodifiable(_announcements);

  @override
  Future<void> markAnnouncementRead(String announcementId) async {
    final index = _announcements.indexWhere(
      (announcement) => announcement.id == announcementId,
    );
    if (index < 0) throw StateError('Announcement is not available.');
    final current = _announcements[index];
    if (current.read) return;
    _announcements[index] = ResidentAnnouncement(
      id: current.id,
      title: current.title,
      category: current.category,
      publishedAt: current.publishedAt,
      body: current.body,
      audienceLabel: current.audienceLabel,
      emergency: current.emergency,
      read: true,
    );
  }

  @override
  Future<List<ResidentInvoice>> loadMyInvoices() async =>
      List.unmodifiable(_invoices);

  @override
  Future<List<ResidentPropertyDetail>> loadMyProperties() async =>
      List.unmodifiable([_myProperty, _otherProperty]);

  @override
  Future<List<ResidentEstateCharge>> loadMyApplicableCharges() async =>
      List.unmodifiable(
        _myCharges.where((charge) => charge.appliesToCurrentResident),
      );

  @override
  Future<ResidentRentSummary?> loadMyRentSummary() async => _myRent;

  @override
  Future<ResidentEstateMap> loadMyEstateMap() async => _estateMap;
}
