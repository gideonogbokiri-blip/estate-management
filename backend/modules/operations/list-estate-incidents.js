class EstateIncidentListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateIncidentListError';
    this.code = code;
  }
}

const incidentStatuses = new Set(Object.values(require('./incident').IncidentStatus));
const projectionFields = new Set([
  'incidentId', 'estateId', 'category', 'priority', 'status', 'createdAt', 'observedAt',
  'locationDescription', 'reporterUserId', 'reporterDisplayName', 'gateId', 'gateLabel',
]);

function safeIncidentSummary(incident, projection, estateId) {
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  const label = (value, field, limit, optional = false) => {
    if (optional && (value === null || value === undefined || value === '')) return null;
    if (typeof value !== 'string' || !value.trim() || value.length > limit) {
      throw new EstateIncidentListError('INVALID_PROJECTION', `${field} must be bounded display text.`);
    }
    return value.trim();
  };
  if (!incident?.id || !incident?.reporterUserId || !incident?.estateId || !estateId
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || !sameId(projection.incidentId, incident.id) || !sameId(projection.estateId, estateId)
    || projection.status !== incident.status || projection.category !== incident.category
    || projection.priority !== incident.priority
    || projection.createdAt !== incident.createdAt || projection.observedAt !== incident.observedAt
    || (projection.locationDescription ?? null) !== (incident.locationDescription ?? null)
    || !sameId(projection.reporterUserId, incident.reporterUserId)
    || !sameId(projection.gateId, incident.gateId)) {
    throw new EstateIncidentListError('INVALID_PROJECTION', 'Incident summary values must match the authorized source record.');
  }
  if (!incidentStatuses.has(incident.status) || typeof incident.category !== 'string' || !incident.category.trim()
    || typeof incident.priority !== 'string' || !incident.priority.trim()
    || typeof incident.createdAt !== 'string' || Number.isNaN(Date.parse(incident.createdAt))
    || typeof incident.observedAt !== 'string' || Number.isNaN(Date.parse(incident.observedAt))) {
    throw new EstateIncidentListError('INVALID_INCIDENT', 'The incident repository returned invalid status or timestamps.');
  }
  const gateLabel = label(projection.gateLabel, 'Gate label', 160, true);
  if (incident.gateId === null || incident.gateId === undefined) {
    if (gateLabel !== null) throw new EstateIncidentListError('INVALID_PROJECTION', 'An incident without a gate cannot have a gate label.');
  } else if (gateLabel === null) {
    throw new EstateIncidentListError('INVALID_PROJECTION', 'Gate incidents require an authorized gate label.');
  }
  return Object.freeze({
    incidentId: incident.id,
    estateId,
    category: label(incident.category, 'Incident category', 80),
    priority: label(incident.priority, 'Incident priority', 40),
    status: incident.status,
    createdAt: incident.createdAt,
    observedAt: incident.observedAt,
    locationDescription: label(incident.locationDescription, 'Incident location', 120, true),
    reporterDisplayName: label(projection.reporterDisplayName, 'Reporter name', 160, true),
    gateLabel,
  });
}

function createEstateIncidentListUseCase({
  transaction,
  requireEstatePermission,
  queryEstateIncidents,
  projectIncidentForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryEstateIncidents, projectIncidentForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateIncidentListError('MISSING_ADAPTER', `Estate incident list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateIncidents({ actorUserId, estateId, page = 1, pageSize = 25, status, category, search } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new EstateIncidentListError('INVALID_QUERY', 'Authenticated staff, estate and bounded pagination are required.');
    }
    if (status !== undefined && !incidentStatuses.has(status)) {
      throw new EstateIncidentListError('INVALID_FILTER', 'Choose a supported incident status.');
    }
    if (category !== undefined && (typeof category !== 'string' || category.length > 80)) {
      throw new EstateIncidentListError('INVALID_FILTER', 'Incident category filter is invalid.');
    }
    if (search !== undefined && (typeof search !== 'string' || search.trim().length > 100)) {
      throw new EstateIncidentListError('INVALID_FILTER', 'Incident search must be text of at most 100 characters.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'incident.view', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new EstateIncidentListError('ESTATE_ACCESS_DENIED', 'The actor cannot view incidents in this estate.');
      }
      const result = await queryEstateIncidents(tx, { estateContext, page, pageSize, status, category, search: search?.trim() || '' });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new EstateIncidentListError('INVALID_LIST_RESULT', 'The incident repository returned an invalid page.');
      }
      const items = [];
      const ids = new Set();
      for (const incident of result.items) {
        if (!incident || !incident.reporterUserId || String(incident.estateId) !== String(estateId) || !incident.id) {
          throw new EstateIncidentListError('CROSS_ESTATE_RESULT', 'The incident repository returned a record outside this estate.');
        }
        if (ids.has(String(incident.id))) throw new EstateIncidentListError('DUPLICATE_INCIDENT', 'The incident repository returned duplicate records.');
        ids.add(String(incident.id));
        const projection = await projectIncidentForActor(tx, { actorUserId, estateContext, incident });
        items.push(safeIncidentSummary(incident, projection, estateId));
      }
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { EstateIncidentListError, createEstateIncidentListUseCase, safeIncidentSummary };
