const { validatePropertyDraft } = require('./property');

class PropertyCreationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyCreationUseCaseError';
    this.code = code;
  }
}

function createPropertyUseCase({
  transaction,
  requireEstatePermission,
  findPropertyParents,
  isPropertyCodeAvailable,
  createPropertyRecord,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findPropertyParents,
    isPropertyCodeAvailable,
    createPropertyRecord,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new PropertyCreationUseCaseError('MISSING_ADAPTER', `Property creation adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new PropertyCreationUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createProperty({ actorUserId, estateId, propertyDraft } = {}) {
    if (!actorUserId || !estateId || !propertyDraft || typeof propertyDraft !== 'object' || Array.isArray(propertyDraft)) {
      throw new PropertyCreationUseCaseError('INVALID_PROPERTY_INPUT', 'Actor, estate context, and property details are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'property.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new PropertyCreationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage properties in this estate.');
      }

      const requestedParentIds = Array.isArray(propertyDraft.parentIds) ? propertyDraft.parentIds : [];
      const parents = await findPropertyParents(tx, { parentIds: requestedParentIds, estateContext });
      if (!Array.isArray(parents) || parents.length !== requestedParentIds.length
        || parents.some((parent) => parent.estateId !== estateId || parent.status !== 'active')
        || new Set(parents.map((parent) => String(parent.id))).size !== requestedParentIds.length
        || requestedParentIds.some((id) => !parents.some((parent) => parent.id === id))) {
        throw new PropertyCreationUseCaseError('HIERARCHY_NOT_FOUND', 'One or more active hierarchy nodes were not found in this estate.');
      }

      const draft = validatePropertyDraft({ ...propertyDraft, estateId, parents });
      const codeAvailable = await isPropertyCodeAvailable(tx, {
        estateId,
        code: draft.code,
        estateContext,
      });
      if (codeAvailable !== true) {
        throw new PropertyCreationUseCaseError('PROPERTY_CODE_UNAVAILABLE', 'This property code is already in use or could not be verified.');
      }

      const timestamp = new Date(clock());
      if (Number.isNaN(timestamp.getTime())) {
        throw new PropertyCreationUseCaseError('INVALID_TIMESTAMP', 'A valid property creation timestamp is required.');
      }
      const createdAt = timestamp.toISOString();
      const property = await createPropertyRecord(tx, { ...draft, createdByUserId: actorUserId, createdAt }, { estateContext });
      if (!property?.id || property.estateId !== estateId || property.code !== draft.code) {
        throw new PropertyCreationUseCaseError('INVALID_PROPERTY_RESULT', 'The repository must create the validated property in this estate.');
      }

      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'property.created',
        targetType: 'property',
        targetId: property.id,
        outcome: 'success',
        occurredAt: createdAt,
      });
      return Object.freeze({ propertyId: property.id, estateId, code: property.code });
    });
  };
}

module.exports = { PropertyCreationUseCaseError, createPropertyUseCase };
