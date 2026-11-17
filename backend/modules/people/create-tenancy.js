const { planTenancyCreation } = require('./tenancy');

class TenancyCreationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyCreationUseCaseError';
    this.code = code;
  }
}

/** Create a draft/pending tenancy using existing identity, estate and policy adapters. */
function createTenancyUseCase({
  transaction,
  requireEstatePermission,
  findPropertyForUpdate,
  validateTenancyParties,
  getTenancyCreationPolicy,
  generateTenancyId,
  createTenancyRecord,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findPropertyForUpdate,
    validateTenancyParties,
    getTenancyCreationPolicy,
    generateTenancyId,
    createTenancyRecord,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new TenancyCreationUseCaseError('MISSING_ADAPTER', `Tenancy creation adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new TenancyCreationUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createTenancy({ actorUserId, estateId, tenancyDraft, initialStatus = 'pending_approval' } = {}) {
    if (!actorUserId || !estateId || !tenancyDraft || tenancyDraft.estateId !== estateId) {
      throw new TenancyCreationUseCaseError('INVALID_CREATION_INPUT', 'Actor, estate context and same-estate tenancy terms are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new TenancyCreationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot create tenancies in this estate.');
      }
      // Lock the property so creation serializes with archive and other relationship writers.
      const property = await findPropertyForUpdate(tx, { propertyId: tenancyDraft.propertyId, estateContext });
      if (!property || property.estateId !== estateId) {
        throw new TenancyCreationUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found in this estate.');
      }
      const policy = await getTenancyCreationPolicy(tx, { estateId, property, estateContext });
      if (!policy || !Number.isInteger(policy.currencyScale) || !Array.isArray(policy.allowedInitialStatuses)
        || !policy.allowedInitialStatuses.includes(initialStatus)) {
        throw new TenancyCreationUseCaseError('TENANCY_POLICY_REQUIRED', 'Load the estate rent and initial-status policy before creating a tenancy.');
      }
      const partiesValid = await validateTenancyParties(tx, {
        estateId,
        property,
        tenantUserId: tenancyDraft.tenantUserId,
        payeeUserIds: tenancyDraft.payeeUserIds,
        estateContext,
      });
      if (partiesValid !== true) {
        throw new TenancyCreationUseCaseError('INVALID_TENANCY_PARTIES', 'The tenant and every payee must be verified, eligible existing Zvend users linked under estate policy.');
      }

      const tenancyId = await generateTenancyId(tx);
      const plan = planTenancyCreation({
        tenancyId,
        actorUserId,
        now: clock(),
        tenancyDraft: { ...tenancyDraft, estateId, currency: policy.currency },
        property,
        currencyScale: policy.currencyScale,
        initialStatus,
      });
      const created = await createTenancyRecord(tx, plan.tenancy);
      if (!created || String(created.id) !== String(plan.tenancyId)
        || created.estateId !== estateId || created.propertyId !== property.id
        || created.tenantUserId !== plan.tenancy.tenantUserId || created.status !== initialStatus) {
        throw new TenancyCreationUseCaseError('INVALID_CREATE_RESULT', 'The repository did not persist the planned tenancy in the selected estate.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ tenancyId: plan.tenancyId, status: initialStatus, result: created });
    });
  };
}

module.exports = { TenancyCreationUseCaseError, createTenancyUseCase };
