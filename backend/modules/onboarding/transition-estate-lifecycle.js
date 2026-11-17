const { planEstateLifecycleTransition } = require('./estate-lifecycle');

class EstateLifecycleUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateLifecycleUseCaseError';
    this.code = code;
  }
}

/** Execute platform-authorized estate lifecycle changes with policy and audit in one transaction. */
function createEstateLifecycleTransitionUseCase({
  transaction,
  requirePlatformPermission,
  findEstateForUpdate,
  checkEstateLifecyclePolicy,
  commitEstateLifecycleTransition,
  enqueueEstateAccessInvalidation,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requirePlatformPermission, findEstateForUpdate, checkEstateLifecyclePolicy, commitEstateLifecycleTransition, enqueueEstateAccessInvalidation, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateLifecycleUseCaseError('MISSING_ADAPTER', `Estate lifecycle adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new EstateLifecycleUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function transitionEstateLifecycle({ actorUserId, estateId, action, reason } = {}) {
    if (!actorUserId || !estateId) throw new EstateLifecycleUseCaseError('INVALID_INPUT', 'Authenticated actor and estate are required.');
    return transaction(async (tx) => {
      const platformContext = await requirePlatformPermission(actorUserId, 'estate.lifecycle.manage', tx);
      if (!platformContext) throw new EstateLifecycleUseCaseError('PERMISSION_DENIED', 'The actor cannot change estate lifecycle state.');
      const estate = await findEstateForUpdate(tx, { estateId });
      if (!estate || String(estate.id) !== String(estateId)) throw new EstateLifecycleUseCaseError('ESTATE_NOT_FOUND', 'The estate was not found.');
      const policyAllowsTransition = await checkEstateLifecyclePolicy(tx, { platformContext, actorUserId, estate, action });
      if (policyAllowsTransition !== true) throw new EstateLifecycleUseCaseError('ESTATE_POLICY_BLOCKED', 'The estate cannot transition under current policy.');
      const plan = planEstateLifecycleTransition({ estate, actorUserId, action, reason, now: clock() });
      const updated = await commitEstateLifecycleTransition(tx, plan);
      if (!updated || String(updated.id) !== String(estate.id) || updated.status !== plan.transition.toStatus) {
        throw new EstateLifecycleUseCaseError('INVALID_COMMIT_RESULT', 'The repository did not persist the planned estate lifecycle transition.');
      }
      if (plan.transition.toStatus !== 'active') {
        await enqueueEstateAccessInvalidation(tx, { estateId, occurredAt: plan.transition.occurredAt });
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ estateId, status: updated.status, changedAt: plan.transition.occurredAt });
    });
  };
}

module.exports = { EstateLifecycleUseCaseError, createEstateLifecycleTransitionUseCase };
