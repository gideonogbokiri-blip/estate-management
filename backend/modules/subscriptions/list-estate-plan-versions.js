const { normalizeDecimal } = require('../billing/money');
const { PlanStatus } = require('./plan');

class PlanCatalogListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PlanCatalogListError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(PlanStatus));

function text(value, field, max = 160) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw new PlanCatalogListError('INVALID_PLAN_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function safePlanVersion(row) {
  const plan = row?.planVersion;
  if (!plan?.planId || !Number.isSafeInteger(plan.version) || plan.version < 1 || !statuses.has(plan.status)
    || !/^[A-Z]{3}$/.test(plan.currency ?? '') || !Number.isInteger(plan.currencyScale)
    || plan.currencyScale < 0 || plan.currencyScale > 6 || !Array.isArray(plan.entitlements?.modules)
    || new Set(plan.entitlements.modules).size !== plan.entitlements.modules.length
    || plan.entitlements.modules.some((module) => typeof module !== 'string' || !module.trim() || module.length > 80)
    || !Array.isArray(row.policyLimitMetrics) || !row.policyLimitMetrics.length
    || !row.policyLimitMetrics.every((metric) => typeof metric === 'string' && metric.trim())) {
    throw new PlanCatalogListError('INVALID_PLAN_PROJECTION', 'The plan catalog returned an invalid version.');
  }
  let price;
  try { price = normalizeDecimal(plan.price, plan.currencyScale); }
  catch { throw new PlanCatalogListError('INVALID_PLAN_PRICE', 'Plan price must use configured exact currency precision.'); }
  const limits = {};
  for (const metric of row.policyLimitMetrics) {
    const limit = plan.entitlements.limits?.[metric];
    if (limit?.mode === 'limited' && Number.isSafeInteger(limit.value) && limit.value >= 0) {
      limits[text(metric, 'limit metric', 80)] = Object.freeze({ mode: 'limited', value: limit.value });
    } else if (limit?.mode === 'unlimited') {
      limits[text(metric, 'limit metric', 80)] = Object.freeze({ mode: 'unlimited' });
    } else if (limit?.mode === 'contract_defined') {
      limits[text(metric, 'limit metric', 80)] = Object.freeze({
        mode: 'contract_defined', contractReference: text(limit.contractReference, 'contract reference', 120),
      });
    } else {
      throw new PlanCatalogListError('INVALID_PLAN_LIMIT', 'Every platform-configured plan limit must be valid.');
    }
  }
  const trial = plan.trial;
  if (!trial || typeof trial.allowed !== 'boolean'
    || trial.allowed && (!Number.isSafeInteger(trial.durationDays) || trial.durationDays < 1)) {
    throw new PlanCatalogListError('INVALID_PLAN_TRIAL', 'Trial terms must be explicitly configured.');
  }
  const effectiveAt = new Date(plan.effectiveAt);
  if (Number.isNaN(effectiveAt.getTime())) throw new PlanCatalogListError('INVALID_EFFECTIVE_DATE', 'Plan effective date must be valid.');
  return Object.freeze({
    planId: String(plan.planId), version: plan.version,
    displayName: text(plan.displayName, 'plan name'), status: plan.status,
    price, currency: plan.currency, billingInterval: text(plan.billingInterval, 'billing interval', 40),
    effectiveAt: effectiveAt.toISOString(), modules: Object.freeze(plan.entitlements.modules.map((item) => text(item, 'module', 80))),
    limits: Object.freeze(limits), supportLevel: text(plan.entitlements.supportLevel, 'support level', 80),
    trial: Object.freeze({ allowed: trial.allowed, durationDays: trial.allowed ? trial.durationDays : null }),
  });
}

function createEstatePlanVersionListUseCase({ transaction, resolvePlanCatalogAccess, queryEstatePlanVersions } = {}) {
  const ports = { transaction, resolvePlanCatalogAccess, queryEstatePlanVersions };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PlanCatalogListError('MISSING_ADAPTER', `Plan catalog adapters are required: ${missing.join(', ')}.`);

  return async function listEstatePlanVersions({ actorUserId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new PlanCatalogListError('INVALID_QUERY', 'Authenticated platform actor and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolvePlanCatalogAccess(tx, { actorUserId });
      if (!access || String(access.actorUserId) !== String(actorUserId) || access.mayViewPlanCatalog !== true) {
        throw new PlanCatalogListError('PLAN_CATALOG_ACCESS_DENIED', 'The actor cannot view the platform plan catalog.');
      }
      const allowedStatuses = ['published'];
      if (access.mayViewDraftPlans === true) allowedStatuses.push('draft');
      if (access.mayViewRetiredPlans === true) allowedStatuses.push('retired');
      const result = await queryEstatePlanVersions(tx, { access, statuses: allowedStatuses, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new PlanCatalogListError('INVALID_LIST_RESULT', 'The plan repository returned an invalid catalog page.');
      }
      const seen = new Set();
      const items = result.items.map((row) => {
        const item = safePlanVersion(row);
        const key = `${item.planId}:${item.version}`;
        if (seen.has(key) || !allowedStatuses.includes(item.status)) {
          throw new PlanCatalogListError('UNAUTHORIZED_OR_DUPLICATE_PLAN', 'The repository returned a duplicate or unauthorized plan version.');
        }
        seen.add(key);
        return item;
      });
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total, totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { PlanCatalogListError, createEstatePlanVersionListUseCase, safePlanVersion };
