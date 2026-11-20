import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_base_url.dart';
import '../../../core/config/shared_session.dart';

class EstateWalletTransactionRecord {
  const EstateWalletTransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.reference,
    required this.description,
    required this.sourceType,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String amount;
  final String currency;
  final String reference;
  final String description;
  final String sourceType;
  final String createdAt;

  factory EstateWalletTransactionRecord.fromJson(Map<String, dynamic> json) =>
      EstateWalletTransactionRecord(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        amount: json['amount']?.toString() ?? '0',
        currency: json['currency'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sourceType: json['sourceType'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class EstateWalletRecord {
  const EstateWalletRecord({
    required this.id,
    required this.estateId,
    required this.estateName,
    required this.currency,
    required this.status,
    required this.balance,
    required this.transactions,
    this.accountNumber,
    this.bankName,
    this.accountName,
  });
  final String id;
  final String estateId;
  final String estateName;
  final String currency;
  final String status;
  final String balance;
  final List<EstateWalletTransactionRecord> transactions;
  final String? accountNumber;
  final String? bankName;
  final String? accountName;

  factory EstateWalletRecord.fromJson(Map<String, dynamic> json) =>
      EstateWalletRecord(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        estateName: json['estateName'] as String? ?? '',
        currency: json['currency'] as String? ?? '',
        status: json['status'] as String? ?? '',
        balance: json['balance']?.toString() ?? '0',
        accountNumber: json['accountNumber'] as String?,
        bankName: json['bankName'] as String?,
        accountName: json['accountName'] as String?,
        transactions: (json['transactions'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateWalletTransactionRecord.fromJson)
            .toList(growable: false),
      );
}

class EstateTreasurySummary {
  const EstateTreasurySummary({
    required this.collections,
    required this.walletBalances,
    required this.outstandingInvoices,
    required this.pendingSettlements,
    required this.reconciliationExceptions,
    required this.expenses,
  });
  final String collections;
  final String walletBalances;
  final String outstandingInvoices;
  final int pendingSettlements;
  final int reconciliationExceptions;
  final List<Map<String, dynamic>> expenses;

  factory EstateTreasurySummary.fromJson(Map<String, dynamic> json) =>
      EstateTreasurySummary(
        collections: json['collections']?.toString() ?? '0',
        walletBalances: json['walletBalances']?.toString() ?? '0',
        outstandingInvoices: json['outstandingInvoices']?.toString() ?? '0',
        pendingSettlements: (json['pendingSettlements'] as num?)?.toInt() ?? 0,
        reconciliationExceptions:
            (json['reconciliationExceptions'] as num?)?.toInt() ?? 0,
        expenses: (json['expenses'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
}

class EstatePayoutRecord {
  const EstatePayoutRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    required this.beneficiaryName,
    required this.createdAt,
  });
  final String id;
  final String amount;
  final String currency;
  final String purpose;
  final String status;
  final String beneficiaryName;
  final String createdAt;

  factory EstatePayoutRecord.fromJson(Map<String, dynamic> json) =>
      EstatePayoutRecord(
        id: json['id'] as String? ?? '',
        amount: json['amount']?.toString() ?? '0',
        currency: json['currency'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        status: json['status'] as String? ?? '',
        beneficiaryName:
            (json['beneficiary'] as Map<String, dynamic>?)?['displayName'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class EstatePayoutBeneficiaryRecord {
  const EstatePayoutBeneficiaryRecord({required this.id, required this.displayName, required this.bankName, required this.accountNumber});
  final String id;
  final String displayName;
  final String bankName;
  final String accountNumber;

  factory EstatePayoutBeneficiaryRecord.fromJson(Map<String, dynamic> json) =>
      EstatePayoutBeneficiaryRecord(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
      );
}

class RentScheduleRecord {
  const RentScheduleRecord({
    required this.id,
    required this.amount,
    required this.balance,
    required this.paid,
    required this.currency,
    required this.dueDate,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.isOverdue,
    required this.tenancyId,
    this.receipts = const [],
  });
  final String id;
  final String amount;
  final String balance;
  final String paid;
  final String currency;
  final String dueDate;
  final String periodStart;
  final String periodEnd;
  final String status;
  final bool isOverdue;
  final String tenancyId;
  final List<dynamic> receipts;

  factory RentScheduleRecord.fromJson(Map<String, dynamic> json) =>
      RentScheduleRecord(
        id: json['id'] as String? ?? '',
        amount: json['amount']?.toString() ?? '0',
        balance: json['balance']?.toString() ?? '0',
        paid: json['paid']?.toString() ?? '0',
        currency: json['currency'] as String? ?? '',
        dueDate: json['dueDate'] as String? ?? '',
        periodStart: json['periodStart'] as String? ?? '',
        periodEnd: json['periodEnd'] as String? ?? '',
        status: json['status'] as String? ?? '',
        isOverdue: json['isOverdue'] as bool? ?? false,
        tenancyId: json['tenancyId'] as String? ?? '',
        receipts: json['receipts'] as List? ?? const [],
      );
}

class PropertyLocationRecord {
  const PropertyLocationRecord({
    required this.id,
    required this.code,
    required this.propertyType,
    required this.verificationStatus,
    this.unitNumber,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.captureMethod,
    this.capturedAt,
    this.verifiedAt,
    this.correctionReason,
  });
  final String id;
  final String code;
  final String propertyType;
  final String verificationStatus;
  final String? unitNumber;
  final String? latitude;
  final String? longitude;
  final String? accuracyMeters;
  final String? captureMethod;
  final String? capturedAt;
  final String? verifiedAt;
  final String? correctionReason;

  factory PropertyLocationRecord.fromJson(Map<String, dynamic> json) => PropertyLocationRecord(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        propertyType: json['propertyType'] as String? ?? '',
        verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
        unitNumber: json['unitNumber'] as String?,
        latitude: json['latitude'] as String?,
        longitude: json['longitude'] as String?,
        accuracyMeters: json['accuracyMeters'] as String?,
        captureMethod: json['captureMethod'] as String?,
        capturedAt: json['capturedAt'] as String?,
        verifiedAt: json['verifiedAt'] as String?,
        correctionReason: json['correctionReason'] as String?,
      );
}

class HouseholdMemberRecord {
  const HouseholdMemberRecord({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.memberType,
    required this.status,
    required this.effectiveFrom,
    required this.propertyCode,
    required this.primaryUserName,
    this.effectiveTo,
    this.financialAccess = false,
    this.decisionReason,
    this.dateOfBirth,
    this.phone,
    this.email,
  });
  final String id;
  final String fullName;
  final String relationship;
  final String memberType;
  final String status;
  final String effectiveFrom;
  final String propertyCode;
  final String primaryUserName;
  final String? effectiveTo;
  final bool financialAccess;
  final String? decisionReason;
  final String? dateOfBirth;
  final String? phone;
  final String? email;

  factory HouseholdMemberRecord.fromJson(Map<String, dynamic> json) => HouseholdMemberRecord(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        memberType: json['memberType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        effectiveFrom: json['effectiveFrom'] as String? ?? '',
        propertyCode: json['propertyCode'] as String? ?? '',
        primaryUserName: json['primaryUserName'] as String? ?? '',
        effectiveTo: json['effectiveTo'] as String?,
        financialAccess: json['financialAccess'] as bool? ?? false,
        decisionReason: json['decisionReason'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );
}

class LandlordRentSummaryRecord {
  const LandlordRentSummaryRecord({
    required this.payeeUserId,
    required this.payeeName,
    required this.entitlement,
    required this.collected,
    required this.outstanding,
    this.currency = 'NGN',
  });
  final String payeeUserId;
  final String payeeName;
  final String entitlement;
  final String collected;
  final String outstanding;
  final String currency;

  factory LandlordRentSummaryRecord.fromJson(Map<String, dynamic> json) =>
      LandlordRentSummaryRecord(
        payeeUserId: json['payeeUserId'] as String? ?? '',
        payeeName: json['payeeName'] as String? ?? '',
        entitlement: json['entitlement']?.toString() ?? '0',
        collected: json['collected']?.toString() ?? '0',
        outstanding: json['outstanding']?.toString() ?? '0',
      );
}

class EstateApplicationDraft {
  const EstateApplicationDraft({
    required this.reference,
    required this.proposedName,
    required this.estateType,
    required this.address,
    required this.state,
    required this.lga,
    required this.applicantRelationship,
    required this.applicantContactName,
    required this.applicantContactEmail,
    required this.applicantContactPhone,
    required this.managementEntityName,
    required this.registrationNumber,
    required this.homeCount,
    required this.phaseCount,
    required this.structureSummary,
    required this.updatedAt,
    this.status = 'draft',
  });

  final String reference;
  final String proposedName;
  final String estateType;
  final String address;
  final String state;
  final String lga;
  final String applicantRelationship;
  final String applicantContactName;
  final String applicantContactEmail;
  final String applicantContactPhone;
  final String managementEntityName;
  final String registrationNumber;
  final String homeCount;
  final String phaseCount;
  final String structureSummary;
  final DateTime updatedAt;
  final String status;

  EstateApplicationDraft copyWith({String? status}) => EstateApplicationDraft(
    reference: reference,
    proposedName: proposedName,
    estateType: estateType,
    address: address,
    state: state,
    lga: lga,
    applicantRelationship: applicantRelationship,
    applicantContactName: applicantContactName,
    applicantContactEmail: applicantContactEmail,
    applicantContactPhone: applicantContactPhone,
    managementEntityName: managementEntityName,
    registrationNumber: registrationNumber,
    homeCount: homeCount,
    phaseCount: phaseCount,
    structureSummary: structureSummary,
    updatedAt: updatedAt,
    status: status ?? this.status,
  );
}

abstract interface class EstateApplicationRepository {
  Future<EstateApplicationDraft?> loadMyDraft();
  Future<EstateApplicationDraft> saveMyDraft(EstateApplicationDraft draft);
}

class EstateAccount {
  const EstateAccount({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  factory EstateAccount.fromJson(Map<String, dynamic> json) => EstateAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
  );
}

class ManagedEstateChoice {
  const ManagedEstateChoice({
    required this.id,
    required this.name,
    required this.roles,
    this.location = '',
  });
  final String id;
  final String name;
  final List<String> roles;
  final String location;

  factory ManagedEstateChoice.fromJson(Map<String, dynamic> json) =>
      ManagedEstateChoice(
        id: json['id'] as String,
        name: json['name'] as String,
        roles: (json['roles'] as List? ?? const []).whereType<String>().toList(
          growable: false,
        ),
        location: json['location'] as String? ?? '',
      );
}

class EstateStaffInvitationRecord {
  const EstateStaffInvitationRecord({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
  });
  final String id, email, role, status, createdBy, createdAt, expiresAt;
  final String? acceptedAt;
  factory EstateStaffInvitationRecord.fromJson(Map<String, dynamic> json) =>
      EstateStaffInvitationRecord(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        expiresAt: json['expiresAt'] as String? ?? '',
        acceptedAt: json['acceptedAt'] as String?,
      );
}

class ResidentAccessRequest {
  const ResidentAccessRequest({
    required this.id,
    required this.applicantName,
    required this.submittedAt,
    required this.status,
    this.applicantEmail,
    this.applicantPhone,
    this.propertyCode,
    this.relationship,
    this.note,
    this.decisionReason,
  });
  final String id;
  final String applicantName;
  final String submittedAt;
  final String status;
  final String? applicantEmail;
  final String? applicantPhone;
  final String? propertyCode;
  final String? relationship;
  final String? note;
  final String? decisionReason;

  factory ResidentAccessRequest.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'] is Map<String, dynamic>
        ? json['applicant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final property = json['property'] is Map<String, dynamic>
        ? json['property'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ResidentAccessRequest(
      id: json['id'] as String,
      applicantName:
          applicant['displayName'] as String? ?? 'Resident applicant',
      applicantEmail: applicant['emailNormalized'] as String?,
      applicantPhone: applicant['phone'] as String?,
      propertyCode: property['code'] as String?,
      relationship: json['relationship'] as String?,
      note: json['note'] as String?,
      submittedAt: json['submittedAt'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      decisionReason: json['decisionReason'] as String?,
    );
  }
}

class JoinRequestPropertyChoice {
  const JoinRequestPropertyChoice({
    required this.id,
    required this.code,
    required this.type,
    required this.structureLabels,
    this.unitNumber,
  });
  final String id;
  final String code;
  final String type;
  final String? unitNumber;
  final List<String> structureLabels;

  factory JoinRequestPropertyChoice.fromJson(Map<String, dynamic> json) =>
      JoinRequestPropertyChoice(
        id: json['id'] as String,
        code: json['code'] as String,
        type: json['propertyType'] as String,
        unitNumber: json['unitNumber'] as String?,
        structureLabels: (json['structure'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((node) => '${node['type']}: ${node['name']}')
            .toList(growable: false),
      );
}

class ResidentJoinRequestStatusEntry {
  const ResidentJoinRequestStatusEntry({
    required this.id,
    required this.estateId,
    required this.estateName,
    required this.status,
    required this.submittedAt,
    this.propertyCode,
    this.relationship,
    this.decisionReason,
  });
  final String id;
  final String estateId;
  final String estateName;
  final String status;
  final String submittedAt;
  final String? propertyCode;
  final String? relationship;
  final String? decisionReason;

  factory ResidentJoinRequestStatusEntry.fromJson(Map<String, dynamic> json) {
    final estate = json['estate'] as Map<String, dynamic>? ?? const {};
    final property = json['property'] as Map<String, dynamic>?;
    return ResidentJoinRequestStatusEntry(
      id: json['id'] as String,
      estateId: estate['id'] as String? ?? '',
      estateName: estate['name'] as String? ?? 'Estate',
      status: json['status'] as String? ?? 'pending',
      submittedAt: json['submittedAt'] as String? ?? '',
      propertyCode: property?['code'] as String?,
      relationship: json['relationship'] as String?,
      decisionReason: json['decisionReason'] as String?,
    );
  }
}

class LandlordPortfolioRecord {
  const LandlordPortfolioRecord({
    required this.id,
    required this.propertyCode,
    required this.propertyType,
    required this.ownershipShare,
    required this.occupancyCount,
    required this.status,
    this.unitNumber,
    this.address,
    this.currentTenancy,
  });
  final String id;
  final String propertyCode;
  final String propertyType;
  final String ownershipShare;
  final int occupancyCount;
  final String status;
  final String? unitNumber;
  final String? address;
  final Map<String, dynamic>? currentTenancy;

  factory LandlordPortfolioRecord.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>? ?? const {};
    final ownership = json['ownership'] as Map<String, dynamic>? ?? const {};
    final occupancy = json['occupancy'] as Map<String, dynamic>? ?? const {};
    return LandlordPortfolioRecord(
      id: json['id'] as String,
      propertyCode: property['code'] as String? ?? '',
      propertyType: property['propertyType'] as String? ?? 'Property',
      status: property['status'] as String? ?? 'active',
      unitNumber: property['unitNumber'] as String?,
      address: property['address'] as String?,
      ownershipShare: ownership['share'] as String? ?? '',
      occupancyCount: occupancy['currentOccupantCount'] as int? ?? 0,
      currentTenancy: json['currentTenancy'] as Map<String, dynamic>?,
    );
  }
}

class LandlordMaintenanceUpdateRecord {
  const LandlordMaintenanceUpdateRecord({
    required this.body,
    required this.occurredAt,
  });
  final String body;
  final String occurredAt;

  factory LandlordMaintenanceUpdateRecord.fromJson(Map<String, dynamic> json) =>
      LandlordMaintenanceUpdateRecord(
        body: json['body'] as String? ?? '',
        occurredAt: json['occurredAt'] as String? ?? '',
      );
}

class LandlordMaintenanceRecord {
  const LandlordMaintenanceRecord({
    required this.id,
    required this.reference,
    required this.propertyLabel,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    required this.residentVisibleUpdates,
  });

  final String id;
  final String reference;
  final String propertyLabel;
  final String category;
  final String priority;
  final String description;
  final String status;
  final String submittedAt;
  final String updatedAt;
  final List<LandlordMaintenanceUpdateRecord> residentVisibleUpdates;

  factory LandlordMaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      LandlordMaintenanceRecord(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        propertyLabel: json['propertyLabel'] as String? ?? 'Property',
        category: json['category'] as String? ?? 'other',
        priority: json['priority'] as String? ?? 'normal',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        submittedAt: json['submittedAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        residentVisibleUpdates:
            (json['residentVisibleUpdates'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(LandlordMaintenanceUpdateRecord.fromJson)
                .toList(growable: false),
      );
}

class TenantTenancyRecord {
  const TenantTenancyRecord({
    required this.id,
    required this.estateId,
    required this.propertyId,
    required this.estateName,
    required this.propertyCode,
    required this.propertyType,
    required this.landlordName,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.dueDay,
    required this.effectiveFrom,
    this.effectiveTo,
  });
  final String id;
  final String estateId;
  final String propertyId;
  final String estateName;
  final String propertyCode;
  final String propertyType;
  final String landlordName;
  final String amount;
  final String currency;
  final String frequency;
  final int dueDay;
  final String effectiveFrom;
  final String? effectiveTo;

  factory TenantTenancyRecord.fromJson(Map<String, dynamic> json) {
    final estate = json['estate'] as Map<String, dynamic>? ?? const {};
    final property = json['property'] as Map<String, dynamic>? ?? const {};
    final rent = json['rent'] as Map<String, dynamic>? ?? const {};
    return TenantTenancyRecord(
      id: json['id'] as String,
      estateId: estate['id'] as String? ?? '',
      propertyId: property['id'] as String? ?? '',
      estateName: estate['name'] as String? ?? 'Estate',
      propertyCode: property['code'] as String? ?? 'Property',
      propertyType: property['propertyType'] as String? ?? 'Home',
      landlordName: json['landlordDisplayName'] as String? ?? 'Landlord',
      amount: rent['amount'] as String? ?? '0.00',
      currency: rent['currency'] as String? ?? 'NGN',
      frequency: rent['frequency'] as String? ?? 'monthly',
      dueDay: rent['dueDay'] as int? ?? 1,
      effectiveFrom: json['effectiveFrom'] as String? ?? '',
      effectiveTo: json['effectiveTo'] as String?,
    );
  }
}

class ResidentVisitorPassRecord {
  const ResidentVisitorPassRecord({
    required this.id,
    required this.propertyId,
    required this.propertyLabel,
    required this.visitorName,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    required this.uses,
    required this.useLimit,
    this.vehicleSummary,
  });
  final String id;
  final String propertyId;
  final String propertyLabel;
  final String visitorName;
  final DateTime validFrom;
  final DateTime validUntil;
  final String status;
  final int uses;
  final int useLimit;
  final String? vehicleSummary;

  factory ResidentVisitorPassRecord.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>? ?? const {};
    return ResidentVisitorPassRecord(
      id: json['id'] as String? ?? json['passId'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      propertyLabel: [
        property['code'],
        property['unitNumber'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      visitorName: json['visitorDisplayName'] as String? ?? '',
      validFrom:
          DateTime.tryParse(json['validFrom'] as String? ?? '') ??
          DateTime.now(),
      validUntil:
          DateTime.tryParse(json['validUntil'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'active',
      uses: json['useCount'] as int? ?? 0,
      useLimit: json['allowedUses'] as int? ?? 1,
      vehicleSummary: json['vehicleSummary'] as String?,
    );
  }
}

class ResidentVisitorPropertyRecord {
  const ResidentVisitorPropertyRecord({required this.id, required this.label});
  final String id;
  final String label;
  factory ResidentVisitorPropertyRecord.fromJson(Map<String, dynamic> json) =>
      ResidentVisitorPropertyRecord(
        id: json['id'] as String,
        label: [
          json['code'],
          json['unitNumber'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      );
}

class EstateGateRecord {
  const EstateGateRecord({
    required this.id,
    required this.estateId,
    required this.code,
    required this.name,
  });
  final String id;
  final String estateId;
  final String code;
  final String name;
  factory EstateGateRecord.fromJson(Map<String, dynamic> json) =>
      EstateGateRecord(
        id: json['id'] as String,
        estateId: json['estateId'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
      );
}

class EstateStructureRecord {
  const EstateStructureRecord({
    required this.id,
    required this.type,
    required this.name,
    this.code,
    this.parentIds = const [],
    this.parentNames = const [],
    this.linkedPropertyCount = 0,
    this.status = 'active',
    this.buildingType,
    this.floorCount,
  });
  final String id, type, name, status;
  final String? code, buildingType;
  final List<String> parentIds, parentNames;
  final int linkedPropertyCount;
  final int? floorCount;
  factory EstateStructureRecord.fromJson(Map<String, dynamic> json) =>
      EstateStructureRecord(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        parentIds: (json['parentIds'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        parentNames: (json['parentNames'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        linkedPropertyCount: json['linkedPropertyCount'] as int? ?? 0,
        status: json['status'] as String? ?? 'active',
        buildingType: json['buildingType'] as String?,
        floorCount: json['floorCount'] as int?,
      );
}

class EstateChargeVersionRecord {
  const EstateChargeVersionRecord({
    required this.id,
    required this.versionNumber,
    required this.name,
    required this.category,
    required this.amount,
    required this.currency,
    required this.recurrence,
    required this.effectiveFrom,
    required this.dueDay,
    required this.graceDays,
    required this.appliesTo,
    required this.status,
    this.description,
    this.effectiveTo,
    this.propertyId,
    this.propertyType,
  });
  final String id,
      name,
      category,
      amount,
      currency,
      recurrence,
      effectiveFrom,
      appliesTo,
      status;
  final String? description, effectiveTo, propertyId, propertyType;
  final int versionNumber, dueDay, graceDays;
  factory EstateChargeVersionRecord.fromJson(Map<String, dynamic> json) =>
      EstateChargeVersionRecord(
        id: json['id'] as String? ?? '',
        versionNumber: json['versionNumber'] as int? ?? 1,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        amount: json['amount'] as String? ?? '0.00',
        currency: json['currency'] as String? ?? 'NGN',
        recurrence: json['recurrence'] as String? ?? 'one_time',
        effectiveFrom: json['effectiveFrom'] as String? ?? '',
        effectiveTo: json['effectiveTo'] as String?,
        dueDay: json['dueDay'] as int? ?? 1,
        graceDays: json['graceDays'] as int? ?? 0,
        appliesTo: json['appliesTo'] as String? ?? 'estate',
        propertyId: json['propertyId'] as String?,
        propertyType: json['propertyType'] as String?,
        status: json['status'] as String? ?? 'draft',
        description: json['description'] as String?,
      );
}

class EstateChargeRecord {
  const EstateChargeRecord({
    required this.id,
    required this.estateId,
    required this.code,
    required this.versions,
  });
  final String id, estateId, code;
  final List<EstateChargeVersionRecord> versions;
  factory EstateChargeRecord.fromJson(Map<String, dynamic> json) =>
      EstateChargeRecord(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        versions: (json['versions'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateChargeVersionRecord.fromJson)
            .toList(growable: false),
      );
}

class ManagedEstatePropertyChoice {
  const ManagedEstatePropertyChoice({
    required this.id,
    required this.code,
    required this.propertyType,
    required this.status,
  });
  final String id, code, propertyType, status;
  factory ManagedEstatePropertyChoice.fromJson(Map<String, dynamic> json) =>
      ManagedEstatePropertyChoice(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        propertyType: json['propertyType'] as String? ?? 'Property',
        status: json['status'] as String? ?? 'active',
      );
}

class EstateInvoiceDraftRecord {
  const EstateInvoiceDraftRecord({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.chargeCode,
    required this.description,
    required this.propertyCode,
    required this.payerName,
    required this.currency,
    required this.total,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    this.createdAt,
    this.balance,
    this.settlements = const [],
  });
  final String id,
      invoiceNumber,
      status,
      chargeCode,
      description,
      propertyCode,
      payerName,
      currency,
      total,
      periodStart,
      periodEnd,
      dueDate;
  final String? createdAt;
  final String? balance;
  final List<Map<String, dynamic>> settlements;
  factory EstateInvoiceDraftRecord.fromJson(Map<String, dynamic> json) =>
      EstateInvoiceDraftRecord(
        id: json['id'] as String? ?? '',
        invoiceNumber: json['invoiceNumber'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
        chargeCode: json['chargeCode'] as String? ?? '',
        description: json['description'] as String? ?? '',
        propertyCode: json['propertyCode'] as String? ?? '',
        payerName: json['payerName'] as String? ?? '',
        currency: json['currency'] as String? ?? 'NGN',
        total: json['total'] as String? ?? '0.00',
        periodStart: json['periodStart'] as String? ?? '',
        periodEnd: json['periodEnd'] as String? ?? '',
        dueDate: json['dueDate'] as String? ?? '',
        createdAt: json['createdAt'] as String?,
        balance: json['balance'] as String?,
        settlements: (json['settlements'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
}

class EstateSettlementPolicyRecord {
  const EstateSettlementPolicyRecord({
    required this.id,
    required this.currency,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.paymentReferenceFormat,
    required this.status,
  });
  final String id,
      currency,
      bankName,
      accountName,
      accountNumber,
      paymentReferenceFormat,
      status;
  factory EstateSettlementPolicyRecord.fromJson(Map<String, dynamic> json) =>
      EstateSettlementPolicyRecord(
        id: json['id'] as String? ?? '',
        currency: json['currency'] as String? ?? 'NGN',
        bankName: json['bankName'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        paymentReferenceFormat: json['paymentReferenceFormat'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
      );
}

class EstateFacilityRecord {
  const EstateFacilityRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.description,
    required this.location,
    required this.capacity,
    required this.durationMinutes,
    required this.openingTime,
    required this.closingTime,
    required this.bookingLeadHours,
    required this.approvalMode,
    required this.policyVersion,
  });
  final String id,
      code,
      name,
      category,
      description,
      location,
      openingTime,
      closingTime,
      approvalMode;
  final int capacity, durationMinutes, bookingLeadHours, policyVersion;
  factory EstateFacilityRecord.fromJson(Map<String, dynamic> json) =>
      EstateFacilityRecord(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        capacity: json['capacity'] as int? ?? 1,
        durationMinutes: json['durationMinutes'] as int? ?? 60,
        openingTime: json['openingTime'] as String? ?? '08:00',
        closingTime: json['closingTime'] as String? ?? '18:00',
        bookingLeadHours: json['bookingLeadHours'] as int? ?? 2,
        approvalMode: json['approvalMode'] as String? ?? 'manual',
        policyVersion: json['policyVersion'] as int? ?? 1,
      );
}

class EstateFacilityBookingRecord {
  const EstateFacilityBookingRecord({
    required this.id,
    required this.reference,
    required this.facilityId,
    required this.facilityName,
    required this.propertyCode,
    required this.requesterName,
    required this.startsAt,
    required this.endsAt,
    required this.attendeeCount,
    required this.status,
    required this.policyVersion,
    this.purpose,
  });
  final String id,
      reference,
      facilityId,
      facilityName,
      propertyCode,
      requesterName,
      startsAt,
      endsAt,
      status;
  final int attendeeCount, policyVersion;
  final String? purpose;
  factory EstateFacilityBookingRecord.fromJson(Map<String, dynamic> json) =>
      EstateFacilityBookingRecord(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        facilityId: json['facilityId'] as String? ?? '',
        facilityName: json['facilityName'] as String? ?? '',
        propertyCode: json['propertyCode'] as String? ?? '',
        requesterName: json['requesterName'] as String? ?? '',
        startsAt: json['startsAt'] as String? ?? '',
        endsAt: json['endsAt'] as String? ?? '',
        attendeeCount: json['attendeeCount'] as int? ?? 1,
        status: json['status'] as String? ?? 'pending_review',
        policyVersion: json['policyVersion'] as int? ?? 1,
        purpose: json['purpose'] as String?,
      );
}

class EstateSecurityIncidentRecord {
  const EstateSecurityIncidentRecord({
    required this.id,
    required this.reference,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    required this.reporterName,
    required this.reportedAt,
    required this.observedAt,
    this.statusHistory = const [],
    this.evidence = const [],
    this.locationDescription,
  });
  final String id,
      reference,
      category,
      priority,
      description,
      status,
      reporterName,
      reportedAt,
      observedAt;
  final String? locationDescription;
  final List<EstateSecurityIncidentHistoryRecord> statusHistory;
  final List<EstateSecurityIncidentEvidenceRecord> evidence;
  factory EstateSecurityIncidentRecord.fromJson(Map<String, dynamic> json) =>
      EstateSecurityIncidentRecord(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        category: json['category'] as String? ?? '',
        priority: json['priority'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'reported',
        reporterName: json['reporterName'] as String? ?? '',
        reportedAt: json['reportedAt'] as String? ?? '',
        observedAt: json['observedAt'] as String? ?? '',
        statusHistory: (json['statusHistory'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateSecurityIncidentHistoryRecord.fromJson)
            .toList(growable: false),
        evidence: (json['evidence'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateSecurityIncidentEvidenceRecord.fromJson)
            .toList(growable: false),
        locationDescription: json['locationDescription'] as String?,
      );
}

class EstateSecurityIncidentEvidenceRecord {
  const EstateSecurityIncidentEvidenceRecord({
    required this.id,
    required this.incidentId,
    required this.displayName,
    required this.contentType,
    required this.byteSize,
    required this.uploadedAt,
  });

  final String id;
  final String incidentId;
  final String displayName;
  final String contentType;
  final int byteSize;
  final DateTime uploadedAt;

  factory EstateSecurityIncidentEvidenceRecord.fromJson(
    Map<String, dynamic> json,
  ) => EstateSecurityIncidentEvidenceRecord(
    id: json['id'] as String? ?? '',
    incidentId: json['incidentId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Incident evidence',
    contentType: json['contentType'] as String? ?? 'application/octet-stream',
    byteSize: json['byteSize'] as int? ?? 0,
    uploadedAt:
        DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class EstateSecurityIncidentHistoryRecord {
  const EstateSecurityIncidentHistoryRecord({
    required this.toStatus,
    required this.occurredAt,
    this.fromStatus,
  });

  final String? fromStatus;
  final String toStatus;
  final String occurredAt;

  factory EstateSecurityIncidentHistoryRecord.fromJson(
    Map<String, dynamic> json,
  ) => EstateSecurityIncidentHistoryRecord(
    fromStatus: json['fromStatus'] as String?,
    toStatus: json['toStatus'] as String? ?? 'reported',
    occurredAt: json['occurredAt'] as String? ?? '',
  );
}

class EstateFacilitySlotRecord {
  const EstateFacilitySlotRecord({
    required this.startsAt,
    required this.endsAt,
    required this.remainingCapacity,
    required this.policyVersion,
  });
  final String startsAt, endsAt;
  final int remainingCapacity, policyVersion;
  factory EstateFacilitySlotRecord.fromJson(Map<String, dynamic> json) =>
      EstateFacilitySlotRecord(
        startsAt: json['startsAt'] as String? ?? '',
        endsAt: json['endsAt'] as String? ?? '',
        remainingCapacity: json['remainingCapacity'] as int? ?? 0,
        policyVersion: json['policyVersion'] as int? ?? 1,
      );
}

class GateCurrentVisitorRecord {
  const GateCurrentVisitorRecord({
    required this.visitId,
    required this.visitorName,
    required this.propertyLabel,
    required this.hostDisplayName,
    required this.checkedInAt,
    this.vehicleSummary,
  });
  final String visitId;
  final String visitorName;
  final String propertyLabel;
  final String hostDisplayName;
  final String checkedInAt;
  final String? vehicleSummary;
  factory GateCurrentVisitorRecord.fromJson(Map<String, dynamic> json) =>
      GateCurrentVisitorRecord(
        visitId: json['visitId'] as String? ?? '',
        visitorName: json['visitorName'] as String? ?? '',
        propertyLabel: json['propertyLabel'] as String? ?? '',
        hostDisplayName: json['hostDisplayName'] as String? ?? '',
        checkedInAt: json['checkedInAt'] as String? ?? '',
        vehicleSummary: json['vehicleSummary'] as String?,
      );
}

class GateExpectedVisitorRecord {
  const GateExpectedVisitorRecord({
    required this.visitorName,
    required this.propertyLabel,
    required this.hostDisplayName,
    required this.validUntil,
    this.vehicleSummary,
  });
  final String visitorName;
  final String propertyLabel;
  final String hostDisplayName;
  final String validUntil;
  final String? vehicleSummary;

  factory GateExpectedVisitorRecord.fromJson(Map<String, dynamic> json) =>
      GateExpectedVisitorRecord(
        visitorName: json['visitorName'] as String? ?? '',
        propertyLabel: json['propertyLabel'] as String? ?? '',
        hostDisplayName: json['hostDisplayName'] as String? ?? '',
        validUntil: json['validUntil'] as String? ?? '',
        vehicleSummary: json['vehicleSummary'] as String?,
      );
}

class EstateGateAccessEventRecord {
  const EstateGateAccessEventRecord({
    required this.id,
    required this.estateId,
    required this.gateId,
    required this.eventKind,
    required this.occurredAt,
    required this.staffUserId,
    this.propertyId,
    this.passId,
    this.visitId,
    this.reasonCode,
    this.propertyLabel,
  });
  final String id;
  final String estateId;
  final String gateId;
  final String eventKind;
  final String occurredAt;
  final String staffUserId;
  final String? propertyId;
  final String? passId;
  final String? visitId;
  final String? reasonCode;
  final String? propertyLabel;

  factory EstateGateAccessEventRecord.fromJson(Map<String, dynamic> json) =>
      EstateGateAccessEventRecord(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        gateId: json['gateId'] as String? ?? '',
        eventKind: json['eventKind'] as String? ?? '',
        occurredAt: json['occurredAt'] as String? ?? '',
        staffUserId: json['staffUserId'] as String? ?? '',
        propertyId: json['propertyId'] as String?,
        passId: json['passId'] as String?,
        visitId: json['visitId'] as String?,
        reasonCode: json['reasonCode'] as String?,
        propertyLabel: json['propertyLabel'] as String?,
      );
}

class EstateSecurityContactRecord {
  const EstateSecurityContactRecord({
    required this.id,
    required this.label,
    required this.displayName,
    required this.phoneDisplay,
  });
  final String id;
  final String label;
  final String displayName;
  final String phoneDisplay;

  factory EstateSecurityContactRecord.fromJson(Map<String, dynamic> json) =>
      EstateSecurityContactRecord(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        phoneDisplay: json['phoneDisplay'] as String? ?? '',
      );
}

class ResidentMaintenanceRecord {
  const ResidentMaintenanceRecord({
    required this.id,
    required this.reference,
    required this.category,
    required this.priority,
    required this.description,
    required this.status,
    required this.propertyLabel,
    required this.submittedAt,
    required this.residentVisibleUpdates,
  });
  final String id;
  final String reference;
  final String category;
  final String priority;
  final String description;
  final String status;
  final String propertyLabel;
  final String submittedAt;
  final List<ResidentMaintenanceUpdateRecord> residentVisibleUpdates;

  factory ResidentMaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      ResidentMaintenanceRecord(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        priority: json['priority'] as String? ?? 'normal',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        propertyLabel: json['propertyLabel'] as String? ?? 'Property',
        submittedAt: json['submittedAt'] as String? ?? '',
        residentVisibleUpdates:
            (json['residentVisibleUpdates'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(ResidentMaintenanceUpdateRecord.fromJson)
                .toList(growable: false),
      );
}

class ResidentMaintenanceUpdateRecord {
  const ResidentMaintenanceUpdateRecord({
    required this.body,
    required this.occurredAt,
  });
  final String body;
  final String occurredAt;
  factory ResidentMaintenanceUpdateRecord.fromJson(Map<String, dynamic> json) =>
      ResidentMaintenanceUpdateRecord(
        body: json['body'] as String? ?? '',
        occurredAt: json['occurredAt'] as String? ?? '',
      );
}

class EstateMaintenanceQueueItem {
  const EstateMaintenanceQueueItem({
    required this.id,
    required this.estateId,
    required this.propertyId,
    required this.reference,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.propertyLabel,
    required this.requesterDisplayName,
    required this.submittedAt,
    required this.allowedCommands,
    required this.residentVisibleUpdates,
    this.assigneeUserId,
    this.assigneeDisplayName,
  });
  final String id;
  final String estateId;
  final String propertyId;
  final String reference;
  final String category;
  final String priority;
  final String status;
  final String description;
  final String propertyLabel;
  final String requesterDisplayName;
  final String submittedAt;
  final String? assigneeUserId;
  final String? assigneeDisplayName;
  final List<String> allowedCommands;
  final List<ResidentMaintenanceUpdateRecord> residentVisibleUpdates;

  factory EstateMaintenanceQueueItem.fromJson(Map<String, dynamic> json) =>
      EstateMaintenanceQueueItem(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        propertyId: json['propertyId'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        priority: json['priority'] as String? ?? 'normal',
        status: json['status'] as String? ?? 'submitted',
        description: json['description'] as String? ?? '',
        propertyLabel: json['propertyLabel'] as String? ?? 'Property',
        requesterDisplayName:
            json['requesterDisplayName'] as String? ?? 'Resident',
        submittedAt: json['submittedAt'] as String? ?? '',
        assigneeUserId: json['assigneeUserId'] as String?,
        assigneeDisplayName: json['assigneeDisplayName'] as String?,
        allowedCommands: (json['allowedCommands'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        residentVisibleUpdates:
            (json['residentVisibleUpdates'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(ResidentMaintenanceUpdateRecord.fromJson)
                .toList(growable: false),
      );
}

class OwnershipReviewRecord {
  const OwnershipReviewRecord({
    required this.id,
    required this.ownerName,
    required this.propertyCode,
    required this.propertyType,
    required this.share,
    required this.effectiveFrom,
    required this.evidenceNote,
    required this.createdAt,
  });
  final String id;
  final String ownerName;
  final String propertyCode;
  final String propertyType;
  final String share;
  final String effectiveFrom;
  final String evidenceNote;
  final String createdAt;

  factory OwnershipReviewRecord.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>? ?? const {};
    final property = json['property'] as Map<String, dynamic>? ?? const {};
    return OwnershipReviewRecord(
      id: json['id'] as String? ?? '',
      ownerName: owner['displayName'] as String? ?? 'Property owner',
      propertyCode: property['code'] as String? ?? 'Property',
      propertyType: property['propertyType'] as String? ?? 'Home',
      share: json['share'] as String? ?? '0.00',
      effectiveFrom: json['effectiveFrom'] as String? ?? '',
      evidenceNote: json['evidenceNote'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class TenancyApprovalRecord {
  const TenancyApprovalRecord({
    required this.id,
    required this.propertyCode,
    required this.tenantName,
    required this.payeeName,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.dueDay,
    required this.effectiveFrom,
    required this.termsNote,
  });
  final String id;
  final String propertyCode;
  final String tenantName;
  final String payeeName;
  final String amount;
  final String currency;
  final String frequency;
  final int dueDay;
  final String effectiveFrom;
  final String? termsNote;

  factory TenancyApprovalRecord.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>? ?? const {};
    final tenant = json['tenant'] as Map<String, dynamic>? ?? const {};
    final payee = json['payee'] as Map<String, dynamic>? ?? const {};
    final rent = json['rent'] as Map<String, dynamic>? ?? const {};
    return TenancyApprovalRecord(
      id: json['id'] as String? ?? '',
      propertyCode: property['code'] as String? ?? 'Property',
      tenantName: tenant['displayName'] as String? ?? 'Tenant',
      payeeName: payee['displayName'] as String? ?? 'Landlord',
      amount: rent['amount'] as String? ?? '0.00',
      currency: rent['currency'] as String? ?? 'NGN',
      frequency: rent['frequency'] as String? ?? 'monthly',
      dueDay: rent['dueDay'] as int? ?? 1,
      effectiveFrom: json['effectiveFrom'] as String? ?? '',
      termsNote: json['termsNote'] as String?,
    );
  }
}

class EstateStaffChoice {
  const EstateStaffChoice({required this.userId, required this.displayName});
  final String userId;
  final String displayName;
  factory EstateStaffChoice.fromJson(Map<String, dynamic> json) =>
      EstateStaffChoice(
        userId: json['userId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Estate staff',
      );
}

class EstateMaintenanceQueue {
  const EstateMaintenanceQueue({
    required this.items,
    required this.assignableStaff,
    required this.total,
    this.page = 1,
    this.pageSize = 50,
    this.totalPages = 1,
  });
  final List<EstateMaintenanceQueueItem> items;
  final List<EstateStaffChoice> assignableStaff;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  factory EstateMaintenanceQueue.fromJson(Map<String, dynamic> json) =>
      EstateMaintenanceQueue(
        items: (json['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateMaintenanceQueueItem.fromJson)
            .toList(growable: false),
        assignableStaff: (json['assignableStaff'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EstateStaffChoice.fromJson)
            .toList(growable: false),
        total: json['total'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 50,
        totalPages: json['totalPages'] as int? ?? 1,
      );
}

class RentSchedulePreviewItem {
  const RentSchedulePreviewItem({
    required this.tenancyId,
    required this.propertyCode,
    required this.tenantName,
    required this.rentPayeeName,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.dueDate,
    this.unitNumber,
  });
  final String tenancyId;
  final String propertyCode;
  final String tenantName;
  final String rentPayeeName;
  final String amount;
  final String currency;
  final String frequency;
  final String dueDate;
  final String? unitNumber;

  factory RentSchedulePreviewItem.fromJson(Map<String, dynamic> json) =>
      RentSchedulePreviewItem(
        tenancyId: json['tenancyId'] as String? ?? '',
        propertyCode: json['propertyCode'] as String? ?? '',
        unitNumber: json['unitNumber'] as String?,
        tenantName: json['tenantName'] as String? ?? 'Tenant',
        rentPayeeName: json['rentPayeeName'] as String? ?? 'Landlord',
        amount: json['amount'] as String? ?? '0.00',
        currency: json['currency'] as String? ?? '',
        frequency: json['frequency'] as String? ?? '',
        dueDate: json['dueDate'] as String? ?? '',
      );
}

class RentSchedulePreview {
  const RentSchedulePreview({required this.period, required this.items});
  final String period;
  final List<RentSchedulePreviewItem> items;

  factory RentSchedulePreview.fromJson(Map<String, dynamic> json) =>
      RentSchedulePreview(
        period: json['period'] as String? ?? '',
        items: (json['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RentSchedulePreviewItem.fromJson)
            .toList(growable: false),
      );
}

class OutstandingIssuedInvoiceSummary {
  const OutstandingIssuedInvoiceSummary({
    required this.currency,
    required this.count,
    required this.total,
  });
  final String currency;
  final int count;
  final String total;

  factory OutstandingIssuedInvoiceSummary.fromJson(Map<String, dynamic> json) =>
      OutstandingIssuedInvoiceSummary(
        currency: json['currency'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        total: json['total'] as String? ?? '0.00',
      );
}

class EstateManagerDashboardSummary {
  const EstateManagerDashboardSummary({
    required this.propertyTotal,
    required this.occupiedProperties,
    required this.vacantProperties,
    required this.residentMemberships,
    required this.pendingAccessRequests,
    required this.pendingOwnershipReviews,
    required this.activeTenancies,
    required this.pendingTenancies,
    required this.outstandingIssuedInvoices,
    required this.asOf,
  });
  final int propertyTotal;
  final int occupiedProperties;
  final int vacantProperties;
  final int residentMemberships;
  final int pendingAccessRequests;
  final int pendingOwnershipReviews;
  final int activeTenancies;
  final int pendingTenancies;
  final List<OutstandingIssuedInvoiceSummary> outstandingIssuedInvoices;
  final String asOf;

  factory EstateManagerDashboardSummary.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? const {};
    final residents = json['residents'] as Map<String, dynamic>? ?? const {};
    final requests =
        json['accessRequests'] as Map<String, dynamic>? ?? const {};
    final reviews =
        json['ownershipReviews'] as Map<String, dynamic>? ?? const {};
    final tenancies = json['tenancies'] as Map<String, dynamic>? ?? const {};
    return EstateManagerDashboardSummary(
      propertyTotal: properties['total'] as int? ?? 0,
      occupiedProperties: properties['occupied'] as int? ?? 0,
      vacantProperties: properties['vacant'] as int? ?? 0,
      residentMemberships: residents['activeMemberships'] as int? ?? 0,
      pendingAccessRequests: requests['pending'] as int? ?? 0,
      pendingOwnershipReviews: reviews['pending'] as int? ?? 0,
      activeTenancies: tenancies['active'] as int? ?? 0,
      pendingTenancies: tenancies['pendingApproval'] as int? ?? 0,
      outstandingIssuedInvoices:
          (json['outstandingIssuedInvoices'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(OutstandingIssuedInvoiceSummary.fromJson)
              .toList(growable: false),
      asOf: json['asOf'] as String? ?? '',
    );
  }
}

class EstateAnnouncementRecord {
  const EstateAnnouncementRecord({
    required this.id,
    required this.estateId,
    required this.title,
    required this.body,
    required this.category,
    required this.audienceLabel,
    required this.status,
    required this.createdAt,
    this.publishedAt,
  });
  final String id, estateId, title, body, category, audienceLabel, status;
  final DateTime createdAt;
  final DateTime? publishedAt;

  factory EstateAnnouncementRecord.fromJson(Map<String, dynamic> json) =>
      EstateAnnouncementRecord(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        category: json['category'] as String? ?? 'normal',
        audienceLabel: json['audienceLabel'] as String? ?? 'All residents',
        status: json['status'] as String? ?? 'draft',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      );
}

class ResidentAnnouncementRecord extends EstateAnnouncementRecord {
  const ResidentAnnouncementRecord({
    required super.id,
    required super.estateId,
    required super.title,
    required super.body,
    required super.category,
    required super.audienceLabel,
    required super.status,
    required super.createdAt,
    super.publishedAt,
    required this.estateName,
    required this.read,
  });
  final String estateName;
  final bool read;

  factory ResidentAnnouncementRecord.fromJson(Map<String, dynamic> json) =>
      ResidentAnnouncementRecord(
        id: json['id'] as String? ?? '',
        estateId: json['estateId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        category: json['category'] as String? ?? 'normal',
        audienceLabel: json['audienceLabel'] as String? ?? 'All residents',
        status: json['status'] as String? ?? 'published',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        estateName: json['estateName'] as String? ?? '',
        read: json['read'] as bool? ?? false,
      );
}

abstract interface class EstateApplicationApiRepository
    implements EstateApplicationRepository {
  Future<List<EstateApplicationDocumentRecord>> loadMyApplicationDocuments();
  Future<EstateApplicationDocumentRecord> uploadMyApplicationDocument({
    required String category,
    required String fileName,
    required Uint8List bytes,
    required String idempotencyKey,
  });
  Future<Uint8List> downloadMyApplicationDocument(String documentId);
  Future<String> submitMyApplication();
  Future<EstateAccount?> restoreSession();
  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  });
  Future<EstateAccount> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<List<ManagedEstateChoice>> loadManagedEstates();
  Future<List<EstateStaffInvitationRecord>> loadStaffInvitations(
    String estateId,
  );
  Future<Map<String, dynamic>> createStaffInvitation({
    required String estateId,
    required String email,
    required String role,
  });
  Future<void> revokeStaffInvitation({
    required String estateId,
    required String invitationId,
  });
  Future<Map<String, dynamic>> acceptStaffInvitation({
    required String estateId,
    required String code,
  });
  Future<EstateTreasurySummary> loadTreasurySummary(String estateId);
  Future<List<EstatePayoutBeneficiaryRecord>> loadPayoutBeneficiaries(String estateId);
  Future<List<EstatePayoutRecord>> loadPayouts(String estateId);
  Future<void> createPayout({
    required String estateId,
    required String beneficiaryId,
    required String amount,
    required String purpose,
    required String idempotencyKey,
  });
  Future<void> decidePayout({required String estateId, required String payoutId, required String decision, String? note});
  Future<EstateManagerDashboardSummary> loadManagerDashboard(String estateId);
  Future<Map<String, dynamic>> loadEstateSettings(String estateId);
  Future<Map<String, dynamic>> updateEstateSettings({
    required String estateId,
    required Map<String, String> fields,
  });
  Future<RentSchedulePreview> loadRentSchedulePreview({
    required String estateId,
    required int year,
    required int month,
  });
  Future<List<EstateAnnouncementRecord>> loadEstateAnnouncements(
    String estateId,
  );
  Future<EstateAnnouncementRecord> createEstateAnnouncementDraft({
    required String estateId,
    required String title,
    required String body,
    required String priority,
  });
  Future<EstateAnnouncementRecord> publishEstateAnnouncement({
    required String estateId,
    required String announcementId,
  });
  Future<List<ResidentAnnouncementRecord>> loadMyAnnouncements();
  Future<void> markMyAnnouncementRead(String announcementId);
  Future<List<Map<String, dynamic>>> loadMyNotifications();
  Future<void> markEstateNotificationRead(String notificationId);
  Future<int> markAllEstateNotificationsRead();
  Future<List<OwnershipReviewRecord>> loadPendingOwnershipReviews(
    String estateId,
  );
  Future<void> decideOwnershipReview({
    required String estateId,
    required String ownershipId,
    required String decision,
    required String reason,
  });
  Future<List<TenancyApprovalRecord>> loadPendingTenancyApprovals(
    String estateId,
  );
  Future<void> createEstateTenancy({
    required String estateId,
    required String propertyId,
    required Map<String, dynamic> fields,
  });
  Future<void> approveTenancy({
    required String estateId,
    required String tenancyId,
    required String reason,
  });
  Future<List<ResidentAccessRequest>> loadResidentAccessRequests(
    String estateId,
  );
  Future<void> decideResidentAccessRequest({
    required String estateId,
    required String requestId,
    required String decision,
    String? reason,
  });
  Future<List<ManagedEstateChoice>> loadAvailableEstates();
  Future<List<ManagedEstateChoice>> loadMyEstates();
  Future<List<JoinRequestPropertyChoice>> loadJoinRequestProperties(
    String estateId,
  );
  Future<List<ResidentJoinRequestStatusEntry>> loadMyJoinRequestHistory();
  Future<void> submitResidentJoinRequest({
    required String estateId,
    String? propertyId,
    String? relationship,
    String? note,
  });
  Future<List<ManagedEstateChoice>> loadMyLandlordEstates();
  Future<List<LandlordPortfolioRecord>> loadLandlordPortfolio(String estateId);
  Future<List<LandlordMaintenanceRecord>> loadMyLandlordPropertyMaintenance({
    int page = 1,
    int pageSize = 25,
  });
  Future<List<TenantTenancyRecord>> loadMyTenancies();
  Future<List<ResidentVisitorPassRecord>> loadMyVisitorPasses(String estateId);
  Future<List<ResidentVisitorPropertyRecord>> loadMyVisitorProperties(
    String estateId,
  );
  Future<Map<String, dynamic>> createVisitorPass({
    required String estateId,
    required String propertyId,
    required String visitorName,
    required DateTime validFrom,
    required DateTime validUntil,
    required String vehicleSummary,
    required String idempotencyKey,
  });
  Future<void> revokeVisitorPass({
    required String estateId,
    required String passId,
    required String reason,
  });
  Future<List<EstateGateRecord>> loadMyGates(String estateId);
  Future<List<EstateGateRecord>> loadEstateGates(String estateId);
  Future<List<EstateStaffChoice>> loadSecurityOfficers(String estateId);
  Future<void> createEstateGate({
    required String estateId,
    required String code,
    required String name,
  });
  Future<void> assignGateOfficer({
    required String estateId,
    required String gateId,
    required String userId,
  });
  Future<List<EstateStructureRecord>> loadEstateStructure(String estateId);
  Future<void> createStructureNode({
    required String estateId,
    required String type,
    required String name,
    String? code,
    List<String> parentIds = const [],
  });
  Future<void> archiveStructureNode({
    required String estateId,
    required String nodeId,
  });
  Future<List<EstateChargeRecord>> loadEstateCharges(String estateId);
  Future<List<ManagedEstatePropertyChoice>> loadManagedEstatePropertyChoices(
    String estateId,
  );
  Future<void> createEstateCharge({
    required String estateId,
    required Map<String, dynamic> fields,
  });
  Future<void> createEstateChargeVersion({
    required String estateId,
    required String chargeId,
    required Map<String, dynamic> fields,
  });
  Future<void> activateEstateChargeVersion({
    required String estateId,
    required String chargeId,
    required String versionId,
  });
  Future<List<EstateInvoiceDraftRecord>> loadEstateInvoiceDrafts(
    String estateId,
  );
  Future<List<EstateSettlementPolicyRecord>> loadEstateSettlementPolicies(
    String estateId,
  );
  Future<void> createEstateSettlementPolicy({
    required String estateId,
    required Map<String, dynamic> fields,
  });
  Future<void> activateEstateSettlementPolicy({
    required String estateId,
    required String policyId,
  });
  Future<void> issueEstateInvoiceDraft({
    required String estateId,
    required String invoiceDraftId,
  });
  Future<void> recordEstateInvoiceSettlement({
    required String estateId,
    required String invoiceId,
    required Map<String, dynamic> fields,
  });
  Future<List<Map<String, dynamic>>> loadMyInvoiceRecords();
  Future<void> createEstateInvoiceDraft({
    required String estateId,
    required Map<String, dynamic> fields,
    required String idempotencyKey,
  });
  Future<List<EstateFacilityRecord>> loadEstateFacilities(String estateId);
  Future<List<EstateFacilityBookingRecord>> loadEstateFacilityBookings(
    String estateId,
  );
  Future<List<EstateSecurityIncidentRecord>> loadSecurityIncidents(
    String estateId,
  );
  Future<List<EstateSecurityIncidentRecord>> loadMySecurityIncidents(
    String estateId,
  );
  Future<List<EstateWalletRecord>> loadMyWallets();
  Future<EstateWalletRecord> provisionEstateWallet(String estateId);
  Future<Map<String, dynamic>> createWalletFundingIntent({
    required String estateId,
    required String amount,
    required String idempotencyKey,
  });
  Future<List<PropertyLocationRecord>> loadPropertyLocations(String estateId);
  Future<PropertyLocationRecord> capturePropertyLocation({
    required String estateId,
    required String propertyId,
    required String latitude,
    required String longitude,
    String? accuracyMeters,
    required String captureMethod,
    String? reason,
  });
  Future<PropertyLocationRecord> verifyPropertyLocation({
    required String estateId,
    required String propertyId,
    required String decision,
    String? reason,
  });
  Future<List<HouseholdMemberRecord>> loadMyHousehold();
  Future<List<HouseholdMemberRecord>> loadEstateHousehold(String estateId);
  Future<HouseholdMemberRecord> addHouseholdMember({
    required String estateId,
    required String propertyId,
    required String fullName,
    required String relationship,
    required String memberType,
    required String effectiveFrom,
    String? primaryUserId,
    String? dateOfBirth,
    String? phone,
    String? email,
    bool financialAccess = false,
  });
  Future<HouseholdMemberRecord> decideHouseholdMember({
    required String estateId,
    required String memberId,
    required String decision,
    String? note,
  });
  Future<HouseholdMemberRecord> endHouseholdMember({
    required String estateId,
    required String memberId,
    required String reason,
  });
  Future<Map<String, dynamic>> previewRecurringLevies(String estateId, {int months = 3});
  Future<Map<String, dynamic>> generateRecurringLevies(String estateId, {int months = 3});
  Future<Map<String, dynamic>> generateRentSchedule(String estateId, {String? from, int months = 3});
  Future<List<RentScheduleRecord>> loadRentSchedule(String estateId);
  Future<List<LandlordRentSummaryRecord>> loadLandlordRentSummary(String estateId);
  Future<Map<String, dynamic>> payRentSchedule({required String scheduleId, required String amount});
  Future<Map<String, dynamic>> creditDemoWallet(String intentId);
  Future<Map<String, dynamic>> payRentFromWallet({
    required String estateId,
    required String invoiceId,
    required String amount,
  });
  Future<EstateSecurityIncidentEvidenceRecord> uploadSecurityIncidentEvidence({
    required String estateId,
    required String incidentId,
    required String fileName,
    required Uint8List bytes,
  });
  Future<Uint8List> downloadSecurityIncidentEvidence({
    required String estateId,
    required String incidentId,
    required String evidenceId,
  });
  Future<void> createSecurityIncident({
    required String estateId,
    required Map<String, dynamic> fields,
  });
  Future<void> reviewSecurityIncident({
    required String estateId,
    required String incidentId,
    required String command,
    String? note,
  });
  Future<Map<String, dynamic>> loadExpensePolicy(String estateId);
  Future<Map<String, dynamic>> configureExpensePolicy({
    required String estateId,
    required Map<String, dynamic> policy,
  });
  Future<List<Map<String, dynamic>>> loadExpenseCategories(String estateId);
  Future<Map<String, dynamic>> createExpenseCategory({
    required String estateId,
    required String code,
    required String name,
  });
  Future<List<Map<String, dynamic>>> loadExpensePayees(String estateId);
  Future<Map<String, dynamic>> createExpensePayee({
    required String estateId,
    required Map<String, dynamic> payee,
  });
  Future<Map<String, dynamic>> verifyExpensePayee({
    required String estateId,
    required String payeeId,
  });
  Future<List<Map<String, dynamic>>> loadExpenseRequests(String estateId);
  Future<Map<String, dynamic>> createExpenseDraft({
    required String estateId,
    required Map<String, dynamic> expense,
    required String idempotencyKey,
  });
  Future<Map<String, dynamic>> submitExpense({
    required String estateId,
    required String expenseId,
  });
  Future<Map<String, dynamic>> decideExpense({
    required String estateId,
    required String expenseId,
    required String decision,
    String? reason,
  });
  Future<Map<String, dynamic>> reconcileExpense({
    required String estateId,
    required String expenseId,
    required Map<String, dynamic> settlement,
    required String idempotencyKey,
  });
  Future<List<Map<String, dynamic>>> loadEstateBudgets(String estateId);
  Future<Map<String, dynamic>> createEstateBudget({
    required String estateId,
    required Map<String, dynamic> budget,
  });
  Future<Map<String, dynamic>> submitEstateBudget({
    required String estateId,
    required String budgetId,
  });
  Future<Map<String, dynamic>> decideEstateBudget({
    required String estateId,
    required String budgetId,
    required String decision,
    String? reason,
  });
  Future<void> createEstateFacility({
    required String estateId,
    required Map<String, dynamic> fields,
  });
  Future<void> reviewEstateFacilityBooking({
    required String estateId,
    required String bookingId,
    required String command,
    String? reason,
  });
  Future<List<EstateFacilityRecord>> loadResidentEstateFacilities(
    String estateId,
  );
  Future<List<EstateFacilityBookingRecord>> loadMyFacilityBookings(
    String estateId,
  );
  Future<List<EstateFacilitySlotRecord>> loadFacilityAvailability({
    required String estateId,
    required String facilityId,
    required String date,
  });
  Future<void> createResidentFacilityBooking({
    required String estateId,
    required String facilityId,
    required Map<String, dynamic> fields,
    required String idempotencyKey,
  });
  Future<void> cancelResidentFacilityBooking({
    required String estateId,
    required String bookingId,
  });
  Future<List<GateCurrentVisitorRecord>> loadCurrentGateVisitors({
    required String estateId,
    required String gateId,
  });
  Future<List<GateExpectedVisitorRecord>> loadExpectedGateVisitors({
    required String estateId,
    required String gateId,
  });
  Future<Map<String, dynamic>> checkInGateVisitor({
    required String estateId,
    required String gateId,
    required String credential,
    required String idempotencyKey,
  });
  Future<Map<String, dynamic>> createGateManualAdmission({
    required String estateId,
    required String gateId,
    required String visitorName,
    required String propertyReference,
    required String reason,
    required String idempotencyKey,
  });
  Future<List<EstateGateAccessEventRecord>> loadGateAccessEvents({
    required String estateId,
    String? gateId,
    String? eventKind,
    int page = 1,
    int pageSize = 25,
  });
  Future<List<EstateSecurityContactRecord>> loadSecurityContacts(
    String estateId,
  );
  Future<void> checkOutGateVisitor({
    required String estateId,
    required String gateId,
    required String visitId,
  });
  Future<List<ResidentMaintenanceRecord>> loadMyMaintenanceRequests(
    String estateId,
  );
  Future<void> createMaintenanceRequest({
    required String estateId,
    required String propertyId,
    required String category,
    required String priority,
    required String description,
    required String idempotencyKey,
  });
  Future<EstateMaintenanceQueue> loadMaintenanceQueue(
    String estateId, {
    int page = 1,
    int pageSize = 50,
    String? status,
    String? search,
  });
  Future<void> reviewMaintenanceRequest({
    required String estateId,
    required String requestId,
    String? command,
    String? assigneeUserId,
    String? reason,
    String? resolutionSummary,
    String? residentUpdate,
    String? internalNote,
  });
}

class EstateApplicationDocumentRecord {
  const EstateApplicationDocumentRecord({
    required this.id,
    required this.category,
    required this.displayName,
    required this.contentType,
    required this.byteSize,
    required this.status,
    required this.uploadedAt,
  });
  final String id;
  final String category;
  final String displayName;
  final String contentType;
  final int byteSize;
  final String status;
  final DateTime uploadedAt;

  factory EstateApplicationDocumentRecord.fromJson(Map<String, dynamic> json) =>
      EstateApplicationDocumentRecord(
        id: json['id'] as String,
        category: json['category'] as String? ?? 'other',
        displayName: json['displayName'] as String? ?? 'Supporting document',
        contentType:
            json['contentType'] as String? ?? 'application/octet-stream',
        byteSize: json['byteSize'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        uploadedAt:
            DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class EstateApiException implements Exception {
  const EstateApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Authenticated API repository for the standalone estate backend.
class EstateApplicationApiClient implements EstateApplicationApiRepository {
  EstateApplicationApiClient({http.Client? client})
    : _client = client ?? http.Client();

  final Map<String, Map<String, dynamic>> _issuedVisitorCredentials = {};
  String? _currentResidentEstateId;
  String? get currentResidentEstateId => _currentResidentEstateId;

  static const _compiledBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4100/api/v1',
  );
  static String get _baseUrl => runtimeApiBaseUrl() ?? _compiledBaseUrl;
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'estate.accessToken';
  static const _refreshKey = 'estate.refreshToken';
  final http.Client _client;
  String? _webAccessToken;
  String? _webRefreshToken;
  String? _applicationId;
  String? _applicationCode;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    String? accessToken,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final request = http.Request(method, _uri(path))..headers.addAll(headers);
    if (additionalHeaders != null) request.headers.addAll(additionalHeaders);
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(await _client.send(request));
  }

  Future<Map<String, dynamic>> _json(
    Future<http.Response> responseFuture,
  ) async {
    final response = await responseFuture;
    final Object? decoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'The estate service could not complete the request.';
      if (decoded is Map<String, dynamic>) {
        final rawMessage = decoded['message'];
        if (rawMessage is String) message = rawMessage;
        if (rawMessage is List && rawMessage.isNotEmpty) {
          message = rawMessage.first.toString();
        }
        if (decoded['code'] is String) {
          if (rawMessage == null) message = decoded['code'] as String;
        }
      }
      throw EstateApiException(message, statusCode: response.statusCode);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<String?> _readAccessToken() async {
    if (!kIsWeb) return _storage.read(key: _accessKey);
    _webAccessToken ??= sharedAccessToken();
    return _webAccessToken;
  }

  Future<String?> _readRefreshToken() async {
    if (!kIsWeb) return _storage.read(key: _refreshKey);
    _webRefreshToken ??= sharedRefreshToken();
    return _webRefreshToken;
  }

  Future<void> _saveTokens(Map<String, dynamic> response) async {
    final access = response['accessToken'] as String?;
    final refresh = response['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw const EstateApiException(
        'The service returned an invalid session.',
      );
    }
    if (kIsWeb) {
      _webAccessToken = access;
      _webRefreshToken = refresh;
    } else {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    }
  }

  Future<void> _clearTokens() async {
    if (kIsWeb) {
      _webAccessToken = null;
      _webRefreshToken = null;
      clearSharedSession();
    } else {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    await _json(
      _send(
        'POST',
        '/auth/register',
        body: {
          'email': email.trim(),
          'displayName': displayName.trim(),
          'password': password,
        },
      ),
    );
  }

  @override
  Future<List<EstateFacilityRecord>> loadResidentEstateFacilities(
    String estateId,
  ) => loadEstateFacilities(estateId);

  @override
  Future<List<EstateFacilityBookingRecord>> loadMyFacilityBookings(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/facility-bookings/mine',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateFacilityBookingRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateSecurityIncidentRecord>> loadSecurityIncidents(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/security-incidents',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateSecurityIncidentRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateSecurityIncidentRecord>> loadMySecurityIncidents(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/security-incidents/mine',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateSecurityIncidentRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EstateSecurityIncidentEvidenceRecord> uploadSecurityIncidentEvidence({
    required String estateId,
    required String incidentId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final access = await _requireAccessToken();
    final idempotencyKey = List<int>.generate(
      24,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final request =
        http.MultipartRequest(
            'POST',
            _uri(
              '/estate/estates/$estateId/security-incidents/$incidentId/evidence',
            ),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $access',
            'Accept': 'application/json',
            'Idempotency-Key': idempotencyKey,
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final json = await _json(Future.value(response));
    return EstateSecurityIncidentEvidenceRecord.fromJson(json);
  }

  @override
  Future<Uint8List> downloadSecurityIncidentEvidence({
    required String estateId,
    required String incidentId,
    required String evidenceId,
  }) async {
    final access = await _requireAccessToken();
    final response = await _send(
      'GET',
      '/estate/estates/$estateId/security-incidents/$incidentId/evidence/$evidenceId/content',
      accessToken: access,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EstateApiException(
        'Incident evidence could not be downloaded.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> createSecurityIncident({
    required String estateId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/security-incidents',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> reviewSecurityIncident({
    required String estateId,
    required String incidentId,
    required String command,
    String? note,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/security-incidents/$incidentId/review',
        accessToken: access,
        body: {'command': command, if (note != null) 'note': note},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> loadExpensePolicy(String estateId) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'GET',
        '/estate/estates/$estateId/expenses/policy',
        accessToken: access,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> configureExpensePolicy({
    required String estateId,
    required Map<String, dynamic> policy,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'PUT',
        '/estate/estates/$estateId/expenses/policy',
        accessToken: access,
        body: policy,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadExpenseCategories(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final result = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/expenses/categories',
        accessToken: access,
      ),
    );
    return (result['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createExpenseCategory({
    required String estateId,
    required String code,
    required String name,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/categories',
        accessToken: access,
        body: {'code': code, 'name': name},
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadExpensePayees(String estateId) async {
    final access = await _requireAccessToken();
    final result = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/expenses/payees',
        accessToken: access,
      ),
    );
    return (result['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createExpensePayee({
    required String estateId,
    required Map<String, dynamic> payee,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/payees',
        accessToken: access,
        body: payee,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> verifyExpensePayee({
    required String estateId,
    required String payeeId,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/payees/$payeeId/verify',
        accessToken: access,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadExpenseRequests(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final result = await _json(
      _send('GET', '/estate/estates/$estateId/expenses', accessToken: access),
    );
    return (result['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createExpenseDraft({
    required String estateId,
    required Map<String, dynamic> expense,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses',
        accessToken: access,
        body: expense,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> submitExpense({
    required String estateId,
    required String expenseId,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/$expenseId/submit',
        accessToken: access,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> decideExpense({
    required String estateId,
    required String expenseId,
    required String decision,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/$expenseId/decision',
        accessToken: access,
        body: {'decision': decision, if (reason != null) 'reason': reason},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> reconcileExpense({
    required String estateId,
    required String expenseId,
    required Map<String, dynamic> settlement,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/expenses/$expenseId/settlements',
        accessToken: access,
        body: settlement,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadEstateBudgets(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/budgets', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createEstateBudget({
    required String estateId,
    required Map<String, dynamic> budget,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/budgets',
        accessToken: access,
        body: budget,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> submitEstateBudget({
    required String estateId,
    required String budgetId,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/budgets/$budgetId/submit',
        accessToken: access,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> decideEstateBudget({
    required String estateId,
    required String budgetId,
    required String decision,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/budgets/$budgetId/decision',
        accessToken: access,
        body: {'decision': decision, if (reason != null) 'reason': reason},
      ),
    );
  }

  @override
  Future<List<EstateFacilitySlotRecord>> loadFacilityAvailability({
    required String estateId,
    required String facilityId,
    required String date,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/facilities/$facilityId/availability?date=$date',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateFacilitySlotRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createResidentFacilityBooking({
    required String estateId,
    required String facilityId,
    required Map<String, dynamic> fields,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/facilities/$facilityId/bookings',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: fields,
      ),
    );
  }

  @override
  Future<void> cancelResidentFacilityBooking({
    required String estateId,
    required String bookingId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/facility-bookings/$bookingId/cancel',
        accessToken: access,
        body: const {},
      ),
    );
  }

  @override
  Future<List<EstateFacilityRecord>> loadEstateFacilities(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/facilities', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateFacilityRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateFacilityBookingRecord>> loadEstateFacilityBookings(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/facility-bookings',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateFacilityBookingRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createEstateFacility({
    required String estateId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/facilities',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> reviewEstateFacilityBooking({
    required String estateId,
    required String bookingId,
    required String command,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/facility-bookings/$bookingId/review',
        accessToken: access,
        body: {'command': command, if (reason != null) 'reason': reason},
      ),
    );
  }

  @override
  Future<List<EstateStructureRecord>> loadEstateStructure(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/structure', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateStructureRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateInvoiceDraftRecord>> loadEstateInvoiceDrafts(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/charges/invoice-drafts',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateInvoiceDraftRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateSettlementPolicyRecord>> loadEstateSettlementPolicies(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/charges/settlement-policies',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateSettlementPolicyRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createEstateSettlementPolicy({
    required String estateId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/settlement-policies',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> activateEstateSettlementPolicy({
    required String estateId,
    required String policyId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/settlement-policies/$policyId/activate',
        accessToken: access,
      ),
    );
  }

  @override
  Future<void> issueEstateInvoiceDraft({
    required String estateId,
    required String invoiceDraftId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/invoice-drafts/$invoiceDraftId/issue',
        accessToken: access,
      ),
    );
  }

  @override
  Future<void> recordEstateInvoiceSettlement({
    required String estateId,
    required String invoiceId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/invoices/$invoiceId/settlements',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadMyInvoiceRecords() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/invoices/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<void> createEstateInvoiceDraft({
    required String estateId,
    required Map<String, dynamic> fields,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/invoice-drafts',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: fields,
      ),
    );
  }

  @override
  Future<void> createStructureNode({
    required String estateId,
    required String type,
    required String name,
    String? code,
    List<String> parentIds = const [],
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/structure/nodes',
        accessToken: access,
        body: {
          'type': type,
          'name': name.trim(),
          if (code?.trim().isNotEmpty == true) 'code': code!.trim(),
          if (parentIds.isNotEmpty) 'parentIds': parentIds,
        },
      ),
    );
  }

  @override
  Future<void> archiveStructureNode({
    required String estateId,
    required String nodeId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'DELETE',
        '/estate/estates/$estateId/structure/nodes/$nodeId',
        accessToken: access,
      ),
    );
  }

  @override
  Future<List<EstateChargeRecord>> loadEstateCharges(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/charges', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateChargeRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ManagedEstatePropertyChoice>> loadManagedEstatePropertyChoices(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/properties?page=1&pageSize=100',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ManagedEstatePropertyChoice.fromJson)
        .where((property) => property.status != 'archived')
        .toList(growable: false);
  }

  @override
  Future<void> createEstateCharge({
    required String estateId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> createEstateChargeVersion({
    required String estateId,
    required String chargeId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/$chargeId/versions',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> activateEstateChargeVersion({
    required String estateId,
    required String chargeId,
    required String versionId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/$chargeId/versions/$versionId/activate',
        accessToken: access,
        body: const {},
      ),
    );
  }

  @override
  Future<EstateAccount> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _json(
      _send(
        'POST',
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      ),
    );
    await _saveTokens(response);
    return EstateAccount.fromJson(response['user'] as Map<String, dynamic>);
  }

  @override
  Future<EstateAccount?> restoreSession() async {
    final refresh = await _readRefreshToken();
    if (refresh == null) return null;
    final access = await _readAccessToken();
    if (access != null) {
      try {
        final current = await _json(
          _send('GET', '/auth/me', accessToken: access),
        );
        return EstateAccount.fromJson(current);
      } on EstateApiException catch (error) {
        if (error.statusCode != 401) rethrow;
      }
    }
    try {
      final rotated = await _json(
        _send('POST', '/auth/refresh', body: {'refreshToken': refresh}),
      );
      await _saveTokens(rotated);
      return EstateAccount.fromJson(rotated['user'] as Map<String, dynamic>);
    } on EstateApiException catch (error) {
      if (error.statusCode == 401) await _clearTokens();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final access = await _readAccessToken();
    try {
      if (access != null) {
        await _send('POST', '/auth/logout', accessToken: access);
      }
    } finally {
      await _clearTokens();
      _applicationId = null;
      _applicationCode = null;
    }
  }

  Future<String> _requireAccessToken() async {
    final access = await _readAccessToken();
    if (access == null) throw const EstateApiException('Sign in to continue.');
    return access;
  }

  @override
  Future<List<ManagedEstateChoice>> loadManagedEstates() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/management', accessToken: access),
    );
    final rows = response['items'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManagedEstateChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateStaffInvitationRecord>> loadStaffInvitations(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/staff-invitations',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateStaffInvitationRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createStaffInvitation({
    required String estateId,
    required String email,
    required String role,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/staff-invitations',
        accessToken: access,
        body: {'email': email.trim(), 'role': role},
      ),
    );
  }

  @override
  Future<void> revokeStaffInvitation({
    required String estateId,
    required String invitationId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'DELETE',
        '/estate/estates/$estateId/staff-invitations/$invitationId',
        accessToken: access,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> acceptStaffInvitation({
    required String estateId,
    required String code,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/staff-invitations/accept',
        accessToken: access,
        body: {'token': code.trim()},
      ),
    );
  }

  @override
  Future<EstateTreasurySummary> loadTreasurySummary(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/treasury/summary',
        accessToken: access,
      ),
    );
    return EstateTreasurySummary.fromJson(response);
  }

  @override
  Future<List<EstatePayoutBeneficiaryRecord>> loadPayoutBeneficiaries(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/finance/beneficiaries',
          accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstatePayoutBeneficiaryRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstatePayoutRecord>> loadPayouts(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/finance/payouts', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstatePayoutRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createPayout({
    required String estateId,
    required String beneficiaryId,
    required String amount,
    required String purpose,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/finance/payouts',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {
          'beneficiaryId': beneficiaryId,
          'amount': amount,
          'currency': 'NGN',
          'purpose': purpose,
          'fundCategory': 'estate_operations',
        },
      ),
    );
  }

  @override
  Future<void> decidePayout({required String estateId, required String payoutId, required String decision, String? note}) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/finance/payouts/$payoutId/decision',
        accessToken: access,
        body: {'decision': decision, if (note != null) 'note': note},
      ),
    );
  }

  @override
  Future<EstateManagerDashboardSummary> loadManagerDashboard(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/dashboard', accessToken: access),
    );
    return EstateManagerDashboardSummary.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> loadEstateSettings(String estateId) async {
    final access = await _requireAccessToken();
    return _json(
      _send('GET', '/estate/estates/$estateId/settings', accessToken: access),
    );
  }

  @override
  Future<Map<String, dynamic>> updateEstateSettings({
    required String estateId,
    required Map<String, String> fields,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'PATCH',
        '/estate/estates/$estateId/settings',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<RentSchedulePreview> loadRentSchedulePreview({
    required String estateId,
    required int year,
    required int month,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/rent-schedule-preview?year=$year&month=$month',
        accessToken: access,
      ),
    );
    return RentSchedulePreview.fromJson(response);
  }

  @override
  Future<List<EstateAnnouncementRecord>> loadEstateAnnouncements(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/announcements',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateAnnouncementRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EstateAnnouncementRecord> createEstateAnnouncementDraft({
    required String estateId,
    required String title,
    required String body,
    required String priority,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/announcements',
        accessToken: access,
        body: {'title': title, 'body': body, 'priority': priority},
      ),
    );
    return EstateAnnouncementRecord.fromJson(response);
  }

  @override
  Future<EstateAnnouncementRecord> publishEstateAnnouncement({
    required String estateId,
    required String announcementId,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/announcements/$announcementId/publish',
        accessToken: access,
      ),
    );
    return EstateAnnouncementRecord.fromJson(response);
  }

  @override
  Future<List<ResidentAnnouncementRecord>> loadMyAnnouncements() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/announcements/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ResidentAnnouncementRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> markMyAnnouncementRead(String announcementId) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/announcements/$announcementId/read',
        accessToken: access,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadMyNotifications() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/notifications/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<void> markEstateNotificationRead(String notificationId) async {
    final access = await _requireAccessToken();
    await _json(
      _send('POST', '/notifications/$notificationId/read', accessToken: access),
    );
  }

  @override
  Future<int> markAllEstateNotificationsRead() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('POST', '/notifications/read-all', accessToken: access),
    );
    return (response['marked'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<OwnershipReviewRecord>> loadPendingOwnershipReviews(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/ownership?page=1&pageSize=100&status=active&verificationStatus=pending',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OwnershipReviewRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> decideOwnershipReview({
    required String estateId,
    required String ownershipId,
    required String decision,
    required String reason,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/ownership/$ownershipId/verify',
        accessToken: access,
        body: {'decision': decision, 'reason': reason.trim()},
      ),
    );
  }

  @override
  Future<List<TenancyApprovalRecord>> loadPendingTenancyApprovals(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/tenancies?page=1&pageSize=100&status=pending_approval',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TenancyApprovalRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createEstateTenancy({
    required String estateId,
    required String propertyId,
    required Map<String, dynamic> fields,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/properties/$propertyId/tenancies',
        accessToken: access,
        body: fields,
      ),
    );
  }

  @override
  Future<void> approveTenancy({
    required String estateId,
    required String tenancyId,
    required String reason,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/tenancies/$tenancyId/approve',
        accessToken: access,
        body: {'reason': reason.trim()},
      ),
    );
  }

  @override
  Future<List<ResidentAccessRequest>> loadResidentAccessRequests(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/resident-requests',
        accessToken: access,
      ),
    );
    final rows = response['items'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ResidentAccessRequest.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> decideResidentAccessRequest({
    required String estateId,
    required String requestId,
    required String decision,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    final path =
        '/estate/estates/$estateId/resident-requests/$requestId/$decision';
    await _json(
      _send(
        'POST',
        path,
        accessToken: access,
        body: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      ),
    );
  }

  @override
  Future<List<ManagedEstateChoice>> loadAvailableEstates() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/available', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ManagedEstateChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ManagedEstateChoice>> loadMyEstates() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ManagedEstateChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<JoinRequestPropertyChoice>> loadJoinRequestProperties(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/join-properties',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(JoinRequestPropertyChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ResidentJoinRequestStatusEntry>>
  loadMyJoinRequestHistory() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/residents/join-requests/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ResidentJoinRequestStatusEntry.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> submitResidentJoinRequest({
    required String estateId,
    String? propertyId,
    String? relationship,
    String? note,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/residents/join-requests',
        accessToken: access,
        body: {
          'estateId': estateId,
          'propertyId': ?propertyId,
          'relationship': ?relationship,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      ),
    );
  }

  @override
  Future<List<ManagedEstateChoice>> loadMyLandlordEstates() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/landlord/estates/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ManagedEstateChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<LandlordPortfolioRecord>> loadLandlordPortfolio(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/landlord/portfolio',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LandlordPortfolioRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<LandlordMaintenanceRecord>> loadMyLandlordPropertyMaintenance({
    int page = 1,
    int pageSize = 25,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/landlord/properties/maintenance?page=$page&pageSize=$pageSize',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LandlordMaintenanceRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<TenantTenancyRecord>> loadMyTenancies() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/tenancies/mine', accessToken: access),
    );
    final items = (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TenantTenancyRecord.fromJson)
        .toList(growable: false);
    _currentResidentEstateId ??= items.firstOrNull?.estateId;
    return items;
  }

  @override
  Future<List<ResidentVisitorPassRecord>> loadMyVisitorPasses(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/visitor-passes/mine?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ResidentVisitorPassRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ResidentVisitorPropertyRecord>> loadMyVisitorProperties(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/visitor-passes/properties?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ResidentVisitorPropertyRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createVisitorPass({
    required String estateId,
    required String propertyId,
    required String visitorName,
    required DateTime validFrom,
    required DateTime validUntil,
    required String vehicleSummary,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/visitor-passes',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {
          'estateId': estateId,
          'propertyId': propertyId,
          'visitorDisplayName': visitorName,
          'validFrom': validFrom.toUtc().toIso8601String(),
          'validUntil': validUntil.toUtc().toIso8601String(),
          if (vehicleSummary.trim().isNotEmpty)
            'vehicleSummary': vehicleSummary.trim(),
        },
      ),
    );
    _issuedVisitorCredentials[response['passId'] as String? ?? ''] = response;
    return response;
  }

  Map<String, dynamic>? takeIssuedVisitorCredential(String passId) =>
      _issuedVisitorCredentials.remove(passId);

  @override
  Future<void> revokeVisitorPass({
    required String estateId,
    required String passId,
    required String reason,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/visitor-passes/$passId/revoke?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
        body: {'reason': reason},
      ),
    );
  }

  @override
  Future<List<EstateGateRecord>> loadMyGates(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/security/gates?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateGateRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateGateRecord>> loadEstateGates(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/security/gates',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateGateRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateStaffChoice>> loadSecurityOfficers(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/security/officers',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateStaffChoice.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createEstateGate({
    required String estateId,
    required String code,
    required String name,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/security/gates',
        accessToken: access,
        body: {'code': code, 'name': name},
      ),
    );
  }

  @override
  Future<void> assignGateOfficer({
    required String estateId,
    required String gateId,
    required String userId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/security/gates/$gateId/assignments',
        accessToken: access,
        body: {'userId': userId},
      ),
    );
  }

  @override
  Future<List<GateCurrentVisitorRecord>> loadCurrentGateVisitors({
    required String estateId,
    required String gateId,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/security/gates/$gateId/visitors/current?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GateCurrentVisitorRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<GateExpectedVisitorRecord>> loadExpectedGateVisitors({
    required String estateId,
    required String gateId,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/security/gates/$gateId/visitors/expected?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GateExpectedVisitorRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> checkInGateVisitor({
    required String estateId,
    required String gateId,
    required String credential,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/security/gates/$gateId/check-in?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {'credential': credential},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createGateManualAdmission({
    required String estateId,
    required String gateId,
    required String visitorName,
    required String propertyReference,
    required String reason,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/security/gates/$gateId/manual-admissions?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {
          'visitorDisplayName': visitorName,
          'propertyReference': propertyReference,
          'reason': reason,
        },
      ),
    );
  }

  @override
  Future<List<EstateGateAccessEventRecord>> loadGateAccessEvents({
    required String estateId,
    String? gateId,
    String? eventKind,
    int page = 1,
    int pageSize = 25,
  }) async {
    final access = await _requireAccessToken();
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (gateId != null) 'gateId': gateId,
      if (eventKind != null) 'eventKind': eventKind,
    };
    final path = Uri(
      path: '/estate/estates/$estateId/security/access-events',
      queryParameters: query,
    ).toString();
    final response = await _json(_send('GET', path, accessToken: access));
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateGateAccessEventRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<EstateSecurityContactRecord>> loadSecurityContacts(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/security/contacts',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateSecurityContactRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> checkOutGateVisitor({
    required String estateId,
    required String gateId,
    required String visitId,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/security/gates/$gateId/visits/$visitId/check-out?estateId=${Uri.encodeQueryComponent(estateId)}',
        accessToken: access,
        body: const {},
      ),
    );
  }

  @override
  Future<List<EstateWalletRecord>> loadMyWallets() async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/wallets/mine', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateWalletRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EstateWalletRecord> provisionEstateWallet(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/wallets/provision',
        accessToken: access,
        body: {'estateId': estateId},
      ),
    );
    return EstateWalletRecord.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> createWalletFundingIntent({
    required String estateId,
    required String amount,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/wallets/funding-intents',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {'estateId': estateId, 'amount': amount},
      ),
    );
  }

  @override
  Future<List<PropertyLocationRecord>> loadPropertyLocations(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/properties/locations', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PropertyLocationRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PropertyLocationRecord> capturePropertyLocation({
    required String estateId,
    required String propertyId,
    required String latitude,
    required String longitude,
    String? accuracyMeters,
    required String captureMethod,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/properties/$propertyId/location',
        accessToken: access,
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'captureMethod': captureMethod,
          if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
          if (reason != null) 'reason': reason,
        },
      ),
    );
    return PropertyLocationRecord.fromJson(response);
  }

  @override
  Future<PropertyLocationRecord> verifyPropertyLocation({
    required String estateId,
    required String propertyId,
    required String decision,
    String? reason,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/properties/$propertyId/location/verify',
        accessToken: access,
        body: {'decision': decision, if (reason != null) 'reason': reason},
      ),
    );
    return PropertyLocationRecord.fromJson(response);
  }

  List<HouseholdMemberRecord> _householdFrom(Map<String, dynamic> response) =>
      (response['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HouseholdMemberRecord.fromJson)
          .toList(growable: false);

  @override
  Future<List<HouseholdMemberRecord>> loadMyHousehold() async {
    final access = await _requireAccessToken();
    return _householdFrom(
      await _json(_send('GET', '/estate/household/mine', accessToken: access)),
    );
  }

  @override
  Future<List<HouseholdMemberRecord>> loadEstateHousehold(String estateId) async {
    final access = await _requireAccessToken();
    return _householdFrom(
      await _json(_send('GET', '/estate/estates/$estateId/household', accessToken: access)),
    );
  }

  @override
  Future<HouseholdMemberRecord> addHouseholdMember({
    required String estateId,
    required String propertyId,
    required String fullName,
    required String relationship,
    required String memberType,
    required String effectiveFrom,
    String? primaryUserId,
    String? dateOfBirth,
    String? phone,
    String? email,
    bool financialAccess = false,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/household',
        accessToken: access,
        body: {
          'propertyId': propertyId,
          'fullName': fullName,
          'relationship': relationship,
          'memberType': memberType,
          'effectiveFrom': effectiveFrom,
          if (primaryUserId != null) 'primaryUserId': primaryUserId,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          'financialAccess': financialAccess,
        },
      ),
    );
    return HouseholdMemberRecord.fromJson(response);
  }

  @override
  Future<HouseholdMemberRecord> decideHouseholdMember({
    required String estateId,
    required String memberId,
    required String decision,
    String? note,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/household/$memberId/decide',
        accessToken: access,
        body: {'decision': decision, if (note != null) 'note': note},
      ),
    );
    return HouseholdMemberRecord.fromJson(response);
  }

  @override
  Future<HouseholdMemberRecord> endHouseholdMember({
    required String estateId,
    required String memberId,
    required String reason,
  }) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/household/$memberId/end',
        accessToken: access,
        body: {'reason': reason},
      ),
    );
    return HouseholdMemberRecord.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> previewRecurringLevies(String estateId, {int months = 3}) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'GET',
        '/estate/estates/$estateId/charges/recurring/preview?months=$months',
        accessToken: access,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> generateRecurringLevies(String estateId, {int months = 3}) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/charges/recurring/generate',
        accessToken: access,
        body: {'months': months},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> generateRentSchedule(String estateId, {String? from, int months = 3}) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/estates/$estateId/rent/generate',
        accessToken: access,
        body: {
          if (from != null) 'from': from,
          'months': months,
        },
      ),
    );
  }

  @override
  Future<List<RentScheduleRecord>> loadRentSchedule(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/rent/schedule', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RentScheduleRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<LandlordRentSummaryRecord>> loadLandlordRentSummary(String estateId) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send('GET', '/estate/estates/$estateId/rent/landlord-summary', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LandlordRentSummaryRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> payRentSchedule({required String scheduleId, required String amount}) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/wallets/pay-rent-schedule',
        accessToken: access,
        body: {'scheduleId': scheduleId, 'amount': amount},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> creditDemoWallet(String intentId) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/wallets/demo-credit',
        accessToken: access,
        body: {'intentId': intentId},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> payRentFromWallet({
    required String estateId,
    required String invoiceId,
    required String amount,
  }) async {
    final access = await _requireAccessToken();
    return _json(
      _send(
        'POST',
        '/estate/wallets/pay-rent',
        accessToken: access,
        body: {
          'estateId': estateId,
          'invoiceId': invoiceId,
          'amount': amount,
        },
      ),
    );
  }

  @override
  Future<List<ResidentMaintenanceRecord>> loadMyMaintenanceRequests(
    String estateId,
  ) async {
    final access = await _requireAccessToken();
    final response = await _json(
      _send(
        'GET',
        '/estate/maintenance/requests/mine?estateId=${Uri.encodeQueryComponent(estateId)}&page=1&pageSize=50',
        accessToken: access,
      ),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ResidentMaintenanceRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> createMaintenanceRequest({
    required String estateId,
    required String propertyId,
    required String category,
    required String priority,
    required String description,
    required String idempotencyKey,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/maintenance/requests',
        accessToken: access,
        additionalHeaders: {'Idempotency-Key': idempotencyKey},
        body: {
          'estateId': estateId,
          'propertyId': propertyId,
          'category': category,
          'priority': priority,
          'description': description,
        },
      ),
    );
  }

  @override
  Future<EstateMaintenanceQueue> loadMaintenanceQueue(
    String estateId, {
    int page = 1,
    int pageSize = 50,
    String? status,
    String? search,
  }) async {
    final access = await _requireAccessToken();
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    ).query;
    final response = await _json(
      _send(
        'GET',
        '/estate/estates/$estateId/maintenance/requests?$query',
        accessToken: access,
      ),
    );
    return EstateMaintenanceQueue.fromJson(response);
  }

  @override
  Future<void> reviewMaintenanceRequest({
    required String estateId,
    required String requestId,
    String? command,
    String? assigneeUserId,
    String? reason,
    String? resolutionSummary,
    String? residentUpdate,
    String? internalNote,
  }) async {
    final access = await _requireAccessToken();
    await _json(
      _send(
        'POST',
        '/estate/estates/$estateId/maintenance/requests/$requestId/review',
        accessToken: access,
        body: {
          if (command != null) 'command': command,
          if (assigneeUserId != null) 'assigneeUserId': assigneeUserId,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
          if (resolutionSummary != null && resolutionSummary.trim().isNotEmpty)
            'resolutionSummary': resolutionSummary.trim(),
          if (residentUpdate != null && residentUpdate.trim().isNotEmpty)
            'residentUpdate': residentUpdate.trim(),
          if (internalNote != null && internalNote.trim().isNotEmpty)
            'internalNote': internalNote.trim(),
        },
      ),
    );
  }

  @override
  Future<EstateApplicationDraft?> loadMyDraft() async {
    final access = await _readAccessToken();
    if (access == null) throw const EstateApiException('Sign in to continue.');
    final response = await _json(
      _send('GET', '/estate/applications/mine', accessToken: access),
    );
    final items = response['items'];
    if (items is! List) return null;
    final applications = items.whereType<Map<String, dynamic>>().toList();
    if (applications.isEmpty) return null;
    final application = applications.firstWhere(
      (item) => ['draft', 'more_information_required'].contains(item['status']),
      orElse: () => applications.first,
    );
    _applicationId = application['id'] as String?;
    _applicationCode = application['applicationCode'] as String?;
    return _draftFromJson(application);
  }

  @override
  Future<List<EstateApplicationDocumentRecord>>
  loadMyApplicationDocuments() async {
    final access = await _readAccessToken();
    final id = _applicationId;
    if (access == null) throw const EstateApiException('Sign in to continue.');
    if (id == null) return const [];
    final response = await _json(
      _send('GET', '/estate/applications/$id/documents', accessToken: access),
    );
    return (response['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EstateApplicationDocumentRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<EstateApplicationDocumentRecord> uploadMyApplicationDocument({
    required String category,
    required String fileName,
    required Uint8List bytes,
    required String idempotencyKey,
  }) async {
    final access = await _readAccessToken();
    final id = _applicationId;
    if (access == null) throw const EstateApiException('Sign in to continue.');
    if (id == null)
      throw const EstateApiException(
        'Save the application before uploading a document.',
      );
    final request =
        http.MultipartRequest(
            'POST',
            _uri('/estate/applications/$id/documents'),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $access',
            'Accept': 'application/json',
            'Idempotency-Key': idempotencyKey,
          })
          ..fields['category'] = category
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final json = await _json(Future.value(response));
    return EstateApplicationDocumentRecord.fromJson(json);
  }

  @override
  Future<Uint8List> downloadMyApplicationDocument(String documentId) async {
    final access = await _readAccessToken();
    final id = _applicationId;
    if (access == null) throw const EstateApiException('Sign in to continue.');
    if (id == null) throw const EstateApiException('Application not found.');
    final response = await _send(
      'GET',
      '/estate/applications/$id/documents/$documentId/content',
      accessToken: access,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EstateApiException(
        'The document could not be downloaded.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<EstateApplicationDraft> saveMyDraft(
    EstateApplicationDraft draft,
  ) async {
    final access = await _readAccessToken();
    if (access == null) throw const EstateApiException('Sign in to continue.');
    if (_applicationId == null) {
      final created = await _json(
        _send('POST', '/estate/applications', accessToken: access),
      );
      _applicationId = created['id'] as String?;
      _applicationCode = created['code'] as String?;
    }
    final applicationId = _applicationId;
    if (applicationId == null) {
      throw const EstateApiException(
        'The application draft could not be created.',
      );
    }
    final changes = <String, dynamic>{
      'proposedName': draft.proposedName,
      'estateType': draft.estateType,
      'address': draft.address,
      'state': draft.state,
      'lga': draft.lga,
      'applicantRelationship': draft.applicantRelationship,
      'applicantContactName': draft.applicantContactName,
      'applicantContactEmail': draft.applicantContactEmail,
      'applicantContactPhone': draft.applicantContactPhone,
      'managementEntityName': draft.managementEntityName,
      'registrationNumber': draft.registrationNumber,
      'structureSummary': draft.structureSummary,
    };
    final homeCount = int.tryParse(draft.homeCount);
    final phaseCount = int.tryParse(draft.phaseCount);
    if (homeCount != null) changes['homeCount'] = homeCount;
    if (phaseCount != null) changes['phaseCount'] = phaseCount;
    final updated = await _json(
      _send(
        'PATCH',
        '/estate/applications/$applicationId',
        accessToken: access,
        body: changes,
      ),
    );
    _applicationCode = updated['code'] as String? ?? _applicationCode;
    return EstateApplicationDraft(
      reference: _applicationCode ?? draft.reference,
      proposedName: draft.proposedName,
      estateType: draft.estateType,
      address: draft.address,
      state: draft.state,
      lga: draft.lga,
      applicantRelationship: draft.applicantRelationship,
      applicantContactName: draft.applicantContactName,
      applicantContactEmail: draft.applicantContactEmail,
      applicantContactPhone: draft.applicantContactPhone,
      managementEntityName: draft.managementEntityName,
      registrationNumber: draft.registrationNumber,
      homeCount: draft.homeCount,
      phaseCount: draft.phaseCount,
      structureSummary: draft.structureSummary,
      updatedAt:
          DateTime.tryParse(updated['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<String> submitMyApplication() async {
    final access = await _readAccessToken();
    if (access == null) throw const EstateApiException('Sign in to continue.');
    final applicationId = _applicationId;
    if (applicationId == null) {
      throw const EstateApiException(
        'Save your application before submitting.',
      );
    }
    final submitted = await _json(
      _send(
        'POST',
        '/estate/applications/$applicationId/submit',
        accessToken: access,
      ),
    );
    return submitted['applicationCode'] as String? ?? _applicationCode ?? '';
  }

  EstateApplicationDraft _draftFromJson(Map<String, dynamic> json) {
    return EstateApplicationDraft(
      reference: json['applicationCode'] as String? ?? '',
      proposedName: json['proposedName'] as String? ?? '',
      estateType: json['estateType'] as String? ?? 'Gated community',
      address: json['address'] as String? ?? '',
      state: json['state'] as String? ?? '',
      lga: json['lga'] as String? ?? '',
      applicantRelationship:
          json['applicantRelationship'] as String? ?? 'Estate owner',
      applicantContactName: json['applicantContactName'] as String? ?? '',
      applicantContactEmail: json['applicantContactEmail'] as String? ?? '',
      applicantContactPhone: json['applicantContactPhone'] as String? ?? '',
      managementEntityName: json['managementEntityName'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String? ?? '',
      homeCount: json['homeCount']?.toString() ?? '',
      phaseCount: json['phaseCount']?.toString() ?? '',
      structureSummary: json['structureSummary'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'draft',
    );
  }
}

/// Kept only for isolated presentation previews; the onboarding entry point uses
/// [EstateApplicationApiClient] and writes drafts to the standalone API.
class PreviewEstateApplicationRepository
    implements EstateApplicationRepository {
  EstateApplicationDraft? _draft;

  @override
  Future<EstateApplicationDraft?> loadMyDraft() async => _draft;

  @override
  Future<EstateApplicationDraft> saveMyDraft(
    EstateApplicationDraft draft,
  ) async {
    _draft = draft;
    return draft;
  }
}
