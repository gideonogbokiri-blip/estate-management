const OccupancyRelationship = Object.freeze({
  TENANT: 'tenant',
  HOUSEHOLD_MEMBER: 'household_member',
  AUTHORIZED_OCCUPANT: 'authorized_occupant',
});
const OccupancyStatus = Object.freeze({ ACTIVE: 'active', ENDED: 'ended' });

class OccupancyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'OccupancyError';
    this.code = code;
  }
}

function isId(value) {
  return (typeof value === 'string' && value.trim().length > 0)
    || (typeof value === 'number' && Number.isFinite(value));
}

function isDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function planOccupancyCreation({ occupancyId, actorUserId, now, draft, property, linkValid } = {}) {
  if (!isId(occupancyId) || !isId(actorUserId) || !draft?.estateId || !isId(draft.propertyId) || !isId(draft.userId)) {
    throw new OccupancyError('INVALID_OCCUPANCY', 'Occupancy, actor, estate, property and user are required.');
  }
  if (!property?.id || property.id !== draft.propertyId || property.estateId !== draft.estateId) {
    throw new OccupancyError('PROPERTY_SCOPE_MISMATCH', 'The property must belong to the selected estate.');
  }
  if (![OccupancyRelationship.TENANT, OccupancyRelationship.HOUSEHOLD_MEMBER, OccupancyRelationship.AUTHORIZED_OCCUPANT].includes(draft.relationship)) {
    throw new OccupancyError('INVALID_RELATIONSHIP', 'Choose tenant, household_member, or authorized_occupant.');
  }
  if (linkValid !== true) {
    throw new OccupancyError('OCCUPANCY_LINK_REQUIRED', 'The user must have an approved estate membership and a valid tenant or occupant link.');
  }
  if (!isDate(draft.effectiveFrom) || (draft.effectiveTo != null && !isDate(draft.effectiveTo))
    || (draft.effectiveTo && draft.effectiveTo < draft.effectiveFrom)) {
    throw new OccupancyError('INVALID_OCCUPANCY_DATES', 'Occupancy dates must be valid and the end cannot precede the start.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new OccupancyError('INVALID_TIMESTAMP', 'A valid creation timestamp is required.');
  }

  const createdAt = new Date(now).toISOString();
  const occupancy = Object.freeze({
    id: occupancyId,
    estateId: draft.estateId,
    propertyId: draft.propertyId,
    userId: draft.userId,
    relationship: draft.relationship,
    effectiveFrom: draft.effectiveFrom,
    effectiveTo: draft.effectiveTo || null,
    status: OccupancyStatus.ACTIVE,
    approvedByUserId: actorUserId,
    approvedAt: createdAt,
    createdAt,
  });
  return Object.freeze({
    transactionRequired: true,
    occupancy,
    effects: Object.freeze([Object.freeze({ type: 'property_occupancy.created', occupancy })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: occupancy.estateId,
      action: 'property_occupancy.created',
      targetType: 'property_occupancy',
      targetId: occupancy.id,
      outcome: 'success',
      occurredAt: createdAt,
    }),
  });
}

function planOccupancyEnd(occupancy, { actorUserId, effectiveTo, reason, now, datePolicyAllowsEnd } = {}) {
  if (!occupancy?.id || !occupancy.estateId || !occupancy.propertyId || !occupancy.userId) {
    throw new OccupancyError('INVALID_OCCUPANCY', 'A persisted occupancy is required.');
  }
  if (!isId(actorUserId)) throw new OccupancyError('MISSING_ACTOR', 'The authenticated actor is required.');
  if (occupancy.status !== OccupancyStatus.ACTIVE) throw new OccupancyError('INVALID_STATE', 'Only active occupancy can be ended.');
  if (!isDate(effectiveTo) || effectiveTo < occupancy.effectiveFrom || datePolicyAllowsEnd !== true) {
    throw new OccupancyError('INVALID_END_DATE', 'The effective end date must pass estate date policy.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new OccupancyError('INVALID_TIMESTAMP', 'A valid end timestamp is required.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  const endedAt = new Date(now).toISOString();
  const changes = Object.freeze({ status: OccupancyStatus.ENDED, effectiveTo, endedByUserId: actorUserId, endedAt, endReason: normalizedReason || null });
  return Object.freeze({
    transactionRequired: true,
    occupancyId: occupancy.id,
    estateId: occupancy.estateId,
    changes,
    effects: Object.freeze([Object.freeze({ type: 'property_occupancy.ended', occupancyId: occupancy.id, ...changes })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: occupancy.estateId,
      action: 'property_occupancy.ended',
      targetType: 'property_occupancy',
      targetId: occupancy.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: endedAt,
    }),
  });
}

module.exports = { OccupancyError, OccupancyRelationship, OccupancyStatus, planOccupancyCreation, planOccupancyEnd };
