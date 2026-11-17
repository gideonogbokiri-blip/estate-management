class PlatformApplication {
  const PlatformApplication({
    this.id = '',
    required this.code,
    required this.estateName,
    required this.estateType,
    required this.location,
    required this.applicantName,
    required this.applicantUserId,
    required this.applicantEmail,
    required this.submittedAt,
    required this.status,
    required this.documentCount,
    required this.pendingDocumentCount,
    this.managementEntityName,
    this.registrationNumber,
    this.applicantRelationship,
    this.homeCount,
    this.phaseCount,
    this.structureSummary,
    this.documents = const [],
    this.reviewMessage,
  });

  final String id;
  final String code;
  final String estateName;
  final String estateType;
  final String location;
  final String applicantName;
  final String applicantUserId;
  final String applicantEmail;
  final DateTime submittedAt;
  final String status;
  final int documentCount;
  final int pendingDocumentCount;
  final String? managementEntityName;
  final String? registrationNumber;
  final String? applicantRelationship;
  final int? homeCount;
  final int? phaseCount;
  final String? structureSummary;
  final List<PlatformApplicationDocument> documents;
  final String? reviewMessage;
}

class PlatformApplicationDocument {
  const PlatformApplicationDocument({
    this.id = '',
    required this.label,
    required this.category,
    required this.reviewStatus,
    required this.uploadedAt,
  });
  final String id;
  final String label;
  final String category;
  final String reviewStatus;
  final DateTime uploadedAt;
}

class PlatformAdministratorChoice {
  const PlatformAdministratorChoice({
    required this.id,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String displayName;
  final String email;

  factory PlatformAdministratorChoice.fromJson(Map<String, dynamic> json) =>
      PlatformAdministratorChoice(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['emailNormalized'] as String,
      );
}

class PlatformTeamMember {
  const PlatformTeamMember({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.accountStatus,
    required this.roles,
  });
  final String userId;
  final String email;
  final String displayName;
  final String accountStatus;
  final List<String> roles;

  factory PlatformTeamMember.fromJson(Map<String, dynamic> json) =>
      PlatformTeamMember(
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        accountStatus: json['accountStatus'] as String? ?? '',
        roles: (json['roles'] as List? ?? const []).whereType<String>().toList(),
      );
}

class PlatformMoneyOverview {
  const PlatformMoneyOverview({
    required this.estatesTotal,
    required this.estatesActive,
    required this.users,
    required this.applications,
    required this.membershipsByRole,
    required this.adjustmentsTotal,
    required this.credited,
    required this.debited,
  });
  final int estatesTotal;
  final int estatesActive;
  final int users;
  final Map<String, dynamic> applications;
  final Map<String, dynamic> membershipsByRole;
  final int adjustmentsTotal;
  final String credited;
  final String debited;

  factory PlatformMoneyOverview.fromJson(Map<String, dynamic> json) {
    final estates = json['estates'] as Map<String, dynamic>? ?? const {};
    final adjustments = json['adjustments'] as Map<String, dynamic>? ?? const {};
    return PlatformMoneyOverview(
      estatesTotal: (estates['total'] as num?)?.toInt() ?? 0,
      estatesActive: (estates['active'] as num?)?.toInt() ?? 0,
      users: (json['users'] as num?)?.toInt() ?? 0,
      applications: json['applications'] as Map<String, dynamic>? ?? const {},
      membershipsByRole: json['membershipsByRole'] as Map<String, dynamic>? ?? const {},
      adjustmentsTotal: (adjustments['total'] as num?)?.toInt() ?? 0,
      credited: adjustments['credited']?.toString() ?? '0',
      debited: adjustments['debited']?.toString() ?? '0',
    );
  }
}

class PlatformMoneyAccount {
  const PlatformMoneyAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.accountRole,
    required this.balances,
  });
  final String userId;
  final String email;
  final String displayName;
  final String accountRole;
  final Map<String, dynamic> balances;

  factory PlatformMoneyAccount.fromJson(Map<String, dynamic> json) =>
      PlatformMoneyAccount(
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        accountRole: json['accountRole'] as String? ?? '',
        balances: json['balances'] as Map<String, dynamic>? ?? const {},
      );
}

class PlatformBalanceAdjustment {
  const PlatformBalanceAdjustment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.reason,
    required this.createdAt,
  });
  final String id;
  final String amount;
  final String currency;
  final String direction;
  final String reason;
  final String createdAt;

  factory PlatformBalanceAdjustment.fromJson(Map<String, dynamic> json) =>
      PlatformBalanceAdjustment(
        id: json['id'] as String? ?? '',
        amount: json['amount']?.toString() ?? '0',
        currency: json['currency'] as String? ?? '',
        direction: json['direction'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class PlatformUserChoice {
  const PlatformUserChoice({
    required this.userId,
    required this.email,
    required this.displayName,
  });
  final String userId;
  final String email;
  final String displayName;

  factory PlatformUserChoice.fromJson(Map<String, dynamic> json) =>
      PlatformUserChoice(
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
      );
}

class PlatformEstateRecord {
  const PlatformEstateRecord({
    required this.id,
    required this.estateCode,
    required this.name,
    required this.estateType,
    required this.location,
    required this.status,
    required this.memberCount,
    required this.propertyCount,
    required this.activatedAt,
  });
  final String id;
  final String estateCode;
  final String name;
  final String estateType;
  final String location;
  final String status;
  final int memberCount;
  final int propertyCount;
  final String activatedAt;

  factory PlatformEstateRecord.fromJson(Map<String, dynamic> json) =>
      PlatformEstateRecord(
        id: json['id'] as String? ?? '',
        estateCode: json['estateCode'] as String? ?? '',
        name: json['name'] as String? ?? '',
        estateType: json['estateType'] as String? ?? '',
        location: [json['address'], json['state']]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(', '),
        status: json['status'] as String? ?? '',
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        propertyCount: (json['propertyCount'] as num?)?.toInt() ?? 0,
        activatedAt: json['activatedAt'] as String? ?? '',
      );
}

abstract interface class PlatformApplicationRepository {
  Future<List<PlatformApplication>> loadApplications();
}

abstract interface class PlatformApplicationApiRepository
    implements PlatformApplicationRepository {
  Future<bool> restoreSession();
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<PlatformApplication> loadApplication(String id);
  Future<void> startReview(String id);
  Future<List<PlatformAdministratorChoice>> loadInitialAdministrators();
  Future<void> approve(String id, String initialAdministratorUserId);
  Future<void> requestInformation(String id, String message);
  Future<void> reject(String id, String reason);
  Future<List<int>> downloadApplicationDocument(
    String applicationId,
    String documentId,
  );
  Future<List<PlatformTeamMember>> loadPlatformTeam();
  Future<List<PlatformUserChoice>> loadPlatformUserCandidates(String search);
  Future<void> grantPlatformRole({
    required String userId,
    required String roleKey,
  });
  Future<void> revokePlatformRole({
    required String userId,
    required String roleKey,
  });
  Future<List<PlatformEstateRecord>> loadPlatformEstates({
    String? search,
    String? status,
  });
  Future<PlatformMoneyOverview> loadPlatformMoneyOverview();
  Future<List<PlatformMoneyAccount>> loadPlatformMoneyAccounts(String estateId);
  Future<void> adjustPlatformBalance({
    required String estateId,
    required String userId,
    required String amount,
    required String currency,
    required String direction,
    required String reason,
    required String idempotencyKey,
  });
  Future<List<PlatformBalanceAdjustment>> loadPlatformBalanceAdjustments(
    String estateId,
    String userId,
  );
}

/// Illustrative data only; the production repository must use the host
/// platform session and reviewer-scoped application API.
class PreviewPlatformApplicationRepository
    implements PlatformApplicationRepository {
  static final _items = <PlatformApplication>[
    PlatformApplication(
      id: 'application-1048',
      code: 'EA-1048',
      estateName: 'Palm Crest Residences',
      estateType: 'Gated community',
      location: 'Ajah, Lagos',
      applicantName: 'Adebayo Martins',
      applicantUserId: 'preview-user-1048',
      applicantEmail: 'adebayo.martins@example.test',
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'submitted',
      documentCount: 5,
      pendingDocumentCount: 2,
      managementEntityName: 'Palm Crest Management Services',
      registrationNumber: 'RC 8134567',
      applicantRelationship: 'Management company',
      homeCount: 186,
      phaseCount: 4,
      structureSummary:
          'Four zones with twelve streets and 186 residential units.',
      documents: [
        PlatformApplicationDocument(
          label: 'Estate management authorization',
          category: 'management_authorization',
          reviewStatus: 'pending',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Proof of estate address',
          category: 'proof_of_address',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Property structure schedule',
          category: 'property_structure',
          reviewStatus: 'pending',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Applicant identity confirmation',
          category: 'applicant_identity',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Management contact authorization',
          category: 'management_contact',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ],
    ),
    PlatformApplication(
      id: 'application-1047',
      code: 'EA-1047',
      estateName: 'Greenview Court',
      estateType: 'Apartment complex',
      location: 'Ikeja, Lagos',
      applicantName: 'Nneka Eze',
      applicantUserId: 'preview-user-1047',
      applicantEmail: 'nneka.eze@example.test',
      submittedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      status: 'under_review',
      documentCount: 7,
      pendingDocumentCount: 1,
      documents: [
        PlatformApplicationDocument(
          label: 'Management company registration',
          category: 'management_entity',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Estate address evidence',
          category: 'proof_of_address',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Site and property layout',
          category: 'property_structure',
          reviewStatus: 'pending',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Applicant identity confirmation',
          category: 'applicant_identity',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Estate management authorization',
          category: 'management_authorization',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Management contact authorization',
          category: 'management_contact',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        PlatformApplicationDocument(
          label: 'Estate ownership or operation evidence',
          category: 'operation_evidence',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    ),
    PlatformApplication(
      id: 'application-1044',
      code: 'EA-1044',
      estateName: 'Lakeview Gardens',
      estateType: 'Residential estate',
      location: 'Abuja, FCT',
      applicantName: 'Sani Ibrahim',
      applicantUserId: 'preview-user-1044',
      applicantEmail: 'sani.ibrahim@example.test',
      submittedAt: DateTime.now().subtract(const Duration(days: 3)),
      status: 'more_information_required',
      documentCount: 4,
      pendingDocumentCount: 0,
      documents: [
        PlatformApplicationDocument(
          label: 'Estate management authorization',
          category: 'management_authorization',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Proof of estate address',
          category: 'proof_of_address',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Applicant identity confirmation',
          category: 'applicant_identity',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        PlatformApplicationDocument(
          label: 'Management contact authorization',
          category: 'management_contact',
          reviewStatus: 'verified',
          uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      reviewMessage:
          'Please provide a current estate management authorization letter.',
    ),
    PlatformApplication(
      id: 'application-1039',
      code: 'EA-1039',
      estateName: 'Cedar Business Park',
      estateType: 'Mixed use',
      location: 'Port Harcourt, Rivers',
      applicantName: 'Ifeoma Okeke',
      applicantUserId: 'preview-user-1039',
      applicantEmail: 'ifeoma.okeke@example.test',
      submittedAt: DateTime.now().subtract(const Duration(days: 7)),
      status: 'approved',
      documentCount: 6,
      pendingDocumentCount: 0,
    ),
    PlatformApplication(
      id: 'application-1031',
      code: 'EA-1031',
      estateName: 'Unity Housing Cooperative',
      estateType: 'Residential estate',
      location: 'Ibadan, Oyo',
      applicantName: 'Tunde Akinola',
      applicantUserId: 'preview-user-1031',
      applicantEmail: 'tunde.akinola@example.test',
      submittedAt: DateTime.now().subtract(const Duration(days: 11)),
      status: 'rejected',
      documentCount: 3,
      pendingDocumentCount: 0,
      reviewMessage:
          'The submitted ownership authorization could not be verified.',
    ),
  ];

  @override
  Future<List<PlatformApplication>> loadApplications() async =>
      List.unmodifiable(_items);
}
