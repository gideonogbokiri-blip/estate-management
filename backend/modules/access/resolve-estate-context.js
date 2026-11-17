const { resolveEstateContext } = require('./estate-context');

class EstateContextResolverError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateContextResolverError';
    this.code = code;
  }
}

/** Resolve request scope from memberships loaded by a trusted repository adapter. */
function createEstateContextResolver({ findActiveMembershipsForActorAndEstate } = {}) {
  if (typeof findActiveMembershipsForActorAndEstate !== 'function') {
    throw new EstateContextResolverError('MISSING_ADAPTER', 'An active-membership repository adapter is required.');
  }

  return async function resolveRequestEstateContext({ actorUserId, requestedEstateId } = {}) {
    if (!actorUserId || !requestedEstateId) {
      // Keep the domain module's established error codes and messages.
      return resolveEstateContext({ actorUserId, requestedEstateId, memberships: [] });
    }

    const memberships = await findActiveMembershipsForActorAndEstate({ actorUserId, estateId: requestedEstateId });
    if (!Array.isArray(memberships)) {
      throw new EstateContextResolverError('INVALID_REPOSITORY_RESULT', 'The membership adapter must return a list.');
    }
    const idMatches = (left, right) => left !== undefined && left !== null && right !== undefined && right !== null
      && String(left) === String(right);
    if (memberships.some((membership) => !idMatches(membership?.userId, actorUserId)
      || !idMatches(membership?.estateId, requestedEstateId))) {
      throw new EstateContextResolverError('REPOSITORY_SCOPE_VIOLATION', 'The membership adapter returned a record outside the requested actor and estate scope.');
    }
    return resolveEstateContext({ actorUserId, requestedEstateId, memberships });
  };
}

module.exports = { EstateContextResolverError, createEstateContextResolver };
