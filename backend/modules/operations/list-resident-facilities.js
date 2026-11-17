const { normalizeDecimal, toMinorUnits } = require('../billing/money');

class ResidentFacilityListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentFacilityListError';
    this.code = code;
  }
}

const fields = new Set([
  'facilityId', 'estateId', 'name', 'description', 'locationLabel', 'capacity',
  'durationMinutes', 'maximumBookingWindowDays', 'policyVersion', 'policySummary', 'timezone', 'approvalMode', 'fee',
]);

function boundedText(value, field, limit, optional = false) {
  if (optional && (value === null || value === undefined || value === '')) return null;
  if (typeof value !== 'string' || !value.trim() || value.length > limit) {
    throw new ResidentFacilityListError('INVALID_FACILITY_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function safeFacility(facility, projection, estateId) {
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  if (!facility?.id || !sameId(facility.estateId, estateId) || facility.status !== 'active' || facility.bookable !== true
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => !fields.has(key))
    || !sameId(projection.facilityId, facility.id) || !sameId(projection.estateId, facility.estateId)) {
    throw new ResidentFacilityListError('INVALID_FACILITY_PROJECTION', 'Facility display values must match an active bookable source facility in this estate.');
  }
  const durationMinutes = facility.maximumDurationMs / 60000;
  if (!Number.isSafeInteger(facility.capacity) || facility.capacity < 1 || facility.capacity > 10000
    || !Number.isSafeInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 10080
    || !Number.isInteger(facility.maximumBookingWindowDays) || facility.maximumBookingWindowDays < 0 || facility.maximumBookingWindowDays > 365
    || typeof facility.policyVersion !== 'string' || !facility.policyVersion.trim() || facility.policyVersion.length > 100
    || !['automatic', 'manual'].includes(facility.approvalMode)) {
    throw new ResidentFacilityListError('INVALID_FACILITY', 'Facility capacity, duration, policy or approval configuration is invalid.');
  }
  try { new Intl.DateTimeFormat('en', { timeZone: facility.timezone }).format(new Date()); }
  catch { throw new ResidentFacilityListError('INVALID_FACILITY_TIMEZONE', 'The facility estate timezone is invalid.'); }
  const fee = facility.fee == null ? null : facility.fee;
  let safeFee = null;
  if (fee !== null) {
    if (!fee || typeof fee !== 'object' || Array.isArray(fee) || !Number.isInteger(fee.currencyScale)
      || fee.currencyScale < 0 || fee.currencyScale > 6 || !/^[A-Z]{3}$/.test(fee.currency ?? '')) {
      throw new ResidentFacilityListError('INVALID_FACILITY_FEE', 'The facility fee policy is invalid.');
    }
    let amount;
    try { amount = normalizeDecimal(fee.amount, fee.currencyScale); }
    catch { throw new ResidentFacilityListError('INVALID_FACILITY_FEE', 'The facility fee must use a valid decimal amount.'); }
    if (toMinorUnits(amount, fee.currencyScale) <= 0n) {
      throw new ResidentFacilityListError('INVALID_FACILITY_FEE', 'The facility fee must be a positive amount.');
    }
    safeFee = Object.freeze({ amount, currency: fee.currency, currencyScale: fee.currencyScale });
  }
  const projectedFeeMatches = projection.fee === undefined || (fee === null
    ? projection.fee === null
    : projection.fee && projection.fee.amount === fee.amount
      && projection.fee.currency === fee.currency && projection.fee.currencyScale === fee.currencyScale);
  if (projection.capacity !== facility.capacity || projection.durationMinutes !== durationMinutes
    || projection.maximumBookingWindowDays !== facility.maximumBookingWindowDays
    || projection.policyVersion !== facility.policyVersion || projection.approvalMode !== facility.approvalMode
    || !projectedFeeMatches) {
    throw new ResidentFacilityListError('INVALID_FACILITY_PROJECTION', 'Facility policy summaries must match the active facility version.');
  }
  if (projection.timezone !== facility.timezone) {
    throw new ResidentFacilityListError('INVALID_FACILITY_PROJECTION', 'Facility timezone must match its estate configuration.');
  }
  return Object.freeze({
    facilityId: facility.id,
    estateId,
    name: boundedText(projection.name, 'Facility name', 120),
    description: boundedText(projection.description, 'Facility description', 300, true),
    locationLabel: boundedText(projection.locationLabel, 'Facility location', 160, true),
    capacity: facility.capacity,
    durationMinutes,
    maximumBookingWindowDays: facility.maximumBookingWindowDays,
    policyVersion: facility.policyVersion,
    policySummary: boundedText(projection.policySummary, 'Facility booking policy', 1000),
    timezone: facility.timezone,
    approvalMode: facility.approvalMode,
    fee: safeFee,
  });
}

function createResidentFacilityListUseCase({
  transaction,
  resolveResidentEstateAccess,
  queryBookableFacilities,
  projectResidentFacility,
} = {}) {
  const ports = { transaction, resolveResidentEstateAccess, queryBookableFacilities, projectResidentFacility };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ResidentFacilityListError('MISSING_ADAPTER', `Resident facility adapters are required: ${missing.join(', ')}.`);

  return async function listResidentFacilities({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new ResidentFacilityListError('INVALID_INPUT', 'Authenticated estate membership is required.');
    return transaction(async (tx) => {
      const access = await resolveResidentEstateAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId) || access.active !== true || access.mayViewFacilities !== true) {
        throw new ResidentFacilityListError('FACILITY_ACCESS_DENIED', 'The member cannot view facilities in this estate.');
      }
      const facilities = await queryBookableFacilities(tx, { estateId, access, limit: 100 });
      if (!Array.isArray(facilities) || facilities.length > 100) {
        throw new ResidentFacilityListError('INVALID_REPOSITORY_RESULT', 'The facility query must return at most 100 records.');
      }
      const ids = new Set();
      const items = [];
      for (const facility of facilities) {
        if (!facility?.id || ids.has(String(facility.id))) {
          throw new ResidentFacilityListError('DUPLICATE_FACILITY', 'The facility query returned an invalid or duplicate facility.');
        }
        ids.add(String(facility.id));
        const projection = await projectResidentFacility({ tx, access, facility });
        items.push(safeFacility(facility, projection, estateId));
      }
      return Object.freeze({ estateId, items: Object.freeze(items) });
    });
  };
}

module.exports = { ResidentFacilityListError, createResidentFacilityListUseCase, safeFacility };
