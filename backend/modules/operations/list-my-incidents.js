class MyIncidentListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyIncidentListError';
    this.code = code;
  }
}

const { IncidentStatus } = require('./incident');
const statuses = new Set(Object.values(IncidentStatus));
const summaryFields = new Set([
  'incidentId', 'estateId', 'category', 'priority', 'status', 'description',
  'locationDescription', 'observedAt', 'createdAt',
]);

function safeMyIncident(incident, projection, actorUserId, estateId) {
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  const instant = (value) => typeof value === 'string' && !Number.isNaN(Date.parse(value))
    && new Date(value).toISOString() === value;
  const text = (value, field, limit) => {
    if (typeof value !== 'string' || !value.trim() || value.length > limit) {
      throw new MyIncidentListError('INVALID_PROJECTION', `${field} must be bounded display text.`);
    }
    return value.trim();
  };
  if (!incident?.id || !sameId(incident.estateId, estateId) || !sameId(incident.reporterUserId, actorUserId)
    || !statuses.has(incident.status) || !instant(incident.observedAt) || !instant(incident.createdAt)
    || incident.locationDescription !== null && incident.locationDescription !== undefined
      && (typeof incident.locationDescription !== 'string' || incident.locationDescription.length > 120)
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !summaryFields.has(field))
    || !sameId(projection.incidentId, incident.id) || !sameId(projection.estateId, estateId)
    || projection.category !== incident.category || projection.priority !== incident.priority
    || projection.status !== incident.status || projection.description !== incident.description
    || (projection.locationDescription ?? null) !== (incident.locationDescription ?? null)
    || projection.observedAt !== incident.observedAt || projection.createdAt !== incident.createdAt) {
    throw new MyIncidentListError('INVALID_PROJECTION', 'Incident summary values must match the authenticated reporter and source record.');
  }
  return Object.freeze({
    incidentId: incident.id,
    estateId,
    category: text(incident.category, 'Incident category', 80),
    priority: text(incident.priority, 'Incident priority', 32),
    status: incident.status,
    description: text(incident.description, 'Incident description', 1000),
    locationDescription: incident.locationDescription ? text(incident.locationDescription, 'Incident location', 120) : null,
    observedAt: incident.observedAt,
    createdAt: incident.createdAt,
  });
}

function createMyIncidentListUseCase({ transaction, resolveIncidentReporterAccess, queryMyIncidents, projectMyIncident } = {}) {
  const ports = { transaction, resolveIncidentReporterAccess, queryMyIncidents, projectMyIncident };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyIncidentListError('MISSING_ADAPTER', `My incident list adapters are required: ${missing.join(', ')}.`);

  return async function listMyIncidents({ actorUserId, estateId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyIncidentListError('INVALID_QUERY', 'Authenticated reporter, estate and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveIncidentReporterAccess(tx, { actorUserId, estateId });
      if (!access || access.userId !== actorUserId || access.estateId !== estateId) {
        throw new MyIncidentListError('REPORT_ACCESS_DENIED', 'The actor cannot view incident reports in this estate.');
      }
      const result = await queryMyIncidents(tx, { actorUserId, estateId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyIncidentListError('INVALID_LIST_RESULT', 'The incident repository returned an invalid page.');
      }
      const items = [];
      const ids = new Set();
      for (const incident of result.items) {
        if (!incident || String(incident.estateId) !== String(estateId)
          || String(incident.reporterUserId) !== String(actorUserId) || !incident.id) {
          throw new MyIncidentListError('CROSS_SCOPE_RESULT', 'The incident repository returned a record outside the reporter scope.');
        }
        if (ids.has(String(incident.id))) throw new MyIncidentListError('DUPLICATE_INCIDENT', 'The incident repository returned duplicate records.');
        ids.add(String(incident.id));
        const projection = await projectMyIncident(tx, { actorUserId, incident });
        items.push(safeMyIncident(incident, projection, actorUserId, estateId));
      }
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { MyIncidentListError, createMyIncidentListUseCase, safeMyIncident };
