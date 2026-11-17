const JoinRequestStatus = Object.freeze({
  SUBMITTED: 'submitted',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  WITHDRAWN: 'withdrawn',
});

const OccupantRelationship = Object.freeze({
  OWNER: 'owner',
  TENANT: 'tenant',
  HOUSEHOLD_MEMBER: 'household_member',
  AUTHORIZED_OCCUPANT: 'authorized_occupant',
});

const JoinRequestDecision = Object.freeze({ APPROVE: 'approve', REJECT: 'reject' });
const JoinRequestRelationships = Object.freeze(Object.values(OccupantRelationship));

class ResidentMembershipError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentMembershipError';
    this.code = code;
  }
}

function planJoinRequestCreation({ requestId, applicantUserId, estateId, property, relationship, note, evidenceDocumentIds = [], now, policyAllowsRequest } = {}) {
  if (!requestId || !applicantUserId || !estateId) {
    throw new ResidentMembershipError('INVALID_JOIN_REQUEST', 'Request, authenticated applicant, and estate are required.');
  }
  if (policyAllowsRequest !== true) {
    throw new ResidentMembershipError('JOIN_REQUEST_NOT_ALLOWED', 'The estate is not accepting this join request under its current policy.');
  }
  if (property && (property.estateId !== estateId || !property.id)) {
    throw new ResidentMembershipError('PROPERTY_SCOPE_MISMATCH', 'The selected property must belong to the requested estate.');
  }
  if (!JoinRequestRelationships.includes(relationship)) {
    throw new ResidentMembershipError('INVALID_RELATIONSHIP', 'Choose owner, tenant, household_member, or authorized_occupant.');
  }
  if (typeof note !== 'string' || note.trim().length > 1000) {
    throw new ResidentMembershipError('INVALID_APPLICANT_NOTE', 'Applicant note must be text of at most 1,000 characters.');
  }
  if (!Array.isArray(evidenceDocumentIds) || evidenceDocumentIds.length > 10
    || evidenceDocumentIds.some((id) => (typeof id !== 'string' && typeof id !== 'number') || !String(id).trim())
    || new Set(evidenceDocumentIds.map(String)).size !== evidenceDocumentIds.length) {
    throw new ResidentMembershipError('INVALID_EVIDENCE_REFERENCES', 'Provide up to ten unique private document references.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new ResidentMembershipError('INVALID_TIMESTAMP', 'A valid submission timestamp is required.');
  }

  const submittedAt = new Date(now).toISOString();
  const request = Object.freeze({
    id: requestId,
    userId: applicantUserId,
    estateId,
    propertyId: property?.id || null,
    relationship,
    applicantNote: note.trim(),
    evidenceDocumentIds: Object.freeze([...evidenceDocumentIds]),
    status: JoinRequestStatus.SUBMITTED,
    submittedAt,
  });
  return Object.freeze({
    transactionRequired: true,
    request,
    effects: Object.freeze([Object.freeze({ type: 'resident_join_request.submitted', requestId, applicantUserId, estateId, propertyId: request.propertyId, submittedAt })]),
    auditEvent: Object.freeze({
      actorUserId: applicantUserId,
      scope: 'estate',
      estateId,
      action: 'resident_join_request.submitted',
      targetType: 'resident_join_request',
      targetId: requestId,
      outcome: 'success',
      occurredAt: submittedAt,
      metadata: Object.freeze({ propertyId: request.propertyId, relationship, evidenceDocumentCount: evidenceDocumentIds.length }),
    }),
  });
}

function planJoinRequestDecision(request, input) {
  if (!request?.id || !request.estateId || !request.userId) {
    throw new ResidentMembershipError('INVALID_JOIN_REQUEST', 'A persisted join request is required.');
  }
  const { decision, actorUserId, now, reason, property } = input ?? {};
  if (!actorUserId) {
    throw new ResidentMembershipError('MISSING_ACTOR', 'The authenticated reviewer is required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new ResidentMembershipError('INVALID_TIMESTAMP', 'A valid decision timestamp is required.');
  }
  if (request.status !== JoinRequestStatus.SUBMITTED) {
    throw new ResidentMembershipError('INVALID_STATE', 'Only a submitted join request can receive a decision.');
  }
  if (![JoinRequestDecision.APPROVE, JoinRequestDecision.REJECT].includes(decision)) {
    throw new ResidentMembershipError('INVALID_DECISION', 'Choose approve or reject.');
  }

  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (decision === JoinRequestDecision.REJECT && !normalizedReason) {
    throw new ResidentMembershipError('REASON_REQUIRED', 'A reason is required to reject a join request.');
  }
  if (decision === JoinRequestDecision.APPROVE && request.propertyId) {
    if (!property?.id || property.id !== request.propertyId || property.estateId !== request.estateId) {
      throw new ResidentMembershipError('PROPERTY_SCOPE_MISMATCH', 'The requested property must belong to this estate.');
    }
    if (!Object.values(OccupantRelationship).includes(request.relationship)) {
      throw new ResidentMembershipError('INVALID_RELATIONSHIP', 'Choose a supported property relationship.');
    }
  }

  const decidedAt = new Date(now).toISOString();
  const nextStatus = decision === JoinRequestDecision.APPROVE
    ? JoinRequestStatus.APPROVED
    : JoinRequestStatus.REJECTED;
  const effects = [
    {
      type: 'resident_join_request.decided',
      requestId: request.id,
      estateId: request.estateId,
      from: request.status,
      to: nextStatus,
      actorUserId,
      reason: normalizedReason || null,
      decidedAt,
    },
  ];

  if (decision === JoinRequestDecision.APPROVE) {
    effects.push({
      type: 'resident_membership.activate_or_create',
      estateId: request.estateId,
      userId: request.userId,
      grantedByUserId: actorUserId,
      grantedAt: decidedAt,
    });
    if (request.propertyId) {
      effects.push({
        type: 'property_occupancy.create',
        estateId: request.estateId,
        propertyId: request.propertyId,
        userId: request.userId,
        relationship: request.relationship,
        approvedByUserId: actorUserId,
        approvedAt: decidedAt,
      });
    }
  }

  return Object.freeze({
    transactionRequired: true,
    requestId: request.id,
    nextStatus,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: request.estateId,
      action: `resident_join_request.${decision}`,
      targetType: 'resident_join_request',
      targetId: request.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: decidedAt,
    }),
  });
}

module.exports = {
  JoinRequestRelationships,
  JoinRequestDecision,
  JoinRequestStatus,
  OccupantRelationship,
  ResidentMembershipError,
  planJoinRequestCreation,
  planJoinRequestDecision,
};
