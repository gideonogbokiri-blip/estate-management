const { prepareOwnershipInterest } = require('./ownership');

class OwnershipCreationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'OwnershipCreationUseCaseError';
    this.code = code;
  }
}

function createOwnershipInterestUseCase({
  transaction,
  requireEstatePermission,
  findPropertyForUpdate,
  resolveOwnershipParty,
  getOwnershipPolicy,
  inspectOwnershipCapacity,
  verifyEvidenceReference,
  createOwnershipRecord,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findPropertyForUpdate,
    resolveOwnershipParty,
    getOwnershipPolicy,
    inspectOwnershipCapacity,
    verifyEvidenceReference,
    createOwnershipRecord,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new OwnershipCreationUseCaseError('MISSING_ADAPTER', `Ownership creation adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new OwnershipCreationUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createOwnershipInterest({ actorUserId, estateId, propertyId, ownershipDraft } = {}) {
    if (!actorUserId || !estateId || !propertyId || !ownershipDraft
      || typeof ownershipDraft !== 'object' || Array.isArray(ownershipDraft)) {
      throw new OwnershipCreationUseCaseError('INVALID_OWNERSHIP_INPUT', 'Actor, estate, property, and ownership details are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'ownership.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new OwnershipCreationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage ownership in this estate.');
      }
      const property = await findPropertyForUpdate(tx, { propertyId, estateContext });
      if (!property || property.estateId !== estateId) {
        throw new OwnershipCreationUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found.');
      }

      const party = await resolveOwnershipParty(tx, {
        ownerUserId: ownershipDraft.ownerUserId,
        legalEntityId: ownershipDraft.legalEntityId,
        estateContext,
      });
      const hasOwnerUserId = ownershipDraft.ownerUserId !== undefined && ownershipDraft.ownerUserId !== null && ownershipDraft.ownerUserId !== '';
      const hasLegalEntityId = ownershipDraft.legalEntityId !== undefined && ownershipDraft.legalEntityId !== null && ownershipDraft.legalEntityId !== '';
      if (!party || (hasOwnerUserId && party.userId !== ownershipDraft.ownerUserId)
        || (hasLegalEntityId && party.legalEntityId !== ownershipDraft.legalEntityId)) {
        throw new OwnershipCreationUseCaseError('OWNERSHIP_PARTY_NOT_FOUND', 'The owner or approved legal entity was not found.');
      }

      const policy = await getOwnershipPolicy(tx, { property, estateContext });
      const capacity = await inspectOwnershipCapacity(tx, {
        property,
        ownershipDraft,
        policy,
        estateContext,
      });
      const evidenceDocumentId = ownershipDraft.evidenceDocumentId;
      const evidenceReferenceVerified = evidenceDocumentId === undefined || evidenceDocumentId === null
        ? true
        : await verifyEvidenceReference(tx, { evidenceDocumentId, property, party, estateContext });
      const plan = prepareOwnershipInterest({
        ...ownershipDraft,
        estateId,
        propertyId,
        propertyEstateId: property.estateId,
      }, {
        actorUserId,
        now: clock(),
        policy,
        canCoexist: capacity?.canCoexist,
        shareCapacityAvailable: capacity?.shareCapacityAvailable,
        evidenceReferenceVerified,
      });

      const ownership = await createOwnershipRecord(tx, plan.record, { estateContext, property });
      if (!ownership?.id || ownership.estateId !== estateId || ownership.propertyId !== propertyId
        || ownership.ownerUserId !== plan.record.ownerUserId || ownership.legalEntityId !== plan.record.legalEntityId
        || ownership.effectiveFrom !== plan.record.effectiveFrom || ownership.ownershipShare !== plan.record.ownershipShare
        || ownership.status !== plan.record.status
        || ownership.verificationStatus !== plan.record.verificationStatus) {
        throw new OwnershipCreationUseCaseError('INVALID_OWNERSHIP_RESULT', 'The repository must create the planned ownership record in this estate.');
      }
      const auditEvent = Object.freeze({
        ...plan.auditEvent,
        targetType: 'ownership_interest',
        targetId: ownership.id,
      });
      await appendAuditEvent(tx, auditEvent);
      return Object.freeze({ ownershipId: ownership.id, estateId, propertyId, verificationStatus: ownership.verificationStatus });
    });
  };
}

module.exports = { OwnershipCreationUseCaseError, createOwnershipInterestUseCase };
