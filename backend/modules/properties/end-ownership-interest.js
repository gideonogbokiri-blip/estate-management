const { planOwnershipEnd } = require('./ownership');

class OwnershipEndUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'OwnershipEndUseCaseError';
    this.code = code;
  }
}

function createOwnershipEndUseCase({
  transaction,
  requireEstatePermission,
  findOwnershipForUpdate,
  checkOwnershipEndDate,
  commitOwnershipEnd,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findOwnershipForUpdate, checkOwnershipEndDate, commitOwnershipEnd, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new OwnershipEndUseCaseError('MISSING_ADAPTER', `Ownership end adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new OwnershipEndUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function endOwnershipInterest({ actorUserId, estateId, ownershipId, effectiveTo, reason } = {}) {
    if (!actorUserId || !estateId || !ownershipId) throw new OwnershipEndUseCaseError('INVALID_INPUT', 'Actor, estate, and ownership interest are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'ownership.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new OwnershipEndUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage ownership in this estate.');
      const ownership = await findOwnershipForUpdate(tx, { ownershipId, estateContext });
      if (!ownership || ownership.estateId !== estateId) throw new OwnershipEndUseCaseError('OWNERSHIP_NOT_FOUND', 'The ownership interest was not found.');
      const datePolicyAllowsEnd = await checkOwnershipEndDate(tx, { ownership, effectiveTo, estateContext });
      const plan = planOwnershipEnd(ownership, { actorUserId, effectiveTo, reason, now: clock(), datePolicyAllowsEnd });
      const updated = await commitOwnershipEnd(tx, plan, { estateContext });
      if (!updated || updated.id !== ownership.id || updated.estateId !== estateId
        || updated.status !== 'ended' || updated.effectiveTo !== effectiveTo) {
        throw new OwnershipEndUseCaseError('INVALID_RESULT', 'The repository must end the ownership interest while retaining its history.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ ownershipId, estateId, status: updated.status, effectiveTo: updated.effectiveTo });
    });
  };
}

module.exports = { OwnershipEndUseCaseError, createOwnershipEndUseCase };
