const { planTenancyTermsUpdate } = require('./tenancy');

class TenancyTermsUpdateUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyTermsUpdateUseCaseError';
    this.code = code;
  }
}

function createTenancyTermsUpdateUseCase({
  transaction,
  requireEstatePermission,
  findTenancyForUpdate,
  findPropertyForUpdate,
  getTenancyTermPolicy,
  validateTenancyParties,
  validateUpdatedTenancyPolicy,
  commitTenancyTermsAndHistory,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findTenancyForUpdate,
    findPropertyForUpdate,
    getTenancyTermPolicy,
    validateTenancyParties,
    validateUpdatedTenancyPolicy,
    commitTenancyTermsAndHistory,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new TenancyTermsUpdateUseCaseError('MISSING_ADAPTER', `Tenancy update adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new TenancyTermsUpdateUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function updateTenancyTerms({ actorUserId, estateId, tenancyId, changes } = {}) {
    if (!actorUserId || !estateId || !tenancyId) {
      throw new TenancyTermsUpdateUseCaseError('INVALID_INPUT', 'Actor, estate and tenancy are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new TenancyTermsUpdateUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage tenancies in this estate.');
      }
      const tenancy = await findTenancyForUpdate(tx, { tenancyId, estateContext });
      if (!tenancy || tenancy.estateId !== estateId) {
        throw new TenancyTermsUpdateUseCaseError('TENANCY_NOT_FOUND', 'The tenancy was not found.');
      }
      const property = await findPropertyForUpdate(tx, { propertyId: tenancy.propertyId, estateContext });
      if (!property || property.estateId !== estateId || property.id !== tenancy.propertyId) {
        throw new TenancyTermsUpdateUseCaseError('PROPERTY_NOT_FOUND', 'The tenancy property was not found in this estate.');
      }
      const policy = await getTenancyTermPolicy(tx, { tenancy, property, estateContext });
      if (!policy || !Number.isInteger(policy.currencyScale) || typeof policy.currency !== 'string') {
        throw new TenancyTermsUpdateUseCaseError('TENANCY_POLICY_REQUIRED', 'Load the estate currency and rent-term policy before editing.');
      }
      const plan = planTenancyTermsUpdate(tenancy, {
        actorUserId,
        now: clock(),
        changes,
        property,
        currencyScale: policy.currencyScale,
      });
      if (plan.nextTenancy.currency !== policy.currency) {
        throw new TenancyTermsUpdateUseCaseError('CURRENCY_MISMATCH', 'Tenancy currency must match the estate policy.');
      }
      const partiesValid = await validateTenancyParties(tx, {
        estateId,
        property,
        tenantUserId: plan.nextTenancy.tenantUserId,
        payeeUserIds: plan.nextTenancy.payeeUserIds,
        estateContext,
      });
      if (partiesValid !== true) {
        throw new TenancyTermsUpdateUseCaseError('INVALID_TENANCY_PARTIES', 'The tenant and payees must remain eligible under estate policy.');
      }
      const policyAllowsUpdate = await validateUpdatedTenancyPolicy(tx, { tenancy, nextTenancy: plan.nextTenancy, estateContext });
      if (policyAllowsUpdate !== true) {
        throw new TenancyTermsUpdateUseCaseError('TENANCY_POLICY_REJECTED', 'Updated dates or rent terms do not satisfy estate policy.');
      }
      const result = await commitTenancyTermsAndHistory(tx, plan, { estateContext });
      if (!result?.tenancy || String(result.tenancy.id) !== String(tenancyId)
        || result.tenancy.estateId !== estateId || result.tenancy.status !== tenancy.status
        || result.tenancy.rentAmount !== plan.nextTenancy.rentAmount
        || result.tenancy.currency !== plan.nextTenancy.currency
        || result.historyRecorded !== true) {
        throw new TenancyTermsUpdateUseCaseError('INVALID_UPDATE_RESULT', 'The repository must save new terms and immutable change history together.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ tenancyId, estateId, status: result.tenancy.status, changedFields: plan.changedFields, result: result.tenancy });
    });
  };
}

module.exports = { TenancyTermsUpdateUseCaseError, createTenancyTermsUpdateUseCase };
