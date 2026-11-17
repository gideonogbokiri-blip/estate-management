const { planOccupancyCreation, planOccupancyEnd } = require('./occupancy');

class PropertyOccupancyUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyOccupancyUseCaseError';
    this.code = code;
  }
}

function createPropertyOccupancyUseCase({
  transaction,
  requireEstatePermission,
  findPropertyForUpdate,
  validateOccupantLink,
  generateOccupancyId,
  createOccupancy,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findPropertyForUpdate, validateOccupantLink, generateOccupancyId, createOccupancy, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PropertyOccupancyUseCaseError('MISSING_ADAPTER', `Occupancy creation adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new PropertyOccupancyUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function addPropertyOccupant({ actorUserId, estateId, propertyId, userId, relationship, effectiveFrom, effectiveTo } = {}) {
    if (!actorUserId || !estateId || !propertyId || !userId) {
      throw new PropertyOccupancyUseCaseError('INVALID_INPUT', 'Actor, estate, property and existing Zvend user are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'occupancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new PropertyOccupancyUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage occupancy in this estate.');
      const property = await findPropertyForUpdate(tx, { propertyId, estateContext });
      if (!property || property.estateId !== estateId) throw new PropertyOccupancyUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found in this estate.');
      const linkValid = await validateOccupantLink(tx, { estateId, property, userId, relationship, estateContext });
      const occupancyId = await generateOccupancyId(tx);
      const plan = planOccupancyCreation({
        occupancyId,
        actorUserId,
        now: clock(),
        property,
        linkValid,
        draft: { estateId, propertyId, userId, relationship, effectiveFrom, effectiveTo },
      });
      const created = await createOccupancy(tx, plan.occupancy, { estateContext });
      if (!created || String(created.id) !== String(occupancyId) || created.estateId !== estateId
        || created.propertyId !== propertyId || created.userId !== userId || created.status !== 'active') {
        throw new PropertyOccupancyUseCaseError('INVALID_CREATE_RESULT', 'The repository did not persist the planned active occupancy.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ occupancyId, estateId, status: created.status, result: created });
    });
  };
}

function createPropertyOccupancyEndUseCase({
  transaction,
  requireEstatePermission,
  findOccupancyForUpdate,
  checkOccupancyEndDate,
  commitOccupancyEnd,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findOccupancyForUpdate, checkOccupancyEndDate, commitOccupancyEnd, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PropertyOccupancyUseCaseError('MISSING_ADAPTER', `Occupancy end adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new PropertyOccupancyUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function endPropertyOccupancy({ actorUserId, estateId, occupancyId, effectiveTo, reason } = {}) {
    if (!actorUserId || !estateId || !occupancyId) throw new PropertyOccupancyUseCaseError('INVALID_INPUT', 'Actor, estate and occupancy are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'occupancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new PropertyOccupancyUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage occupancy in this estate.');
      const occupancy = await findOccupancyForUpdate(tx, { occupancyId, estateContext });
      if (!occupancy || occupancy.estateId !== estateId) throw new PropertyOccupancyUseCaseError('OCCUPANCY_NOT_FOUND', 'The occupancy was not found.');
      const datePolicyAllowsEnd = await checkOccupancyEndDate(tx, { occupancy, effectiveTo, estateContext });
      const plan = planOccupancyEnd(occupancy, { actorUserId, effectiveTo, reason, now: clock(), datePolicyAllowsEnd });
      const ended = await commitOccupancyEnd(tx, plan, { estateContext });
      if (!ended || String(ended.id) !== String(occupancy.id) || ended.estateId !== estateId
        || ended.status !== 'ended' || ended.effectiveTo !== effectiveTo) {
        throw new PropertyOccupancyUseCaseError('INVALID_END_RESULT', 'The repository must end the occupancy while retaining its history.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ occupancyId, estateId, status: ended.status, effectiveTo });
    });
  };
}

module.exports = { PropertyOccupancyUseCaseError, createPropertyOccupancyUseCase, createPropertyOccupancyEndUseCase };
