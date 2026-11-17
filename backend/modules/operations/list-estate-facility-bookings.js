const { BookingStatus } = require('./facility-booking');

class FacilityBookingListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityBookingListError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(BookingStatus));
const projectionFields = new Set([
  'id', 'facilityId', 'requesterUserId', 'propertyId', 'facilityLabel', 'requesterLabel',
  'propertyLabel', 'startsAt', 'endsAt', 'attendeeCount', 'status',
]);

function validInstant(value) {
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) return false;
  return new Date(value).toISOString() === value;
}

function normalizeQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new FacilityBookingListError('INVALID_QUERY', 'Booking filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new FacilityBookingListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status && !statuses.has(query.status)) {
    throw new FacilityBookingListError('INVALID_STATUS_FILTER', 'Choose a supported facility booking status.');
  }
  const search = typeof query.search === 'string' ? query.search.trim() : '';
  if (query.search !== undefined && typeof query.search !== 'string' || search.length > 100) {
    throw new FacilityBookingListError('INVALID_SEARCH', 'Search must be text of at most 100 characters.');
  }
  const filters = {};
  if (query.status) filters.status = query.status;
  if (search) filters.search = search;
  for (const field of ['facilityId', 'requesterUserId', 'propertyId']) {
    const value = query[field];
    if (value !== undefined && value !== null && value !== '') {
      if (!['string', 'number'].includes(typeof value) || !String(value).trim()
        || (typeof value === 'number' && !Number.isFinite(value))) {
        throw new FacilityBookingListError('INVALID_FILTER', `${field} is invalid.`);
      }
      filters[field] = value;
    }
  }
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters) });
}

function safeBookingSummary(booking, projection, estateId) {
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  const validId = (value) => ['string', 'number'].includes(typeof value) && String(value).trim() !== ''
    && (typeof value !== 'number' || Number.isFinite(value));
  if (!validId(booking?.id) || !validId(booking?.facilityId) || !validId(booking?.requesterUserId)
    || (booking.propertyId !== null && booking.propertyId !== undefined && !validId(booking.propertyId))
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || !sameId(projection.id, booking.id) || !sameId(projection.facilityId, booking.facilityId)
    || !sameId(projection.requesterUserId, booking.requesterUserId)
    || !sameId(projection.propertyId, booking.propertyId)
    || projection.startsAt !== booking.startsAt || projection.endsAt !== booking.endsAt
    || projection.attendeeCount !== booking.attendeeCount || projection.status !== booking.status) {
    throw new FacilityBookingListError('INVALID_PROJECTION', 'Booking labels must match the source facility, requester and booking record.');
  }
  if (!statuses.has(booking.status) || !validInstant(booking.startsAt) || !validInstant(booking.endsAt)
    || Date.parse(booking.endsAt) <= Date.parse(booking.startsAt)
    || !Number.isSafeInteger(booking.attendeeCount) || booking.attendeeCount < 1) {
    throw new FacilityBookingListError('INVALID_BOOKING', 'Booking status, times or attendee count are invalid.');
  }
  const boundedText = (value, field, maxLength, optional = false) => {
    if (optional && (value === null || value === undefined || value === '')) return null;
    if (typeof value !== 'string' || !value.trim() || value.length > maxLength) {
      throw new FacilityBookingListError('INVALID_PROJECTION', `${field} must be bounded display text.`);
    }
    return value.trim();
  };
  const propertyLabel = boundedText(projection.propertyLabel, 'Property label', 160, true);
  if ((booking.propertyId === null || booking.propertyId === undefined) && propertyLabel !== null) {
    throw new FacilityBookingListError('INVALID_PROJECTION', 'A booking without a property cannot have a property label.');
  }
  if (booking.propertyId !== null && booking.propertyId !== undefined && propertyLabel === null) {
    throw new FacilityBookingListError('INVALID_PROJECTION', 'Property bookings require an authorized property label.');
  }
  return Object.freeze({
    id: booking.id,
    estateId,
    facilityLabel: boundedText(projection.facilityLabel, 'Facility label', 160),
    requesterLabel: boundedText(projection.requesterLabel, 'Requester label', 160),
    propertyLabel,
    startsAt: booking.startsAt,
    endsAt: booking.endsAt,
    attendeeCount: booking.attendeeCount,
    status: booking.status,
  });
}

/** Estate-scoped booking manager read; adapters apply scope before filtering and pagination. */
function createEstateFacilityBookingListUseCase({
  transaction,
  requireEstatePermission,
  queryFacilityBookings,
  projectFacilityBookingForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryFacilityBookings, projectFacilityBookingForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new FacilityBookingListError('MISSING_ADAPTER', `Facility booking list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateFacilityBookings({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new FacilityBookingListError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizeQuery(query);
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'facility.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new FacilityBookingListError('ESTATE_ACCESS_DENIED', 'The actor cannot view facility bookings in this estate.');
      }
      const result = await queryFacilityBookings(tx, { estateContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new FacilityBookingListError('INVALID_REPOSITORY_RESULT', 'The booking query must return a bounded page and authorized total.');
      }
      if (result.items.some((booking) => !booking?.id || booking.estateId !== estateId)) {
        throw new FacilityBookingListError('ESTATE_SCOPE_VIOLATION', 'The repository returned a booking outside the selected estate.');
      }
      const bookingIds = new Set(result.items.map((booking) => String(booking.id)));
      if (bookingIds.size !== result.items.length) {
        throw new FacilityBookingListError('DUPLICATE_BOOKING', 'The booking query returned duplicate records.');
      }
      const items = [];
      for (const booking of result.items) {
        const projection = await projectFacilityBookingForActor({ actorUserId, estateContext, booking, tx });
        items.push(safeBookingSummary(booking, projection, estateId));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
      });
    });
  };
}

module.exports = { FacilityBookingListError, createEstateFacilityBookingListUseCase, normalizeQuery, safeBookingSummary };
