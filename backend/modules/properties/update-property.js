'use strict';

const { PropertyStatus, validatePropertyDraft } = require('./property');

const mutableFields = new Set([
  'code',
  'propertyType',
  'status',
  'unitNumber',
  'address',
  'description',
  'parentIds',
]);

class PropertyUpdateUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PropertyUpdateUseCaseError';
    this.code = code;
  }
}

function createPropertyUpdateUseCase({
  transaction,
  requireEstatePermission,
  findPropertyForUpdate,
  findPropertyParents,
  isPropertyCodeAvailable,
  commitPropertyUpdate,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findPropertyForUpdate,
    findPropertyParents,
    isPropertyCodeAvailable,
    commitPropertyUpdate,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, value]) => typeof value !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new PropertyUpdateUseCaseError(
      'MISSING_ADAPTER',
      `Property update adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new PropertyUpdateUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function updateProperty({ actorUserId, estateId, propertyId, changes } = {}) {
    if (!actorUserId || !estateId || !propertyId
      || !changes || typeof changes !== 'object' || Array.isArray(changes)
      || Object.keys(changes).length === 0) {
      throw new PropertyUpdateUseCaseError(
        'INVALID_INPUT',
        'Actor, estate, property and at least one property change are required.',
      );
    }
    const unsupported = Object.keys(changes).filter((field) => !mutableFields.has(field));
    if (unsupported.length) {
      throw new PropertyUpdateUseCaseError(
        'IMMUTABLE_PROPERTY_FIELD',
        'Estate, ownership, occupancy, archive and system fields cannot be changed here.',
      );
    }
    if (changes.parentIds !== undefined && !Array.isArray(changes.parentIds)) {
      throw new PropertyUpdateUseCaseError('INVALID_HIERARCHY', 'Parent IDs must be supplied as a list.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(
        actorUserId,
        estateId,
        'property.manage',
        tx,
      );
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new PropertyUpdateUseCaseError(
          'ESTATE_ACCESS_DENIED',
          'The actor cannot manage properties in this estate.',
        );
      }

      const current = await findPropertyForUpdate(tx, { propertyId, estateContext });
      if (!current || String(current.estateId) !== String(estateId)) {
        throw new PropertyUpdateUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found.');
      }
      if (current.status === PropertyStatus.ARCHIVED) {
        throw new PropertyUpdateUseCaseError('PROPERTY_ARCHIVED', 'Archived properties cannot be edited.');
      }

      const parentIds = changes.parentIds === undefined
        ? current.parentIds
        : changes.parentIds;
      if (!Array.isArray(parentIds)) {
        throw new PropertyUpdateUseCaseError(
          'HIERARCHY_CHECK_REQUIRED',
          'The locked property record must include its current hierarchy before editing.',
        );
      }
      const parents = await findPropertyParents(tx, { parentIds, estateContext });
      if (!Array.isArray(parents) || parents.length !== parentIds.length
        || parents.some((parent) => String(parent.estateId) !== String(estateId) || parent.status !== 'active')
        || new Set(parents.map((parent) => String(parent.id))).size !== parentIds.length
        || parentIds.some((id) => !parents.some((parent) => String(parent.id) === String(id)))) {
        throw new PropertyUpdateUseCaseError(
          'HIERARCHY_NOT_FOUND',
          'One or more active hierarchy nodes were not found in this estate.',
        );
      }

      const draft = validatePropertyDraft({
        ...current,
        ...changes,
        estateId,
        parents,
      });
      if (draft.status === PropertyStatus.ARCHIVED) {
        throw new PropertyUpdateUseCaseError(
          'INVALID_PROPERTY_STATUS',
          'Use the archive workflow to archive a property.',
        );
      }

      if (draft.code.toLocaleLowerCase('en') !== String(current.code).toLocaleLowerCase('en')) {
        const codeAvailable = await isPropertyCodeAvailable(tx, {
          estateId,
          code: draft.code,
          excludePropertyId: current.id,
          estateContext,
        });
        if (codeAvailable !== true) {
          throw new PropertyUpdateUseCaseError(
            'PROPERTY_CODE_UNAVAILABLE',
            'This property code is already in use or could not be verified.',
          );
        }
      }

      const updatedAtDate = new Date(clock());
      if (Number.isNaN(updatedAtDate.getTime())) {
        throw new PropertyUpdateUseCaseError('INVALID_TIMESTAMP', 'A valid property update timestamp is required.');
      }
      const updatedAt = updatedAtDate.toISOString();
      const updated = await commitPropertyUpdate(tx, {
        propertyId: current.id,
        estateId,
        changes: draft,
        actorUserId,
        updatedAt,
      }, { estateContext });
      if (!updated || String(updated.id) !== String(current.id)
        || String(updated.estateId) !== String(estateId)
        || updated.status !== draft.status || updated.code !== draft.code
        || updated.propertyType !== draft.propertyType) {
        throw new PropertyUpdateUseCaseError(
          'INVALID_RESULT',
          'The repository must apply the validated property update in this estate.',
        );
      }

      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'property.updated',
        targetType: 'property',
        targetId: current.id,
        outcome: 'success',
        occurredAt: updatedAt,
        metadata: Object.freeze({
          changedFields: Object.freeze(Object.keys(changes).sort()),
        }),
      });
      return Object.freeze({ propertyId: current.id, estateId, status: updated.status });
    });
  };
}

module.exports = { PropertyUpdateUseCaseError, createPropertyUpdateUseCase };
