import 'dart:math';

import '../../onboarding/data/estate_application_repository.dart';

class SecurityGateContext {
  const SecurityGateContext({
    required this.estateName,
    required this.gateName,
    required this.shiftLabel,
    required this.assignmentLabel,
  });
  final String estateName;
  final String gateName;
  final String shiftLabel;
  final String assignmentLabel;
}

class SecurityExpectedVisitor {
  const SecurityExpectedVisitor({
    required this.visitorName,
    required this.propertyLabel,
    required this.hostName,
    required this.validUntilLabel,
    this.vehicleSummary,
  });
  final String visitorName;
  final String propertyLabel;
  final String hostName;
  final String validUntilLabel;
  final String? vehicleSummary;
}

class SecurityCurrentVisitor {
  const SecurityCurrentVisitor({
    required this.visitId,
    required this.visitorName,
    required this.propertyLabel,
    required this.hostName,
    required this.checkedInLabel,
    required this.admissionType,
    this.vehicleSummary,
  });
  final String visitId;
  final String visitorName;
  final String propertyLabel;
  final String hostName;
  final String checkedInLabel;
  final String admissionType;
  final String? vehicleSummary;
}

class SecurityEmergencyContact {
  const SecurityEmergencyContact({
    required this.label,
    required this.displayName,
    required this.phoneDisplay,
  });
  final String label;
  final String displayName;
  final String phoneDisplay;
}

class SecurityIncidentReport {
  const SecurityIncidentReport({
    required this.reference,
    required this.category,
    required this.priority,
    required this.location,
    required this.description,
    required this.observedAt,
    required this.reportedAt,
    required this.status,
  });

  final String reference;
  final String category;
  final String priority;
  final String? location;
  final String description;
  final DateTime observedAt;
  final DateTime reportedAt;
  final String status;
}

class SecurityCheckedInVisitor {
  const SecurityCheckedInVisitor({
    required this.visitId,
    required this.visitorName,
    required this.propertyLabel,
    required this.hostName,
    required this.checkedInLabel,
    this.vehicleSummary,
  });
  final String visitId;
  final String visitorName;
  final String propertyLabel;
  final String hostName;
  final String checkedInLabel;
  final String? vehicleSummary;
}

class SecurityAccessEvent {
  const SecurityAccessEvent({
    required this.id,
    required this.eventKind,
    required this.occurredAt,
    required this.gateId,
    this.propertyId,
    this.visitId,
    this.reasonCode,
    this.propertyLabel,
  });
  final String id;
  final String eventKind;
  final String occurredAt;
  final String gateId;
  final String? propertyId;
  final String? visitId;
  final String? reasonCode;
  final String? propertyLabel;
}

abstract interface class SecurityRepository {
  bool get isPreview;
  bool get supportsManualAdmission;
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<SecurityGateContext?> loadAssignedGate();
  Future<List<SecurityExpectedVisitor>> loadExpectedVisitors();
  Future<List<SecurityCurrentVisitor>> loadCurrentVisitors();
  Future<List<SecurityEmergencyContact>> loadEmergencyContacts();
  Future<List<SecurityAccessEvent>> loadAccessEvents();
  Future<List<SecurityIncidentReport>> loadMyIncidentReports();
  Future<SecurityCurrentVisitor> createManualAdmission({
    required String visitorName,
    required String propertyReference,
    required String reason,
  });
  Future<SecurityCheckedInVisitor> checkInVisitor(String credential);
  Future<void> checkOutVisitor(String visitId);
  Future<SecurityIncidentReport> createIncidentReport({
    required String category,
    required String priority,
    required String location,
    required String description,
    required DateTime observedAt,
  });
}

class PreviewSecurityRepository implements SecurityRepository {
  static const _incidentCategories = {
    'safety',
    'theft',
    'suspicious_activity',
    'property_damage',
    'access_control',
    'other',
  };
  static const _incidentPriorities = {'normal', 'high', 'urgent'};
  static const _gate = SecurityGateContext(
    estateName: 'Oakwood Estate',
    gateName: 'Main Gate',
    shiftLabel: 'Day shift · 7:00 am–7:00 pm',
    assignmentLabel: 'Assigned security staff',
  );
  static const _expected = <SecurityExpectedVisitor>[
    SecurityExpectedVisitor(
      visitorName: 'Adaeze Nnadi',
      propertyLabel: 'Block A · Unit 04',
      hostName: 'Tunde Balogun',
      validUntilLabel: 'Today · 6:00 pm',
      vehicleSummary: 'Blue sedan · LND 219 GK',
    ),
    SecurityExpectedVisitor(
      visitorName: 'Chinwe Okoro',
      propertyLabel: 'Block C · Unit 12',
      hostName: 'Amara Okafor',
      validUntilLabel: 'Today · 8:30 pm',
    ),
    SecurityExpectedVisitor(
      visitorName: 'Northstar Plumbing',
      propertyLabel: 'Block D · Unit 21',
      hostName: 'Estate office',
      validUntilLabel: 'Today · 4:00 pm',
    ),
  ];
  static final _current = <SecurityCurrentVisitor>[
    SecurityCurrentVisitor(
      visitId: 'visit-801',
      visitorName: 'Adaeze Nnadi',
      propertyLabel: 'Block A · Unit 04',
      hostName: 'Tunde Balogun',
      checkedInLabel: '9:42 am',
      admissionType: 'pass',
    ),
    SecurityCurrentVisitor(
      visitId: 'visit-800',
      visitorName: 'Samuel Eze',
      propertyLabel: 'Block C · Unit 19',
      hostName: 'Manual admission',
      checkedInLabel: '9:16 am',
      admissionType: 'manual',
    ),
  ];
  static const _contacts = <SecurityEmergencyContact>[
    SecurityEmergencyContact(
      label: 'Emergency response',
      displayName: 'Estate Control Room',
      phoneDisplay: '+234 800 000 0142',
    ),
    SecurityEmergencyContact(
      label: 'Estate manager',
      displayName: 'On-call Manager',
      phoneDisplay: '+234 800 000 0124',
    ),
  ];
  static final _incidentReports = <SecurityIncidentReport>[];

  @override
  bool get isPreview => true;
  @override
  bool get supportsManualAdmission => true;
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}

  @override
  Future<SecurityGateContext?> loadAssignedGate() async => _gate;
  @override
  Future<List<SecurityExpectedVisitor>> loadExpectedVisitors() async =>
      List.unmodifiable(_expected);
  @override
  Future<List<SecurityCurrentVisitor>> loadCurrentVisitors() async =>
      List.unmodifiable(_current);
  @override
  Future<List<SecurityEmergencyContact>> loadEmergencyContacts() async =>
      List.unmodifiable(_contacts);

  @override
  Future<List<SecurityAccessEvent>> loadAccessEvents() async => const [];

  @override
  Future<List<SecurityIncidentReport>> loadMyIncidentReports() async =>
      List.unmodifiable(_incidentReports);

  @override
  Future<SecurityCurrentVisitor> createManualAdmission({
    required String visitorName,
    required String propertyReference,
    required String reason,
  }) async {
    final name = visitorName.trim();
    final property = propertyReference.trim();
    final normalizedReason = reason.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        property.isEmpty ||
        property.length > 80 ||
        normalizedReason.length < 10 ||
        normalizedReason.length > 500) {
      throw ArgumentError(
        'Provide a visitor name, property reference and reason of 10 to 500 characters.',
      );
    }
    final now = DateTime.now();
    final visitor = SecurityCurrentVisitor(
      visitId: 'preview-visit-${now.microsecondsSinceEpoch}',
      visitorName: name,
      propertyLabel: property,
      hostName: 'Manual admission',
      checkedInLabel:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      admissionType: 'manual',
    );
    _current.insert(0, visitor);
    return visitor;
  }

  Future<void> checkOutVisitorPreview(String visitId) async {
    final index = _current.indexWhere((visitor) => visitor.visitId == visitId);
    if (index < 0) {
      throw StateError('The visitor is no longer checked in at this gate.');
    }
    _current.removeAt(index);
  }

  @override
  Future<SecurityCheckedInVisitor> checkInVisitor(String credential) async =>
      throw UnsupportedError(
        'Visitor pass verification is not available in the preview.',
      );

  @override
  Future<void> checkOutVisitor(String visitId) =>
      checkOutVisitorPreview(visitId);

  @override
  Future<SecurityIncidentReport> createIncidentReport({
    required String category,
    required String priority,
    required String location,
    required String description,
    required DateTime observedAt,
  }) async {
    final normalizedLocation = location.trim();
    final normalizedDescription = description.trim();
    final now = DateTime.now();
    if (!_incidentCategories.contains(category) ||
        !_incidentPriorities.contains(priority) ||
        normalizedDescription.isEmpty ||
        normalizedDescription.length > 1000 ||
        normalizedLocation.length > 120 ||
        observedAt.isAfter(now)) {
      throw ArgumentError(
        'Check the incident category, priority, location and description.',
      );
    }
    final report = SecurityIncidentReport(
      reference: 'PREVIEW-${now.millisecondsSinceEpoch}',
      category: category,
      priority: priority,
      location: normalizedLocation.isEmpty ? null : normalizedLocation,
      description: normalizedDescription,
      observedAt: observedAt,
      reportedAt: now,
      status: 'preview_reported',
    );
    _incidentReports.insert(0, report);
    return report;
  }
}

class ApiSecurityRepository implements SecurityRepository {
  ApiSecurityRepository(this.api);

  final EstateApplicationApiClient api;
  ManagedEstateChoice? _estate;
  EstateGateRecord? _gate;

  @override
  bool get isPreview => false;
  @override
  bool get supportsManualAdmission => true;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await api.signIn(email: email, password: password);
    _estate = null;
    _gate = null;
  }

  @override
  Future<void> signOut() => api.signOut();

  @override
  Future<SecurityGateContext?> loadAssignedGate() async {
    final estates = await api.loadMyEstates();
    for (final estate in estates.where(
      (item) => item.roles.contains('security_officer'),
    )) {
      final gates = await api.loadMyGates(estate.id);
      if (gates.isEmpty) continue;
      _estate = estate;
      _gate = gates.first;
      return SecurityGateContext(
        estateName: estate.name,
        gateName: _gate!.name,
        shiftLabel: 'Assigned security officer',
        assignmentLabel: 'Gate assignment active',
      );
    }
    _estate = null;
    _gate = null;
    return null;
  }

  @override
  Future<List<SecurityExpectedVisitor>> loadExpectedVisitors() async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) return const [];
    final records = await api.loadExpectedGateVisitors(
      estateId: estate.id,
      gateId: gate.id,
    );
    return records
        .map(
          (record) => SecurityExpectedVisitor(
            visitorName: record.visitorName,
            propertyLabel: record.propertyLabel,
            hostName: record.hostDisplayName,
            validUntilLabel: _dateTimeLabel(record.validUntil),
            vehicleSummary: record.vehicleSummary,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SecurityCurrentVisitor>> loadCurrentVisitors() async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) return const [];
    final records = await api.loadCurrentGateVisitors(
      estateId: estate.id,
      gateId: gate.id,
    );
    return records
        .map(
          (record) => SecurityCurrentVisitor(
            visitId: record.visitId,
            visitorName: record.visitorName,
            propertyLabel: record.propertyLabel,
            hostName: record.hostDisplayName,
            checkedInLabel: _dateTimeLabel(record.checkedInAt),
            admissionType: 'pass',
            vehicleSummary: record.vehicleSummary,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SecurityEmergencyContact>> loadEmergencyContacts() async {
    final estate = _estate;
    if (estate == null) return const [];
    final records = await api.loadSecurityContacts(estate.id);
    return records
        .map(
          (record) => SecurityEmergencyContact(
            label: record.label,
            displayName: record.displayName,
            phoneDisplay: record.phoneDisplay,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SecurityAccessEvent>> loadAccessEvents() async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) return const [];
    final records = await api.loadGateAccessEvents(
      estateId: estate.id,
      gateId: gate.id,
      pageSize: 30,
    );
    return records
        .map(
          (record) => SecurityAccessEvent(
            id: record.id,
            eventKind: record.eventKind,
            occurredAt: _dateTimeLabel(record.occurredAt),
            gateId: record.gateId,
            propertyId: record.propertyId,
            visitId: record.visitId,
            reasonCode: record.reasonCode,
            propertyLabel: record.propertyLabel,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SecurityIncidentReport>> loadMyIncidentReports() async {
    final estate = _estate;
    if (estate == null) return const [];
    final records = await api.loadMySecurityIncidents(estate.id);
    return records
        .map(
          (record) => SecurityIncidentReport(
            reference: record.reference,
            category: record.category,
            priority: record.priority,
            location: record.locationDescription,
            description: record.description,
            observedAt: DateTime.tryParse(record.observedAt) ?? DateTime.now(),
            reportedAt: DateTime.tryParse(record.reportedAt) ?? DateTime.now(),
            status: record.status,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SecurityCurrentVisitor> createManualAdmission({
    required String visitorName,
    required String propertyReference,
    required String reason,
  }) async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) {
      throw StateError('No assigned gate is available.');
    }
    final key = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final result = await api.createGateManualAdmission(
      estateId: estate.id,
      gateId: gate.id,
      visitorName: visitorName,
      propertyReference: propertyReference,
      reason: reason,
      idempotencyKey: key,
    );
    return SecurityCurrentVisitor(
      visitId: result['visitId'] as String? ?? '',
      visitorName: result['visitorName'] as String? ?? visitorName,
      propertyLabel: result['propertyLabel'] as String? ?? propertyReference,
      hostName: result['hostDisplayName'] as String? ?? 'Manual admission',
      checkedInLabel: _dateTimeLabel(result['checkedInAt'] as String? ?? ''),
      admissionType: 'manual',
    );
  }

  @override
  Future<SecurityCheckedInVisitor> checkInVisitor(String credential) async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) {
      throw StateError('No assigned gate is available.');
    }
    final key = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final result = await api.checkInGateVisitor(
      estateId: estate.id,
      gateId: gate.id,
      credential: credential.trim(),
      idempotencyKey: key,
    );
    return SecurityCheckedInVisitor(
      visitId: result['visitId'] as String? ?? '',
      visitorName: result['visitorName'] as String? ?? 'Visitor',
      propertyLabel: result['propertyLabel'] as String? ?? '',
      hostName: result['hostDisplayName'] as String? ?? '',
      checkedInLabel: _dateTimeLabel(
        result['checkedInAt'] as String? ?? '',
      ),
      vehicleSummary: result['vehicleSummary'] as String?,
    );
  }

  @override
  Future<void> checkOutVisitor(String visitId) async {
    final estate = _estate;
    final gate = _gate;
    if (estate == null || gate == null) {
      throw StateError('No assigned gate is available.');
    }
    await api.checkOutGateVisitor(
      estateId: estate.id,
      gateId: gate.id,
      visitId: visitId,
    );
  }

  @override
  Future<SecurityIncidentReport> createIncidentReport({
    required String category,
    required String priority,
    required String location,
    required String description,
    required DateTime observedAt,
  }) async {
    final estate = _estate;
    if (estate == null) throw StateError('No assigned estate is available.');
    await api.createSecurityIncident(
      estateId: estate.id,
      fields: {
        'category': category,
        'priority': priority,
        'description': description,
        if (location.trim().isNotEmpty) 'locationDescription': location.trim(),
        'observedAt': observedAt.toUtc().toIso8601String(),
      },
    );
    final now = DateTime.now();
    return SecurityIncidentReport(
      reference: 'Submitted',
      category: category,
      priority: priority,
      location: location.trim().isEmpty ? null : location.trim(),
      description: description.trim(),
      observedAt: observedAt,
      reportedAt: now,
      status: 'reported',
    );
  }
}

String _dateTimeLabel(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Time unavailable';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'am' : 'pm';
  return '${date.day}/${date.month}/${date.year} · $hour:$minute $period';
}
