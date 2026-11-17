const { ExpenseError, ExpenseStatus, planExpenseDecision } = require('./expense');

class ExpenseDecisionUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ExpenseDecisionUseCaseError';
    this.code = code;
  }
}

/** Apply an estate expense approval stage without creating a payment. */
function decideExpenseRequestUseCase({
  transaction,
  findExpenseForUpdate,
  loadExpenseApprovalPolicy,
  requireEstatePermission,
  loadBudgetForUpdate,
  calculateBudgetRemaining,
  loadVerifiedPaymentDestination,
  commitExpenseDecision,
  appendAuditEvent,
  enqueueExpenseDecisionNotice,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    findExpenseForUpdate,
    loadExpenseApprovalPolicy,
    requireEstatePermission,
    loadBudgetForUpdate,
    calculateBudgetRemaining,
    loadVerifiedPaymentDestination,
    commitExpenseDecision,
    appendAuditEvent,
    enqueueExpenseDecisionNotice,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new ExpenseDecisionUseCaseError(
      'MISSING_ADAPTER',
      `Expense decision adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new ExpenseDecisionUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function decideExpenseRequest({
    actorUserId,
    estateId,
    expenseId,
    decision,
    reason = '',
  } = {}) {
    if (!actorUserId || !estateId || !expenseId
      || !['approve', 'reject'].includes(decision)
      || typeof reason !== 'string' || reason.length > 500) {
      throw new ExpenseDecisionUseCaseError(
        'INVALID_INPUT',
        'Actor, estate, expense and a supported decision are required; notes must be 500 characters or fewer.',
      );
    }
    return transaction(async (tx) => {
      const expense = await findExpenseForUpdate(tx, { actorUserId, estateId, expenseId });
      if (!expense || String(expense.id) !== String(expenseId)
        || String(expense.estateId) !== String(estateId)) {
        throw new ExpenseDecisionUseCaseError(
          'EXPENSE_NOT_FOUND',
          'The expense request was not found in this estate.',
        );
      }
      const approvalPolicy = await loadExpenseApprovalPolicy(tx, { estateId, expense });
      if (!approvalPolicy?.version || approvalPolicy.version !== expense.approvalPolicyVersion
        || !Array.isArray(approvalPolicy.stages)) {
        throw new ExpenseDecisionUseCaseError(
          'APPROVAL_POLICY_CHANGED',
          'The approval policy changed. Reload the request before deciding.',
        );
      }
      const stage = approvalPolicy.stages[expense.approvalStageIndex];
      if (!stage || typeof stage.permission !== 'string' || !stage.permission.trim()) {
        throw new ExpenseDecisionUseCaseError(
          'INVALID_APPROVAL_STAGE',
          'The current approval stage is not configured.',
        );
      }
      const permission = await requireEstatePermission(
        actorUserId,
        estateId,
        stage.permission,
        tx,
      );
      if (!permission || String(permission.estateId) !== String(estateId)) {
        throw new ExpenseDecisionUseCaseError(
          'PERMISSION_DENIED',
          'The actor cannot decide this expense at the current approval stage.',
        );
      }
      const actorPermissions = [stage.permission];
      let budget = null;
      let budgetRemaining = null;
      let paymentDestination = null;
      const finalApproval = decision === 'approve'
        && expense.approvalStageIndex + 1 >= approvalPolicy.stages.length;
      if (finalApproval) {
        paymentDestination = await loadVerifiedPaymentDestination(tx, {
          actorUserId,
          estateId,
          expense,
        });
        if (expense.budgetId) {
          budget = await loadBudgetForUpdate(tx, {
            actorUserId,
            estateId,
            expense,
          });
          if (!budget || String(budget.id) !== String(expense.budgetId)
            || String(budget.estateId) !== String(estateId)) {
            throw new ExpenseDecisionUseCaseError(
              'BUDGET_NOT_FOUND',
              'The linked approved budget was not found in this estate.',
            );
          }
          budgetRemaining = await calculateBudgetRemaining(tx, {
            actorUserId,
            estateId,
            expense,
            budget,
          });
          if (typeof budgetRemaining !== 'string') {
            throw new ExpenseDecisionUseCaseError(
              'INVALID_BUDGET_BALANCE',
              'A current budget balance could not be verified.',
            );
          }
        }
      }
      const now = clock();
      if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
        throw new ExpenseDecisionUseCaseError('INVALID_CLOCK', 'A valid decision timestamp is required.');
      }
      const plan = planExpenseDecision(expense, {
        actorUserId,
        decision,
        reason,
        now,
        approvalPolicy,
        actorPermissions,
        budget,
        budgetRemaining,
        paymentDestination,
      });
      const committed = await commitExpenseDecision(tx, {
        actorUserId,
        estateId,
        expenseId,
        expectedStatus: ExpenseStatus.PENDING_APPROVAL,
        expectedVersion: expense.version ?? 1,
        nextStatus: plan.nextStatus,
        nextStageIndex: plan.nextStageIndex,
        effects: plan.effects,
        approvalPolicyVersion: approvalPolicy.version,
      });
      if (!committed || String(committed.id) !== String(expenseId)
        || String(committed.estateId) !== String(estateId)
        || committed.status !== plan.nextStatus
        || committed.approvalStageIndex !== plan.nextStageIndex) {
        throw new ExpenseDecisionUseCaseError(
          'CONCURRENT_DECISION',
          'This expense changed while the decision was being recorded. Reload the request.',
        );
      }
      await appendAuditEvent(tx, plan.auditEvent);
      await enqueueExpenseDecisionNotice(tx, {
        estateId,
        expenseId,
        requesterUserId: expense.requesterUserId,
        decision,
        nextStatus: plan.nextStatus,
        stageIndex: expense.approvalStageIndex,
      });
      return Object.freeze({
        expenseId,
        estateId,
        decision,
        status: plan.nextStatus,
        approvalStageIndex: plan.nextStageIndex,
        decidedAt: plan.auditEvent.occurredAt,
      });
    }).catch((error) => {
      if (error instanceof ExpenseDecisionUseCaseError) throw error;
      if (error instanceof ExpenseError) {
        throw new ExpenseDecisionUseCaseError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = { ExpenseDecisionUseCaseError, decideExpenseRequestUseCase };
