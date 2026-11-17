const { EstateType, OperationalEstateStatus } = require('./estate');

class EstateSummaryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateSummaryError';
    this.code = code;
  }
}

function safeOptionalText(value, field, maxLength) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new EstateSummaryError('INVALID_REPOSITORY_RESULT', `The estate ${field} summary is invalid.`);
  }
  return value;
}

/** Read a safe estate summary under the caller's active estate membership context. */
function createEstateSummaryUseCase({
  transaction,
  requireEstatePermission,
  findEstateInContext,
} = {}) {
  const ports = { transaction, requireEstatePermission, findEstateInContext };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateSummaryError('MISSING_ADAPTER', `Estate summary adapters are required: ${missing.join(', ')}.`);

  return async function readEstateSummary({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new EstateSummaryError('INVALID_INPUT', 'Authenticated actor and estate are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'estate.view', tx);
      if (!estateContext || String(estateContext.actorUserId) !== String(actorUserId)
        || String(estateContext.estateId) !== String(estateId)) {
        throw new EstateSummaryError('ESTATE_ACCESS_DENIED', 'The actor cannot view this estate.');
      }
      const estate = await findEstateInContext(tx, { estateContext, estateId });
      if (!estate || String(estate.id) !== String(estateId)) {
        throw new EstateSummaryError('ESTATE_NOT_FOUND', 'The estate was not found in this context.');
      }
      if (estate.status !== OperationalEstateStatus.ACTIVE) {
        throw new EstateSummaryError('ESTATE_NOT_ACTIVE', 'This estate is not available for normal operations.');
      }
      if (typeof estate.name !== 'string' || !estate.name.trim() || !Object.values(EstateType).includes(estate.type)) {
        throw new EstateSummaryError('INVALID_REPOSITORY_RESULT', 'The estate summary is missing its display identity.');
      }
      const latitude = estate.latitude ?? null;
      const longitude = estate.longitude ?? null;
      if ((latitude === null) !== (longitude === null)
        || (latitude !== null && (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
          || !Number.isFinite(longitude) || longitude < -180 || longitude > 180))) {
        throw new EstateSummaryError('INVALID_REPOSITORY_RESULT', 'The estate summary contains invalid coordinates.');
      }
      const location = Object.freeze({
        address: safeOptionalText(estate.address, 'address', 180),
        state: safeOptionalText(estate.state, 'state', 100),
        lga: safeOptionalText(estate.lga, 'LGA', 100),
        latitude,
        longitude,
      });
      const currency = safeOptionalText(estate.currency, 'currency', 3);
      if (currency !== null && !/^[A-Z]{3}$/.test(currency)) {
        throw new EstateSummaryError('INVALID_REPOSITORY_RESULT', 'The estate summary contains an invalid currency code.');
      }
      return Object.freeze({
        id: estate.id,
        code: safeOptionalText(estate.code, 'code', 40),
        name: estate.name.trim(),
        type: estate.type,
        status: estate.status,
        location,
        timezone: safeOptionalText(estate.timezone, 'timezone', 100),
        currency,
      });
    });
  };
}

module.exports = { EstateSummaryError, createEstateSummaryUseCase };
