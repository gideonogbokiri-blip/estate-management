const { StructureNodeStatus, planStructureNodeArchive } = require('./structure');
const { StructureUseCaseError } = require('./manage-estate-structure');

function createEstateStructureNodeArchiveUseCase({
  transaction,
  requireEstatePermission,
  findStructureNodeForUpdate,
  inspectStructureRelationships,
  commitStructureNodeArchive,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findStructureNodeForUpdate, inspectStructureRelationships, commitStructureNodeArchive, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, value]) => typeof value !== 'function').map(([name]) => name);
  if (missing.length) throw new StructureUseCaseError('MISSING_ADAPTER', `Estate structure archive adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new StructureUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function archiveEstateStructureNode({ actorUserId, estateId, nodeId } = {}) {
    if (!actorUserId || !estateId || !nodeId) throw new StructureUseCaseError('INVALID_INPUT', 'Actor, estate, and structure node are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'structure.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new StructureUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage structure in this estate.');
      const node = await findStructureNodeForUpdate(tx, { nodeId, estateContext });
      if (!node || node.estateId !== estateId) throw new StructureUseCaseError('STRUCTURE_NODE_NOT_FOUND', 'The structure node was not found.');
      const relationshipCheck = await inspectStructureRelationships(tx, { node, estateContext });
      if (!relationshipCheck || relationshipCheck.complete !== true || !Array.isArray(relationshipCheck.blockingRelationships)) {
        throw new StructureUseCaseError('RELATIONSHIP_CHECK_INCOMPLETE', 'All child structure nodes and properties must be checked before archiving.');
      }
      const plan = planStructureNodeArchive(node, {
        actorUserId,
        now: clock(),
        blockingRelationships: relationshipCheck.blockingRelationships,
      });
      const archived = await commitStructureNodeArchive(tx, plan, { estateContext });
      if (!archived || archived.id !== node.id || archived.estateId !== estateId || archived.status !== StructureNodeStatus.ARCHIVED) {
        throw new StructureUseCaseError('INVALID_RESULT', 'The repository must archive the node without deleting its history.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ nodeId, estateId, status: StructureNodeStatus.ARCHIVED });
    });
  };
}

module.exports = { createEstateStructureNodeArchiveUseCase };
