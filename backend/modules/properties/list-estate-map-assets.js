class EstateMapListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateMapListError';
    this.code = code;
  }
}

const assetTypes = new Set([
  'zone', 'street', 'building', 'property', 'gate', 'parking', 'facility',
]);
const locationConfidenceValues = new Set([
  'verified', 'approximate', 'unverified', 'unmapped',
]);

function safeDisplay(value, field, limit, nullable = false) {
  if (nullable && (value === null || value === undefined || value === '')) {
    return null;
  }
  if (typeof value !== 'string' || !value.trim() || value.length > limit) {
    throw new EstateMapListError('INVALID_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function safeMapAsset(row, estateId) {
  const asset = row?.asset;
  const location = row?.location;
  const projection = row?.projection;
  if (!asset?.id || String(asset.estateId) !== String(estateId)
    || !assetTypes.has(asset.type)) {
    throw new EstateMapListError('ESTATE_SCOPE_VIOLATION', 'The map repository returned an invalid or cross-estate asset.');
  }
  if (!location || !locationConfidenceValues.has(location.confidence)) {
    throw new EstateMapListError('INVALID_LOCATION', 'Map locations must include an explicit confidence state.');
  }
  const noCoordinates = location.latitude === null || location.latitude === undefined;
  if (noCoordinates) {
    if (location.longitude !== null && location.longitude !== undefined
      || location.confidence !== 'unmapped'
      || (location.accuracyMeters !== null && location.accuracyMeters !== undefined)) {
      throw new EstateMapListError('INVALID_LOCATION', 'Unmapped assets cannot include partial or unverified coordinates.');
    }
  } else if (typeof location.latitude !== 'number'
    || !Number.isFinite(location.latitude) || location.latitude < -90
    || location.latitude > 90 || typeof location.longitude !== 'number'
    || !Number.isFinite(location.longitude) || location.longitude < -180
    || location.longitude > 180 || location.confidence === 'unmapped') {
    throw new EstateMapListError('INVALID_LOCATION', 'Mapped assets require a complete in-range coordinate pair and confidence label.');
  }
  const accuracyMeters = location.accuracyMeters ?? null;
  if (accuracyMeters !== null && (typeof accuracyMeters !== 'number'
    || !Number.isFinite(accuracyMeters) || accuracyMeters < 0
    || accuracyMeters > 100000)) {
    throw new EstateMapListError('INVALID_LOCATION', 'Location accuracy must be a bounded non-negative number of metres.');
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => !['assetId', 'label', 'detail'].includes(key))
    || String(projection.assetId) !== String(asset.id)) {
    throw new EstateMapListError('INVALID_PROJECTION', 'The map projection must be allowlisted and match its asset.');
  }
  const updatedAt = location.updatedAt ?? null;
  if (updatedAt !== null && (typeof updatedAt !== 'string'
    || Number.isNaN(Date.parse(updatedAt))
    || new Date(updatedAt).toISOString() !== updatedAt)) {
    throw new EstateMapListError('INVALID_LOCATION', 'Location update time must be a normalized ISO timestamp.');
  }
  return Object.freeze({
    id: asset.id,
    type: asset.type,
    label: safeDisplay(projection.label, 'label', 160),
    detail: safeDisplay(projection.detail, 'detail', 240, true),
    latitude: noCoordinates ? null : location.latitude,
    longitude: noCoordinates ? null : location.longitude,
    locationConfidence: location.confidence,
    accuracyMeters,
    source: safeDisplay(location.source, 'location source', 80, true),
    updatedAt,
  });
}

/** Read authorized estate-asset locations; repositories must scope each asset before returning it. */
function createEstateMapAssetListUseCase({
  transaction,
  resolveEstateMapAccess,
  queryAuthorizedMapAssets,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveEstateMapAccess, queryAuthorizedMapAssets };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new EstateMapListError('MISSING_ADAPTER', `Estate map adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateMapListError('INVALID_CLOCK', 'A map query clock is required.');
  }

  return async function listEstateMapAssets({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) {
      throw new EstateMapListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveEstateMapAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)
        || access.active !== true || access.mayViewMap !== true) {
        throw new EstateMapListError('MAP_ACCESS_DENIED', 'The actor cannot view map assets in this estate.');
      }
      const asOfDate = new Date(clock());
      if (Number.isNaN(asOfDate.getTime())) {
        throw new EstateMapListError('INVALID_CLOCK', 'The map query time must be valid.');
      }
      // The repository resolves authorized layers and asset relationships before this bounded read.
      const rows = await queryAuthorizedMapAssets(tx, {
        access,
        estateId,
        limit: 500,
        asOf: asOfDate.toISOString(),
      });
      if (!Array.isArray(rows) || rows.length > 500) {
        throw new EstateMapListError('INVALID_REPOSITORY_RESULT', 'The map query must return a bounded asset list.');
      }
      const seen = new Set();
      const items = rows.map((row) => {
        const id = String(row?.asset?.id ?? '');
        if (!id || seen.has(id)) {
          throw new EstateMapListError('INVALID_REPOSITORY_RESULT', 'The map result contains a missing or duplicate asset.');
        }
        seen.add(id);
        return safeMapAsset(row, estateId);
      });
      return Object.freeze({
        estateId,
        asOf: asOfDate.toISOString(),
        items: Object.freeze(items),
      });
    });
  };
}

module.exports = { EstateMapListError, createEstateMapAssetListUseCase, safeMapAsset };
