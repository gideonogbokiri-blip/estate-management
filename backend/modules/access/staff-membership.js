const StaffMembershipStatus = Object.freeze({
  ACTIVE: 'active',
  SUSPENDED: 'suspended',
  REVOKED: 'revoked',
});

const StaffMembershipAction = Object.freeze({
  SUSPEND: 'suspend',
  REVOKE: 'revoke',
});

class StaffMembershipError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffMembershipError';
    this.code = code;
  }
}

function planStaffMembershipTransition({ membership, actorUserId, action, reason, now } = {}) {
  if (!membership?.id || !membership.estateId || !membership.userId || !actorUserId) {
    throw new StaffMembershipError('INVALID_MEMBERSHIP', 'A persisted estate membership and authenticated actor are required.');
  }
  if (String(membership.userId) === String(actorUserId)) {
    throw new StaffMembershipError('SELF_MANAGEMENT_NOT_ALLOWED', 'Members cannot suspend or revoke their own estate access through this operation.');
  }
  if (!Object.values(StaffMembershipAction).includes(action)) {
    throw new StaffMembershipError('INVALID_ACTION', 'Choose suspend or revoke.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!normalizedReason || normalizedReason.length > 500) {
    throw new StaffMembershipError('INVALID_REASON', 'Provide a reason of up to 500 characters.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new StaffMembershipError('INVALID_TIMESTAMP', 'A valid membership transition timestamp is required.');
  }
  const nextStatus = action === StaffMembershipAction.SUSPEND
    ? StaffMembershipStatus.SUSPENDED
    : StaffMembershipStatus.REVOKED;
  const allowedFrom = action === StaffMembershipAction.SUSPEND
    ? [StaffMembershipStatus.ACTIVE]
    : [StaffMembershipStatus.ACTIVE, StaffMembershipStatus.SUSPENDED];
  if (!allowedFrom.includes(membership.status)) {
    throw new StaffMembershipError('INVALID_STATE', `A ${action} transition is not allowed from ${membership.status || 'unknown'}.`);
  }

  const occurredAt = new Date(now).toISOString();
  const transition = Object.freeze({
    membershipId: membership.id,
    estateId: membership.estateId,
    userId: membership.userId,
    actorUserId,
    fromStatus: membership.status,
    toStatus: nextStatus,
    action,
    reason: normalizedReason,
    occurredAt,
  });
  const nextMembership = Object.freeze({
    ...membership,
    status: nextStatus,
    updatedAt: occurredAt,
    ...(action === StaffMembershipAction.SUSPEND
      ? { suspendedAt: occurredAt, suspendedByUserId: actorUserId, suspensionReason: normalizedReason }
      : { revokedAt: occurredAt, revokedByUserId: actorUserId, revocationReason: normalizedReason }),
  });
  return Object.freeze({
    transactionRequired: true,
    transition,
    nextMembership,
    effects: Object.freeze([Object.freeze({ type: `estate_membership.${action}`, ...transition })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: membership.estateId,
      action: `staff.membership.${action}`,
      targetType: 'estate_membership',
      targetId: membership.id,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt,
      metadata: Object.freeze({ fromStatus: membership.status, toStatus: nextStatus, userId: membership.userId }),
    }),
  });
}

module.exports = { StaffMembershipAction, StaffMembershipError, StaffMembershipStatus, planStaffMembershipTransition };
