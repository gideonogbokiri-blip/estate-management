const { StructureNodeStatus, validateStructureNodeDraft } = require('./structure');
const { StructureUseCaseError } = require('./manage-estate-structure');

const mutableFields = new Set(['name', 'code', 'parentIds', 'buildingType', 'floorCount', 'sortOrder']);

function createEstateStructureNodeUpdateUseCase({
  transaction,
  requireEstatePermission,
  findStructureNodeForUpdate,
  loadStructurePolicy,
  findStructureParents,
  isStructureCodeAvailable,
  validateChildCompatibility,
  commitStructureNodeUpdate,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findStructureNodeForUpdate, loadStructurePolicy, findStructureParents, isStructureCodeAvailable, validateChildCompatibility, commitStructureNodeUpdate, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, value]) => typeof value !== 'function').map(([name]) => name);
  if (missing.length) throw new StructureUseCaseError('MISSING_ADAPTER', `Estate structure update adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new StructureUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function updateEstateStructureNode({ actorUserId, estateId, nodeId, changes } = {}) {
    if (!actorUserId || !estateId || !nodeId || !changes || typeof changes !== 'object' || Array.isArray(changes)) {
      throw new StructureUseCaseError('INVALID_INPUT', 'Actor, estate, structure node, and update fields are required.');
    }
    const unsupported = Object.keys(changes).filter((field) => !mutableFields.has(field));
    if (unsupported.length) throw new StructureUseCaseError('IMMUTABLE_STRUCTURE_FIELD', 'Structure estate, type, status, and system fields cannot be changed here.');
    if (changes.parentIds !== undefined && !Array.isArray(changes.parentIds)) throw new StructureUseCaseError('INVALID_INPUT', 'Structure parent IDs must be supplied as a list.');

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'structure.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new StructureUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage structure in this estate.');
      const current = await findStructureNodeForUpdate(tx, { nodeId, estateContext });
      if (!current || current.estateId !== estateId) throw new StructureUseCaseError('STRUCTURE_NODE_NOT_FOUND', 'The structure node was not found.');
      if (current.status !== StructureNodeStatus.ACTIVE) throw new StructureUseCaseError('INVALID_STRUCTURE_STATE', 'Only an active structure node can be updated.');

      const policy = await loadStructurePolicy(tx, { estateContext });
      const parentIds = changes.parentIds ?? current.parentIds ?? [];
      const parents = await findStructureParents(tx, { parentIds, estateContext });
      const draft = validateStructureNodeDraft({ ...current, ...changes, type: current.type, parentIds }, { estateId, parents, policy });
      if (draft.code !== null && draft.code !== current.code) {
        const available = await isStructureCodeAvailable(tx, { estateId, type: draft.type, code: draft.code, excludeNodeId: current.id, estateContext });
        if (available !== true) throw new StructureUseCaseError('STRUCTURE_CODE_UNAVAILABLE', 'This structure code is already in use or could not be verified.');
      }
      const childCheck = await validateChildCompatibility(tx, { node: current, proposed: draft, estateContext });
      if (!childCheck || childCheck.complete !== true || childCheck.compatible !== true) {
        throw new StructureUseCaseError('INCOMPATIBLE_CHILDREN', 'The change conflicts with existing child nodes or attached properties.');
      }
      const updatedAtDate = new Date(clock());
      if (Number.isNaN(updatedAtDate.getTime())) throw new StructureUseCaseError('INVALID_TIMESTAMP', 'A valid structure update timestamp is required.');
      const updatedAt = updatedAtDate.toISOString();
      const updated = await commitStructureNodeUpdate(tx, { nodeId: current.id, estateId, changes: draft, actorUserId, updatedAt }, { estateContext });
      if (!updated || updated.id !== current.id || updated.estateId !== estateId || updated.type !== current.type
        || updated.status !== current.status || updated.name !== draft.name || updated.code !== draft.code) {
        throw new StructureUseCaseError('INVALID_RESULT', 'The repository must apply the validated structure update.');
      }
      await appendAuditEvent(tx, {
        actorUserId, scope: 'estate', estateId, action: 'estate_structure_node.updated',
        targetType: 'estate_structure_node', targetId: current.id, outcome: 'success', occurredAt: updatedAt,
        metadata: Object.freeze({ changedFields: Object.freeze(Object.keys(changes).sort()) }),
      });
      return Object.freeze({ nodeId: updated.id, estateId, type: updated.type, status: updated.status });
    });
  };
}

module.exports = { createEstateStructureNodeUpdateUseCase };
