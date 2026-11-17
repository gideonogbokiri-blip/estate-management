const { OwnershipVerification, planOwnershipVerification } = require('./ownership');

class OwnershipVerificationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'OwnershipVerificationUseCaseError';
    this.code = code;
  }
}

function createOwnershipVerificationUseCase({
  transaction,
  requireEstatePermission,
  findOwnershipForUpdate,
  verifyEvidenceReference,
  commitOwnershipVerification,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findOwnershipForUpdate, verifyEvidenceReference, commitOwnershipVerification, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new OwnershipVerificationUseCaseError('MISSING_ADAPTER', `Ownership review adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new OwnershipVerificationUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function decideOwnershipVerification({ actorUserId, estateId, ownershipId, decision, reason } = {}) {
    if (!actorUserId || !estateId || !ownershipId) throw new OwnershipVerificationUseCaseError('INVALID_INPUT', 'Actor, estate, and ownership interest are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'ownership.verify', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new OwnershipVerificationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot review ownership in this estate.');
      const ownership = await findOwnershipForUpdate(tx, { ownershipId, estateContext });
      if (!ownership || ownership.estateId !== estateId) throw new OwnershipVerificationUseCaseError('OWNERSHIP_NOT_FOUND', 'The ownership interest was not found.');
      const evidenceReferenceVerified = decision === 'verify' && ownership.evidenceDocumentId
        ? await verifyEvidenceReference(tx, { evidenceDocumentId: ownership.evidenceDocumentId, ownership, estateContext })
        : false;
      const plan = planOwnershipVerification(ownership, { actorUserId, decision, reason, now: clock(), evidenceReferenceVerified });
      const updated = await commitOwnershipVerification(tx, plan, { estateContext });
      if (!updated || updated.id !== ownership.id || updated.estateId !== estateId || updated.verificationStatus !== plan.verificationStatus) {
        throw new OwnershipVerificationUseCaseError('INVALID_RESULT', 'The repository must apply the planned ownership review.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ ownershipId, estateId, verificationStatus: updated.verificationStatus });
    });
  };
}

module.exports = { OwnershipVerificationUseCaseError, createOwnershipVerificationUseCase };
