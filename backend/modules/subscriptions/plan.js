const { normalizeDecimal } = require('../billing/money');

const PlanStatus = Object.freeze({ DRAFT: 'draft', PUBLISHED: 'published', RETIRED: 'retired' });

class PlanError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PlanError';
    this.code = code;
  }
}

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function validateLimit(limit, name) {
  if (limit?.mode === 'unlimited') return Object.freeze({ mode: 'unlimited' });
  if (limit?.mode === 'limited' && Number.isSafeInteger(limit.value) && limit.value >= 0) {
    return Object.freeze({ mode: 'limited', value: limit.value });
  }
  if (limit?.mode === 'contract_defined' && typeof limit.contractReference === 'string' && limit.contractReference.trim()) {
    return Object.freeze({ mode: 'contract_defined', contractReference: limit.contractReference.trim() });
  }
  throw new PlanError('INVALID_ENTITLEMENT_LIMIT', `Configure ${name} as limited, unlimited, or contract_defined.`);
}

function preparePlanVersion(input, policy, now) {
  const {
    planId,
    version,
    displayName,
    price,
    currency,
    currencyScale,
    billingInterval,
    effectiveAt,
    modules,
    limits,
    supportLevel,
    trial,
    createdByUserId,
  } = input ?? {};
  const createdTime = parseInstant(now);
  const effectiveTime = parseInstant(effectiveAt);
  if (!planId || !Number.isSafeInteger(version) || version < 1
    || typeof displayName !== 'string' || !displayName.trim() || !createdByUserId) {
    throw new PlanError('INVALID_PLAN_VERSION', 'Plan identity, version, name, and creator are required.');
  }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)
    || typeof billingInterval !== 'string' || !policy?.billingIntervals?.includes(billingInterval)) {
    throw new PlanError('INVALID_BILLING_TERMS', 'Currency and billing interval must be supported by platform policy.');
  }
  const normalizedPrice = normalizeDecimal(price, currencyScale);
  if (createdTime === null || effectiveTime === null || effectiveTime < createdTime) {
    throw new PlanError('INVALID_EFFECTIVE_DATE', 'Plan effective time must be valid and cannot precede version creation.');
  }
  if (!Array.isArray(modules) || new Set(modules).size !== modules.length
    || modules.some((moduleCode) => !policy?.availableModules?.includes(moduleCode))) {
    throw new PlanError('INVALID_PLAN_MODULES', 'Plan modules must be unique available platform modules.');
  }
  if (!Array.isArray(policy?.supportLevels) || !policy.supportLevels.includes(supportLevel)) {
    throw new PlanError('INVALID_SUPPORT_LEVEL', 'Choose a support level configured by the platform.');
  }
  if (!trial || typeof trial.allowed !== 'boolean'
    || (trial.allowed && (!Number.isSafeInteger(trial.durationDays) || trial.durationDays < 1
      || !Number.isSafeInteger(policy.maximumTrialDays) || policy.maximumTrialDays < 1
      || trial.durationDays > policy.maximumTrialDays))) {
    throw new PlanError('INVALID_TRIAL_POLICY', 'Trial terms must follow the configured platform limits.');
  }
  if (!Array.isArray(policy.limitMetrics) || policy.limitMetrics.length === 0
    || policy.limitMetrics.some((metric) => typeof metric !== 'string' || !metric.trim())
    || new Set(policy.limitMetrics).size !== policy.limitMetrics.length
    || !limits || typeof limits !== 'object') {
    throw new PlanError('INVALID_ENTITLEMENTS', 'Configure every platform usage metric explicitly.');
  }
  const entitlementLimits = {};
  for (const metric of policy.limitMetrics ?? []) {
    entitlementLimits[metric] = validateLimit(limits?.[metric], metric);
  }

  return Object.freeze({
    planId,
    version,
    displayName: displayName.trim(),
    status: PlanStatus.DRAFT,
    price: normalizedPrice,
    currency,
    currencyScale,
    billingInterval,
    effectiveAt: new Date(effectiveTime).toISOString(),
    entitlements: Object.freeze({
      modules: Object.freeze([...modules]),
      limits: Object.freeze(entitlementLimits),
      supportLevel,
    }),
    trial: Object.freeze({ allowed: trial.allowed, durationDays: trial.allowed ? trial.durationDays : null }),
    createdByUserId,
    createdAt: new Date(createdTime).toISOString(),
  });
}

function planVersionPublish(planVersion, { actorUserId, mayPublish, now } = {}) {
  const publishedAtMs = parseInstant(now);
  if (!planVersion?.planId || !Number.isSafeInteger(planVersion.version)
    || planVersion.status !== PlanStatus.DRAFT) {
    throw new PlanError('INVALID_STATE', 'Only a draft plan version can be published.');
  }
  if (!actorUserId || mayPublish !== true || publishedAtMs === null) {
    throw new PlanError('PERMISSION_DENIED', 'An authorized plan publisher and timestamp are required.');
  }

  const publishedAt = new Date(publishedAtMs).toISOString();
  return Object.freeze({
    transactionRequired: true,
    planId: planVersion.planId,
    version: planVersion.version,
    nextStatus: PlanStatus.PUBLISHED,
    effects: Object.freeze([Object.freeze({
      type: 'estate_plan_version.published',
      planId: planVersion.planId,
      version: planVersion.version,
      from: PlanStatus.DRAFT,
      to: PlanStatus.PUBLISHED,
      actorUserId,
      publishedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_plan_version.publish',
      targetType: 'estate_plan_version',
      targetId: `${planVersion.planId}:${planVersion.version}`,
      outcome: 'success',
      occurredAt: publishedAt,
    }),
  });
}

function planVersionRetire(planVersion, { actorUserId, mayRetire, now, reason } = {}) {
  const retiredAtMs = parseInstant(now);
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!planVersion?.planId || !Number.isSafeInteger(planVersion.version)
    || planVersion.status !== PlanStatus.PUBLISHED) {
    throw new PlanError('INVALID_STATE', 'Only a published plan version can be retired.');
  }
  if (!actorUserId || mayRetire !== true || retiredAtMs === null || !normalizedReason) {
    throw new PlanError('PERMISSION_DENIED', 'Authorized actor, timestamp, and retirement reason are required.');
  }

  const retiredAt = new Date(retiredAtMs).toISOString();
  return Object.freeze({
    transactionRequired: true,
    planId: planVersion.planId,
    version: planVersion.version,
    nextStatus: PlanStatus.RETIRED,
    effects: Object.freeze([Object.freeze({
      type: 'estate_plan_version.retired',
      planId: planVersion.planId,
      version: planVersion.version,
      from: PlanStatus.PUBLISHED,
      to: PlanStatus.RETIRED,
      actorUserId,
      reason: normalizedReason,
      retiredAt,
      applyToExistingSubscriptions: false,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_plan_version.retire',
      targetType: 'estate_plan_version',
      targetId: `${planVersion.planId}:${planVersion.version}`,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt: retiredAt,
    }),
  });
}

function prepareSubscriptionAgreement(input, now) {
  const { estateId, billingCustomerReference, billingContactUserId, planVersion, startAt, renewalMode } = input ?? {};
  const createdTime = parseInstant(now);
  const startTime = parseInstant(startAt);
  if (!estateId || !billingCustomerReference || !billingContactUserId
    || planVersion?.status !== PlanStatus.PUBLISHED || !planVersion.planId
    || !Number.isSafeInteger(planVersion.version)) {
    throw new PlanError('INVALID_SUBSCRIPTION', 'Estate billing identity and a published plan version are required.');
  }
  const planEffectiveTime = parseInstant(planVersion.effectiveAt);
  if (createdTime === null || startTime === null || planEffectiveTime === null
    || startTime < createdTime || startTime < planEffectiveTime) {
    throw new PlanError('INVALID_START_DATE', 'Subscription must begin after creation and plan effectiveness.');
  }
  if (!['automatic', 'manual'].includes(renewalMode)) {
    throw new PlanError('INVALID_RENEWAL_MODE', 'Choose an allowed renewal mode.');
  }

  return Object.freeze({
    estateId,
    billingCustomerReference,
    billingContactUserId,
    planReference: Object.freeze({ planId: planVersion.planId, version: planVersion.version }),
    termsSnapshot: Object.freeze({
      price: planVersion.price,
      currency: planVersion.currency,
      currencyScale: planVersion.currencyScale,
      billingInterval: planVersion.billingInterval,
      entitlements: planVersion.entitlements,
      trial: planVersion.trial,
    }),
    startAt: new Date(startTime).toISOString(),
    renewalMode,
    status: 'pending_setup',
    createdAt: new Date(createdTime).toISOString(),
  });
}

function assertEntitlement(planSnapshot, metric, currentUsage, increment = 1, resolvedContractLimit) {
  if (!Number.isSafeInteger(currentUsage) || currentUsage < 0
    || !Number.isSafeInteger(increment) || increment < 0) {
    throw new PlanError('INVALID_USAGE', 'Usage must be server-derived, non-negative safe integers.');
  }
  const limit = planSnapshot?.entitlements?.limits?.[metric];
  if (limit?.mode === 'unlimited') return Object.freeze({ allowed: true, currentUsage, increment, limit: null });
  let maximum;
  if (limit?.mode === 'limited') maximum = limit.value;
  if (limit?.mode === 'contract_defined') maximum = resolvedContractLimit;
  if (!Number.isSafeInteger(maximum) || maximum < 0) {
    throw new PlanError('ENTITLEMENT_UNRESOLVED', `Resolve the current ${metric} limit from the active contract.`);
  }
  if (BigInt(currentUsage) + BigInt(increment) > BigInt(maximum)) {
    throw new PlanError('ENTITLEMENT_LIMIT_REACHED', `The active plan limit for ${metric} would be exceeded.`);
  }
  return Object.freeze({ allowed: true, currentUsage, increment, limit: maximum });
}

function assertModuleEnabled(planSnapshot, moduleCode) {
  if (!Array.isArray(planSnapshot?.entitlements?.modules)
    || !planSnapshot.entitlements.modules.includes(moduleCode)) {
    throw new PlanError('MODULE_NOT_ENTITLED', 'This module is not enabled by the active subscription.');
  }
  return true;
}

module.exports = {
  PlanError,
  PlanStatus,
  assertEntitlement,
  assertModuleEnabled,
  planVersionPublish,
  planVersionRetire,
  preparePlanVersion,
  prepareSubscriptionAgreement,
};
