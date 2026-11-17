class EstatePermissionSummaryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstatePermissionSummaryError';
    this.code = code;
  }
}

function normalizeEstatePermissions(permissions) {
  if (!Array.isArray(permissions)) {
    throw new EstatePermissionSummaryError('INVALID_PERMISSION_RESULT', 'The authorization adapter must return estate permissions as a list.');
  }
  const normalized = [];
  const seen = new Set();
  for (const permission of permissions) {
    if (typeof permission !== 'string' || !permission.trim() || permission.length > 120) {
      throw new EstatePermissionSummaryError('INVALID_PERMISSION_RESULT', 'The authorization adapter returned an invalid permission.');
    }
    const capability = permission.trim();
    if (capability.startsWith('platform.')) {
      throw new EstatePermissionSummaryError('PLATFORM_PERMISSION_LEAK', 'Platform permissions cannot be returned in an estate permission summary.');
    }
    if (!seen.has(capability)) {
      seen.add(capability);
      normalized.push(capability);
    }
  }
  return Object.freeze(normalized.sort());
}

/** Return the actor's current estate capabilities for UI affordances, never as an authorization token. */
function createEstatePermissionSummaryUseCase({ resolveEffectiveEstatePermissions, clock = () => new Date() } = {}) {
  if (typeof resolveEffectiveEstatePermissions !== 'function') {
    throw new EstatePermissionSummaryError('MISSING_ADAPTER', 'An effective-permission resolver is required.');
  }
  if (typeof clock !== 'function') throw new EstatePermissionSummaryError('INVALID_CLOCK', 'A clock function is required.');

  return async function getEstatePermissionSummary({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) {
      throw new EstatePermissionSummaryError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    }
    const resolved = await resolveEffectiveEstatePermissions({ actorUserId, estateId });
    if (!resolved || String(resolved.actorUserId) !== String(actorUserId) || String(resolved.estateId) !== String(estateId)) {
      throw new EstatePermissionSummaryError('ESTATE_ACCESS_DENIED', 'The actor has no active access to this estate.');
    }
    const permissions = normalizeEstatePermissions(resolved.permissions);
    const timestamp = new Date(clock());
    if (Number.isNaN(timestamp.getTime())) {
      throw new EstatePermissionSummaryError('INVALID_TIMESTAMP', 'A valid permissions timestamp is required.');
    }
    return Object.freeze({
      estateId,
      permissions,
      resolvedAt: timestamp.toISOString(),
      purpose: 'ui_affordances_only',
    });
  };
}

module.exports = { EstatePermissionSummaryError, createEstatePermissionSummaryUseCase, normalizeEstatePermissions };
