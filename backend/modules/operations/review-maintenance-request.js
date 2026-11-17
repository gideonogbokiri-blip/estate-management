const {
  MaintenanceCommand,
  planMaintenanceAssignment,
  planMaintenanceTransition,
  planMaintenanceUpdate,
} = require('./maintenance');

class MaintenanceReviewError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MaintenanceReviewError';
    this.code = code;
  }
}

const commandPermission = Object.freeze({
  [MaintenanceCommand.REVIEW]: 'maintenance.review',
  [MaintenanceCommand.ASSIGN]: 'maintenance.assign',
  [MaintenanceCommand.START]: 'maintenance.update',
  [MaintenanceCommand.AWAIT_PARTS]: 'maintenance.update',
  [MaintenanceCommand.RESUME]: 'maintenance.update',
  [MaintenanceCommand.RESOLVE]: 'maintenance.resolve',
  [MaintenanceCommand.CLOSE]: 'maintenance.close',
  [MaintenanceCommand.REJECT]: 'maintenance.reject',
  [MaintenanceCommand.REOPEN]: 'maintenance.reopen',
});

function createMaintenanceRequestReviewUseCase({
  transaction,
  requireEstatePermission,
  findRequestForUpdate,
  findAssignableStaffMember,
  commitMaintenanceReview,
  appendAuditEvent,
  enqueueResidentNotice,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findRequestForUpdate, findAssignableStaffMember,
    commitMaintenanceReview, appendAuditEvent, enqueueResidentNotice };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MaintenanceReviewError('MISSING_ADAPTER', `Maintenance review adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new MaintenanceReviewError('INVALID_CLOCK', 'A clock function is required.');

  return async function reviewMaintenanceRequest({
    actorUserId, estateId, requestId, command = null, reason = '', resolutionSummary = '',
    assigneeUserId = null, residentUpdate = '', internalNote = '',
  } = {}) {
    if (!actorUserId || !estateId || !requestId
      || (command !== null && !Object.values(MaintenanceCommand).includes(command))) {
      throw new MaintenanceReviewError('INVALID_REVIEW_INPUT', 'Actor, estate, request and a supported command are required.');
    }
    for (const [value, label, limit] of [[reason, 'Reason', 300], [resolutionSummary, 'Resolution', 700],
      [residentUpdate, 'Resident update', 700], [internalNote, 'Internal note', 700]]) {
      if (typeof value !== 'string' || value.length > limit) {
        throw new MaintenanceReviewError('INVALID_REVIEW_INPUT', `${label} must be no more than ${limit} characters.`);
      }
    }
    if (assigneeUserId !== null && (typeof assigneeUserId !== 'string' || !assigneeUserId.trim())) {
      throw new MaintenanceReviewError('INVALID_ASSIGNEE', 'Choose an active staff member in this estate.');
    }
    if (command === null && !assigneeUserId && !residentUpdate.trim() && !internalNote.trim()) {
      throw new MaintenanceReviewError('EMPTY_REVIEW', 'Provide a status change, assignment or update.');
    }

    return transaction(async (tx) => {
      const requiredPermissions = new Set();
      if (command) requiredPermissions.add(commandPermission[command]);
      if (assigneeUserId && command !== MaintenanceCommand.ASSIGN) requiredPermissions.add('maintenance.assign');
      if (residentUpdate.trim()) requiredPermissions.add('maintenance.update');
      if (internalNote.trim()) requiredPermissions.add('maintenance.note_internal');
      if (!requiredPermissions.size) throw new MaintenanceReviewError('EMPTY_REVIEW', 'Provide an authorized maintenance action.');

      let estateContext = null;
      for (const permission of requiredPermissions) {
        const context = await requireEstatePermission(actorUserId, estateId, permission, tx);
        if (!context || context.estateId !== estateId) {
          throw new MaintenanceReviewError('PERMISSION_DENIED', `The actor cannot perform ${permission} in this estate.`);
        }
        estateContext = context;
      }

      const request = await findRequestForUpdate(tx, { requestId, estateContext });
      if (!request || request.estateId !== estateId || String(request.id) !== String(requestId)) {
        throw new MaintenanceReviewError('REQUEST_NOT_FOUND', 'The maintenance request was not found in this estate.');
      }
      const now = clock();
      let assignee = null;
      if (assigneeUserId) {
        assignee = await findAssignableStaffMember(tx, { userId: assigneeUserId, estateContext });
        if (!assignee || assignee.estateId !== estateId || assignee.status !== 'active'
          || String(assignee.userId) !== String(assigneeUserId)) {
          throw new MaintenanceReviewError('INVALID_ASSIGNEE', 'The selected assignee is not an active member of this estate.');
        }
      }

      let transitionPlan = null;
      if (command) transitionPlan = planMaintenanceTransition(request, {
        command, actorUserId, now, reason, resolutionSummary,
        assignee: command === MaintenanceCommand.ASSIGN ? assignee : undefined,
        mayReopen: requiredPermissions.has('maintenance.reopen'),
      });
      let assignmentPlan = null;
      if (assigneeUserId && command !== MaintenanceCommand.ASSIGN) {
        assignmentPlan = planMaintenanceAssignment(request, { actorUserId, now, reason, assignee });
      }
      const updatePlans = [];
      if (residentUpdate.trim()) updatePlans.push(planMaintenanceUpdate(request, {
        actorUserId, now, body: residentUpdate, visibility: 'resident_visible',
      }));
      if (internalNote.trim()) updatePlans.push(planMaintenanceUpdate(request, {
        actorUserId, now, body: internalNote, visibility: 'internal', mayAddInternalNote: true,
      }));

      const plan = Object.freeze({ estateId, requestId: request.id, transitionPlan, assignmentPlan,
        updatePlans: Object.freeze(updatePlans) });
      const updated = await commitMaintenanceReview(tx, { estateContext, request, plan });
      if (!updated || String(updated.id) !== String(request.id) || updated.estateId !== estateId) {
        throw new MaintenanceReviewError('INVALID_COMMIT_RESULT', 'The maintenance repository did not confirm the review update.');
      }
      for (const event of [transitionPlan?.auditEvent, assignmentPlan?.auditEvent, ...updatePlans.map((entry) => entry.auditEvent)].filter(Boolean)) {
        await appendAuditEvent(tx, event);
      }
      if (residentUpdate.trim() || transitionPlan || assignmentPlan) {
        await enqueueResidentNotice(tx, {
          estateId,
          requestId: request.id,
          status: updated.status ?? transitionPlan?.nextStatus ?? request.status,
          residentUpdate: residentUpdate.trim() || null,
          resolutionSummary: transitionPlan?.effects.find((effect) => effect.resolutionSummary)?.resolutionSummary ?? null,
        });
      }
      return Object.freeze({ requestId: request.id, estateId, status: updated.status ?? transitionPlan?.nextStatus ?? request.status,
        assigneeUserId: updated.assigneeUserId ?? assigneeUserId ?? request.assigneeUserId ?? null,
        updatedAt: updated.updatedAt ?? null });
    });
  };
}

module.exports = { MaintenanceReviewError, createMaintenanceRequestReviewUseCase };
