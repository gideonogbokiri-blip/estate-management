const { planPassRevocation } = require('./visitor-pass');

class VisitorPassRevocationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'VisitorPassRevocationUseCaseError';
    this.code = code;
  }
}

function createVisitorPassRevocationUseCase({
  transaction,
  findHostPassForUpdate,
  commitRevocation,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, findHostPassForUpdate, commitRevocation, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new VisitorPassRevocationUseCaseError('MISSING_ADAPTER', `Visitor pass revocation adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new VisitorPassRevocationUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function revokeVisitorPass({ actorUserId, estateId, passId, reason } = {}) {
    if (!actorUserId || !estateId || !passId || typeof reason !== 'string' || !reason.trim() || reason.trim().length > 300) {
      throw new VisitorPassRevocationUseCaseError('INVALID_REVOCATION_INPUT', 'Authenticated host, estate, pass and a reason of up to 300 characters are required.');
    }
    return transaction(async (tx) => {
      // The repository must lock by estate, host and pass ID so ownership cannot race a transfer/revocation.
      const pass = await findHostPassForUpdate(tx, { actorUserId, estateId, passId });
      if (!pass || pass.estateId !== estateId || pass.hostUserId !== actorUserId || String(pass.id) !== String(passId)) {
        throw new VisitorPassRevocationUseCaseError('PASS_NOT_FOUND', 'The visitor pass was not found for this host and estate.');
      }
      const plan = planPassRevocation(pass, { actorUserId, now: clock(), reason });
      const updated = await commitRevocation(tx, plan);
      if (!updated || String(updated.id) !== String(passId) || updated.estateId !== estateId
        || updated.hostUserId !== actorUserId || !updated.revokedAt) {
        throw new VisitorPassRevocationUseCaseError('INVALID_REVOKE_RESULT', 'The repository did not confirm pass revocation.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ passId: updated.id, estateId, status: 'revoked', revokedAt: updated.revokedAt });
    });
  };
}

module.exports = { VisitorPassRevocationUseCaseError, createVisitorPassRevocationUseCase };
