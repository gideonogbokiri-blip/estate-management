const StructureNodeStatus = Object.freeze({ ACTIVE: 'active', ARCHIVED: 'archived' });
const StructureNodeTypes = Object.freeze(['zone', 'street', 'building', 'floor']);

class StructureError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StructureError';
    this.code = code;
  }
}

function hasId(value) {
  return (typeof value === 'string' && value.trim() !== '')
    || (typeof value === 'number' && Number.isFinite(value));
}

function validateStructureNodeDraft(input, { estateId, parents, policy } = {}) {
  const { type, name, code, parentIds = [], buildingType, floorCount, sortOrder } = input ?? {};
  if (!hasId(estateId) || !StructureNodeTypes.includes(type)) {
    throw new StructureError('INVALID_STRUCTURE_NODE', 'Choose a supported structure type in the selected estate.');
  }
  if (!policy || !Array.isArray(policy.allowedTypes) || !policy.parentTypesByType || !policy.codeRequiredByType
    || typeof policy.codeRequiredByType !== 'object') {
    throw new StructureError('STRUCTURE_POLICY_REQUIRED', 'Load trusted structure configuration for this estate.');
  }
  if (!policy.allowedTypes.includes(type)) {
    throw new StructureError('STRUCTURE_TYPE_DISABLED', 'This structure type is not enabled for the estate.');
  }
  if (typeof name !== 'string' || !name.trim() || name.trim().length > 120) {
    throw new StructureError('INVALID_STRUCTURE_NAME', 'Enter a structure name of 1 to 120 characters.');
  }
  const codeRequired = policy.codeRequiredByType[type] === true;
  if (codeRequired && (typeof code !== 'string' || !code.trim())) {
    throw new StructureError('STRUCTURE_CODE_REQUIRED', 'A code is required for this structure type.');
  }
  if (code !== undefined && code !== null && (typeof code !== 'string' || code.trim().length > 60)) {
    throw new StructureError('INVALID_STRUCTURE_CODE', 'Structure codes must be text no longer than 60 characters.');
  }
  if (!Array.isArray(parentIds) || !Array.isArray(parents)) {
    throw new StructureError('INVALID_STRUCTURE_PARENTS', 'Structure parents must be supplied as a list.');
  }
  if (new Set(parentIds.map(String)).size !== parentIds.length || parents.length !== parentIds.length) {
    throw new StructureError('INVALID_STRUCTURE_PARENTS', 'Each selected parent must resolve exactly once in this estate.');
  }
  if (parents.some((parent) => parent.estateId !== estateId || parent.status !== StructureNodeStatus.ACTIVE)) {
    throw new StructureError('CROSS_ESTATE_STRUCTURE_PARENT', 'Structure parents must be active and belong to the selected estate.');
  }
  if (parentIds.some((id) => !parents.some((parent) => parent.id === id))) {
    throw new StructureError('STRUCTURE_PARENT_NOT_FOUND', 'One or more selected parents are not available in this estate.');
  }
  const allowedParentTypes = policy.parentTypesByType[type];
  if (!Array.isArray(allowedParentTypes)) {
    throw new StructureError('STRUCTURE_POLICY_REQUIRED', `Configure valid parents for ${type} nodes.`);
  }
  if (parents.some((parent) => !allowedParentTypes.includes(parent.type))) {
    throw new StructureError('INVALID_STRUCTURE_PARENT_TYPE', 'A selected parent type is not allowed for this structure node.');
  }
  if (policy.parentRequiredByType?.[type] === true && parents.length === 0) {
    throw new StructureError('STRUCTURE_PARENT_REQUIRED', 'Select a parent structure for this node.');
  }
  if (type === 'building' && buildingType !== undefined && buildingType !== null
    && (typeof buildingType !== 'string' || !buildingType.trim())) {
    throw new StructureError('INVALID_BUILDING_TYPE', 'Building type must be non-empty text.');
  }
  if (type === 'building' && floorCount !== undefined && floorCount !== null
    && (!Number.isInteger(floorCount) || floorCount < 1 || floorCount > 300)) {
    throw new StructureError('INVALID_FLOOR_COUNT', 'Floor count must be a whole number between 1 and 300.');
  }
  if (sortOrder !== undefined && (!Number.isInteger(sortOrder) || sortOrder < 0)) {
    throw new StructureError('INVALID_SORT_ORDER', 'Sort order must be a non-negative whole number.');
  }
  return Object.freeze({
    estateId,
    type,
    name: name.trim(),
    code: typeof code === 'string' ? code.trim() || null : null,
    parentIds: Object.freeze(parentIds.slice()),
    buildingType: type === 'building' ? buildingType?.trim() || null : null,
    floorCount: type === 'building' ? floorCount ?? null : null,
    sortOrder: sortOrder ?? 0,
    status: StructureNodeStatus.ACTIVE,
  });
}

function planStructureNodeArchive(node, { actorUserId, now, blockingRelationships } = {}) {
  if (!node?.id || !hasId(node.estateId) || !StructureNodeTypes.includes(node.type)) {
    throw new StructureError('INVALID_STRUCTURE_NODE', 'A persisted structure node is required.');
  }
  if (!hasId(actorUserId) || now === undefined || now === null || Number.isNaN(new Date(now).getTime())) {
    throw new StructureError('INVALID_ACTOR_OR_TIMESTAMP', 'An authenticated actor and valid archive timestamp are required.');
  }
  if (node.status !== StructureNodeStatus.ACTIVE) {
    throw new StructureError('INVALID_STRUCTURE_STATE', 'Only an active structure node can be archived.');
  }
  if (!Array.isArray(blockingRelationships)) {
    throw new StructureError('RELATIONSHIP_CHECK_REQUIRED', 'Check child nodes and properties before archiving.');
  }
  if (blockingRelationships.length) {
    throw new StructureError('ACTIVE_STRUCTURE_RELATIONSHIPS', 'Move or archive child nodes and properties before archiving this structure node.');
  }
  const archivedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    nodeId: node.id,
    estateId: node.estateId,
    status: StructureNodeStatus.ARCHIVED,
    archivedAt,
    actorUserId,
    effects: Object.freeze([Object.freeze({
      type: 'estate_structure_node.archived', nodeId: node.id, estateId: node.estateId,
      nodeType: node.type, from: node.status, to: StructureNodeStatus.ARCHIVED, actorUserId, archivedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId, scope: 'estate', estateId: node.estateId, action: 'estate_structure_node.archive',
      targetType: 'estate_structure_node', targetId: node.id, outcome: 'success', occurredAt: archivedAt,
    }),
  });
}

module.exports = { StructureError, StructureNodeStatus, StructureNodeTypes, planStructureNodeArchive, validateStructureNodeDraft };
