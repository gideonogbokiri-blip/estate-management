const { TenancyCommand, TenancyStatus, planTenancyCommand, planTenancyRenewalActivation } = require('./tenancy');

class TenancyApprovalUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyApprovalUseCaseError';
    this.code = code;
  }
}

function validateApprovalCommitResult(result, plan, tenancy) {
  const activated = result?.tenancy;
  const occupancy = result?.occupancy;
  const unchangedTerms = ['rentAmount', 'currency', 'rentFrequency', 'startDate', 'endDate']
    .every((field) => activated?.[field] === tenancy[field]);
  const unchangedPayees = Array.isArray(activated?.payeeUserIds) && Array.isArray(tenancy.payeeUserIds)
    && activated.payeeUserIds.length === tenancy.payeeUserIds.length
    && activated.payeeUserIds.every((userId, index) => String(userId) === String(tenancy.payeeUserIds[index]));
  if (!activated?.id || String(activated.id) !== String(tenancy.id)
    || String(activated.estateId) !== String(tenancy.estateId)
    || String(activated.propertyId) !== String(tenancy.propertyId)
    || String(activated.tenantUserId) !== String(tenancy.tenantUserId)
    || activated.status !== TenancyStatus.ACTIVE || (activated.renewalOfTenancyId ?? null) !== (tenancy.renewalOfTenancyId ?? null)
    || !unchangedTerms || !unchangedPayees
    || !occupancy?.id || String(occupancy.estateId) !== String(tenancy.estateId)
    || String(occupancy.propertyId) !== String(tenancy.propertyId)
    || String(occupancy.userId) !== String(tenancy.tenantUserId)
    || String(occupancy.tenancyId) !== String(tenancy.id) || occupancy.status !== 'active'
    || occupancy.effectiveFrom !== tenancy.startDate) {
    throw new TenancyApprovalUseCaseError('INVALID_COMMIT_RESULT', 'Approval must persist the active tenancy and its linked active occupancy atomically.');
  }

  if (plan.priorTenancyId) {
    const prior = result.previousTenancy;
    if (!prior?.id || String(prior.id) !== String(plan.priorTenancyId)
      || String(prior.estateId) !== String(tenancy.estateId)
      || String(prior.propertyId) !== String(tenancy.propertyId)
      || String(prior.tenantUserId) !== String(tenancy.tenantUserId)
      || prior.status !== TenancyStatus.EXPIRED) {
      throw new TenancyApprovalUseCaseError('INVALID_PRIOR_COMMIT_RESULT', 'Renewal approval must preserve the linked prior tenancy in the expired state.');
    }
    const priorOccupancyEnd = plan.effects.some((effect) => effect.type === 'property_occupancy.end_from_tenancy');
    if (priorOccupancyEnd) {
      const previousOccupancy = result.previousOccupancy;
      const plannedEnd = plan.effects.find((effect) => effect.type === 'property_occupancy.end_from_tenancy');
      if (!previousOccupancy?.id || String(previousOccupancy.tenancyId) !== String(plan.priorTenancyId)
        || String(previousOccupancy.estateId) !== String(tenancy.estateId)
        || String(previousOccupancy.propertyId) !== String(tenancy.propertyId)
        || String(previousOccupancy.userId) !== String(tenancy.tenantUserId)
        || previousOccupancy.status !== 'ended' || previousOccupancy.endedAt !== plannedEnd.endedAt) {
        throw new TenancyApprovalUseCaseError('INVALID_PRIOR_OCCUPANCY_RESULT', 'Renewal approval must close the prior occupancy when the transition plan requires it.');
      }
    }
  }
  return Object.freeze({
    occupancyId: occupancy.id,
    previousOccupancyId: result.previousOccupancy?.id ?? null,
  });
}

function createTenancyApprovalUseCase({
  transaction,
  requireEstatePermission,
  findTenancyForUpdate,
  findLinkedPriorTenancyForUpdate,
  findPropertyInEstate,
  findActiveTenanciesForProperty,
  getRenewalActivationWindow,
  commitDecisionEffects,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findTenancyForUpdate,
    findLinkedPriorTenancyForUpdate,
    findPropertyInEstate,
    findActiveTenanciesForProperty,
    getRenewalActivationWindow,
    commitDecisionEffects,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new TenancyApprovalUseCaseError('MISSING_ADAPTER', `Tenancy approval adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new TenancyApprovalUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function approveTenancy({ actorUserId, estateId, tenancyId } = {}) {
    if (!actorUserId || !estateId || !tenancyId) {
      throw new TenancyApprovalUseCaseError('INVALID_APPROVAL_INPUT', 'Approver, estate context, and tenancy are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.approve', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new TenancyApprovalUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot approve tenancies in this estate.');
      }
      const tenancy = await findTenancyForUpdate(tx, { tenancyId, estateContext });
      if (!tenancy || String(tenancy.estateId) !== String(estateId)) {
        throw new TenancyApprovalUseCaseError('TENANCY_NOT_FOUND', 'The tenancy was not found.');
      }
      const property = await findPropertyInEstate(tx, { propertyId: tenancy.propertyId, estateContext });
      if (!property || String(property.estateId) !== String(tenancy.estateId)) {
        throw new TenancyApprovalUseCaseError('PROPERTY_NOT_FOUND', 'The tenancy property was not found.');
      }

      // This adapter must lock the property's active-tenancy conflict scope until commit.
      const activeConflicts = await findActiveTenanciesForProperty(tx, {
        estateId,
        propertyId: tenancy.propertyId,
        estateContext,
      });
      let plan;
      if (tenancy.renewalOfTenancyId) {
        const previousTenancy = await findLinkedPriorTenancyForUpdate(tx, {
          tenancyId: tenancy.renewalOfTenancyId,
          estateContext,
        });
        if (!previousTenancy || String(previousTenancy.estateId) !== String(estateId)) {
          throw new TenancyApprovalUseCaseError('PRIOR_TENANCY_NOT_FOUND', 'The linked prior tenancy was not found.');
        }
        const renewalWindow = await getRenewalActivationWindow(tx, { renewal: tenancy, previousTenancy, estateContext });
        plan = planTenancyRenewalActivation(tenancy, {
          previousTenancy,
          actorUserId,
          now: clock(),
          property,
          activeConflicts,
          renewalWindow,
        });
      } else {
        plan = planTenancyCommand(tenancy, {
          command: TenancyCommand.APPROVE,
          actorUserId,
          now: clock(),
          property,
          activeConflicts,
        });
      }

      const result = await commitDecisionEffects(tx, plan);
      const committed = validateApprovalCommitResult(result, plan, tenancy);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        tenancyId: plan.tenancyId,
        estateId,
        status: plan.nextStatus,
        occupancyId: committed.occupancyId,
        priorTenancyId: plan.priorTenancyId ?? null,
        priorOccupancyId: committed.previousOccupancyId,
      });
    });
  };
}

module.exports = { TenancyApprovalUseCaseError, createTenancyApprovalUseCase, validateApprovalCommitResult };
