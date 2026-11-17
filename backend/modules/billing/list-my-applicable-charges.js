const { normalizeDecimal, toMinorUnits } = require('./money');

class ApplicableChargeListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApplicableChargeListError';
    this.code = code;
  }
}

const recurrenceValues = new Set(['one_time', 'daily', 'weekly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'custom']);
const chargeStatuses = new Set(['draft', 'active', 'inactive', 'retired']);
const audienceTypes = new Set(['all_residents', 'property', 'property_type', 'zone', 'resident_role']);

function validDate(value, field, nullable = false) {
  if (nullable && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new ApplicableChargeListError('INVALID_CHARGE_DATE', `${field} must use YYYY-MM-DD.`);
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new ApplicableChargeListError('INVALID_CHARGE_DATE', `${field} must be a valid calendar date.`);
  }
  return value;
}

function boundedText(value, field, maxLength, nullable = false) {
  if (nullable && (value === null || value === undefined || value === '')) return null;
  if (typeof value !== 'string' || !value.trim() || value.length > maxLength) {
    throw new ApplicableChargeListError('INVALID_CHARGE_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function safeApplicableCharge(charge, projection, context) {
  if (!charge?.id || String(charge.estateId) !== String(context.estateId)
    || charge.status !== 'active' || !charge.audience || !audienceTypes.has(charge.audience.type)) {
    throw new ApplicableChargeListError('ESTATE_SCOPE_VIOLATION', 'Only active charge definitions in the resident estate can be returned.');
  }
  const property = context.property;
  const audience = charge.audience;
  const matches = audience.type === 'all_residents'
    || (audience.type === 'property' && String(audience.propertyId) === String(property.id))
    || (audience.type === 'property_type' && audience.propertyType === property.propertyType
      && (!audience.zoneId || String(audience.zoneId) === String(property.zoneId)))
    || (audience.type === 'zone' && String(audience.zoneId) === String(property.zoneId))
    || (audience.type === 'resident_role' && String(audience.roleId) === String(context.residentRoleId));
  if (!matches) throw new ApplicableChargeListError('CHARGE_NOT_APPLICABLE', 'The charge does not apply to the authenticated resident property.');

  const start = validDate(charge.effectiveFrom, 'effectiveFrom');
  const end = validDate(charge.effectiveTo, 'effectiveTo', true);
  const asOf = context.asOf.slice(0, 10);
  if (start > asOf || (end && end < asOf)) {
    throw new ApplicableChargeListError('CHARGE_NOT_EFFECTIVE', 'Only currently effective charge versions can be returned.');
  }
  if (typeof charge.currency !== 'string' || !/^[A-Z]{3}$/.test(charge.currency)
    || !Number.isInteger(charge.currencyScale) || charge.currencyScale < 0 || charge.currencyScale > 6) {
    throw new ApplicableChargeListError('INVALID_CHARGE_MONEY', 'Charge currency and configured scale are invalid.');
  }
  if (!recurrenceValues.has(charge.recurrence) || !chargeStatuses.has(charge.status)) {
    throw new ApplicableChargeListError('INVALID_CHARGE_VERSION', 'Charge recurrence or status is invalid.');
  }
  let amount;
  try {
    amount = normalizeDecimal(charge.amount, charge.currencyScale);
    if (toMinorUnits(amount, charge.currencyScale) <= 0n) throw new Error('non-positive');
  } catch {
    throw new ApplicableChargeListError('INVALID_CHARGE_MONEY', 'Charge amount must be a positive exact decimal value.');
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)) {
    throw new ApplicableChargeListError('INVALID_CHARGE_PROJECTION', 'A resident-safe charge projection is required.');
  }
  const allowed = new Set(['name', 'description', 'category', 'dueRuleLabel']);
  if (Object.keys(projection).some((key) => !allowed.has(key))) {
    throw new ApplicableChargeListError('UNSAFE_CHARGE_PROJECTION', 'The resident projection contains fields outside the charge summary.');
  }
  if (!projection.name || projection.name !== charge.name || !projection.category || projection.category !== charge.category) {
    throw new ApplicableChargeListError('INVALID_CHARGE_PROJECTION', 'Charge summary identity must match its effective definition.');
  }
  return Object.freeze({
    id: charge.id,
    name: boundedText(projection.name, 'name', 120),
    category: boundedText(projection.category, 'category', 80),
    description: boundedText(projection.description, 'description', 400, true),
    amount,
    currency: charge.currency,
    recurrence: charge.recurrence,
    dueRuleLabel: boundedText(projection.dueRuleLabel, 'dueRuleLabel', 120, true),
    effectiveFrom: start,
    effectiveTo: end,
  });
}

/** Lists only effective charge versions applicable to the authenticated resident property. */
function createMyApplicableChargeListUseCase({ transaction, resolveResidentPropertyContext, queryEffectiveCharges, projectChargeForResident, clock = () => new Date() } = {}) {
  const ports = { transaction, resolveResidentPropertyContext, queryEffectiveCharges, projectChargeForResident };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ApplicableChargeListError('MISSING_ADAPTER', `Applicable charge list adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new ApplicableChargeListError('INVALID_CLOCK', 'A charge-list clock function is required.');

  return async function listMyApplicableCharges({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new ApplicableChargeListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    return transaction(async (tx) => {
      const context = await resolveResidentPropertyContext(tx, { actorUserId, estateId });
      if (!context || String(context.actorUserId) !== String(actorUserId)
        || String(context.estateId) !== String(estateId) || context.mayViewApplicableCharges !== true
        || !context.property?.id || String(context.property.estateId) !== String(estateId)
        || !context.residentRoleId) {
        throw new ApplicableChargeListError('RESIDENT_CHARGE_ACCESS_DENIED', 'The actor has no authorized resident/property charge context.');
      }
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new ApplicableChargeListError('INVALID_CLOCK', 'A valid charge-list timestamp is required.');
      const charges = await queryEffectiveCharges(tx, { context, asOf: now.toISOString(), status: 'active' });
      if (!Array.isArray(charges) || charges.length > 250) {
        throw new ApplicableChargeListError('INVALID_REPOSITORY_RESULT', 'Effective charge definitions must be a bounded list.');
      }
      const seen = new Set();
      const items = [];
      for (const charge of charges) {
        const key = String(charge?.id ?? '');
        if (!key || seen.has(key)) throw new ApplicableChargeListError('INVALID_REPOSITORY_RESULT', 'Charge identifiers must be present and unique.');
        seen.add(key);
        const audience = charge.audience;
        const property = context.property;
        const matches = audience?.type === 'all_residents'
          || (audience?.type === 'property' && String(audience.propertyId) === String(property.id))
          || (audience?.type === 'property_type' && audience.propertyType === property.propertyType
            && (!audience.zoneId || String(audience.zoneId) === String(property.zoneId)))
          || (audience?.type === 'zone' && String(audience.zoneId) === String(property.zoneId))
          || (audience?.type === 'resident_role' && String(audience.roleId) === String(context.residentRoleId));
        if (!matches) continue;
        const projection = await projectChargeForResident({ actorUserId, context, charge, tx });
        items.push(safeApplicableCharge(charge, projection, { ...context, asOf: now.toISOString() }));
      }
      return Object.freeze({ items: Object.freeze(items), propertyId: context.property.id, estateId, asOf: now.toISOString() });
    });
  };
}

module.exports = { ApplicableChargeListError, createMyApplicableChargeListUseCase, safeApplicableCharge };
