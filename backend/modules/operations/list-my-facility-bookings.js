const { BookingStatus } = require('./facility-booking');

class MyFacilityBookingListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyFacilityBookingListError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(BookingStatus));
const fields = new Set([
  'bookingId', 'estateId', 'facilityId', 'facilityLabel', 'locationLabel',
  'timezone', 'startsAt', 'endsAt', 'attendeeCount', 'status', 'policyVersion', 'feeInvoiceId', 'fee',
]);

function safeBooking(booking, projection, actorUserId, estateId) {
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  const sameNullableId = (a, b) => (a === null || a === undefined)
    ? (b === null || b === undefined)
    : b !== null && b !== undefined && sameId(a, b);
  const instant = (value) => typeof value === 'string' && !Number.isNaN(Date.parse(value))
    && new Date(value).toISOString() === value;
  if (!booking?.id || !sameId(booking.estateId, estateId) || !sameId(booking.requesterUserId, actorUserId)
    || !booking.facilityId || !statuses.has(booking.status) || !instant(booking.startsAt) || !instant(booking.endsAt)
    || Date.parse(booking.endsAt) <= Date.parse(booking.startsAt)
    || !Number.isSafeInteger(booking.attendeeCount) || booking.attendeeCount < 1
    || typeof booking.policyVersion !== 'string' || !booking.policyVersion.trim()
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => !fields.has(key))
    || !sameId(projection.bookingId, booking.id) || !sameId(projection.estateId, booking.estateId)
    || !sameId(projection.facilityId, booking.facilityId) || projection.startsAt !== booking.startsAt
    || projection.endsAt !== booking.endsAt || projection.attendeeCount !== booking.attendeeCount
    || projection.status !== booking.status || projection.policyVersion !== booking.policyVersion
    || !sameNullableId(projection.feeInvoiceId, booking.feeInvoiceId ?? null)) {
    throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', 'Booking summaries must match the authenticated resident and source booking.');
  }
  try { new Intl.DateTimeFormat('en', { timeZone: projection.timezone }).format(new Date(booking.startsAt)); }
  catch { throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', 'Booking timezone is invalid.'); }
  const text = (value, field, limit) => {
    if (typeof value !== 'string' || !value.trim() || value.length > limit) {
      throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', `${field} must be bounded display text.`);
    }
    return value.trim();
  };
  let fee = null;
  if (booking.fee) {
    if (!projection.fee || projection.fee.amount !== booking.fee.amount || projection.fee.currency !== booking.fee.currency
      || projection.fee.currencyScale !== booking.fee.currencyScale) {
      throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', 'Booking fee details must match the captured fee terms.');
    }
    fee = Object.freeze({
      amount: text(projection.fee.amount, 'Booking fee', 32),
      currency: text(projection.fee.currency, 'Booking currency', 3),
      currencyScale: projection.fee.currencyScale,
    });
    if (!/^[A-Z]{3}$/.test(fee.currency) || !Number.isInteger(fee.currencyScale)
      || fee.currencyScale < 0 || fee.currencyScale > 6) {
      throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', 'Booking currency terms are invalid.');
    }
  } else if (projection.fee !== null && projection.fee !== undefined) {
    throw new MyFacilityBookingListError('INVALID_BOOKING_PROJECTION', 'A booking without a fee cannot expose fee details.');
  }
  return Object.freeze({
    bookingId: booking.id, estateId, facilityId: booking.facilityId,
    facilityLabel: text(projection.facilityLabel, 'Facility label', 160),
    timezone: projection.timezone,
    locationLabel: typeof projection.locationLabel === 'string' && projection.locationLabel.trim()
      ? text(projection.locationLabel, 'Facility location', 160) : null,
    startsAt: booking.startsAt, endsAt: booking.endsAt, attendeeCount: booking.attendeeCount,
    status: booking.status, policyVersion: booking.policyVersion,
    feeInvoiceId: booking.feeInvoiceId ?? null, fee,
  });
}

function createMyFacilityBookingListUseCase({
  transaction,
  resolveResidentEstateAccess,
  queryMyFacilityBookings,
  projectMyFacilityBooking,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveResidentEstateAccess, queryMyFacilityBookings, projectMyFacilityBooking };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyFacilityBookingListError('MISSING_ADAPTER', `Resident booking adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new MyFacilityBookingListError('INVALID_CLOCK', 'A clock function is required.');

  return async function listMyFacilityBookings({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new MyFacilityBookingListError('INVALID_INPUT', 'Authenticated estate membership is required.');
    return transaction(async (tx) => {
      const access = await resolveResidentEstateAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId) || String(access.estateId) !== String(estateId)
        || access.active !== true || access.mayViewBookings !== true) {
        throw new MyFacilityBookingListError('BOOKING_ACCESS_DENIED', 'The member cannot view bookings in this estate.');
      }
      const bookings = await queryMyFacilityBookings(tx, { actorUserId, estateId, limit: 100 });
      if (!Array.isArray(bookings) || bookings.length > 100) {
        throw new MyFacilityBookingListError('INVALID_REPOSITORY_RESULT', 'The resident booking query must return at most 100 records.');
      }
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new MyFacilityBookingListError('INVALID_CLOCK', 'The booking list clock is invalid.');
      const ids = new Set();
      const items = [];
      for (const booking of bookings) {
        if (!booking?.id || ids.has(String(booking.id))) {
          throw new MyFacilityBookingListError('DUPLICATE_BOOKING', 'The resident booking query returned a duplicate booking.');
        }
        ids.add(String(booking.id));
        const projection = await projectMyFacilityBooking({ tx, access, booking });
        items.push(safeBooking(booking, projection, actorUserId, estateId));
      }
      return Object.freeze({ estateId, asOf: now.toISOString(), items: Object.freeze(items) });
    });
  };
}

module.exports = { MyFacilityBookingListError, createMyFacilityBookingListUseCase, safeBooking };
