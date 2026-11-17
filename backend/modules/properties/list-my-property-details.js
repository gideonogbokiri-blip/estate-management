const { safePropertyDetail, PropertyDetailReadError } = require('./read-property-detail');

class MyPropertyListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyPropertyListError';
    this.code = code;
  }
}

/** Lists properties the authenticated actor may currently inspect across estates. */
function createMyPropertyDetailListUseCase({ transaction, resolveMyPropertyListAccess, queryMyAuthorizedProperties } = {}) {
  const ports = { transaction, resolveMyPropertyListAccess, queryMyAuthorizedProperties };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyPropertyListError('MISSING_ADAPTER', `My property list adapters are required: ${missing.join(', ')}.`);

  return async function listMyPropertyDetails({ actorUserId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyPropertyListError('INVALID_QUERY', 'Authenticated resident and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveMyPropertyListAccess(tx, { actorUserId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || access.active !== true || access.mayViewMyProperties !== true) {
        throw new MyPropertyListError('PROPERTY_LIST_ACCESS_DENIED', 'The actor cannot view their property relationships.');
      }
      // Query by current actor relationships across estates before counting or pagination.
      const result = await queryMyAuthorizedProperties(tx, { access, actorUserId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyPropertyListError('INVALID_LIST_RESULT', 'The property repository returned an invalid page.');
      }
      const seen = new Set();
      const items = result.items.map((row) => {
        const property = row?.property;
        const key = `${property?.estateId ?? ''}:${property?.id ?? ''}`;
        if (!property?.id || !property.estateId || seen.has(key)) {
          throw new MyPropertyListError('DUPLICATE_OR_INVALID_PROPERTY', 'The property repository returned a duplicate or invalid property.');
        }
        seen.add(key);
        try {
          return safePropertyDetail(property, row.ownerRecords, row.occupancyRecords, row.projection);
        } catch (error) {
          if (error?.name === 'PropertyDetailReadError') throw new MyPropertyListError(error.code, error.message);
          throw error;
        }
      });
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { MyPropertyListError, createMyPropertyDetailListUseCase };
