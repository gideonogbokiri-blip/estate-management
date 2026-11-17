const { safeFacility } = require('./list-resident-facilities');

class FacilityAvailabilityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityAvailabilityError';
    this.code = code;
  }
}

function canonicalInstant(value) {
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) return false;
  return new Date(value).toISOString() === value;
}

function estateDate(value, timezone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(value);
  const record = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${record.year}-${record.month}-${record.day}`;
}

function validCalendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function createFacilityAvailabilityUseCase({
  transaction,
  resolveResidentFacilityAccess,
  findBookableFacility,
  projectResidentFacility,
  loadFacilityAvailability,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveResidentFacilityAccess, findBookableFacility, projectResidentFacility, loadFacilityAvailability };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new FacilityAvailabilityError('MISSING_ADAPTER', `Facility availability adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new FacilityAvailabilityError('INVALID_CLOCK', 'A clock function is required.');

  return async function readFacilityAvailability({ actorUserId, estateId, facilityId, date } = {}) {
    if (!actorUserId || !estateId || !facilityId || !validCalendarDate(date)) {
      throw new FacilityAvailabilityError('INVALID_INPUT', 'Member, estate, facility and a calendar date are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveResidentFacilityAccess(tx, { actorUserId, estateId, facilityId });
      if (!access || String(access.userId) !== String(actorUserId) || String(access.estateId) !== String(estateId)
        || String(access.facilityId) !== String(facilityId) || access.active !== true || access.mayBook !== true) {
        throw new FacilityAvailabilityError('BOOKING_NOT_AUTHORIZED', 'The member cannot view availability for this facility.');
      }
      const facility = await findBookableFacility(tx, { estateId, facilityId });
      if (!facility || String(facility.id) !== String(facilityId) || String(facility.estateId) !== String(estateId)
        || facility.status !== 'active' || facility.bookable !== true) {
        throw new FacilityAvailabilityError('FACILITY_NOT_FOUND', 'The facility is not available in this estate.');
      }
      const projection = await projectResidentFacility({ tx, access, facility });
      const safe = safeFacility(facility, projection, estateId);
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new FacilityAvailabilityError('INVALID_CLOCK', 'The availability service clock is invalid.');
      const localToday = estateDate(now, safe.timezone);
      const dateOffset = (Date.parse(`${date}T00:00:00.000Z`) - Date.parse(`${localToday}T00:00:00.000Z`)) / 86400000;
      const maxWindow = facility.maximumBookingWindowDays;
      if (!Number.isInteger(maxWindow) || maxWindow < 0 || maxWindow > 365 || dateOffset < 0 || dateOffset > maxWindow) {
        throw new FacilityAvailabilityError('DATE_OUTSIDE_POLICY', 'Choose a date within the facility booking window.');
      }
      const calculated = await loadFacilityAvailability(tx, { estateId, facility, access, date, now: now.toISOString() });
      if (!calculated || !Array.isArray(calculated.slots) || calculated.slots.length > 100) {
        throw new FacilityAvailabilityError('INVALID_AVAILABILITY_RESULT', 'The availability service must return at most 100 server-calculated slots.');
      }
      const seen = new Set();
      const slots = calculated.slots.map((slot) => {
        if (!slot || !canonicalInstant(slot.startsAt) || !canonicalInstant(slot.endsAt)
          || Date.parse(slot.startsAt) <= now.getTime() || Date.parse(slot.endsAt) <= Date.parse(slot.startsAt)
          || estateDate(new Date(slot.startsAt), safe.timezone) !== date
          || Date.parse(slot.endsAt) - Date.parse(slot.startsAt) > facility.maximumDurationMs
          || slot.policyVersion !== facility.policyVersion
          || !Number.isSafeInteger(slot.remainingCapacity) || slot.remainingCapacity < 1
          || slot.remainingCapacity > facility.capacity) {
          throw new FacilityAvailabilityError('INVALID_AVAILABILITY_SLOT', 'The availability service returned an invalid or unavailable slot.');
        }
        const key = `${slot.startsAt}/${slot.endsAt}`;
        if (seen.has(key)) throw new FacilityAvailabilityError('DUPLICATE_AVAILABILITY_SLOT', 'The availability service returned a duplicate slot.');
        seen.add(key);
        return Object.freeze({
          startsAt: slot.startsAt, endsAt: slot.endsAt,
          remainingCapacity: slot.remainingCapacity,
          policyVersion: facility.policyVersion,
          fee: safe.fee,
        });
      });
      slots.sort((a, b) => Date.parse(a.startsAt) - Date.parse(b.startsAt));
      return Object.freeze({
        estateId, facilityId, date, timezone: safe.timezone,
        policyVersion: facility.policyVersion, asOf: now.toISOString(),
        items: Object.freeze(slots),
      });
    });
  };
}

module.exports = { FacilityAvailabilityError, createFacilityAvailabilityUseCase, validCalendarDate };
