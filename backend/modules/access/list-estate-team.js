const TeamMembershipStatuses = Object.freeze(['active', 'invited', 'suspended', 'revoked', 'expired']);
const TeamRecordKinds = Object.freeze(['membership', 'invitation']);

class EstateTeamListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateTeamListError';
    this.code = code;
  }
}

function normalizeEstateTeamQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new EstateTeamListError('INVALID_QUERY', 'Team filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new EstateTeamListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  const status = query.status || 'all';
  if (status !== 'all' && !TeamMembershipStatuses.includes(status)) {
    throw new EstateTeamListError('INVALID_STATUS_FILTER', 'Choose a supported staff membership or invitation status.');
  }
  const search = typeof query.search === 'string' ? query.search.trim() : '';
  if (query.search !== undefined && typeof query.search !== 'string') {
    throw new EstateTeamListError('INVALID_SEARCH', 'Search must be text.');
  }
  if (search.length > 100) throw new EstateTeamListError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');
  if (query.roleId !== undefined && query.roleId !== null && query.roleId !== '') {
    if (!['string', 'number'].includes(typeof query.roleId) || !String(query.roleId).trim()) {
      throw new EstateTeamListError('INVALID_ROLE_FILTER', 'Role filter is invalid.');
    }
  }
  const filters = {};
  if (status !== 'all') filters.status = status;
  if (search) filters.search = search;
  if (query.roleId !== undefined && query.roleId !== null && query.roleId !== '') filters.roleId = query.roleId;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters) });
}

function validOptionalTimestamp(value) {
  return value === null || value === undefined
    || (typeof value === 'string' && !Number.isNaN(new Date(value).getTime()));
}

function sanitizeTeamProjection(record, projection) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)) {
    throw new EstateTeamListError('PROJECTION_REQUIRED', 'Every team entry requires an actor-authorized projection.');
  }
  const allowedKeys = new Set(['displayName', 'email', 'roleId', 'roleLabel', 'accessScopeLabel', 'lastActiveAt']);
  if (Object.keys(projection).some((key) => !allowedKeys.has(key))) {
    throw new EstateTeamListError('UNSAFE_PROJECTION', 'The team projection contains fields outside the staff directory contract.');
  }
  const { displayName, email = null, roleId, roleLabel, accessScopeLabel = null, lastActiveAt = null } = projection;
  if (typeof displayName !== 'string' || displayName.length > 200
    || (email !== null && (typeof email !== 'string' || email.length > 254))
    || (roleId !== null && roleId !== undefined && !['string', 'number'].includes(typeof roleId))
    || (roleLabel !== null && roleLabel !== undefined && (typeof roleLabel !== 'string' || roleLabel.length > 120))
    || (accessScopeLabel !== null && (typeof accessScopeLabel !== 'string' || accessScopeLabel.length > 200))
    || !validOptionalTimestamp(lastActiveAt)) {
    throw new EstateTeamListError('INVALID_PROJECTION', 'The staff directory projection contains invalid display fields.');
  }
  return Object.freeze({
    id: record.id,
    kind: record.kind,
    displayName,
    email,
    role: roleId === null || roleId === undefined ? null : Object.freeze({ id: roleId, label: roleLabel || null }),
    accessScopeLabel,
    status: record.status,
    invitedAt: record.invitedAt || null,
    expiresAt: record.expiresAt || null,
    lastActiveAt,
  });
}

/** List members and invitations under an authorized estate scope with safe display projections. */
function createEstateTeamListUseCase({
  transaction,
  requireEstatePermission,
  queryEstateTeam,
  projectEstateTeamEntryForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryEstateTeam, projectEstateTeamEntryForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateTeamListError('MISSING_ADAPTER', `Estate team list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateTeam({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new EstateTeamListError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizeEstateTeamQuery(query);
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'staff.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new EstateTeamListError('ESTATE_ACCESS_DENIED', 'The actor cannot view staff access in this estate.');
      }
      // Repository filtering, totals and pagination must all be applied after server-side estate scoping.
      const result = await queryEstateTeam(tx, { estateContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new EstateTeamListError('INVALID_REPOSITORY_RESULT', 'The team query must return a bounded page and authorized total.');
      }
      const seen = new Set();
      const items = [];
      for (const record of result.items) {
        if (!record?.id || String(record.estateId) !== String(estateId)
          || !TeamRecordKinds.includes(record.kind) || !TeamMembershipStatuses.includes(record.status)) {
          throw new EstateTeamListError('ESTATE_SCOPE_VIOLATION', 'The repository returned an invalid or out-of-scope team record.');
        }
        const key = `${record.kind}:${record.id}`;
        if (seen.has(key)) throw new EstateTeamListError('DUPLICATE_REPOSITORY_RESULT', 'The team query returned a duplicate record.');
        seen.add(key);
        if (!validOptionalTimestamp(record.invitedAt) || !validOptionalTimestamp(record.expiresAt)) {
          throw new EstateTeamListError('INVALID_REPOSITORY_RESULT', 'Invitation timestamps must be valid.');
        }
        const projection = await projectEstateTeamEntryForActor({ actorUserId, estateContext, record, tx });
        items.push(sanitizeTeamProjection(record, projection));
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

module.exports = {
  EstateTeamListError,
  TeamMembershipStatuses,
  TeamRecordKinds,
  createEstateTeamListUseCase,
  normalizeEstateTeamQuery,
  sanitizeTeamProjection,
};
