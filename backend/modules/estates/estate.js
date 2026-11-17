const OperationalEstateStatus = Object.freeze({
  ACTIVE: 'active',
  SUSPENDED: 'suspended',
  DEACTIVATED: 'deactivated',
});

const EstateType = Object.freeze({
  GATED_COMMUNITY: 'gated_community',
  RESIDENTIAL: 'residential',
  APARTMENT_COMMUNITY: 'apartment_community',
  COMMERCIAL: 'commercial',
  MIXED_USE: 'mixed_use',
});

const validEstateTypes = new Set(Object.values(EstateType));

class EstateError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateError';
    this.code = code;
  }
}

function requiredText(value, field, maxLength) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > maxLength) {
    throw new EstateError('INVALID_FIELD', `${field} must be non-empty text of at most ${maxLength} characters.`);
  }
  return value.trim();
}

/** Build the approved operational estate from a reviewed application and trusted IDs. */
function createEstateFromApproval({
  estateId,
  application,
  approvedByUserId,
  estateCode,
  now,
  timezone,
  currency,
} = {}) {
  if (!estateId || !approvedByUserId || !application?.id) {
    throw new EstateError('INVALID_APPROVAL', 'Estate ID, approved application and approving actor are required.');
  }
  if (application.status !== 'approved') {
    throw new EstateError('APPLICATION_NOT_APPROVED', 'An estate can only be created from an approved application.');
  }
  const code = requiredText(estateCode, 'Estate code', 40);
  if (!/^[A-Z0-9][A-Z0-9_-]*$/.test(code)) {
    throw new EstateError('INVALID_ESTATE_CODE', 'Estate code must use uppercase letters, numbers, underscores or hyphens.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new EstateError('INVALID_TIMESTAMP', 'A valid approval timestamp is required.');
  }
  const approvedAt = new Date(now).toISOString();
  if (!validEstateTypes.has(application.estateType)) {
    throw new EstateError('INVALID_ESTATE_TYPE', 'The approved application must have a supported estate type.');
  }
  const latitude = application.latitude ?? null;
  const longitude = application.longitude ?? null;
  if ((latitude === null) !== (longitude === null)
    || (latitude !== null && (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
      || !Number.isFinite(longitude) || longitude < -180 || longitude > 180))) {
    throw new EstateError('INVALID_COORDINATES', 'Estate coordinates must be a valid latitude and longitude pair.');
  }

  const estate = {
    id: estateId,
    code,
    name: requiredText(application.proposedName, 'Estate name', 120),
    type: application.estateType,
    address: requiredText(application.address, 'Estate address', 180),
    state: requiredText(application.state, 'State', 100),
    lga: requiredText(application.lga, 'LGA', 100),
    latitude,
    longitude,
    status: OperationalEstateStatus.ACTIVE,
    approvedApplicationId: application.id,
    approvedAt,
    approvedByUserId,
    createdAt: approvedAt,
    updatedAt: approvedAt,
  };
  if (timezone !== undefined) estate.timezone = requiredText(timezone, 'Timezone', 100);
  if (currency !== undefined) {
    if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
      throw new EstateError('INVALID_CURRENCY', 'Currency must be a three-letter uppercase code.');
    }
    estate.currency = currency;
  }
  return Object.freeze(estate);
}

/** Return an operational estate only if it is active and matches the selected context. */
function requireOperationalEstate(estate, estateId) {
  if (!estate?.id || String(estate.id) !== String(estateId)) {
    throw new EstateError('ESTATE_NOT_FOUND', 'The estate was not found in the selected context.');
  }
  if (estate.status !== OperationalEstateStatus.ACTIVE) {
    throw new EstateError('ESTATE_NOT_ACTIVE', 'This estate is not available for normal operations.');
  }
  return estate;
}

module.exports = { EstateError, EstateType, OperationalEstateStatus, createEstateFromApproval, requireOperationalEstate };
