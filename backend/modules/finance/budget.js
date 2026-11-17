const { fromMinorUnits, normalizeDecimal, toMinorUnits } = require('../billing/money');

const BudgetStatus = Object.freeze({ DRAFT: 'draft', PENDING_APPROVAL: 'pending_approval', APPROVED: 'approved', REJECTED: 'rejected' });

class BudgetError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'BudgetError';
    this.code = code;
  }
}

function isDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function prepareBudgetDraft(input, categories, now, priorBudget) {
  const { estateId, name, periodStart, periodEnd, currency, currencyScale, lines, createdByUserId } = input ?? {};
  const createdAtMs = now === undefined || now === null ? null : new Date(now).getTime();
  if (!estateId || typeof name !== 'string' || !name.trim() || !createdByUserId
    || !isDate(periodStart) || !isDate(periodEnd) || periodEnd <= periodStart) {
    throw new BudgetError('INVALID_BUDGET', 'Estate, budget name, creator and valid period are required.');
  }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
    throw new BudgetError('INVALID_CURRENCY', 'Currency must be a three-letter uppercase code.');
  }
  if (createdAtMs === null || Number.isNaN(createdAtMs)) {
    throw new BudgetError('INVALID_TIMESTAMP', 'A valid budget creation time is required.');
  }
  if (priorBudget && (!priorBudget.id || priorBudget.estateId !== estateId
    || priorBudget.status !== BudgetStatus.APPROVED || priorBudget.periodStart !== periodStart
    || priorBudget.periodEnd !== periodEnd || priorBudget.currency !== currency)) {
    throw new BudgetError('INVALID_BUDGET_REVISION', 'A budget revision must link an approved same-estate version for the same period and currency.');
  }
  if (!Array.isArray(lines) || lines.length === 0) {
    throw new BudgetError('EMPTY_BUDGET', 'A budget must contain at least one line.');
  }

  const lineIds = new Set();
  const lineSnapshots = lines.map((line) => {
    const category = (Array.isArray(categories) ? categories : []).find((candidate) =>
      candidate?.id === line?.categoryId && candidate.estateId === estateId && candidate.status === 'active',
    );
    if (!category || typeof line.name !== 'string' || !line.name.trim()) {
      throw new BudgetError('INVALID_BUDGET_LINE', 'Each line needs an active same-estate category and name.');
    }
    if (lineIds.has(category.id)) {
      throw new BudgetError('DUPLICATE_BUDGET_CATEGORY', 'Budget categories can appear only once per version.');
    }
    lineIds.add(category.id);
    const amount = normalizeDecimal(line.amount, currencyScale);
    if (toMinorUnits(amount, currencyScale) <= 0n) {
      throw new BudgetError('INVALID_BUDGET_AMOUNT', 'Budget line amounts must be greater than zero.');
    }
    return Object.freeze({ categoryId: category.id, categoryName: category.name, name: line.name.trim(), amount, currency });
  });
  const totalMinor = lineSnapshots.reduce((sum, line) => sum + toMinorUnits(line.amount, currencyScale), 0n);

  return Object.freeze({
    estateId,
    name: name.trim(),
    periodStart,
    periodEnd,
    currency,
    currencyScale,
    lines: Object.freeze(lineSnapshots),
    total: fromMinorUnits(totalMinor, currencyScale),
    status: BudgetStatus.DRAFT,
    approvalStageIndex: 0,
    approvalHistory: Object.freeze([]),
    supersedesBudgetId: priorBudget?.id ?? null,
    createdByUserId,
    createdAt: new Date(createdAtMs).toISOString(),
  });
}

function planBudgetSubmission(budget, { actorUserId, now, approvalPolicy } = {}) {
  const submittedAtMs = now === undefined || now === null ? null : new Date(now).getTime();
  if (!budget?.estateId || budget.status !== BudgetStatus.DRAFT) {
    throw new BudgetError('INVALID_STATE', 'Only a draft budget can be submitted.');
  }
  if (!actorUserId || submittedAtMs === null || Number.isNaN(submittedAtMs)
    || !approvalPolicy?.version || !Array.isArray(approvalPolicy.stages) || approvalPolicy.stages.length === 0) {
    throw new BudgetError('APPROVAL_POLICY_REQUIRED', 'A valid actor, timestamp and configured approval policy are required.');
  }

  const submittedAt = new Date(submittedAtMs).toISOString();
  return Object.freeze({
    transactionRequired: true,
    budgetId: budget.id ?? null,
    estateId: budget.estateId,
    nextStatus: BudgetStatus.PENDING_APPROVAL,
    effects: Object.freeze([Object.freeze({
      type: 'budget.submitted',
      budgetId: budget.id ?? null,
      estateId: budget.estateId,
      from: BudgetStatus.DRAFT,
      to: BudgetStatus.PENDING_APPROVAL,
      approvalPolicyVersion: approvalPolicy.version,
      approvalStageIndex: 0,
      submittedByUserId: actorUserId,
      submittedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: budget.estateId,
      action: 'budget.submit',
      targetType: 'budget',
      targetId: budget.id ?? null,
      outcome: 'success',
      occurredAt: submittedAt,
    }),
  });
}

function planBudgetDecision(budget, input) {
  if (!budget?.id || !budget.estateId || budget.status !== BudgetStatus.PENDING_APPROVAL) {
    throw new BudgetError('INVALID_STATE', 'Only a pending budget can receive an approval decision.');
  }
  const { decision, actorUserId, now, reason, approvalPolicy, actorPermissions } = input ?? {};
  const timestamp = now === undefined || now === null ? null : new Date(now).getTime();
  if (!actorUserId || timestamp === null || Number.isNaN(timestamp)
    || !['approve', 'reject'].includes(decision)) {
    throw new BudgetError('INVALID_DECISION', 'An authorized actor, timestamp and approve/reject decision are required.');
  }
  if (!approvalPolicy?.version || approvalPolicy.version !== budget.approvalPolicyVersion
    || !Array.isArray(approvalPolicy.stages)) {
    throw new BudgetError('APPROVAL_POLICY_CHANGED', 'Budget approval policy changed; resubmit for review.');
  }
  const stage = approvalPolicy.stages[budget.approvalStageIndex];
  if (!stage || typeof stage.permission !== 'string' || !Array.isArray(actorPermissions)
    || !actorPermissions.includes(stage.permission)) {
    throw new BudgetError('PERMISSION_DENIED', 'The actor cannot decide this budget approval stage.');
  }
  if (decision === 'approve' && approvalPolicy.preventRequesterApproval === true
    && budget.submittedByUserId === actorUserId) {
    throw new BudgetError('SEGREGATION_OF_DUTIES', 'The budget requester cannot approve their own submission.');
  }
  if (approvalPolicy.requireDistinctApprovers === true
    && (budget.approvalHistory ?? []).some((record) => record.actorUserId === actorUserId)) {
    throw new BudgetError('DISTINCT_APPROVER_REQUIRED', 'A different authorized approver is required for this stage.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (decision === 'reject' && !normalizedReason) {
    throw new BudgetError('REASON_REQUIRED', 'A reason is required to reject a budget.');
  }

  const decidedAt = new Date(timestamp).toISOString();
  const nextStatus = decision === 'reject' ? BudgetStatus.REJECTED
    : budget.approvalStageIndex + 1 >= approvalPolicy.stages.length ? BudgetStatus.APPROVED
      : BudgetStatus.PENDING_APPROVAL;
  const nextStageIndex = decision === 'approve' ? budget.approvalStageIndex + 1 : budget.approvalStageIndex;
  const approval = Object.freeze({
    stageIndex: budget.approvalStageIndex,
    actorUserId,
    decision,
    permission: stage.permission,
    reason: normalizedReason || null,
    decidedAt,
  });

  return Object.freeze({
    transactionRequired: true,
    budgetId: budget.id,
    estateId: budget.estateId,
    nextStatus,
    nextStageIndex,
    effects: Object.freeze([Object.freeze({
      type: 'budget.approval_recorded',
      budgetId: budget.id,
      estateId: budget.estateId,
      approval,
      nextStatus,
      nextStageIndex,
      finalApproval: nextStatus === BudgetStatus.APPROVED,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: budget.estateId,
      action: `budget.${decision}`,
      targetType: 'budget',
      targetId: budget.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: decidedAt,
    }),
  });
}

module.exports = { BudgetError, BudgetStatus, planBudgetDecision, planBudgetSubmission, prepareBudgetDraft };
