const { TenancyCommand, planTenancyCommand } = require('./tenancy');

class TenancyTerminationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyTerminationUseCaseError';
    this.code = code;
  }
}

function createTenancyTerminationUseCase({
  transaction,
  requireEstatePermission,
  findTenancyForUpdate,
  findPropertyForUpdate,
  findActiveOccupancyForTenancyForUpdate,
  checkTerminationDate,
  commitTerminationEffects,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findTenancyForUpdate,
    findPropertyForUpdate,
    findActiveOccupancyForTenancyForUpdate,
    checkTerminationDate,
    commitTerminationEffects,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new TenancyTerminationUseCaseError('MISSING_ADAPTER', `Tenancy termination adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new TenancyTerminationUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function terminateTenancy({ actorUserId, estateId, tenancyId, terminationDate, reason } = {}) {
    if (!actorUserId || !estateId || !tenancyId) {
      throw new TenancyTerminationUseCaseError('INVALID_INPUT', 'Actor, estate and tenancy are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new TenancyTerminationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage tenancies in this estate.');
      }
      const tenancy = await findTenancyForUpdate(tx, { tenancyId, estateContext });
      if (!tenancy || tenancy.estateId !== estateId) {
        throw new TenancyTerminationUseCaseError('TENANCY_NOT_FOUND', 'The tenancy was not found.');
      }
      const property = await findPropertyForUpdate(tx, { propertyId: tenancy.propertyId, estateContext });
      if (!property || property.estateId !== estateId || property.id !== tenancy.propertyId) {
        throw new TenancyTerminationUseCaseError('PROPERTY_NOT_FOUND', 'The tenancy property was not found in this estate.');
      }
      const activeOccupancy = await findActiveOccupancyForTenancyForUpdate(tx, { tenancy, estateContext });
      const datePolicyAllowsTermination = await checkTerminationDate(tx, { tenancy, property, terminationDate, estateContext });
      const plan = planTenancyCommand(tenancy, {
        command: TenancyCommand.TERMINATE,
        actorUserId,
        now: clock(),
        reason,
        terminationDate,
        datePolicyAllowsTermination,
        activeOccupancy,
      });
      const result = await commitTerminationEffects(tx, plan, { tenancy, property, activeOccupancy, estateContext });
      if (!result?.tenancy || String(result.tenancy.id) !== String(tenancyId)
        || result.tenancy.estateId !== estateId || result.tenancy.status !== 'terminated'
        || !result.occupancy || String(result.occupancy.id) !== String(activeOccupancy.id)
        || result.occupancy.status !== 'ended' || result.occupancy.effectiveTo !== terminationDate) {
        throw new TenancyTerminationUseCaseError('INVALID_TERMINATION_RESULT', 'The transaction must terminate the tenancy and end its linked occupancy while preserving both records.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ tenancyId, occupancyId: activeOccupancy.id, estateId, status: result.tenancy.status, terminationDate });
    });
  };
}

module.exports = { TenancyTerminationUseCaseError, createTenancyTerminationUseCase };
