const OwnershipStatus = Object.freeze({ ACTIVE: 'active', ENDED: 'ended' });
const OwnershipVerification = Object.freeze({
  NOT_REQUIRED: 'not_required',
  PENDING: 'pending',
  VERIFIED: 'verified',
  REJECTED: 'rejected',
});
const OwnershipDecision = Object.freeze({ VERIFY: 'verify', REJECT: 'reject' });

class OwnershipError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'OwnershipError';
    this.code = code;
  }
}

function isPresentId(value) {
  return (typeof value === 'string' && value.trim().length > 0)
    || (typeof value === 'number' && Number.isFinite(value));
}

function isCalendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function parseSharePercent(value, scale = 2) {
  if (typeof value !== 'string' || !Number.isInteger(scale) || scale < 0 || scale > 4
    || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(value)) {
    throw new OwnershipError('INVALID_OWNERSHIP_SHARE', 'Ownership share must be a decimal string.');
  }
  const [whole, fraction = ''] = value.split('.');
  if (fraction.length > scale) {
    throw new OwnershipError('INVALID_OWNERSHIP_SHARE_PRECISION', 'Ownership share exceeds the configured precision.');
  }
  const units = (BigInt(whole) * (10n ** BigInt(scale))) + BigInt(fraction.padEnd(scale, '0') || '0');
  const maximum = 100n * (10n ** BigInt(scale));
  if (units <= 0n || units > maximum) {
    throw new OwnershipError('INVALID_OWNERSHIP_SHARE', 'Ownership share must be greater than zero and no more than 100%.');
  }
  return units;
}

function prepareOwnershipInterest(input, {
  actorUserId,
  now,
  policy,
  canCoexist,
  shareCapacityAvailable,
  evidenceReferenceVerified,
} = {}) {
  const {
    estateId,
    propertyId,
    propertyEstateId,
    ownerUserId,
    legalEntityId,
    ownershipShare,
    effectiveFrom,
    effectiveTo,
    evidenceDocumentId,
  } = input ?? {};
  const hasOwnerUser = isPresentId(ownerUserId);
  const hasLegalEntity = isPresentId(legalEntityId);
  if (!isPresentId(estateId) || !isPresentId(propertyId) || propertyEstateId !== estateId
    || (hasOwnerUser === hasLegalEntity)) {
    throw new OwnershipError('INVALID_OWNERSHIP_SCOPE', 'Link one existing user or approved legal entity to a property in the same estate.');
  }
  if (!isPresentId(actorUserId) || !validTimestamp(now)) {
    throw new OwnershipError('INVALID_ACTOR_OR_TIMESTAMP', 'An authenticated actor and valid creation timestamp are required.');
  }
  if (!policy || typeof policy.allowMultipleOwners !== 'boolean'
    || typeof policy.trackOwnershipShare !== 'boolean'
    || typeof policy.verificationRequired !== 'boolean'
    || !Number.isInteger(policy.sharePrecision)) {
    throw new OwnershipError('OWNERSHIP_POLICY_REQUIRED', 'Load the estate ownership policy from a trusted service.');
  }
  if (!isCalendarDate(effectiveFrom) || (effectiveTo !== undefined && effectiveTo !== null && !isCalendarDate(effectiveTo))) {
    throw new OwnershipError('INVALID_EFFECTIVE_DATES', 'Ownership dates must be valid YYYY-MM-DD calendar dates.');
  }
  if (effectiveTo && effectiveTo < effectiveFrom) {
    throw new OwnershipError('INVALID_EFFECTIVE_DATES', 'Ownership end date cannot be before its start date.');
  }
  if (canCoexist !== true) {
    throw new OwnershipError('OWNERSHIP_CONFLICT', 'The proposed ownership conflicts with current estate ownership policy or effective records.');
  }
  let normalizedShare = null;
  if (policy.trackOwnershipShare) {
    if (ownershipShare === undefined || ownershipShare === null) {
      throw new OwnershipError('OWNERSHIP_SHARE_REQUIRED', 'Provide an ownership share under the estate policy.');
    }
    const units = parseSharePercent(ownershipShare, policy.sharePrecision);
    if (shareCapacityAvailable !== true) {
      throw new OwnershipError('OWNERSHIP_SHARE_OVERALLOCATED', 'The proposed share exceeds the available property ownership share.');
    }
    const scale = policy.sharePrecision;
    const base = 10n ** BigInt(scale);
    const whole = units / base;
    const fraction = (units % base).toString().padStart(scale, '0');
    normalizedShare = scale === 0 ? whole.toString() : `${whole}.${fraction}`;
  } else if (ownershipShare !== undefined && ownershipShare !== null) {
    throw new OwnershipError('OWNERSHIP_SHARE_DISABLED', 'Ownership shares are not enabled for this estate.');
  }

  if (policy.evidenceRequiredAtCreate === true && !isPresentId(evidenceDocumentId)) {
    throw new OwnershipError('OWNERSHIP_EVIDENCE_REQUIRED', 'Provide an authorized private evidence reference for ownership review.');
  }
  if (evidenceDocumentId !== undefined && evidenceDocumentId !== null && evidenceReferenceVerified !== true) {
    throw new OwnershipError('OWNERSHIP_EVIDENCE_UNVERIFIED', 'The evidence reference must be verified by the private file service.');
  }

  const createdAt = new Date(now).toISOString();
  const record = Object.freeze({
    estateId,
    propertyId,
    ownerUserId: ownerUserId ?? null,
    legalEntityId: legalEntityId ?? null,
    ownershipShare: normalizedShare,
    effectiveFrom,
    effectiveTo: effectiveTo ?? null,
    status: OwnershipStatus.ACTIVE,
    verificationStatus: policy.verificationRequired ? OwnershipVerification.PENDING : OwnershipVerification.NOT_REQUIRED,
    evidenceDocumentId: evidenceDocumentId ?? null,
    createdByUserId: actorUserId,
    createdAt,
  });
  return Object.freeze({
    transactionRequired: true,
    record,
    effects: Object.freeze([Object.freeze({ type: 'ownership_interest.created', ownership: record })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId,
      action: 'ownership.created',
      targetType: 'property',
      targetId: propertyId,
      outcome: 'success',
      occurredAt: createdAt,
      metadata: Object.freeze({ verificationStatus: record.verificationStatus }),
    }),
  });
}

function planOwnershipVerification(ownership, {
  actorUserId,
  decision,
  now,
  reason,
  evidenceReferenceVerified,
} = {}) {
  if (!ownership?.id || !isPresentId(ownership.estateId) || !isPresentId(ownership.propertyId)) {
    throw new OwnershipError('INVALID_OWNERSHIP', 'A persisted ownership interest is required.');
  }
  if (!isPresentId(actorUserId) || !validTimestamp(now)) {
    throw new OwnershipError('INVALID_ACTOR_OR_TIMESTAMP', 'An authenticated reviewer and valid decision timestamp are required.');
  }
  if (ownership.status !== OwnershipStatus.ACTIVE || ownership.verificationStatus !== OwnershipVerification.PENDING) {
    throw new OwnershipError('INVALID_STATE', 'Only an active pending ownership interest can be reviewed.');
  }
  if (![OwnershipDecision.VERIFY, OwnershipDecision.REJECT].includes(decision)) {
    throw new OwnershipError('INVALID_DECISION', 'Choose verify or reject.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (decision === OwnershipDecision.REJECT && !normalizedReason) {
    throw new OwnershipError('REASON_REQUIRED', 'A reason is required to reject ownership evidence.');
  }
  if (decision === OwnershipDecision.VERIFY && (!ownership.evidenceDocumentId || evidenceReferenceVerified !== true)) {
    throw new OwnershipError('OWNERSHIP_EVIDENCE_UNVERIFIED', 'Verify the private evidence reference before approving ownership.');
  }

  const verifiedAt = new Date(now).toISOString();
  const verificationStatus = decision === OwnershipDecision.VERIFY
    ? OwnershipVerification.VERIFIED
    : OwnershipVerification.REJECTED;
  return Object.freeze({
    transactionRequired: true,
    ownershipId: ownership.id,
    verificationStatus,
    effects: Object.freeze([Object.freeze({
      type: 'ownership.verification_decided',
      ownershipId: ownership.id,
      estateId: ownership.estateId,
      from: ownership.verificationStatus,
      to: verificationStatus,
      actorUserId,
      reason: normalizedReason || null,
      decidedAt: verifiedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: ownership.estateId,
      action: `ownership.${decision}`,
      targetType: 'ownership_interest',
      targetId: ownership.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: verifiedAt,
    }),
  });
}

function planOwnershipEnd(ownership, {
  actorUserId,
  now,
  effectiveTo,
  datePolicyAllowsEnd,
  reason,
} = {}) {
  if (!ownership?.id || !isPresentId(ownership.estateId) || !isPresentId(ownership.propertyId)) {
    throw new OwnershipError('INVALID_OWNERSHIP', 'A persisted ownership interest is required.');
  }
  if (!isPresentId(actorUserId) || !validTimestamp(now)) {
    throw new OwnershipError('INVALID_ACTOR_OR_TIMESTAMP', 'An authenticated actor and valid end timestamp are required.');
  }
  if (ownership.status !== OwnershipStatus.ACTIVE) {
    throw new OwnershipError('INVALID_STATE', 'Only an active ownership interest can be ended.');
  }
  if (!isCalendarDate(effectiveTo) || effectiveTo < ownership.effectiveFrom || datePolicyAllowsEnd !== true) {
    throw new OwnershipError('INVALID_EFFECTIVE_END', 'The ownership end date must be valid under the estate date policy.');
  }
  const endedAt = new Date(now).toISOString();
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  return Object.freeze({
    transactionRequired: true,
    ownershipId: ownership.id,
    estateId: ownership.estateId,
    effectiveTo,
    effects: Object.freeze([Object.freeze({
      type: 'ownership_interest.ended',
      ownershipId: ownership.id,
      estateId: ownership.estateId,
      from: ownership.status,
      to: OwnershipStatus.ENDED,
      effectiveTo,
      actorUserId,
      reason: normalizedReason || null,
      endedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: ownership.estateId,
      action: 'ownership.end',
      targetType: 'ownership_interest',
      targetId: ownership.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: endedAt,
    }),
  });
}

function validTimestamp(value) {
  return value !== undefined && value !== null && value !== '' && !Number.isNaN(new Date(value).getTime());
}

module.exports = {
  OwnershipDecision,
  OwnershipError,
  OwnershipStatus,
  OwnershipVerification,
  parseSharePercent,
  planOwnershipEnd,
  planOwnershipVerification,
  prepareOwnershipInterest,
};
