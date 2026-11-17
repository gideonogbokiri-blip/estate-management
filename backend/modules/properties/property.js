const PropertyStatus = Object.freeze({
  ACTIVE: 'active',
  UNDER_DEVELOPMENT: 'under_development',
  RESERVED: 'reserved',
  UNDER_MAINTENANCE: 'under_maintenance',
  INACTIVE: 'inactive',
  ARCHIVED: 'archived',
});

const OccupancyStatus = Object.freeze({ VACANT: 'vacant', OCCUPIED: 'occupied' });

class PropertyDomainError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyDomainError';
    this.code = code;
  }
}

function deriveOccupancyStatus(effectiveOccupancies) {
  if (!Array.isArray(effectiveOccupancies)) {
    throw new PropertyDomainError('INVALID_OCCUPANCY_SET', 'Effective occupancy records must be provided as a list.');
  }
  return effectiveOccupancies.length > 0 ? OccupancyStatus.OCCUPIED : OccupancyStatus.VACANT;
}

function validatePropertyDraft(input) {
  const {
    estateId,
    code,
    propertyType,
    status,
    parents = [],
    unitNumber,
    address,
    description,
    latitude,
    longitude,
  } = input ?? {};
  if (!estateId || typeof code !== 'string' || !code.trim() || typeof propertyType !== 'string' || !propertyType.trim()) {
    throw new PropertyDomainError('INVALID_PROPERTY', 'Estate, property code, and property type are required.');
  }
  if (code.trim().length > 80 || propertyType.trim().length > 80) {
    throw new PropertyDomainError('INVALID_PROPERTY', 'Property code and type must be 80 characters or fewer.');
  }
  if (!Object.values(PropertyStatus).includes(status) || status === PropertyStatus.ARCHIVED) {
    throw new PropertyDomainError('INVALID_PROPERTY_STATUS', 'Choose a supported property status.');
  }
  if (!Array.isArray(parents)) {
    throw new PropertyDomainError('INVALID_HIERARCHY', 'Property hierarchy parents must be a list.');
  }
  for (const parent of parents) {
    if (!parent?.id || parent.estateId !== estateId) {
      throw new PropertyDomainError('CROSS_ESTATE_HIERARCHY', 'Every hierarchy parent must belong to the same estate.');
    }
  }
  if (new Set(parents.map((parent) => String(parent.id))).size !== parents.length) {
    throw new PropertyDomainError('DUPLICATE_HIERARCHY_PARENT', 'A hierarchy parent can only be linked once.');
  }

  for (const [field, value] of Object.entries({ unitNumber, address, description })) {
    if (value !== undefined && value !== null && typeof value !== 'string') {
      throw new PropertyDomainError('INVALID_PROPERTY_FIELD', `${field} must be text.`);
    }
  }
  const fieldLimits = { unitNumber: 80, address: 240, description: 700 };
  for (const [field, maximum] of Object.entries(fieldLimits)) {
    const value = input?.[field];
    if (typeof value === 'string' && value.trim().length > maximum) {
      throw new PropertyDomainError(
        'PROPERTY_FIELD_TOO_LONG',
        `${field} must be ${maximum} characters or fewer.`,
      );
    }
  }
  const hasLatitude = latitude !== undefined && latitude !== null && !(typeof latitude === 'string' && !latitude.trim());
  const hasLongitude = longitude !== undefined && longitude !== null && !(typeof longitude === 'string' && !longitude.trim());
  if (hasLatitude !== hasLongitude) {
    throw new PropertyDomainError('INCOMPLETE_COORDINATES', 'Provide both latitude and longitude, or neither.');
  }
  let normalizedLatitude = null;
  let normalizedLongitude = null;
  if (hasLatitude) {
    if (!['number', 'string'].includes(typeof latitude) || !['number', 'string'].includes(typeof longitude)) {
      throw new PropertyDomainError('INVALID_COORDINATE', 'Map coordinates must be numeric.');
    }
    normalizedLatitude = Number(latitude);
    normalizedLongitude = Number(longitude);
    if (!Number.isFinite(normalizedLatitude) || normalizedLatitude < -90 || normalizedLatitude > 90
      || !Number.isFinite(normalizedLongitude) || normalizedLongitude < -180 || normalizedLongitude > 180) {
      throw new PropertyDomainError('INVALID_COORDINATE', 'Map coordinates are outside their valid ranges.');
    }
  }

  return Object.freeze({
    estateId,
    code: code.trim(),
    propertyType: propertyType.trim(),
    status,
    unitNumber: typeof unitNumber === 'string' ? unitNumber.trim() || null : null,
    address: typeof address === 'string' ? address.trim() || null : null,
    description: typeof description === 'string' ? description.trim() || null : null,
    latitude: normalizedLatitude,
    longitude: normalizedLongitude,
    parentIds: Object.freeze(parents.map((parent) => parent.id)),
  });
}

/** Plan a non-destructive archive after the caller checks live relationships. */
function planPropertyArchive(property, { actorUserId, now, blockingRelationships } = {}) {
  if (!property?.id || !property.estateId) {
    throw new PropertyDomainError('INVALID_PROPERTY', 'A persisted property is required.');
  }
  if (!actorUserId) {
    throw new PropertyDomainError('MISSING_ACTOR', 'The authenticated actor is required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new PropertyDomainError('INVALID_TIMESTAMP', 'A valid archive timestamp is required.');
  }
  if (property.status === PropertyStatus.ARCHIVED) {
    throw new PropertyDomainError('ALREADY_ARCHIVED', 'The property is already archived.');
  }
  if (!Array.isArray(blockingRelationships)) {
    throw new PropertyDomainError('RELATIONSHIP_CHECK_REQUIRED', 'Check active estate relationships before archiving.');
  }
  if (blockingRelationships.length > 0) {
    throw new PropertyDomainError('ACTIVE_RELATIONSHIPS', 'Resolve active relationships before archiving this property.');
  }

  const archivedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    propertyId: property.id,
    estateId: property.estateId,
    effects: Object.freeze([Object.freeze({
      type: 'property.archived',
      propertyId: property.id,
      estateId: property.estateId,
      from: property.status,
      to: PropertyStatus.ARCHIVED,
      actorUserId,
      archivedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: property.estateId,
      action: 'property.archive',
      targetType: 'property',
      targetId: property.id,
      outcome: 'success',
      occurredAt: archivedAt,
    }),
  });
}

module.exports = {
  OccupancyStatus,
  PropertyDomainError,
  PropertyStatus,
  deriveOccupancyStatus,
  planPropertyArchive,
  validatePropertyDraft,
};
