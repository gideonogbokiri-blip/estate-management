const { OccupancyStatus, PropertyStatus } = require('./property');
const propertyDisplayFields = new Set(['occupancyStatus', 'structureLabel', 'occupancyLabel', 'ownershipLabel', 'tenancyLabel']);

class PropertyListUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyListUseCaseError';
    this.code = code;
  }
}

function normalizePropertyQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new PropertyListUseCaseError('INVALID_QUERY', 'Property filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new PropertyListUseCaseError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status && !Object.values(PropertyStatus).includes(query.status)) {
    throw new PropertyListUseCaseError('INVALID_STATUS_FILTER', 'Choose a supported property status.');
  }
  if (query.occupancy && !Object.values(OccupancyStatus).includes(query.occupancy)) {
    throw new PropertyListUseCaseError('INVALID_OCCUPANCY_FILTER', 'Choose occupied or vacant.');
  }
  const filters = {};
  for (const field of ['status', 'occupancy', 'propertyType', 'structureNodeId']) {
    const value = query[field];
    if (value !== undefined && value !== null && value !== '') {
      if (typeof value !== 'string' || !value.trim()) throw new PropertyListUseCaseError('INVALID_FILTER', `${field} is invalid.`);
      filters[field] = value.trim();
    }
  }
  if (query.search !== undefined && typeof query.search !== 'string') {
    throw new PropertyListUseCaseError('INVALID_SEARCH', 'Search must be text.');
  }
  const search = query.search?.trim() || '';
  if (search.length > 100) throw new PropertyListUseCaseError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');
  if (search) filters.search = search;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters) });
}

function displayLabel(value, field, maxLength = 120) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new PropertyListUseCaseError('INVALID_PROJECTION', `${field} must be a safe display label.`);
  }
  return value;
}

function projectPropertySummary(property, projection, estateId) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !propertyDisplayFields.has(field))) {
    throw new PropertyListUseCaseError('INVALID_PROJECTION', 'Property summaries may contain only approved display labels.');
  }
  if (!property?.id || String(property.estateId) !== String(estateId)
    || typeof property.code !== 'string' || !property.code.trim() || property.code.length > 80
    || typeof property.propertyType !== 'string' || !property.propertyType.trim() || property.propertyType.length > 80
    || !Object.values(PropertyStatus).includes(property.status)) {
    throw new PropertyListUseCaseError('INVALID_PROPERTY_RESULT', 'Property identity, type and status must match an estate-scoped source record.');
  }
  const occupancyStatus = projection.occupancyStatus;
  if (occupancyStatus !== undefined && occupancyStatus !== null && !Object.values(OccupancyStatus).includes(occupancyStatus)) {
    throw new PropertyListUseCaseError('INVALID_PROJECTION', 'Occupancy must be derived as occupied or vacant.');
  }
  return Object.freeze({
    id: property.id,
    estateId,
    code: property.code,
    propertyType: property.propertyType,
    status: property.status,
    unitNumber: displayLabel(property.unitNumber, 'unit number', 80),
    occupancyStatus: occupancyStatus ?? null,
    structureLabel: displayLabel(projection.structureLabel, 'structure label'),
    occupancyLabel: displayLabel(projection.occupancyLabel, 'occupancy label'),
    ownershipLabel: displayLabel(projection.ownershipLabel, 'ownership label'),
    tenancyLabel: displayLabel(projection.tenancyLabel, 'tenancy label'),
  });
}

function createEstatePropertyListUseCase({
  transaction,
  requireEstatePermission,
  queryProperties,
  projectPropertyForActor,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, queryProperties, projectPropertyForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PropertyListUseCaseError('MISSING_ADAPTER', `Property list adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new PropertyListUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function listEstateProperties({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new PropertyListUseCaseError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizePropertyQuery(query);
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'property.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new PropertyListUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot view properties in this estate.');
      }
      const asOf = new Date(clock());
      if (Number.isNaN(asOf.getTime())) throw new PropertyListUseCaseError('INVALID_CLOCK', 'A valid query timestamp is required.');
      // The adapter derives occupancy as of this instant and scopes before filters/count/pagination.
      const result = await queryProperties(tx, { estateContext, ...normalized, asOf: asOf.toISOString() });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new PropertyListUseCaseError('INVALID_REPOSITORY_RESULT', 'The property query must return a bounded page and authorized total.');
      }
      if (result.items.some((property) => !property?.id || String(property.estateId) !== String(estateId))) {
        throw new PropertyListUseCaseError('ESTATE_SCOPE_VIOLATION', 'The repository returned a property outside the selected estate.');
      }
      const items = [];
      const seenPropertyIds = new Set();
      for (const property of result.items) {
        if (seenPropertyIds.has(String(property.id))) {
          throw new PropertyListUseCaseError('DUPLICATE_RESULT', 'The property repository returned a duplicate record.');
        }
        seenPropertyIds.add(String(property.id));
        const projection = await projectPropertyForActor({ actorUserId, estateContext, property, tx });
        const item = projectPropertySummary(property, projection, estateId);
        if ((normalized.filters.status && item.status !== normalized.filters.status)
          || (normalized.filters.propertyType && item.propertyType !== normalized.filters.propertyType)
          || (normalized.filters.occupancy && item.occupancyStatus !== normalized.filters.occupancy)) {
          throw new PropertyListUseCaseError('FILTER_SCOPE_VIOLATION', 'The property repository returned a record outside the requested filters.');
        }
        items.push(item);
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
        asOf: asOf.toISOString(),
      });
    });
  };
}

module.exports = { PropertyListUseCaseError, createEstatePropertyListUseCase, normalizePropertyQuery, projectPropertySummary };
