const { planTenancyRenewal } = require('./tenancy');

class TenancyRenewalUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyRenewalUseCaseError';
    this.code = code;
  }
}

function createTenancyRenewalUseCase({
  transaction,
  requireEstatePermission,
  findTenancyForUpdate,
  findPropertyInEstate,
  getRenewalPolicy,
  validateRenewalParties,
  createLinkedRenewal,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findTenancyForUpdate,
    findPropertyInEstate,
    getRenewalPolicy,
    validateRenewalParties,
    createLinkedRenewal,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new TenancyRenewalUseCaseError('MISSING_ADAPTER', `Tenancy renewal adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new TenancyRenewalUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createTenancyRenewal({ actorUserId, estateId, tenancyId, renewalTerms } = {}) {
    if (!actorUserId || !estateId || !tenancyId) {
      throw new TenancyRenewalUseCaseError('INVALID_RENEWAL_INPUT', 'Actor, estate context, and prior tenancy are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new TenancyRenewalUseCaseError('ESTATE_ACCESS_DENIED', 'The actor is not authorized to manage tenancies in this estate.');
      }
      const previousTenancy = await findTenancyForUpdate(tx, { tenancyId, estateContext });
      if (!previousTenancy || previousTenancy.estateId !== estateContext.estateId) {
        throw new TenancyRenewalUseCaseError('TENANCY_NOT_FOUND', 'The prior tenancy was not found.');
      }

      const property = await findPropertyInEstate(tx, {
        propertyId: previousTenancy.propertyId,
        estateContext,
      });
      if (!property || property.estateId !== previousTenancy.estateId) {
        throw new TenancyRenewalUseCaseError('PROPERTY_NOT_FOUND', 'The tenancy property was not found in this estate.');
      }

      const policy = await getRenewalPolicy(tx, { previousTenancy, estateContext });
      await validateRenewalParties(tx, { previousTenancy, renewalTerms, estateContext });
      const plan = planTenancyRenewal(previousTenancy, {
        actorUserId,
        now: clock(),
        renewalDraft: renewalTerms,
        property,
        mayRenew: policy?.mayRenew,
        initialStatus: policy?.initialStatus,
      });

      const renewal = await createLinkedRenewal(tx, plan.renewal, { priorTenancy: previousTenancy });
      if (!renewal?.id || renewal.renewalOfTenancyId !== previousTenancy.id
        || renewal.estateId !== previousTenancy.estateId || renewal.propertyId !== previousTenancy.propertyId
        || renewal.tenantUserId !== previousTenancy.tenantUserId || renewal.status !== plan.renewal.status) {
        throw new TenancyRenewalUseCaseError('INVALID_RENEWAL_RESULT', 'The repository must create a separate renewal linked to the prior tenancy.');
      }
      const auditEvent = Object.freeze({
        ...plan.auditEvent,
        metadata: Object.freeze({ ...plan.auditEvent.metadata, renewalTenancyId: renewal.id }),
      });
      await appendAuditEvent(tx, auditEvent);
      return Object.freeze({ priorTenancyId: previousTenancy.id, renewalTenancyId: renewal.id, status: renewal.status });
    });
  };
}

module.exports = { TenancyRenewalUseCaseError, createTenancyRenewalUseCase };
