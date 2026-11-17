const { MaintenanceStatus } = require('./maintenance');

class MyMaintenanceRequestListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyMaintenanceRequestListError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(MaintenanceStatus));
const instant = (value) => typeof value === 'string' && !Number.isNaN(Date.parse(value))
  && new Date(value).toISOString() === value;

function safeUpdate(update) {
  if (!update || update.visibility !== 'resident_visible'
    || typeof update.body !== 'string' || !update.body.trim() || update.body.length > 700
    || !instant(update.occurredAt)) return null;
  return Object.freeze({ body: update.body.trim(), occurredAt: update.occurredAt });
}

function boundedLabel(value, fallback, limit) {
  if (value === null || value === undefined || value === '') return fallback;
  if (typeof value !== 'string' || value.trim().length > limit) {
    throw new MyMaintenanceRequestListError('INVALID_PROJECTION', 'Maintenance display labels must be bounded text.');
  }
  return value.trim() || fallback;
}

function safeMyMaintenanceRequest(row, actorUserId, estateId) {
  const request = row?.request;
  if (!request?.id || String(request.estateId) !== String(estateId)
    || String(request.requesterUserId) !== String(actorUserId) || !statuses.has(request.status)
    || !['plumbing', 'electrical', 'security', 'cleaning', 'other'].includes(request.category)
    || !['normal', 'high', 'urgent'].includes(request.priority)
    || typeof request.description !== 'string' || !request.description.trim() || request.description.length > 700
    || !instant(request.submittedAt) || request.updatedAt != null && !instant(request.updatedAt)
    || !Array.isArray(row.residentVisibleUpdates) || row.residentVisibleUpdates.length > 100) {
    throw new MyMaintenanceRequestListError('CROSS_SCOPE_RESULT', 'The repository returned an invalid or unauthorized request.');
  }
  const updates = row.residentVisibleUpdates.map((update) => {
    const safe = safeUpdate(update);
    if (!safe) throw new MyMaintenanceRequestListError('INVALID_UPDATE_PROJECTION', 'The repository returned an invalid resident-visible update.');
    return safe;
  });
  return Object.freeze({
    id: request.id,
    requestId: request.id,
    estateId,
    reference: boundedLabel(row.reference, String(request.id), 80),
    category: request.category,
    priority: request.priority,
    description: request.description.trim(),
    status: request.status,
    propertyLabel: boundedLabel(row.propertyLabel, null, 160),
    submittedAt: request.submittedAt,
    updatedAt: request.updatedAt ?? null,
    residentVisibleUpdates: Object.freeze(updates),
  });
}

function createMyMaintenanceRequestListUseCase({
  transaction,
  resolveResidentMaintenanceAccess,
  queryMyMaintenanceRequests,
} = {}) {
  const ports = { transaction, resolveResidentMaintenanceAccess, queryMyMaintenanceRequests };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyMaintenanceRequestListError('MISSING_ADAPTER', `Resident maintenance list adapters are required: ${missing.join(', ')}.`);

  return async function listMyMaintenanceRequests({ actorUserId, estateId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyMaintenanceRequestListError('INVALID_QUERY', 'Authenticated resident, estate and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveResidentMaintenanceAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId) || String(access.estateId) !== String(estateId)
        || access.active !== true || access.mayViewMaintenance !== true) {
        throw new MyMaintenanceRequestListError('RESIDENT_ACCESS_DENIED', 'The resident cannot view maintenance requests in this estate.');
      }
      // Scope to the actor's currently authorized estate/property relationships before count and pagination.
      const result = await queryMyMaintenanceRequests(tx, { access, actorUserId, estateId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyMaintenanceRequestListError('INVALID_LIST_RESULT', 'The maintenance repository returned an invalid page.');
      }
      const seen = new Set();
      const items = result.items.map((row) => {
        const key = String(row?.request?.id ?? '');
        if (!key) throw new MyMaintenanceRequestListError('CROSS_SCOPE_RESULT', 'The repository returned an invalid or unauthorized request.');
        if (seen.has(key)) throw new MyMaintenanceRequestListError('DUPLICATE_RESULT', 'The repository returned a duplicate maintenance request.');
        seen.add(key);
        return safeMyMaintenanceRequest(row, actorUserId, estateId);
      });
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { MyMaintenanceRequestListError, createMyMaintenanceRequestListUseCase, safeMyMaintenanceRequest };
