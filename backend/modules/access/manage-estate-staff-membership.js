const { planStaffMembershipTransition } = require('./staff-membership');

class StaffMembershipUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffMembershipUseCaseError';
    this.code = code;
  }
}

/** Suspend or revoke another member in the authorized estate while preserving history. */
function createEstateStaffMembershipTransitionUseCase({
  transaction,
  requireEstatePermission,
  findMembershipForUpdate,
  checkMembershipLifecyclePolicy,
  commitMembershipTransition,
  enqueueAuthorizationInvalidation,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findMembershipForUpdate,
    checkMembershipLifecyclePolicy,
    commitMembershipTransition,
    enqueueAuthorizationInvalidation,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new StaffMembershipUseCaseError('MISSING_ADAPTER', `Staff membership adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') throw new StaffMembershipUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function transitionEstateStaffMembership({ actorUserId, estateId, membershipId, action, reason } = {}) {
    if (!actorUserId || !estateId || !membershipId) {
      throw new StaffMembershipUseCaseError('INVALID_INPUT', 'Authenticated actor, estate and membership are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'staff.manage', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new StaffMembershipUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage staff access in this estate.');
      }
      const membership = await findMembershipForUpdate(tx, { membershipId, estateContext });
      if (!membership || String(membership.estateId) !== String(estateId)) {
        throw new StaffMembershipUseCaseError('MEMBERSHIP_NOT_FOUND', 'The membership was not found in this estate.');
      }
      if (String(membership.userId) === String(actorUserId)) {
        throw new StaffMembershipUseCaseError('SELF_MANAGEMENT_NOT_ALLOWED', 'Members cannot suspend or revoke their own estate access through this operation.');
      }
      const policyAllowsTransition = await checkMembershipLifecyclePolicy(tx, {
        estateContext,
        actorUserId,
        membership,
        action,
      });
      if (policyAllowsTransition !== true) {
        throw new StaffMembershipUseCaseError('MEMBERSHIP_POLICY_BLOCKED', 'This membership cannot be changed under current estate access policy.');
      }
      const plan = planStaffMembershipTransition({ membership, actorUserId, action, reason, now: clock() });
      const updated = await commitMembershipTransition(tx, plan);
      if (!updated || String(updated.id) !== String(membership.id)
        || String(updated.estateId) !== String(estateId)
        || String(updated.userId) !== String(membership.userId)
        || updated.status !== plan.transition.toStatus) {
        throw new StaffMembershipUseCaseError('INVALID_COMMIT_RESULT', 'The repository did not persist the planned membership transition.');
      }
      // Queue cache/session grant invalidation using the existing Zvend strategy in the same transaction.
      await enqueueAuthorizationInvalidation(tx, {
        estateId,
        userId: membership.userId,
        membershipId: membership.id,
        occurredAt: plan.transition.occurredAt,
      });
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        membershipId: membership.id,
        estateId,
        userId: membership.userId,
        status: updated.status,
        changedAt: plan.transition.occurredAt,
      });
    });
  };
}

module.exports = { StaffMembershipUseCaseError, createEstateStaffMembershipTransitionUseCase };
