const { MaintenanceCommand, MaintenanceStatus } = require('./maintenance');

class MaintenanceQueueError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MaintenanceQueueError';
    this.code = code;
  }
}

const allowedStatuses = new Set(Object.values(MaintenanceStatus));
const allowedCategories = new Set(['plumbing', 'electrical', 'security', 'cleaning', 'other']);
const allowedPriorities = new Set(['low', 'normal', 'high', 'urgent']);
const queueProjectionFields = new Set([
  'id', 'estateId', 'propertyId', 'reference', 'title', 'category', 'priority', 'status', 'submittedAt',
  'propertyLabel', 'requesterDisplayName', 'assigneeUserId', 'assigneeDisplayName',
  'description', 'residentVisibleUpdates', 'allowedCommands',
]);

function optionalLabel(value, field, maxLength) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new MaintenanceQueueError('INVALID_PROJECTION', `${field} is not a safe display label.`);
  }
  return value;
}

function safeQueueProjection(request, projected, estateId) {
  if (!projected || typeof projected !== 'object' || Array.isArray(projected)
    || Object.keys(projected).some((field) => !queueProjectionFields.has(field))) {
    throw new MaintenanceQueueError('INVALID_PROJECTION', 'The queue projection contains unsupported fields.');
  }
  if (String(projected.id) !== String(request.id) || String(projected.estateId) !== String(estateId)
    || String(projected.propertyId) !== String(request.propertyId)
    || !allowedStatuses.has(request.status) || !allowedCategories.has(request.category)
    || !allowedPriorities.has(request.priority) || typeof request.description !== 'string'
    || request.description.length > 700 || typeof request.submittedAt !== 'string'
    || Number.isNaN(Date.parse(request.submittedAt))
    || projected.status !== request.status || projected.category !== request.category
    || projected.priority !== request.priority || projected.description !== request.description
    || projected.submittedAt !== request.submittedAt || !Array.isArray(projected.allowedCommands)
    || projected.allowedCommands.some((command) => !Object.values(MaintenanceCommand).includes(command))
    || new Set(projected.allowedCommands).size !== projected.allowedCommands.length) {
    throw new MaintenanceQueueError('INVALID_PROJECTION', 'The maintenance request projection is invalid.');
  }
  if (projected.assigneeUserId !== null && projected.assigneeUserId !== undefined
    && !['string', 'number'].includes(typeof projected.assigneeUserId)) {
    throw new MaintenanceQueueError('INVALID_PROJECTION', 'The assignee reference is invalid.');
  }
  if (String(projected.assigneeUserId ?? '') !== String(request.assigneeUserId ?? '')) {
    throw new MaintenanceQueueError('INVALID_PROJECTION', 'The displayed assignee must match the scoped maintenance record.');
  }
  const updates = projected.residentVisibleUpdates ?? [];
  if (!Array.isArray(updates)) throw new MaintenanceQueueError('INVALID_PROJECTION', 'Resident-visible updates must be a list.');
  const residentVisibleUpdates = updates.filter((update) => update?.visibility === 'resident_visible')
    .filter((update) => typeof update.body === 'string' && update.body.trim() && update.body.length <= 700
      && typeof update.occurredAt === 'string' && !Number.isNaN(Date.parse(update.occurredAt)))
    .map((update) => Object.freeze({ body: update.body, occurredAt: update.occurredAt }));
  return Object.freeze({
    id: request.id,
    estateId,
    reference: optionalLabel(projected.reference, 'reference', 80) || String(request.id),
    title: optionalLabel(projected.title, 'title', 160),
    category: request.category,
    priority: request.priority,
    status: request.status,
    submittedAt: request.submittedAt,
    propertyLabel: optionalLabel(projected.propertyLabel, 'propertyLabel', 160),
    requesterDisplayName: optionalLabel(projected.requesterDisplayName, 'requesterDisplayName', 160),
    assigneeUserId: request.assigneeUserId ?? null,
    assigneeDisplayName: optionalLabel(projected.assigneeDisplayName, 'assigneeDisplayName', 160),
    description: request.description,
    residentVisibleUpdates: Object.freeze(residentVisibleUpdates),
    allowedCommands: Object.freeze([...projected.allowedCommands]),
  });
}

function createMaintenanceQueueListUseCase({
  transaction,
  requireEstatePermission,
  queryMaintenanceRequests,
  projectMaintenanceQueueItem,
  listAssignableStaff,
  resolveMaintenanceCapabilities,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryMaintenanceRequests, projectMaintenanceQueueItem,
    listAssignableStaff, resolveMaintenanceCapabilities };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MaintenanceQueueError('MISSING_ADAPTER', `Maintenance queue adapters are required: ${missing.join(', ')}.`);

  return async function listMaintenanceQueue({ actorUserId, estateId, page = 1, pageSize = 25, status, statuses, priority, search } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MaintenanceQueueError('INVALID_QUERY', 'Authenticated actor, estate and bounded pagination are required.');
    }
    const allowedStatuses = Object.values(require('./maintenance').MaintenanceStatus);
    const normalizedStatuses = statuses === undefined ? (status === undefined ? undefined : [status]) : statuses;
    if (normalizedStatuses !== undefined && (!Array.isArray(normalizedStatuses) || !normalizedStatuses.length
      || normalizedStatuses.length > allowedStatuses.length || normalizedStatuses.some((value) => !allowedStatuses.includes(value)))) {
      throw new MaintenanceQueueError('INVALID_FILTER', 'Choose a supported maintenance status.');
    }
    if (search !== undefined && typeof search !== 'string') {
      throw new MaintenanceQueueError('INVALID_FILTER', 'Maintenance search must be text.');
    }
    const normalizedSearch = typeof search === 'string' ? search.trim().slice(0, 100) : '';
    if (priority !== undefined && !['low', 'normal', 'high', 'urgent'].includes(priority)) {
      throw new MaintenanceQueueError('INVALID_FILTER', 'Choose a supported maintenance priority.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'maintenance.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new MaintenanceQueueError('ESTATE_ACCESS_DENIED', 'The actor cannot view maintenance requests in this estate.');
      }
      const result = await queryMaintenanceRequests(tx, {
        estateContext, page, pageSize, statuses: normalizedStatuses, priority, search: normalizedSearch,
      });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || ((page - 1) * pageSize >= result.total && result.items.length > 0)) {
        throw new MaintenanceQueueError('INVALID_QUERY_RESULT', 'The maintenance repository returned an invalid page.');
      }
      const items = [];
      for (const request of result.items) {
        if (!request || String(request.estateId) !== String(estateId) || !request.id || !request.propertyId) {
          throw new MaintenanceQueueError('CROSS_ESTATE_RESULT', 'The maintenance repository returned a record outside the selected estate.');
        }
        const projected = await projectMaintenanceQueueItem(tx, { actorUserId, estateContext, request });
        items.push(safeQueueProjection(request, projected, estateId));
      }
      const capabilities = await resolveMaintenanceCapabilities(tx, { actorUserId, estateContext });
      if (!capabilities || typeof capabilities.canAssign !== 'boolean' || typeof capabilities.canAddInternalNote !== 'boolean') {
        throw new MaintenanceQueueError('INVALID_CAPABILITIES', 'Maintenance capabilities must be resolved from estate permissions.');
      }
      const staff = capabilities.canAssign ? await listAssignableStaff(tx, { actorUserId, estateContext }) : [];
      if (!Array.isArray(staff) || staff.some((member) => !member || String(member.estateId) !== String(estateId)
        || member.status !== 'active' || !member.userId || typeof member.displayName !== 'string' || !member.displayName.trim()
        || member.displayName.length > 160)) {
        throw new MaintenanceQueueError('INVALID_STAFF_RESULT', 'Assignable staff must be active members of the selected estate.');
      }
      return Object.freeze({
        items: Object.freeze(items),
        assignableStaff: Object.freeze(staff.map((member) => Object.freeze({ userId: member.userId, displayName: member.displayName }))),
        capabilities: Object.freeze({ canAssign: capabilities.canAssign, canAddInternalNote: capabilities.canAddInternalNote }),
        page, pageSize, total: result.total, totalPages: Math.ceil(result.total / pageSize),
      });
    });
  };
}

module.exports = { MaintenanceQueueError, createMaintenanceQueueListUseCase, safeQueueProjection };
