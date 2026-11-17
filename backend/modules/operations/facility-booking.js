const { normalizeDecimal, toMinorUnits } = require('../billing/money');

const BookingStatus = Object.freeze({
  REQUESTED: 'requested',
  PENDING_REVIEW: 'pending_review',
  PENDING_PAYMENT: 'pending_payment',
  CONFIRMED: 'confirmed',
  DECLINED: 'declined',
  EXPIRED: 'expired',
  CANCELLED: 'cancelled',
  COMPLETED: 'completed',
});

const BookingDecision = Object.freeze({ CONFIRM: 'confirm', DECLINE: 'decline' });

class FacilityBookingError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FacilityBookingError';
    this.code = code;
  }
}

function instant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function overlaps(startA, endA, startB, endB) {
  return startA < endB && startB < endA;
}

function blockingBooking(booking, facility, currentTime) {
  if (booking.status === BookingStatus.CONFIRMED) return true;
  if (booking.status !== BookingStatus.PENDING_REVIEW || facility.pendingBlocksAvailability !== true) return false;
  const holdExpiry = instant(booking.holdExpiresAt);
  if (holdExpiry === null) {
    throw new FacilityBookingError('INVALID_PENDING_HOLD', 'A blocking pending booking must have a valid hold expiry.');
  }
  return holdExpiry > currentTime;
}

function assertAvailability({ facility, startsAt, endsAt, attendeeCount, existingBookings, now, excludeBookingId }) {
  const currentTime = instant(now);
  const startTime = instant(startsAt);
  const endTime = instant(endsAt);
  if (!Array.isArray(existingBookings) || currentTime === null || startTime === null || endTime === null || endTime <= startTime) {
    throw new FacilityBookingError('AVAILABILITY_CHECK_REQUIRED', 'Provide valid times and a server-loaded booking conflict set.');
  }

  const overlappingBookings = existingBookings.filter((booking) => {
    if (booking?.estateId !== facility.estateId || booking?.facilityId !== facility.id) {
      throw new FacilityBookingError('AVAILABILITY_SCOPE_MISMATCH', 'Conflict records must be scoped to this facility and estate.');
    }
    if (booking.id === excludeBookingId || !blockingBooking(booking, facility, currentTime)) return false;
    const existingStart = instant(booking.startsAt);
    const existingEnd = instant(booking.endsAt);
    if (existingStart === null || existingEnd === null || existingEnd <= existingStart) {
      throw new FacilityBookingError('INVALID_EXISTING_BOOKING', 'Existing booking time data is invalid.');
    }
    return overlaps(startTime, endTime, existingStart, existingEnd);
  });

  if (facility.exclusive === true && overlappingBookings.length > 0) {
    throw new FacilityBookingError('BOOKING_CONFLICT', 'This facility is already reserved for part of that time.');
  }
  if (facility.exclusive !== true) {
    const existingAttendees = overlappingBookings.reduce((sum, booking) => {
      if (!Number.isInteger(booking.attendeeCount) || booking.attendeeCount < 1) {
        throw new FacilityBookingError('INVALID_EXISTING_BOOKING', 'Existing attendee count is invalid.');
      }
      return sum + booking.attendeeCount;
    }, 0);
    if (!Number.isInteger(facility.capacity) || facility.capacity < 1
      || existingAttendees + attendeeCount > facility.capacity) {
      throw new FacilityBookingError('CAPACITY_EXCEEDED', 'The facility does not have enough capacity for that time.');
    }
  }

  return overlappingBookings.length;
}

function prepareBookingRequest(input, now) {
  const { facility, requesterUserId, property, startsAt, endsAt, attendeeCount, purpose, acceptedPolicyVersion, authorization, availability, existingBookings } = input ?? {};
  const currentTime = instant(now);
  const startTime = instant(startsAt);
  const endTime = instant(endsAt);
  if (!facility?.id || !facility.estateId || facility.status !== 'active' || facility.bookable !== true) {
    throw new FacilityBookingError('FACILITY_UNAVAILABLE', 'This facility is not currently bookable.');
  }
  if (!requesterUserId || authorization?.mayBook !== true
    || (property && property.estateId !== facility.estateId)) {
    throw new FacilityBookingError('BOOKING_NOT_AUTHORIZED', 'The requester and property must be authorized for this estate.');
  }
  if (!Number.isInteger(attendeeCount) || attendeeCount < 1
    || !Number.isInteger(facility.capacity) || attendeeCount > facility.capacity) {
    throw new FacilityBookingError('INVALID_ATTENDEE_COUNT', 'Attendee count exceeds facility capacity.');
  }
  if (currentTime === null || startTime === null || endTime === null || startTime <= currentTime || endTime <= startTime) {
    throw new FacilityBookingError('INVALID_BOOKING_TIME', 'Choose a valid future booking time.');
  }
  if (!Number.isFinite(facility.minimumLeadTimeMs) || facility.minimumLeadTimeMs < 0
    || startTime - currentTime < facility.minimumLeadTimeMs
    || !Number.isFinite(facility.maximumDurationMs) || facility.maximumDurationMs <= 0
    || endTime - startTime > facility.maximumDurationMs) {
    throw new FacilityBookingError('BOOKING_POLICY_VIOLATION', 'Booking time is outside facility lead-time or duration policy.');
  }
  if (acceptedPolicyVersion !== facility.policyVersion) {
    throw new FacilityBookingError('POLICY_ACCEPTANCE_REQUIRED', 'Accept the current facility booking policy.');
  }
  if (availability?.withinOpeningHours !== true || availability?.outsideBlackout !== true) {
    throw new FacilityBookingError('FACILITY_CLOSED', 'The selected time is outside facility availability.');
  }
  if (!['automatic', 'manual'].includes(facility.approvalMode)) {
    throw new FacilityBookingError('INVALID_APPROVAL_POLICY', 'Facility approval mode is not configured.');
  }
  assertAvailability({ facility, startsAt, endsAt, attendeeCount, existingBookings, now });

  if (facility.paymentRequiredBeforeConfirmation === true && !facility.fee) {
    throw new FacilityBookingError('MISSING_BOOKING_FEE', 'Payment cannot be required without a configured facility fee.');
  }
  const status = facility.approvalMode === 'automatic'
    ? (facility.paymentRequiredBeforeConfirmation === true ? BookingStatus.PENDING_PAYMENT : BookingStatus.CONFIRMED)
    : BookingStatus.PENDING_REVIEW;
  let holdExpiresAt = null;
  if (status === BookingStatus.PENDING_REVIEW && facility.pendingBlocksAvailability === true) {
    if (!Number.isFinite(facility.pendingHoldMs) || facility.pendingHoldMs <= 0) {
      throw new FacilityBookingError('INVALID_PENDING_HOLD', 'Blocking pending bookings require a finite hold duration.');
    }
    holdExpiresAt = new Date(currentTime + facility.pendingHoldMs).toISOString();
  }

  let fee = null;
  if (facility.fee) {
    const { amount, currency, currencyScale } = facility.fee;
    const normalizedAmount = normalizeDecimal(amount, currencyScale);
    if (toMinorUnits(normalizedAmount, currencyScale) <= 0n || !/^[A-Z]{3}$/.test(currency ?? '')) {
      throw new FacilityBookingError('INVALID_FACILITY_FEE', 'Facility fee must use a positive amount and configured currency.');
    }
    fee = Object.freeze({ amount: normalizedAmount, currency, currencyScale, policyVersion: facility.policyVersion });
  }

  return Object.freeze({
    estateId: facility.estateId,
    facilityId: facility.id,
    requesterUserId,
    propertyId: property?.id ?? null,
    startsAt: new Date(startTime).toISOString(),
    endsAt: new Date(endTime).toISOString(),
    attendeeCount,
    purpose: typeof purpose === 'string' ? purpose.trim() || null : null,
    policyVersion: facility.policyVersion,
    status,
    blocksAvailability: status === BookingStatus.CONFIRMED || holdExpiresAt !== null,
    holdExpiresAt,
    fee,
    requestedAt: new Date(currentTime).toISOString(),
  });
}

function planBookingDecision(booking, input) {
  if (!booking?.id || !booking.estateId || !booking.facilityId) {
    throw new FacilityBookingError('INVALID_BOOKING', 'A persisted facility booking is required.');
  }
  const { decision, actorUserId, now, reason, facility, availability, existingBookings, verifiedFeeInvoice } = input ?? {};
  const currentTime = instant(now);
  if (!actorUserId || currentTime === null || ![BookingDecision.CONFIRM, BookingDecision.DECLINE].includes(decision)) {
    throw new FacilityBookingError('INVALID_DECISION', 'An authorized actor, timestamp, and booking decision are required.');
  }
  if (booking.status !== BookingStatus.PENDING_REVIEW) {
    throw new FacilityBookingError('INVALID_STATE', 'Only a pending booking can receive a decision.');
  }
  if (decision === BookingDecision.DECLINE && !(typeof reason === 'string' && reason.trim())) {
    throw new FacilityBookingError('REASON_REQUIRED', 'A reason is required to decline a booking.');
  }

  let nextStatus = BookingStatus.DECLINED;
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  const effects = [];
  if (decision === BookingDecision.CONFIRM) {
    if (!facility?.id || facility.id !== booking.facilityId || facility.estateId !== booking.estateId
      || facility.status !== 'active' || facility.policyVersion !== booking.policyVersion) {
      throw new FacilityBookingError('FACILITY_POLICY_CHANGED', 'The booking must be reviewed against the current facility policy.');
    }
    if (availability?.withinOpeningHours !== true || availability?.outsideBlackout !== true) {
      throw new FacilityBookingError('FACILITY_CLOSED', 'The requested time is no longer available under facility policy.');
    }
    assertAvailability({
      facility,
      startsAt: booking.startsAt,
      endsAt: booking.endsAt,
      attendeeCount: booking.attendeeCount,
      existingBookings,
      now,
      excludeBookingId: booking.id,
    });
    if (facility.paymentRequiredBeforeConfirmation === true
      && (!booking.feeInvoiceId || verifiedFeeInvoice?.id !== booking.feeInvoiceId
        || verifiedFeeInvoice?.status !== 'paid' || !verifiedFeeInvoice?.asOf)) {
      throw new FacilityBookingError('BOOKING_FEE_UNPAID', 'The linked fee invoice must be paid according to verified billing records.');
    }
    nextStatus = BookingStatus.CONFIRMED;
  } else {
    effects.push({
      type: 'facility_booking.hold_released',
      bookingId: booking.id,
      estateId: booking.estateId,
      releasedAt: new Date(currentTime).toISOString(),
    });
  }

  const decidedAt = new Date(currentTime).toISOString();
  effects.unshift({
    type: 'facility_booking.status_changed',
    bookingId: booking.id,
    estateId: booking.estateId,
    from: booking.status,
    to: nextStatus,
    actorUserId,
    reason: normalizedReason || null,
    decidedAt,
    policyVersion: booking.policyVersion,
  });

  return Object.freeze({
    transactionRequired: true,
    bookingId: booking.id,
    estateId: booking.estateId,
    nextStatus,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: booking.estateId,
      action: `facility_booking.${decision}`,
      targetType: 'facility_booking',
      targetId: booking.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: decidedAt,
    }),
  });
}

function planBookingPaymentConfirmation(booking, input) {
  if (!booking?.id || !booking.estateId || !booking.facilityId) {
    throw new FacilityBookingError('INVALID_BOOKING', 'A persisted facility booking is required.');
  }
  const { actorUserId, now, facility, availability, existingBookings, verifiedFeeInvoice } = input ?? {};
  const currentTime = instant(now);
  if (!actorUserId || currentTime === null || booking.status !== BookingStatus.PENDING_PAYMENT) {
    throw new FacilityBookingError('INVALID_STATE', 'A pending-payment booking and valid system actor are required.');
  }
  if (!booking.feeInvoiceId || verifiedFeeInvoice?.id !== booking.feeInvoiceId
    || verifiedFeeInvoice?.status !== 'paid' || !verifiedFeeInvoice?.asOf) {
    throw new FacilityBookingError('BOOKING_FEE_UNPAID', 'The linked fee invoice must be paid according to verified billing records.');
  }
  if (!facility?.id || facility.id !== booking.facilityId || facility.estateId !== booking.estateId
    || facility.status !== 'active' || facility.policyVersion !== booking.policyVersion
    || availability?.withinOpeningHours !== true || availability?.outsideBlackout !== true) {
    throw new FacilityBookingError('FACILITY_POLICY_CHANGED', 'Recheck facility policy and availability before confirmation.');
  }
  assertAvailability({
    facility,
    startsAt: booking.startsAt,
    endsAt: booking.endsAt,
    attendeeCount: booking.attendeeCount,
    existingBookings,
    now,
    excludeBookingId: booking.id,
  });

  const confirmedAt = new Date(currentTime).toISOString();
  return Object.freeze({
    transactionRequired: true,
    bookingId: booking.id,
    estateId: booking.estateId,
    nextStatus: BookingStatus.CONFIRMED,
    effects: Object.freeze([Object.freeze({
      type: 'facility_booking.status_changed',
      bookingId: booking.id,
      estateId: booking.estateId,
      from: booking.status,
      to: BookingStatus.CONFIRMED,
      actorUserId,
      reason: null,
      decidedAt: confirmedAt,
      policyVersion: booking.policyVersion,
      verifiedInvoiceId: verifiedFeeInvoice.id,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: booking.estateId,
      action: 'facility_booking.confirm_after_payment',
      targetType: 'facility_booking',
      targetId: booking.id,
      outcome: 'success',
      occurredAt: confirmedAt,
    }),
  });
}

/** Plan a cancellation from trusted actor, captured policy and billing projections. */
function planBookingCancellation(booking, input) {
  if (!booking?.id || !booking.estateId || !booking.facilityId) {
    throw new FacilityBookingError('INVALID_BOOKING', 'A persisted facility booking is required.');
  }
  const { actorUserId, now, authorization, policy, refundPlan = null, reason = '' } = input ?? {};
  const currentTime = instant(now);
  const cancellable = [BookingStatus.REQUESTED, BookingStatus.PENDING_REVIEW,
    BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED];
  if (!actorUserId || currentTime === null || !cancellable.includes(booking.status)) {
    throw new FacilityBookingError('INVALID_CANCELLATION_STATE', 'This booking can no longer be cancelled.');
  }
  if (authorization?.mayCancel !== true) {
    throw new FacilityBookingError('CANCELLATION_NOT_AUTHORIZED', 'The actor cannot cancel this booking.');
  }
  if (!policy || policy.version !== booking.policyVersion || policy.mayCancel !== true) {
    throw new FacilityBookingError('CANCELLATION_NOT_ALLOWED', 'Cancellation is not allowed under the booking policy.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (normalizedReason.length > 500) {
    throw new FacilityBookingError('INVALID_CANCELLATION_REASON', 'Cancellation reason must be at most 500 characters.');
  }
  if (refundPlan !== null) {
    if (!booking.feeInvoiceId || refundPlan.invoiceId !== booking.feeInvoiceId
      || refundPlan.bookingId !== booking.id || refundPlan.estateId !== booking.estateId
      || refundPlan.status !== 'requested' || !refundPlan.requestId
      || typeof refundPlan.amount !== 'string' || !/^[A-Z]{3}$/.test(refundPlan.currency ?? '')
      || !Number.isInteger(refundPlan.currencyScale) || refundPlan.currencyScale < 0
      || refundPlan.currencyScale > 6
      || !booking.fee || booking.fee.currency !== refundPlan.currency
      || booking.fee.currencyScale !== refundPlan.currencyScale) {
      throw new FacilityBookingError('INVALID_REFUND_PLAN', 'A refund request must match the linked booking invoice and estate.');
    }
    try {
      const refundMinor = toMinorUnits(refundPlan.amount, refundPlan.currencyScale);
      if (refundMinor <= 0n
        || refundMinor > toMinorUnits(booking.fee.amount, booking.fee.currencyScale)) {
        throw new Error('non-positive');
      }
    } catch {
      throw new FacilityBookingError('INVALID_REFUND_PLAN', 'Refund amount must use exact positive currency precision.');
    }
  }
  const cancelledAt = new Date(currentTime).toISOString();
  const effects = [Object.freeze({
    type: 'facility_booking.status_changed',
    bookingId: booking.id,
    estateId: booking.estateId,
    from: booking.status,
    to: BookingStatus.CANCELLED,
    actorUserId,
    reason: normalizedReason || null,
    decidedAt: cancelledAt,
    policyVersion: booking.policyVersion,
  })];
  if (booking.status === BookingStatus.PENDING_REVIEW && booking.holdExpiresAt) {
    effects.push(Object.freeze({
      type: 'facility_booking.hold_released',
      bookingId: booking.id,
      estateId: booking.estateId,
      releasedAt: cancelledAt,
    }));
  }
  return Object.freeze({
    transactionRequired: true,
    bookingId: booking.id,
    estateId: booking.estateId,
    nextStatus: BookingStatus.CANCELLED,
    cancelledAt,
    refundPlan: refundPlan ? Object.freeze({ ...refundPlan }) : null,
    effects: Object.freeze(effects),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: booking.estateId,
      action: 'facility_booking.cancel',
      targetType: 'facility_booking',
      targetId: booking.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: cancelledAt,
    }),
  });
}

module.exports = {
  BookingDecision,
  BookingStatus,
  FacilityBookingError,
  assertAvailability,
  planBookingDecision,
  planBookingCancellation,
  planBookingPaymentConfirmation,
  prepareBookingRequest,
};
