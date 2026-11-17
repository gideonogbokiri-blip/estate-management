const { FacilityBookingError, planBookingDecision } = require('./facility-booking');

class FacilityBookingDecisionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityBookingDecisionError';
    this.code = code;
  }
}

function sameId(a, b) {
  return a !== null && a !== undefined && b !== null && b !== undefined
    && String(a) === String(b);
}

/** Decide a pending booking after rechecking policy, availability and any fee invoice. */
function createFacilityBookingDecisionUseCase({
  transaction,
  requireEstatePermission,
  findBookingForUpdate,
  findFacilityForUpdate,
  loadFacilityAvailability,
  readVerifiedFeeInvoice,
  commitFacilityBookingDecision,
  appendAuditEvent,
  enqueueBookingNotice,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findBookingForUpdate,
    findFacilityForUpdate,
    loadFacilityAvailability,
    readVerifiedFeeInvoice,
    commitFacilityBookingDecision,
    appendAuditEvent,
    enqueueBookingNotice,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new FacilityBookingDecisionError(
      'MISSING_ADAPTER',
      `Facility booking decision adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new FacilityBookingDecisionError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function decideFacilityBooking({
    actorUserId,
    estateId,
    bookingId,
    decision,
    reason = '',
  } = {}) {
    if (!actorUserId || !estateId || !bookingId
      || !['confirm', 'decline'].includes(decision)) {
      throw new FacilityBookingDecisionError(
        'INVALID_INPUT',
        'Authenticated actor, estate, booking and supported decision are required.',
      );
    }
    if (typeof reason !== 'string' || reason.length > 500) {
      throw new FacilityBookingDecisionError('INVALID_REASON', 'Decision reason must be at most 500 characters.');
    }
    if (decision === 'decline' && !reason.trim()) {
      throw new FacilityBookingDecisionError('REASON_REQUIRED', 'A reason is required to decline a booking.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(
        actorUserId, estateId, 'booking.approve', tx,
      );
      if (!estateContext || !sameId(estateContext.estateId, estateId)) {
        throw new FacilityBookingDecisionError(
          'PERMISSION_DENIED',
          'The actor cannot approve facility bookings in this estate.',
        );
      }

      const booking = await findBookingForUpdate(tx, { bookingId, estateContext });
      if (!booking || !sameId(booking.id, bookingId)
        || !sameId(booking.estateId, estateId)) {
        throw new FacilityBookingDecisionError('BOOKING_NOT_FOUND', 'The booking was not found in this estate.');
      }
      const facility = await findFacilityForUpdate(tx, {
        facilityId: booking.facilityId,
        estateContext,
      });
      if (!facility || !sameId(facility.id, booking.facilityId)
        || !sameId(facility.estateId, estateId)) {
        throw new FacilityBookingDecisionError('FACILITY_NOT_FOUND', 'The linked facility was not found in this estate.');
      }

      const now = clock();
      const availability = decision === 'confirm'
        ? await loadFacilityAvailability(tx, {
          estateContext,
          facility,
          startsAt: booking.startsAt,
          endsAt: booking.endsAt,
          now,
          excludeBookingId: booking.id,
        })
        : { withinOpeningHours: true, outsideBlackout: true, existingBookings: [] };
      if (!availability || !Array.isArray(availability.existingBookings)) {
        throw new FacilityBookingDecisionError('AVAILABILITY_UNAVAILABLE', 'Facility availability could not be confirmed.');
      }
      const verifiedFeeInvoice = decision === 'confirm' && booking.feeInvoiceId
        ? await readVerifiedFeeInvoice(tx, {
          estateContext,
          invoiceId: booking.feeInvoiceId,
          bookingId: booking.id,
          requesterUserId: booking.requesterUserId,
        })
        : null;

      let plan;
      try {
        plan = planBookingDecision(booking, {
          decision,
          actorUserId,
          now,
          reason,
          facility,
          availability,
          existingBookings: availability.existingBookings,
          verifiedFeeInvoice,
        });
      } catch (error) {
        if (error instanceof FacilityBookingError) {
          throw new FacilityBookingDecisionError(error.code, error.message);
        }
        throw error;
      }

      const updated = await commitFacilityBookingDecision(tx, {
        estateContext,
        booking,
        facility,
        plan,
      });
      if (!updated || !sameId(updated.id, booking.id)
        || !sameId(updated.estateId, estateId)
        || updated.status !== plan.nextStatus) {
        throw new FacilityBookingDecisionError(
          'INVALID_COMMIT_RESULT',
          'The booking repository did not persist the planned decision.',
        );
      }
      for (const event of plan.effects) await appendAuditEvent(tx, event);
      await appendAuditEvent(tx, plan.auditEvent);
      await enqueueBookingNotice(tx, {
        estateId,
        bookingId: booking.id,
        facilityId: booking.facilityId,
        requesterUserId: booking.requesterUserId,
        status: plan.nextStatus,
        reason: reason.trim() || null,
      });
      return Object.freeze({
        bookingId: booking.id,
        estateId,
        status: plan.nextStatus,
        decidedAt: plan.auditEvent.occurredAt,
      });
    });
  };
}

module.exports = { FacilityBookingDecisionError, createFacilityBookingDecisionUseCase };
