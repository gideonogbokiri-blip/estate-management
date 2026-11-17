class VisitorPassListUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'VisitorPassListUseCaseError';
    this.code = code;
  }
}

function createMyVisitorPassListUseCase({ transaction, resolveHostEstateAccess, queryMyVisitorPasses, clock = () => new Date() } = {}) {
  const ports = { transaction, resolveHostEstateAccess, queryMyVisitorPasses, clock };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new VisitorPassListUseCaseError('MISSING_ADAPTER', `Visitor pass list adapters are required: ${missing.join(', ')}.`);

  return async function listMyVisitorPasses({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new VisitorPassListUseCaseError('INVALID_LIST_INPUT', 'Authenticated host and estate are required.');
    return transaction(async (tx) => {
      const access = await resolveHostEstateAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId) || access.active !== true) {
        throw new VisitorPassListUseCaseError('HOST_ACCESS_DENIED', 'The host cannot view visitor passes in this estate.');
      }
      const asOf = new Date(clock()).getTime();
      if (!Number.isFinite(asOf)) throw new VisitorPassListUseCaseError('INVALID_CLOCK', 'A valid server timestamp is required.');
      const result = await queryMyVisitorPasses(tx, { actorUserId, estateId, limit: 100 });
      if (!Array.isArray(result) || result.length > 100) throw new VisitorPassListUseCaseError('INVALID_LIST_RESULT', 'The visitor pass repository must return at most 100 records.');
      const passIds = new Set();
      const items = result.map((pass) => {
        if (!pass || String(pass.estateId) !== String(estateId)
          || String(pass.hostUserId) !== String(actorUserId) || !pass.id) {
          throw new VisitorPassListUseCaseError('CROSS_SCOPE_RESULT', 'The visitor pass repository returned a record outside the host scope.');
        }
        if (passIds.has(String(pass.id))) throw new VisitorPassListUseCaseError('DUPLICATE_PASS', 'The visitor pass repository returned duplicate records.');
        passIds.add(String(pass.id));
        const validFrom = new Date(pass.validFrom).getTime();
        const validUntil = new Date(pass.validUntil).getTime();
        if (!pass.propertyId || typeof pass.visitorDisplayName !== 'string' || !pass.visitorDisplayName.trim()
          || pass.visitorDisplayName.length > 100 || !Number.isFinite(validFrom) || !Number.isFinite(validUntil)
          || validUntil <= validFrom || !Number.isInteger(pass.allowedUses) || pass.allowedUses < 1
          || !Number.isInteger(pass.useCount) || pass.useCount < 0 || pass.useCount > pass.allowedUses) {
          throw new VisitorPassListUseCaseError('INVALID_PASS_RESULT', 'The visitor pass repository returned invalid lifecycle data.');
        }
        if (pass.vehicleSummary !== null && pass.vehicleSummary !== undefined
          && (typeof pass.vehicleSummary !== 'string' || pass.vehicleSummary.length > 80)) {
          throw new VisitorPassListUseCaseError('INVALID_PASS_RESULT', 'The visitor pass repository returned invalid vehicle details.');
        }
        const revokedTime = pass.revokedAt === null || pass.revokedAt === undefined ? null : new Date(pass.revokedAt).getTime();
        if (revokedTime !== null && !Number.isFinite(revokedTime)) {
          throw new VisitorPassListUseCaseError('INVALID_PASS_RESULT', 'The visitor pass repository returned an invalid revocation timestamp.');
        }
        return Object.freeze({
          passId: pass.id, estateId: access.estateId, propertyId: pass.propertyId,
          visitorDisplayName: pass.visitorDisplayName,
          validFrom: new Date(validFrom).toISOString(), validUntil: new Date(validUntil).toISOString(),
          allowedUses: pass.allowedUses, useCount: pass.useCount,
          revokedAt: revokedTime === null ? null : new Date(revokedTime).toISOString(),
          vehicleSummary: pass.vehicleSummary ?? null,
          status: revokedTime !== null ? 'revoked' : pass.useCount >= pass.allowedUses ? 'exhausted'
            : asOf >= validUntil ? 'expired' : 'active',
        });
      });
      return Object.freeze({ items: Object.freeze(items) });
    });
  };
}

module.exports = { VisitorPassListUseCaseError, createMyVisitorPassListUseCase };
