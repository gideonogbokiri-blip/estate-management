const { TenancyStatus } = require('./tenancy');

class TenancyListUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyListUseCaseError';
    this.code = code;
  }
}

const listableStatuses = new Set(Object.values(TenancyStatus));
const dateFilterFields = ['startFrom', 'startTo', 'endFrom', 'endTo'];
const projectionFields = new Set([
  'id', 'propertyLabel', 'tenantLabel', 'landlordLabel', 'rentAmount', 'currency',
  'rentFrequency', 'startDate', 'endDate', 'nextDueDate', 'status',
]);

function boundedLabel(value, field, limit = 160, optional = false) {
  if (optional && (value === null || value === undefined || value === '')) return null;
  if (typeof value !== 'string' || !value.trim() || value.length > limit) {
    throw new TenancyListUseCaseError('INVALID_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function safeTenancyListItem(tenancy, projection) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || projection.id !== tenancy.id || projection.status !== tenancy.status
    || projection.rentAmount !== tenancy.rentAmount || projection.currency !== tenancy.currency
    || projection.rentFrequency !== tenancy.rentFrequency || projection.startDate !== tenancy.startDate
    || (projection.endDate ?? null) !== (tenancy.endDate ?? null)) {
    throw new TenancyListUseCaseError('INVALID_PROJECTION', 'Tenancy display terms must match the authorized source record.');
  }
  if (!listableStatuses.has(projection.status)
    || typeof projection.rentAmount !== 'string' || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(projection.rentAmount)
    || typeof projection.currency !== 'string' || !/^[A-Z]{3}$/.test(projection.currency)
    || typeof projection.rentFrequency !== 'string' || projection.rentFrequency.length > 40
    || !validDate(projection.startDate)
    || (projection.endDate !== null && projection.endDate !== undefined && !validDate(projection.endDate))
    || (projection.nextDueDate !== null && projection.nextDueDate !== undefined && !validDate(projection.nextDueDate))) {
    throw new TenancyListUseCaseError('INVALID_PROJECTION', 'Tenancy rent, status and date values are invalid.');
  }
  return Object.freeze({
    id: tenancy.id,
    propertyLabel: boundedLabel(projection.propertyLabel, 'Property label'),
    tenantLabel: boundedLabel(projection.tenantLabel, 'Tenant label'),
    landlordLabel: boundedLabel(projection.landlordLabel, 'Landlord label', 160, true),
    rentAmount: projection.rentAmount,
    currency: projection.currency,
    rentFrequency: projection.rentFrequency,
    startDate: projection.startDate,
    endDate: projection.endDate ?? null,
    nextDueDate: projection.nextDueDate ?? null,
    status: projection.status,
  });
}

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function normalizeQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new TenancyListUseCaseError('INVALID_QUERY', 'Tenancy filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new TenancyListUseCaseError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status && !listableStatuses.has(query.status)) {
    throw new TenancyListUseCaseError('INVALID_STATUS_FILTER', 'Choose a supported tenancy status.');
  }
  for (const field of dateFilterFields) {
    if (query[field] !== undefined && query[field] !== '' && !validDate(query[field])) {
      throw new TenancyListUseCaseError('INVALID_DATE_FILTER', `${field} must be a valid YYYY-MM-DD date.`);
    }
  }
  if (query.startFrom && query.startTo && query.startFrom > query.startTo) {
    throw new TenancyListUseCaseError('INVALID_DATE_RANGE', 'Start date range is reversed.');
  }
  if (query.endFrom && query.endTo && query.endFrom > query.endTo) {
    throw new TenancyListUseCaseError('INVALID_DATE_RANGE', 'End date range is reversed.');
  }
  const search = typeof query.search === 'string' ? query.search.trim() : '';
  if (search.length > 100) throw new TenancyListUseCaseError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');

  const filters = {};
  for (const field of ['propertyId', 'tenantUserId', 'landlordUserId']) {
    if (query[field] !== undefined && query[field] !== null && query[field] !== '') {
      if (!['string', 'number'].includes(typeof query[field]) || String(query[field]).trim().length === 0) {
        throw new TenancyListUseCaseError('INVALID_FILTER', `${field} is invalid.`);
      }
      filters[field] = query[field];
    }
  }
  for (const field of ['status', ...dateFilterFields]) {
    if (query[field]) filters[field] = query[field];
  }
  if (search) filters.search = search;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters) });
}

/** Paginated tenancy list under a resolved estate context and actor-specific projection. */
function createEstateTenancyListUseCase({ transaction, requireEstatePermission, queryTenancies, projectTenancyForActor } = {}) {
  const ports = { transaction, requireEstatePermission, queryTenancies, projectTenancyForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new TenancyListUseCaseError('MISSING_ADAPTER', `Tenancy list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateTenancies({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new TenancyListUseCaseError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizeQuery(query);
    return ports.transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'tenancy.view', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new TenancyListUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot view tenancies in this estate.');
      }
      // The repository must apply estate/relationship authorization before filters, counts and pagination.
      const result = await queryTenancies(tx, { estateContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new TenancyListUseCaseError('INVALID_REPOSITORY_RESULT', 'The tenancy query must return a bounded page and authorized total.');
      }
      if (result.items.some((tenancy) => !tenancy?.id || tenancy.estateId !== estateId)) {
        throw new TenancyListUseCaseError('ESTATE_SCOPE_VIOLATION', 'The repository returned a tenancy outside the selected estate.');
      }
      const items = [];
      for (const tenancy of result.items) {
        const projection = await projectTenancyForActor({ actorUserId, estateContext, tenancy, tx });
        items.push(safeTenancyListItem(tenancy, projection));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
      });
    });
  };
}

module.exports = { TenancyListUseCaseError, createEstateTenancyListUseCase, normalizeQuery, safeTenancyListItem };
