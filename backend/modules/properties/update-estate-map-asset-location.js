'use strict';

const assetTypes = new Set([
  'zone',
  'street',
  'building',
  'property',
  'gate',
  'parking',
  'facility',
]);
const confidenceValues = new Set([
  'verified',
  'approximate',
  'unverified',
  'unmapped',
]);

class EstateMapLocationUpdateError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateMapLocationUpdateError';
    this.code = code;
  }
}

function requirePorts(ports) {
  const missing = Object.entries(ports)
    .filter(([, value]) => typeof value !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new EstateMapLocationUpdateError(
      'MISSING_ADAPTER',
      `Estate map location adapters are required: ${missing.join(', ')}.`,
    );
  }
}

function validateLocation(input, access) {
  const { latitude, longitude, confidence, source, accuracyMeters = null } = input;
  if (!confidenceValues.has(confidence)) {
    throw new EstateMapLocationUpdateError(
      'INVALID_CONFIDENCE',
      'Choose verified, approximate, unverified or unmapped location confidence.',
    );
  }
  if (typeof source !== 'string' || !source.trim() || source.length > 80
    || !Array.isArray(access.allowedLocationSources)
    || !access.allowedLocationSources.includes(source)) {
    throw new EstateMapLocationUpdateError(
      'INVALID_LOCATION_SOURCE',
      'Choose a location source configured for this estate.',
    );
  }
  const isUnmapped = latitude === null && longitude === null;
  if (isUnmapped) {
    if (confidence !== 'unmapped' || accuracyMeters !== null) {
      throw new EstateMapLocationUpdateError(
        'INVALID_LOCATION',
        'An unmapped asset must have no coordinates or accuracy and use unmapped confidence.',
      );
    }
  } else if (
    typeof latitude !== 'number' || !Number.isFinite(latitude)
    || latitude < -90 || latitude > 90
    || typeof longitude !== 'number' || !Number.isFinite(longitude)
    || longitude < -180 || longitude > 180
    || confidence === 'unmapped'
  ) {
    throw new EstateMapLocationUpdateError(
      'INVALID_LOCATION',
      'Mapped assets require a complete WGS 84 coordinate pair and non-unmapped confidence.',
    );
  }
  if (accuracyMeters !== null && (
    typeof accuracyMeters !== 'number' || !Number.isFinite(accuracyMeters)
    || accuracyMeters < 0 || accuracyMeters > 100000
  )) {
    throw new EstateMapLocationUpdateError(
      'INVALID_ACCURACY',
      'Location accuracy must be a non-negative number no greater than 100000 metres.',
    );
  }
  return Object.freeze({
    latitude: isUnmapped ? null : latitude,
    longitude: isUnmapped ? null : longitude,
    confidence,
    source: source.trim(),
    accuracyMeters,
  });
}

function sameLocation(actual, expected) {
  return actual && actual.latitude === expected.latitude
    && actual.longitude === expected.longitude
    && actual.confidence === expected.confidence
    && actual.source === expected.source
    && actual.accuracyMeters === expected.accuracyMeters;
}

/** Update an estate asset location through existing authorization, storage and audit services. */
function createEstateMapAssetLocationUpdateUseCase({
  transaction,
  resolveEstateMapLocationAccess,
  findMapAssetForUpdate,
  commitAssetLocationUpdate,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  requirePorts({
    transaction,
    resolveEstateMapLocationAccess,
    findMapAssetForUpdate,
    commitAssetLocationUpdate,
    appendAuditEvent,
  });
  if (typeof clock !== 'function') {
    throw new EstateMapLocationUpdateError('INVALID_CLOCK', 'A map update clock is required.');
  }

  return async function updateEstateMapAssetLocation({
    actorUserId,
    estateId,
    assetType,
    assetId,
    location,
    reason,
  } = {}) {
    if (!actorUserId || !estateId || !assetId || !assetTypes.has(assetType)
      || !location || typeof location !== 'object' || Array.isArray(location)
      || typeof reason !== 'string' || reason.trim().length < 10 || reason.length > 500) {
      throw new EstateMapLocationUpdateError(
        'INVALID_INPUT',
        'Actor, estate, asset, location and a 10 to 500 character reason are required.',
      );
    }

    return transaction(async (tx) => {
      const access = await resolveEstateMapLocationAccess(tx, {
        actorUserId,
        estateId,
        assetType,
        assetId,
      });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)
        || String(access.assetId) !== String(assetId)
        || access.assetType !== assetType || access.active !== true
        || access.mayManageLocation !== true
        || access.mayManageAsset !== true) {
        throw new EstateMapLocationUpdateError(
          'MAP_LOCATION_ACCESS_DENIED',
          'The actor cannot update this asset location in the selected estate.',
        );
      }
      const nextLocation = validateLocation(location, access);
      const asset = await findMapAssetForUpdate(tx, {
        estateId,
        assetType,
        assetId,
        access,
      });
      if (!asset || String(asset.id) !== String(assetId)
        || String(asset.estateId) !== String(estateId)
        || asset.type !== assetType) {
        throw new EstateMapLocationUpdateError(
          'MAP_ASSET_NOT_FOUND',
          'The map asset was not found in this estate.',
        );
      }
      const previousLocation = asset.location ?? null;
      if (previousLocation !== null && (
        typeof previousLocation !== 'object'
        || Array.isArray(previousLocation)
        || String(previousLocation.assetId) !== String(assetId)
        || String(previousLocation.estateId) !== String(estateId)
      )) {
        throw new EstateMapLocationUpdateError(
          'INVALID_CURRENT_LOCATION',
          'The stored location must be bound to the locked same-estate asset.',
        );
      }
      const updatedAtDate = new Date(clock());
      if (Number.isNaN(updatedAtDate.getTime())) {
        throw new EstateMapLocationUpdateError('INVALID_CLOCK', 'The map update time must be valid.');
      }
      const updatedAt = updatedAtDate.toISOString();
      const committed = await commitAssetLocationUpdate(tx, {
        estateId,
        assetType,
        assetId,
        location: nextLocation,
        actorUserId,
        updatedAt,
      }, { access, asset });
      if (!committed || String(committed.assetId) !== String(assetId)
        || String(committed.estateId) !== String(estateId)
        || committed.assetType !== assetType
        || committed.updatedAt !== updatedAt
        || !sameLocation(committed.location, nextLocation)) {
        throw new EstateMapLocationUpdateError(
          'INVALID_COMMIT_RESULT',
          'The repository must persist the requested location for the authorized asset.',
        );
      }
      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'estate_map_asset.location_updated',
        targetType: assetType,
        targetId: assetId,
        outcome: 'success',
        occurredAt: updatedAt,
        metadata: Object.freeze({
          reason: reason.trim(),
          previousLocation: previousLocation === null ? null : Object.freeze({
            latitude: previousLocation.latitude ?? null,
            longitude: previousLocation.longitude ?? null,
            confidence: previousLocation.confidence ?? null,
            source: previousLocation.source ?? null,
            accuracyMeters: previousLocation.accuracyMeters ?? null,
          }),
          newLocation: Object.freeze({ ...nextLocation }),
        }),
      });
      return Object.freeze({
        assetId,
        estateId,
        assetType,
        location: Object.freeze({ ...nextLocation, updatedAt }),
      });
    });
  };
}

module.exports = {
  EstateMapLocationUpdateError,
  createEstateMapAssetLocationUpdateUseCase,
};
