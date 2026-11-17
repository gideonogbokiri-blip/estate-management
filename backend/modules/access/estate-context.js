const MembershipStatus = Object.freeze({ ACTIVE: 'active' });
const { EstateStatus } = require('../onboarding/estate-lifecycle');
const resolvedContexts = new WeakSet();

class EstateAccessError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateAccessError';
    this.code = code;
  }
}

/**
 * Resolves an estate scope from memberships loaded for the authenticated actor.
 * `memberships` must come from a trusted repository query, never request data.
 */
function resolveEstateContext({ actorUserId, requestedEstateId, memberships }) {
  if (!actorUserId) {
    throw new EstateAccessError('UNAUTHENTICATED', 'An authenticated actor is required.');
  }
  if (!requestedEstateId) {
    throw new EstateAccessError('ESTATE_CONTEXT_REQUIRED', 'Choose an estate context.');
  }

  const idMatches = (left, right) => left !== undefined && left !== null && right !== undefined && right !== null
    && String(left) === String(right);
  const activeMemberships = (Array.isArray(memberships) ? memberships : []).filter((membership) =>
    idMatches(membership?.userId, actorUserId)
    && idMatches(membership?.estateId, requestedEstateId)
    && membership?.status === MembershipStatus.ACTIVE
    && membership?.estate?.status === EstateStatus.ACTIVE,
  );

  if (activeMemberships.length === 0) {
    throw new EstateAccessError('ESTATE_ACCESS_DENIED', 'No active membership grants access to this estate.');
  }

  const permissions = new Set();
  for (const membership of activeMemberships) {
    if (!Array.isArray(membership.permissions)) continue;
    for (const permission of membership.permissions) {
      if (typeof permission !== 'string' || !permission.trim() || permission.length > 120) {
        throw new EstateAccessError('INVALID_PERMISSION_RESULT', 'The membership resolver returned an invalid estate permission.');
      }
      const capability = permission.trim();
      if (capability.startsWith('platform.')) {
        throw new EstateAccessError('PLATFORM_PERMISSION_LEAK', 'Platform permissions cannot be used in estate context.');
      }
      permissions.add(capability);
    }
  }

  const context = Object.freeze({
    actorUserId,
    estateId: requestedEstateId,
    membershipIds: Object.freeze(activeMemberships.map((membership) => membership.id).filter(Boolean)),
    permissions: Object.freeze([...permissions]),
  });
  resolvedContexts.add(context);
  return context;
}

function requireEstatePermission(context, permission) {
  if (!context || !resolvedContexts.has(context)) {
    throw new EstateAccessError('ESTATE_CONTEXT_REQUIRED', 'A resolved estate context is required.');
  }
  if (!permission || !context.permissions.includes(permission)) {
    throw new EstateAccessError('PERMISSION_DENIED', 'The actor does not have the required estate permission.');
  }
  return context;
}

/** Hide records outside the authorized estate behind the same result as missing data. */
function assertRecordInEstate(record, context) {
  if (!record || !context || !resolvedContexts.has(context) || String(record.estateId) !== String(context.estateId)) {
    throw new EstateAccessError('RECORD_NOT_FOUND', 'The requested record was not found.');
  }
  return record;
}

module.exports = {
  EstateAccessError,
  EstateStatus,
  MembershipStatus,
  assertRecordInEstate,
  requireEstatePermission,
  resolveEstateContext,
};
