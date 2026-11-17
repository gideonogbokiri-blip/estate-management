const { PropertyStatus, planPropertyArchive } = require('./property');

class PropertyArchiveUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyArchiveUseCaseError';
    this.code = code;
  }
}

function createPropertyArchiveUseCase({
  transaction,
  requireEstatePermission,
  findPropertyForUpdate,
  inspectArchiveRelationships,
  commitArchive,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findPropertyForUpdate,
    inspectArchiveRelationships,
    commitArchive,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new PropertyArchiveUseCaseError('MISSING_ADAPTER', `Property archive adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new PropertyArchiveUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function archiveProperty({ actorUserId, estateId, propertyId } = {}) {
    if (!actorUserId || !estateId || !propertyId) {
      throw new PropertyArchiveUseCaseError('INVALID_ARCHIVE_INPUT', 'Actor, estate context, and property are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'property.archive', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new PropertyArchiveUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot archive properties in this estate.');
      }
      const property = await findPropertyForUpdate(tx, { propertyId, estateContext });
      if (!property || property.estateId !== estateId) {
        throw new PropertyArchiveUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found.');
      }

      // The adapter must inspect all relationship domains while holding the property's archive lock.
      const relationshipCheck = await inspectArchiveRelationships(tx, { property, estateContext });
      if (!relationshipCheck || relationshipCheck.complete !== true
        || !Array.isArray(relationshipCheck.blockingRelationships)) {
        throw new PropertyArchiveUseCaseError('RELATIONSHIP_CHECK_INCOMPLETE', 'All active estate relationships must be checked before archiving.');
      }

      const plan = planPropertyArchive(property, {
        actorUserId,
        now: clock(),
        blockingRelationships: relationshipCheck.blockingRelationships,
      });
      const archivedProperty = await commitArchive(tx, plan);
      if (!archivedProperty?.id || archivedProperty.id !== property.id
        || archivedProperty.estateId !== estateId || archivedProperty.status !== PropertyStatus.ARCHIVED) {
        throw new PropertyArchiveUseCaseError('INVALID_ARCHIVE_RESULT', 'The repository must archive the property without deleting its history.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ propertyId, estateId, status: PropertyStatus.ARCHIVED });
    });
  };
}

module.exports = { PropertyArchiveUseCaseError, createPropertyArchiveUseCase };
