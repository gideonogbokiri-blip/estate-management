const { PropertyStatus } = require('./property');

class PropertyDetailReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyDetailReadError';
    this.code = code;
  }
}

function optionalString(value, field, maxLength = 500) {
  if (value !== null && value !== undefined && (typeof value !== 'string' || value.length > maxLength)) {
    throw new PropertyDetailReadError('INVALID_PROJECTION', `${field} must be bounded text or null.`);
  }
  return value ?? null;
}

function safePropertyDetail(property, ownerRecords, occupancyRecords, projection) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || !projection.property || projection.property.id !== property.id
    || projection.property.estateId !== property.estateId
    || !Array.isArray(projection.ownershipRecords) || !Array.isArray(projection.occupancyRecords)) {
    throw new PropertyDetailReadError('INVALID_PROJECTION', 'An actor-authorized property and relationship summary is required.');
  }
  for (const record of [...projection.ownershipRecords, ...projection.occupancyRecords]) {
    if (!record?.id || record.estateId !== property.estateId || record.propertyId !== property.id) {
      throw new PropertyDetailReadError('RELATIONSHIP_SCOPE_VIOLATION', 'A projected relationship is outside this property or estate.');
    }
  }
  if (ownerRecords.some((record) => record.estateId !== property.estateId || record.propertyId !== property.id)
    || occupancyRecords.some((record) => record.estateId !== property.estateId || record.propertyId !== property.id)) {
    throw new PropertyDetailReadError('RELATIONSHIP_SCOPE_VIOLATION', 'The relationship adapter returned records outside this property or estate.');
  }
  const sourceOwnershipIds = new Set(ownerRecords.map((record) => String(record.id)));
  const sourceOccupancyIds = new Set(occupancyRecords.map((record) => String(record.id)));
  if (sourceOwnershipIds.size !== ownerRecords.length || sourceOccupancyIds.size !== occupancyRecords.length
    || projection.ownershipRecords.some((record) => !sourceOwnershipIds.has(String(record.id)))
    || projection.occupancyRecords.some((record) => !sourceOccupancyIds.has(String(record.id)))) {
    throw new PropertyDetailReadError('UNAUTHORIZED_RELATIONSHIP_PROJECTION', 'Projected relationships must come from the actor-authorized relationship query results.');
  }

  const propertyView = projection.property;
  const matchesAuthorizedSource = (projected, source) => projected === null || projected === undefined
    || projected === (source ?? null);
  if (!Object.values(PropertyStatus).includes(propertyView.status) || propertyView.status !== property.status
    || !matchesAuthorizedSource(propertyView.code, property.code)
    || !matchesAuthorizedSource(propertyView.propertyType, property.propertyType)
    || !matchesAuthorizedSource(propertyView.unitNumber, property.unitNumber)
    || !matchesAuthorizedSource(propertyView.address, property.address)
    || !matchesAuthorizedSource(propertyView.description, property.description)) {
    throw new PropertyDetailReadError('INVALID_PROJECTION', 'Property display values must match or be redacted from the authorized property record.');
  }
  const ownershipIds = new Set();
  const owners = projection.ownershipRecords.map((record) => {
    if (ownershipIds.has(String(record.id))) throw new PropertyDetailReadError('DUPLICATE_RELATIONSHIP', 'Duplicate ownership records are not allowed.');
    ownershipIds.add(String(record.id));
    return Object.freeze({
      id: record.id,
      displayName: optionalString(record.owner?.displayName, 'owner display name', 200),
      ownershipShare: optionalString(record.ownershipShare, 'ownership share', 40),
      effectiveFrom: optionalString(record.effectiveFrom, 'ownership start date', 40),
      effectiveTo: optionalString(record.effectiveTo, 'ownership end date', 40),
      status: optionalString(record.status, 'ownership status', 40),
      verificationStatus: optionalString(record.verificationStatus, 'ownership verification status', 40),
    });
  });
  const occupancyIds = new Set();
  const occupants = projection.occupancyRecords.map((record) => {
    if (occupancyIds.has(String(record.id))) throw new PropertyDetailReadError('DUPLICATE_RELATIONSHIP', 'Duplicate occupancy records are not allowed.');
    occupancyIds.add(String(record.id));
    return Object.freeze({
      id: record.id,
      displayName: optionalString(record.resident?.displayName, 'resident display name', 200),
      relationship: optionalString(record.relationship, 'occupancy relationship', 40),
      effectiveFrom: optionalString(record.effectiveFrom, 'occupancy start date', 40),
      effectiveTo: optionalString(record.effectiveTo, 'occupancy end date', 40),
      status: optionalString(record.status, 'occupancy status', 40),
    });
  });

  return Object.freeze({
    property: Object.freeze({
      id: property.id,
      estateId: property.estateId,
      code: optionalString(propertyView.code, 'property code', 80),
      propertyType: optionalString(propertyView.propertyType, 'property type', 80),
      status: propertyView.status,
      unitNumber: optionalString(propertyView.unitNumber, 'unit number', 80),
      address: optionalString(propertyView.address, 'property address', 240),
      description: optionalString(propertyView.description, 'property description', 700),
    }),
    ownershipRecords: Object.freeze(owners),
    occupancyRecords: Object.freeze(occupants),
  });
}

/** Read a property through estate staff permission or a verified owner/tenant relationship. */
function createPropertyDetailReadUseCase({
  transaction,
  findPropertyById,
  authorizePropertyView,
  loadPropertyOwnershipRecords,
  loadPropertyOccupancyRecords,
  projectPropertyDetailForActor,
} = {}) {
  const ports = { transaction, findPropertyById, authorizePropertyView, loadPropertyOwnershipRecords, loadPropertyOccupancyRecords, projectPropertyDetailForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PropertyDetailReadError('MISSING_ADAPTER', `Property detail adapters are required: ${missing.join(', ')}.`);

  return async function readPropertyDetail({ actorUserId, propertyId, estateId } = {}) {
    if (!actorUserId || !propertyId) throw new PropertyDetailReadError('INVALID_INPUT', 'Actor and property are required.');
    return transaction(async (tx) => {
      const property = await findPropertyById(tx, { propertyId });
      if (!property?.id || (estateId && property.estateId !== estateId)) {
        throw new PropertyDetailReadError('PROPERTY_NOT_FOUND', 'The property was not found.');
      }
      const access = await authorizePropertyView(tx, { actorUserId, property, requestedEstateId: estateId });
      if (access?.allowed !== true || access.estateId !== property.estateId) {
        throw new PropertyDetailReadError('PROPERTY_NOT_FOUND', 'The property was not found.');
      }
      const ownerRecords = await loadPropertyOwnershipRecords(tx, { property, actorUserId, access });
      const occupancyRecords = await loadPropertyOccupancyRecords(tx, { property, actorUserId, access });
      if (!Array.isArray(ownerRecords) || !Array.isArray(occupancyRecords)) {
        throw new PropertyDetailReadError('INVALID_REPOSITORY_RESULT', 'Ownership and occupancy adapters must return lists.');
      }
      const projection = await projectPropertyDetailForActor({ actorUserId, property, ownerRecords, occupancyRecords, access, tx });
      return safePropertyDetail(property, ownerRecords, occupancyRecords, projection);
    });
  };
}

module.exports = { PropertyDetailReadError, createPropertyDetailReadUseCase, safePropertyDetail };
