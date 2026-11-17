const { StructureNodeStatus, StructureNodeTypes, validateStructureNodeDraft } = require('./structure');

class StructureUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StructureUseCaseError';
    this.code = code;
  }
}

function requirePorts(ports) {
  const missing = Object.entries(ports).filter(([, value]) => typeof value !== 'function').map(([name]) => name);
  if (missing.length) throw new StructureUseCaseError('MISSING_ADAPTER', `Estate structure adapters are required: ${missing.join(', ')}.`);
}

function createEstateStructureNodeUseCase({
  transaction,
  requireEstatePermission,
  loadStructurePolicy,
  findStructureParents,
  isStructureCodeAvailable,
  createStructureNode,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  requirePorts({ transaction, requireEstatePermission, loadStructurePolicy, findStructureParents, isStructureCodeAvailable, createStructureNode, appendAuditEvent });
  if (typeof clock !== 'function') throw new StructureUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function createEstateStructureNode({ actorUserId, estateId, nodeDraft } = {}) {
    if (!actorUserId || !estateId || !nodeDraft || typeof nodeDraft !== 'object' || Array.isArray(nodeDraft)) {
      throw new StructureUseCaseError('INVALID_INPUT', 'Actor, estate, and structure node details are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'structure.manage', tx);
      if (!estateContext || estateContext.estateId !== estateId) throw new StructureUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot manage structure in this estate.');
      if (nodeDraft.parentIds !== undefined && !Array.isArray(nodeDraft.parentIds)) {
        throw new StructureUseCaseError('INVALID_INPUT', 'Structure parent IDs must be supplied as a list.');
      }
      const policy = await loadStructurePolicy(tx, { estateContext });
      const requestedParentIds = nodeDraft.parentIds ?? [];
      const parents = await findStructureParents(tx, { parentIds: requestedParentIds, estateContext });
      const draft = validateStructureNodeDraft({ ...nodeDraft, parentIds: requestedParentIds }, { estateId, parents, policy });
      if (draft.code !== null) {
        const available = await isStructureCodeAvailable(tx, { estateId, type: draft.type, code: draft.code, estateContext });
        if (available !== true) throw new StructureUseCaseError('STRUCTURE_CODE_UNAVAILABLE', 'This structure code is already in use or could not be verified.');
      }
      const createdAtDate = new Date(clock());
      if (Number.isNaN(createdAtDate.getTime())) throw new StructureUseCaseError('INVALID_TIMESTAMP', 'A valid structure creation timestamp is required.');
      const createdAt = createdAtDate.toISOString();
      const node = await createStructureNode(tx, { ...draft, createdByUserId: actorUserId, createdAt }, { estateContext });
      if (!node?.id || node.estateId !== estateId || node.type !== draft.type || node.name !== draft.name
        || node.status !== StructureNodeStatus.ACTIVE) {
        throw new StructureUseCaseError('INVALID_RESULT', 'The repository must create the validated structure node in this estate.');
      }
      await appendAuditEvent(tx, {
        actorUserId, scope: 'estate', estateId, action: 'estate_structure_node.created',
        targetType: 'estate_structure_node', targetId: node.id, outcome: 'success', occurredAt: createdAt,
      });
      return Object.freeze({ nodeId: node.id, estateId, type: node.type, status: node.status });
    });
  };
}

function createEstateStructureListUseCase({ transaction, requireEstatePermission, listStructureNodes } = {}) {
  requirePorts({ transaction, requireEstatePermission, listStructureNodes });
  return async function listEstateStructure({ actorUserId, estateId, includeArchived = false } = {}) {
    if (!actorUserId || !estateId || typeof includeArchived !== 'boolean') throw new StructureUseCaseError('INVALID_INPUT', 'Actor, estate, and valid structure-list options are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'structure.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) throw new StructureUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot view structure in this estate.');
      const nodes = await listStructureNodes(tx, { estateContext, includeArchived });
      if (!Array.isArray(nodes)) throw new StructureUseCaseError('INVALID_RESULT', 'The structure repository must return a list.');
      const seen = new Set();
      const safeNodes = nodes.map((node) => {
        if (!node?.id || String(node.estateId) !== String(estateId) || !StructureNodeTypes.includes(node.type)
          || ![StructureNodeStatus.ACTIVE, StructureNodeStatus.ARCHIVED].includes(node.status)
          || (!includeArchived && node.status !== StructureNodeStatus.ACTIVE)
          || typeof node.name !== 'string' || !node.name.trim() || node.name.length > 120
          || (node.code !== null && node.code !== undefined && (typeof node.code !== 'string' || node.code.length > 60))
          || (node.parentId !== null && node.parentId !== undefined && !['string', 'number'].includes(typeof node.parentId))
          || (node.linkedPropertyCount !== undefined && (!Number.isSafeInteger(node.linkedPropertyCount) || node.linkedPropertyCount < 0))) {
          throw new StructureUseCaseError('INVALID_RESULT', 'Structure records must have valid same-estate identity and display values.');
        }
        const key = String(node.id);
        if (seen.has(key)) throw new StructureUseCaseError('DUPLICATE_RESULT', 'The structure repository returned a duplicate node.');
        seen.add(key);
        return node;
      });
      const byId = new Map(safeNodes.map((node) => [String(node.id), node]));
      const items = safeNodes.map((node) => {
        const parent = node.parentId === null || node.parentId === undefined ? null : byId.get(String(node.parentId));
        if (node.parentId !== null && node.parentId !== undefined && !parent && node.status === StructureNodeStatus.ACTIVE) {
          throw new StructureUseCaseError('INVALID_PARENT_RESULT', 'An active structure node cannot reference a missing parent in the authorized estate.');
        }
        if (node.status === StructureNodeStatus.ACTIVE && parent?.status !== undefined && parent.status !== StructureNodeStatus.ACTIVE) {
          throw new StructureUseCaseError('INVALID_PARENT_RESULT', 'An active structure node cannot have an archived parent.');
        }
        return Object.freeze({
          id: node.id,
          estateId,
          type: node.type,
          name: node.name,
          code: node.code ?? null,
          parentId: node.parentId ?? null,
          parentName: parent?.name ?? null,
          linkedPropertyCount: node.linkedPropertyCount ?? null,
          status: node.status,
        });
      });
      return Object.freeze({
        items: Object.freeze(items),
        activeCount: items.filter((node) => node.status === StructureNodeStatus.ACTIVE).length,
        total: items.length,
      });
    });
  };
}

module.exports = { StructureUseCaseError, createEstateStructureListUseCase, createEstateStructureNodeUseCase };
