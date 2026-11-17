const { MaintenanceStatus } = require('./maintenance');
const { MyMaintenanceRequestListError } = require('./list-my-maintenance-requests');

const statuses = new Set(Object.values(MaintenanceStatus));
const instant = (value) => typeof value === 'string' && !Number.isNaN(Date.parse(value))
  && new Date(value).toISOString() === value;

function safeLandlordMaintenanceRequest(row, actorUserId, estateId, access) {
  const request = row?.request;
  const propertyId = String(request?.propertyId ?? '');
  const authorized = access?.properties?.some((property) => String(property.id) === propertyId
    && property.estateId === estateId && property.activeOwnership === true && property.verifiedOwnership === true);
  if (!request?.id || String(request.estateId) !== String(estateId) || !authorized
    || !statuses.has(request.status)
    || !['plumbing', 'electrical', 'security', 'cleaning', 'other'].includes(request.category)
    || !['normal', 'high', 'urgent'].includes(request.priority)
    || typeof request.description !== 'string' || !request.description.trim() || request.description.length > 700
    || !instant(request.submittedAt) || request.updatedAt != null && !instant(request.updatedAt)
    || !Array.isArray(row.residentVisibleUpdates) || row.residentVisibleUpdates.length > 100
    || row.residentVisibleUpdates.some((update) => update?.visibility !== 'resident_visible'
      || typeof update.body !== 'string' || !update.body.trim() || update.body.length > 700 || !instant(update.occurredAt))) {
    throw new MyMaintenanceRequestListError('CROSS_SCOPE_RESULT', 'The repository returned an invalid or unauthorized landlord maintenance request.');
  }
  return Object.freeze({
    id: request.id,
    reference: typeof row.reference === 'string' && row.reference.trim() ? row.reference.trim().slice(0, 80) : String(request.id),
    propertyId,
    propertyLabel: typeof row.propertyLabel === 'string' ? row.propertyLabel.trim().slice(0, 160) : 'Property',
    category: request.category,
    priority: request.priority,
    description: request.description.trim(),
    status: request.status,
    submittedAt: request.submittedAt,
    updatedAt: request.updatedAt ?? null,
    residentVisibleUpdates: Object.freeze(row.residentVisibleUpdates.map((update) => Object.freeze({
      body: update.body.trim(), occurredAt: update.occurredAt,
    }))),
  });
}

function createMyLandlordPropertyMaintenanceListUseCase({ transaction, resolveLandlordMaintenanceAccess, queryMyLandlordPropertyMaintenance } = {}) {
  const ports = { transaction, resolveLandlordMaintenanceAccess, queryMyLandlordPropertyMaintenance };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyMaintenanceRequestListError('MISSING_ADAPTER', `Landlord maintenance list adapters are required: ${missing.join(', ')}.`);

  return async function listMyLandlordPropertyMaintenance({ actorUserId, estateId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyMaintenanceRequestListError('INVALID_QUERY', 'Authenticated landlord, estate and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveLandlordMaintenanceAccess(tx, { actorUserId, estateId });
      if (!access || String(access.userId) !== String(actorUserId) || access.estateId !== estateId
        || access.active !== true || access.mayViewPropertyMaintenance !== true || !Array.isArray(access.properties)) {
        throw new MyMaintenanceRequestListError('LANDLORD_ACCESS_DENIED', 'The landlord cannot view property maintenance requests in this estate.');
      }
      // The query must apply verified ownership scope before counting or pagination.
      const result = await queryMyLandlordPropertyMaintenance(tx, { access, actorUserId, estateId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyMaintenanceRequestListError('INVALID_LIST_RESULT', 'The landlord maintenance repository returned an invalid page.');
      }
      const seen = new Set();
      const items = result.items.map((row) => {
        const id = String(row?.request?.id ?? '');
        if (!id || seen.has(id)) throw new MyMaintenanceRequestListError('DUPLICATE_OR_INVALID_RESULT', 'The repository returned a duplicate or invalid maintenance request.');
        seen.add(id);
        return safeLandlordMaintenanceRequest(row, actorUserId, estateId, access);
      });
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total, totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { createMyLandlordPropertyMaintenanceListUseCase, safeLandlordMaintenanceRequest };
