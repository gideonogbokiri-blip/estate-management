class AccessibleEstateListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AccessibleEstateListError';
    this.code = code;
  }
}

function sameId(left, right) {
  return left !== undefined && left !== null && right !== undefined && right !== null
    && String(left) === String(right);
}

/** List active estates from trusted membership records for the authenticated actor. */
function createAccessibleEstateListUseCase({ findActiveMembershipsForActor } = {}) {
  if (typeof findActiveMembershipsForActor !== 'function') {
    throw new AccessibleEstateListError('MISSING_ADAPTER', 'An active-membership repository adapter is required.');
  }

  return async function listAccessibleEstates({ actorUserId } = {}) {
    if (!actorUserId) {
      throw new AccessibleEstateListError('UNAUTHENTICATED', 'An authenticated actor is required.');
    }

    const memberships = await findActiveMembershipsForActor({ actorUserId });
    if (!Array.isArray(memberships)) {
      throw new AccessibleEstateListError('INVALID_REPOSITORY_RESULT', 'The membership adapter must return a list.');
    }

    if (memberships.some((membership) => !sameId(membership?.userId, actorUserId))) {
      throw new AccessibleEstateListError('REPOSITORY_SCOPE_VIOLATION', 'The membership adapter returned a record outside the authenticated actor scope.');
    }
    if (memberships.some((membership) => membership?.status === 'active'
      && (!membership.estate?.id || !sameId(membership.estateId, membership.estate.id)))) {
      throw new AccessibleEstateListError('INVALID_REPOSITORY_RESULT', 'An active membership must include its matching estate record.');
    }

    const estatesById = new Map();
    for (const membership of memberships) {
      if (membership.status !== 'active') continue;
      const estate = membership.estate;
      if (!estate?.id || estate.status !== 'active' || typeof estate.name !== 'string') continue;

      const key = String(estate.id);
      if (estatesById.has(key)) continue;

      const locationParts = [estate.lga, estate.state].filter((part) => typeof part === 'string' && part.trim());
      estatesById.set(key, Object.freeze({
        id: estate.id,
        name: estate.name,
        code: typeof estate.code === 'string' ? estate.code : null,
        locationLabel: typeof estate.locationLabel === 'string'
          ? estate.locationLabel
          : locationParts.length ? locationParts.join(', ') : null,
      }));
    }

    return Object.freeze([...estatesById.values()].sort((left, right) => left.name.localeCompare(right.name)));
  };
}

module.exports = { AccessibleEstateListError, createAccessibleEstateListUseCase };
