const EstateStatus = Object.freeze({
  DRAFT: 'draft',
  PENDING: 'pending',
  UNDER_REVIEW: 'under_review',
  ACTIVE: 'active',
  REJECTED: 'rejected',
  SUSPENDED: 'suspended',
  DEACTIVATED: 'deactivated',
});

const ApplicationEstateStatus = Object.freeze({
  draft: EstateStatus.DRAFT,
  submitted: EstateStatus.PENDING,
  under_review: EstateStatus.UNDER_REVIEW,
  more_information_required: EstateStatus.PENDING,
  approved: EstateStatus.ACTIVE,
  rejected: EstateStatus.REJECTED,
});

const EstateLifecycleAction = Object.freeze({
  SUSPEND: 'suspend',
  REACTIVATE: 'reactivate',
  DEACTIVATE: 'deactivate',
});

const allowedTransitions = Object.freeze({
  [EstateLifecycleAction.SUSPEND]: Object.freeze([EstateStatus.ACTIVE]),
  [EstateLifecycleAction.REACTIVATE]: Object.freeze([EstateStatus.SUSPENDED]),
  [EstateLifecycleAction.DEACTIVATE]: Object.freeze([EstateStatus.ACTIVE, EstateStatus.SUSPENDED]),
});

class EstateLifecycleError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateLifecycleError';
    this.code = code;
  }
}

/** Plan an explicit platform lifecycle command; never apply arbitrary status patches. */
function planEstateLifecycleTransition({ estate, actorUserId, action, reason, now } = {}) {
  if (!estate?.id || !actorUserId) {
    throw new EstateLifecycleError('INVALID_INPUT', 'A persisted estate and authenticated platform actor are required.');
  }
  if (!Object.hasOwn(allowedTransitions, action)) {
    throw new EstateLifecycleError('INVALID_ACTION', 'Choose suspend, reactivate or deactivate.');
  }
  if (!allowedTransitions[action].includes(estate.status)) {
    throw new EstateLifecycleError('INVALID_STATE', `Estate lifecycle action ${action} is not allowed from ${estate.status || 'unknown'}.`);
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!normalizedReason || normalizedReason.length > 1000) {
    throw new EstateLifecycleError('INVALID_REASON', 'Provide a reason of up to 1000 characters.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new EstateLifecycleError('INVALID_TIMESTAMP', 'A valid estate lifecycle timestamp is required.');
  }
  const nextStatus = action === EstateLifecycleAction.SUSPEND
    ? EstateStatus.SUSPENDED
    : action === EstateLifecycleAction.REACTIVATE ? EstateStatus.ACTIVE : EstateStatus.DEACTIVATED;
  const occurredAt = new Date(now).toISOString();
  const transition = Object.freeze({
    estateId: estate.id,
    actorUserId,
    action,
    fromStatus: estate.status,
    toStatus: nextStatus,
    reason: normalizedReason,
    occurredAt,
  });
  return Object.freeze({
    transactionRequired: true,
    transition,
    nextEstate: Object.freeze({
      ...estate,
      status: nextStatus,
      updatedAt: occurredAt,
      lifecycleChangedAt: occurredAt,
      lifecycleChangedByUserId: actorUserId,
      lifecycleReason: normalizedReason,
    }),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: `estate.${action}`,
      targetType: 'estate',
      targetId: estate.id,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt,
      metadata: Object.freeze({ fromStatus: estate.status, toStatus: nextStatus }),
    }),
  });
}

module.exports = { ApplicationEstateStatus, EstateLifecycleAction, EstateLifecycleError, EstateStatus, planEstateLifecycleTransition };
