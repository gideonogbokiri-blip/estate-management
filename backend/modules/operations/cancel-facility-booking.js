const { FacilityBookingError, planBookingCancellation } = require('./facility-booking');

class FacilityBookingCancellationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityBookingCancellationError';
    this.code = code;
  }
}

function sameId(a, b) {
  return a !== null && a !== undefined && b !== null && b !== undefined
    && String(a) === String(b);
}

/** Cancel an authorized booking and create an optional billing refund request atomically. */
function createFacilityBookingCancellationUseCase({
  transaction,
  findBookingForUpdate,
  resolveCancellationAccess,
  loadCapturedCancellationPolicy,
  prepareVerifiedRefundRequest,
  commitFacilityBookingCancellation,
  createBillingRefundRequest,
  appendAuditEvent,
  enqueueBookingNotice,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    findBookingForUpdate,
    resolveCancellationAccess,
    loadCapturedCancellationPolicy,
    prepareVerifiedRefundRequest,
    commitFacilityBookingCancellation,
    createBillingRefundRequest,
    appendAuditEvent,
    enqueueBookingNotice,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new FacilityBookingCancellationError(
      'MISSING_ADAPTER',
      `Facility booking cancellation adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new FacilityBookingCancellationError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function cancelFacilityBooking({
    actorUserId,
    estateId,
    bookingId,
    reason = '',
  } = {}) {
    if (!actorUserId || !estateId || !bookingId) {
      throw new FacilityBookingCancellationError(
        'INVALID_INPUT',
        'Authenticated actor, estate and booking context are required.',
      );
    }
    if (typeof reason !== 'string' || reason.length > 500) {
      throw new FacilityBookingCancellationError('INVALID_REASON', 'Cancellation reason must be at most 500 characters.');
    }

    return transaction(async (tx) => {
      const booking = await findBookingForUpdate(tx, { estateId, bookingId });
      if (!booking || !sameId(booking.id, bookingId)
        || !sameId(booking.estateId, estateId)) {
        throw new FacilityBookingCancellationError('BOOKING_NOT_FOUND', 'The booking was not found in this estate.');
      }
      const authorization = await resolveCancellationAccess(tx, {
        actorUserId,
        estateId,
        booking,
      });
      if (!authorization || !sameId(authorization.actorUserId, actorUserId)
        || !sameId(authorization.estateId, estateId)
        || !sameId(authorization.bookingId, booking.id)
        || authorization.mayCancel !== true) {
        throw new FacilityBookingCancellationError(
          'CANCELLATION_NOT_AUTHORIZED',
          'The actor cannot cancel this booking.',
        );
      }
      const policy = await loadCapturedCancellationPolicy(tx, {
        estateId,
        facilityId: booking.facilityId,
        policyVersion: booking.policyVersion,
        booking,
      });
      if (!policy || policy.version !== booking.policyVersion) {
        throw new FacilityBookingCancellationError(
          'CAPTURED_POLICY_UNAVAILABLE',
          'The booking cancellation policy could not be verified.',
        );
      }
      const refundPlan = await prepareVerifiedRefundRequest(tx, {
        estateId,
        booking,
        policy,
        authorization,
      });
      if (refundPlan !== null && refundPlan !== undefined
        && !sameId(refundPlan.invoiceId, booking.feeInvoiceId)) {
        throw new FacilityBookingCancellationError(
          'REFUND_INVOICE_MISMATCH',
          'The refund request must match the booking fee invoice.',
        );
      }

      let plan;
      try {
        plan = planBookingCancellation(booking, {
          actorUserId,
          now: clock(),
          authorization,
          policy,
          refundPlan: refundPlan ?? null,
          reason,
        });
      } catch (error) {
        if (error instanceof FacilityBookingError) {
          throw new FacilityBookingCancellationError(error.code, error.message);
        }
        throw error;
      }

      const updated = await commitFacilityBookingCancellation(tx, {
        estateId,
        booking,
        plan,
      });
      if (!updated || !sameId(updated.id, booking.id)
        || !sameId(updated.estateId, estateId)
        || updated.status !== plan.nextStatus) {
        throw new FacilityBookingCancellationError(
          'INVALID_COMMIT_RESULT',
          'The booking repository did not persist the planned cancellation.',
        );
      }
      let refundRequestId = null;
      if (plan.refundPlan) {
        const refund = await createBillingRefundRequest(tx, {
          estateId,
          booking,
          plan: plan.refundPlan,
        });
        if (!refund || !sameId(refund.id, plan.refundPlan.requestId)
          || !sameId(refund.estateId, estateId)
          || !sameId(refund.invoiceId, booking.feeInvoiceId)
          || !sameId(refund.bookingId, booking.id)
          || refund.status !== 'requested') {
          throw new FacilityBookingCancellationError(
            'INVALID_REFUND_RESULT',
            'Billing did not persist the planned refund request.',
          );
        }
        refundRequestId = refund.id;
      }
      for (const event of plan.effects) await appendAuditEvent(tx, event);
      await appendAuditEvent(tx, plan.auditEvent);
      await enqueueBookingNotice(tx, {
        estateId,
        bookingId: booking.id,
        facilityId: booking.facilityId,
        requesterUserId: booking.requesterUserId,
        status: plan.nextStatus,
        refundRequestId,
      });
      return Object.freeze({
        bookingId: booking.id,
        estateId,
        status: plan.nextStatus,
        cancelledAt: plan.cancelledAt,
        refundRequestId,
      });
    });
  };
}

module.exports = {
  FacilityBookingCancellationError,
  createFacilityBookingCancellationUseCase,
};
