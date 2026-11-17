const { createHash, createHmac } = require('node:crypto');
const { FacilityBookingError, prepareBookingRequest } = require('./facility-booking');

class FacilityBookingCreationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityBookingCreationError';
    this.code = code;
  }
}

function sameId(a, b) {
  return a !== null && a !== undefined && b !== null && b !== undefined && String(a) === String(b);
}
function sameNullableId(a, b) {
  if (a === null || a === undefined) return b === null || b === undefined;
  if (b === null || b === undefined) return false;
  return sameId(a, b);
}

function createFacilityBookingUseCase({
  transaction,
  resolveResidentFacilityAccess,
  findFacilityForUpdate,
  findPropertyForUpdate,
  loadFacilityAvailability,
  generateBookingId,
  createFacilityBookingRecord,
  createFacilityBookingFeeInvoice,
  linkFacilityBookingFeeInvoice,
  appendAuditEvent,
  enqueueBookingNotice,
  readBookingCreationIdempotency,
  claimBookingCreationIdempotency,
  completeBookingCreationIdempotency,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction, resolveResidentFacilityAccess, findFacilityForUpdate, findPropertyForUpdate,
    loadFacilityAvailability, generateBookingId, createFacilityBookingRecord,
    createFacilityBookingFeeInvoice, linkFacilityBookingFeeInvoice, appendAuditEvent, enqueueBookingNotice,
    readBookingCreationIdempotency, claimBookingCreationIdempotency, completeBookingCreationIdempotency,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new FacilityBookingCreationError('MISSING_ADAPTER', `Facility booking adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new FacilityBookingCreationError('INVALID_CLOCK', 'A clock function is required.');

  return async function createFacilityBooking({
    actorUserId, estateId, facilityId, startsAt, endsAt, attendeeCount,
    purpose = '', acceptedPolicyVersion, idempotencyKey,
  } = {}) {
    if (!actorUserId || !estateId || !facilityId) {
      throw new FacilityBookingCreationError('INVALID_BOOKING_INPUT', 'Authenticated resident, estate and facility context are required.');
    }
    if (!Number.isSafeInteger(attendeeCount) || attendeeCount < 1
      || typeof acceptedPolicyVersion !== 'string' || !acceptedPolicyVersion.trim()
      || typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new FacilityBookingCreationError('INVALID_BOOKING_INPUT', 'Attendee count, accepted policy version and a valid request key are required.');
    }
    const normalizedPurpose = typeof purpose === 'string' ? purpose.trim() : '';
    if (normalizedPurpose.length > 250) throw new FacilityBookingCreationError('INVALID_PURPOSE', 'Purpose must be 250 characters or fewer.');
    const startsTime = new Date(startsAt).getTime();
    const endsTime = new Date(endsAt).getTime();
    if (!Number.isFinite(startsTime) || !Number.isFinite(endsTime)) {
      throw new FacilityBookingCreationError('INVALID_BOOKING_TIME', 'Choose a valid booking time.');
    }
    const normalizedStartsAt = new Date(startsTime).toISOString();
    const normalizedEndsAt = new Date(endsTime).toISOString();
    const idempotencyKeyHash = createHash('sha256').update(`facility-booking-create:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const scope = { actorUserId, estateId, idempotencyKeyHash };

    return transaction(async (tx) => {
      const access = await resolveResidentFacilityAccess(tx, { actorUserId, estateId, facilityId });
      if (!access || !sameId(access.userId, actorUserId) || !sameId(access.estateId, estateId)
        || !sameId(access.facilityId, facilityId) || access.active !== true || access.mayBook !== true) {
        throw new FacilityBookingCreationError('BOOKING_NOT_AUTHORIZED', 'The resident cannot request this facility in the selected estate.');
      }
      const facility = await findFacilityForUpdate(tx, { estateId, facilityId });
      if (!facility || !sameId(facility.id, facilityId) || !sameId(facility.estateId, estateId)) {
        throw new FacilityBookingCreationError('FACILITY_NOT_FOUND', 'The facility is not available in the selected estate.');
      }
      let property = null;
      if (access.propertyId !== null && access.propertyId !== undefined) {
        property = await findPropertyForUpdate(tx, { estateId, propertyId: access.propertyId });
        if (!property || !sameId(property.id, access.propertyId) || !sameId(property.estateId, estateId)
          || property.status === 'archived') {
          throw new FacilityBookingCreationError('PROPERTY_NOT_AVAILABLE', 'The resident property is not active in this estate.');
        }
      }

      const payloadHash = createHmac('sha256', idempotencyKey)
        .update(JSON.stringify([String(facility.id), property ? String(property.id) : null,
          normalizedStartsAt, normalizedEndsAt, attendeeCount, normalizedPurpose, acceptedPolicyVersion]), 'utf8')
        .digest('hex');
      const replay = (record) => {
        if (!record || !sameId(record.actorUserId, actorUserId) || !sameId(record.estateId, estateId)
          || record.idempotencyKeyHash !== idempotencyKeyHash || record.payloadHash !== payloadHash
          || record.state !== 'completed' || !record.result
          || !sameId(record.result.estateId, estateId) || !sameId(record.result.facilityId, facilityId)
          || !record.result.bookingId) {
          throw new FacilityBookingCreationError('IDEMPOTENCY_KEY_REUSED', 'This request key is already in use with different or incomplete booking details.');
        }
        return Object.freeze({ ...record.result, replayed: true });
      };
      const prior = await readBookingCreationIdempotency(tx, scope);
      if (prior) return replay(prior);

      const now = clock();
      const availability = await loadFacilityAvailability(tx, {
        estateId, facility, property, startsAt: normalizedStartsAt, endsAt: normalizedEndsAt, now,
      });
      if (!availability || !Array.isArray(availability.existingBookings)) {
        throw new FacilityBookingCreationError('AVAILABILITY_UNAVAILABLE', 'Facility availability could not be confirmed.');
      }
      let prepared;
      try {
        prepared = prepareBookingRequest({
          facility,
          requesterUserId: actorUserId,
          property,
          startsAt: normalizedStartsAt,
          endsAt: normalizedEndsAt,
          attendeeCount,
          purpose: normalizedPurpose,
          acceptedPolicyVersion,
          authorization: { mayBook: true },
          availability,
          existingBookings: availability.existingBookings,
        }, now);
      } catch (error) {
        if (error instanceof FacilityBookingError) throw new FacilityBookingCreationError(error.code, error.message);
        throw error;
      }
      const claim = await claimBookingCreationIdempotency(tx, { ...scope, payloadHash });
      if (claim?.state === 'completed') return replay(claim.record);
      if (!claim || claim.state !== 'claimed' || !claim.id
        || !sameId(claim.actorUserId, actorUserId) || !sameId(claim.estateId, estateId)
        || claim.idempotencyKeyHash !== idempotencyKeyHash || claim.payloadHash !== payloadHash) {
        throw new FacilityBookingCreationError('IDEMPOTENCY_CLAIM_FAILED', 'The booking request could not be claimed safely.');
      }

      const bookingId = await generateBookingId(tx, { estateId, facilityId });
      if (!bookingId) throw new FacilityBookingCreationError('INVALID_BOOKING_ID', 'A booking reference could not be generated.');
      let feeInvoiceId = null;
      const record = Object.freeze({ id: bookingId, ...prepared, feeInvoiceId: null });
      const created = await createFacilityBookingRecord(tx, record);
      if (!created || !sameId(created.id, bookingId) || !sameId(created.estateId, estateId)
        || !sameId(created.facilityId, facilityId) || !sameId(created.requesterUserId, actorUserId)
        || !sameNullableId(created.propertyId, prepared.propertyId) || created.status !== prepared.status
        || created.startsAt !== prepared.startsAt || created.endsAt !== prepared.endsAt
        || created.attendeeCount !== prepared.attendeeCount || created.policyVersion !== prepared.policyVersion
        || created.requestedAt !== prepared.requestedAt
        || !sameNullableId(created.feeInvoiceId, null)) {
        throw new FacilityBookingCreationError('INVALID_CREATE_RESULT', 'The booking repository did not persist the planned reservation.');
      }
      if (prepared.fee) {
        const invoice = await createFacilityBookingFeeInvoice(tx, {
          estateId, requesterUserId: actorUserId, propertyId: prepared.propertyId,
          facilityId, bookingId, fee: prepared.fee,
        });
        if (!invoice?.id || !sameId(invoice.estateId, estateId) || !sameId(invoice.bookingId, bookingId)
          || invoice.status !== 'issued' || invoice.amount !== prepared.fee.amount
          || invoice.currency !== prepared.fee.currency || invoice.currencyScale !== prepared.fee.currencyScale) {
          throw new FacilityBookingCreationError('INVALID_BOOKING_INVOICE', 'The facility fee invoice was not created as planned.');
        }
        feeInvoiceId = invoice.id;
        const linked = await linkFacilityBookingFeeInvoice(tx, {
          estateId, bookingId, invoiceId: feeInvoiceId, expectedStatus: prepared.status,
        });
        if (!linked || !sameId(linked.id, bookingId) || !sameId(linked.estateId, estateId)
          || !sameId(linked.feeInvoiceId, feeInvoiceId) || linked.status !== prepared.status) {
          throw new FacilityBookingCreationError('INVALID_BOOKING_INVOICE_LINK', 'The facility fee invoice was not linked to its booking.');
        }
      }
      const result = Object.freeze({
        bookingId, estateId, facilityId, status: prepared.status,
        startsAt: prepared.startsAt, endsAt: prepared.endsAt,
        attendeeCount: prepared.attendeeCount, policyVersion: prepared.policyVersion, feeInvoiceId,
        fee: prepared.fee ? Object.freeze({
          amount: prepared.fee.amount, currency: prepared.fee.currency,
          currencyScale: prepared.fee.currencyScale,
        }) : null,
      });
      const requestedAt = prepared.requestedAt;
      await appendAuditEvent(tx, {
        actorUserId, scope: 'estate', estateId, action: 'facility_booking.request',
        targetType: 'facility_booking', targetId: bookingId, outcome: 'success', occurredAt: requestedAt,
      });
      await enqueueBookingNotice(tx, {
        estateId, bookingId, facilityId, requesterUserId: actorUserId, status: prepared.status,
      });
      const completed = await completeBookingCreationIdempotency(tx, { claim, payloadHash, result });
      if (!completed || !sameId(completed.id, claim.id) || completed.state !== 'completed'
        || !sameId(completed.actorUserId, actorUserId) || !sameId(completed.estateId, estateId)
        || completed.idempotencyKeyHash !== idempotencyKeyHash || completed.payloadHash !== payloadHash
        || !sameId(completed.result?.bookingId, bookingId)) {
        throw new FacilityBookingCreationError('IDEMPOTENCY_COMPLETION_FAILED', 'The booking request could not be committed for safe retry.');
      }
      return result;
    });
  };
}

module.exports = { FacilityBookingCreationError, createFacilityBookingUseCase };
