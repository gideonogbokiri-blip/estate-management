const { TenancyStatus } = require('./tenancy');

class LandlordPortfolioListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'LandlordPortfolioListError';
    this.code = code;
  }
}

const allowedStatuses = new Set(Object.values(TenancyStatus));
const projectionFields = new Set([
  'propertyId', 'estateName', 'estateLocation', 'propertyLabel', 'propertyAddress', 'propertyType',
  'operationalStatus', 'occupancyStatus', 'tenantUserId', 'tenantDisplayName', 'tenancyStatus', 'tenancyStartDate',
  'tenancyEndDate', 'rentAmount', 'currency', 'currencyScale', 'rentFrequency',
]);

function displayText(value, field, maxLength, required = false) {
  if (value === null || value === undefined) {
    if (required) throw new LandlordPortfolioListError('INVALID_PROJECTION', `${field} is required.`);
    return null;
  }
  if (typeof value !== 'string' || value.length > maxLength || (required && !value.trim())) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', `${field} is not a safe display value.`);
  }
  return value;
}

function projectPortfolioItem(row, projection, actorUserId, estateId) {
  const tenancy = row?.tenancy ?? null;
  const property = row?.property;
  const ownership = row?.ownership;
  if (!property?.id || String(property.estateId) !== String(estateId)
    || !ownership?.id || String(ownership.estateId) !== String(estateId)
    || String(ownership.propertyId) !== String(property.id)
    || String(ownership.userId) !== String(actorUserId) || ownership.status !== 'active'
    || ownership.verificationStatus !== 'verified'
    || (tenancy && (String(tenancy.estateId) !== String(estateId)
      || String(tenancy.propertyId) !== String(property.id) || !allowedStatuses.has(tenancy.status)))) {
    throw new LandlordPortfolioListError('RELATIONSHIP_SCOPE_VIOLATION', 'The repository returned a property or tenancy outside the verified landlord relationship.');
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || String(projection.propertyId) !== String(property.id)) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', 'The landlord portfolio projection must be allowlisted and match its property.');
  }
  if (projection.operationalStatus !== property.status) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', 'Displayed property status must match the scoped property record.');
  }
  if (tenancy && (!projection.tenancyStatus || projection.tenancyStatus !== tenancy.status
    || String(projection.tenantUserId) !== String(tenancy.tenantUserId)
    || !allowedStatuses.has(projection.tenancyStatus)
    || projection.tenancyStartDate !== tenancy.startDate || projection.tenancyEndDate !== (tenancy.endDate ?? null)
    || projection.rentAmount !== tenancy.rentAmount || projection.currency !== tenancy.currency
    || projection.currencyScale !== tenancy.currencyScale || projection.rentFrequency !== tenancy.rentFrequency)) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', 'Displayed tenancy terms must match the verified tenancy record.');
  }
  if (!tenancy && (projection.tenantUserId || projection.tenancyStatus || projection.tenantDisplayName || projection.rentAmount)) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', 'An unoccupied ownership record cannot include tenancy details.');
  }
  const currency = displayText(projection.currency, 'currency', 3, Boolean(tenancy));
  if (currency && !/^[A-Z]{3}$/.test(currency)) throw new LandlordPortfolioListError('INVALID_PROJECTION', 'Currency must be a three-letter code.');
  if (tenancy && (typeof projection.rentAmount !== 'string' || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(projection.rentAmount)
    || !Number.isInteger(projection.currencyScale) || projection.currencyScale < 0 || projection.currencyScale > 6
    || (projection.rentAmount.split('.')[1]?.length ?? 0) > projection.currencyScale)) {
    throw new LandlordPortfolioListError('INVALID_PROJECTION', 'Rent must use an exact decimal string and configured currency precision.');
  }
  return Object.freeze({
    propertyId: property.id,
    estateId,
    estateName: displayText(projection.estateName, 'estateName', 120, true),
    estateLocation: displayText(projection.estateLocation, 'estateLocation', 160),
    propertyLabel: displayText(projection.propertyLabel, 'propertyLabel', 160, true),
    propertyAddress: displayText(projection.propertyAddress, 'propertyAddress', 240),
    propertyType: displayText(projection.propertyType, 'propertyType', 80),
    operationalStatus: displayText(projection.operationalStatus, 'operationalStatus', 40, true),
    occupancyStatus: tenancy && [TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(tenancy.status) ? 'rented' : 'not_currently_rented',
    tenantDisplayName: tenancy ? displayText(projection.tenantDisplayName, 'tenantDisplayName', 160, true) : null,
    tenancyStatus: tenancy?.status ?? null,
    tenancyStartDate: tenancy?.startDate ?? null,
    tenancyEndDate: tenancy?.endDate ?? null,
    rentAmount: tenancy ? projection.rentAmount : null,
    currency: tenancy ? currency : null,
    currencyScale: tenancy ? projection.currencyScale : null,
    rentFrequency: tenancy ? displayText(projection.rentFrequency, 'rentFrequency', 40, true) : null,
  });
}

function createMyLandlordPortfolioListUseCase({ transaction, resolveLandlordAccess, queryVerifiedLandlordPortfolio, projectLandlordPortfolioItem } = {}) {
  const ports = { transaction, resolveLandlordAccess, queryVerifiedLandlordPortfolio, projectLandlordPortfolioItem };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new LandlordPortfolioListError('MISSING_ADAPTER', `Landlord portfolio adapters are required: ${missing.join(', ')}.`);

  return async function listMyLandlordPortfolio({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new LandlordPortfolioListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    return transaction(async (tx) => {
      const access = await resolveLandlordAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId) || access.mayViewPortfolio !== true) {
        throw new LandlordPortfolioListError('LANDLORD_ACCESS_DENIED', 'The actor cannot view landlord properties in this estate.');
      }
      const rows = await queryVerifiedLandlordPortfolio(tx, { access, limit: 100 });
      if (!Array.isArray(rows) || rows.length > 100) {
        throw new LandlordPortfolioListError('INVALID_REPOSITORY_RESULT', 'The landlord portfolio repository must return a bounded list.');
      }
      const seen = new Set();
      const items = [];
      for (const row of rows) {
        const propertyId = String(row?.property?.id ?? '');
        if (!propertyId || seen.has(propertyId)) throw new LandlordPortfolioListError('INVALID_REPOSITORY_RESULT', 'The landlord portfolio contains a missing or duplicate property.');
        seen.add(propertyId);
        const projection = await projectLandlordPortfolioItem(tx, { actorUserId, access, row });
        items.push(projectPortfolioItem(row, projection, actorUserId, estateId));
      }
      return Object.freeze({ items: Object.freeze(items) });
    });
  };
}

module.exports = { LandlordPortfolioListError, createMyLandlordPortfolioListUseCase, projectPortfolioItem };
