const { fromMinorUnits, normalizeDecimal, toMinorUnits } = require('../billing/money');

const ExpenseStatus = Object.freeze({
  DRAFT: 'draft',
  PENDING_APPROVAL: 'pending_approval',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
  PARTIALLY_PAID: 'partially_paid',
  PAID: 'paid',
});

class ExpenseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ExpenseError';
    this.code = code;
  }
}

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function prepareExpenseDraft(input, context) {
  const {
    estateId,
    requesterUserId,
    description,
    categoryId,
    payeeReference,
    amount,
    currency,
    currencyScale,
    neededBy,
    budgetId,
    budgetLineId,
    attachmentIds = [],
  } = input ?? {};
  if (!estateId || estateId !== context?.estateId || !requesterUserId
    || context.mayRequestExpense !== true) {
    throw new ExpenseError('PERMISSION_DENIED', 'Expense request permission and matching estate context are required.');
  }
  if (typeof description !== 'string' || !description.trim()
    || typeof payeeReference !== 'string' || !payeeReference.trim()) {
    throw new ExpenseError('INVALID_EXPENSE', 'Description and payee reference are required.');
  }
  const category = (context.categories ?? []).find((candidate) =>
    candidate.id === categoryId && candidate.estateId === estateId && candidate.status === 'active',
  );
  if (!category) throw new ExpenseError('INVALID_CATEGORY', 'Choose an active expense category in this estate.');
  if (budgetLineId && !(context.budgetLines ?? []).some((line) =>
    line.id === budgetLineId && line.budgetId === budgetId
      && line.estateId === estateId && line.currency === currency,
  )) {
    throw new ExpenseError('INVALID_BUDGET_LINE', 'Budget line must belong to this estate and match the expense currency.');
  }
  if (budgetLineId && !budgetId) {
    throw new ExpenseError('INVALID_BUDGET_LINE', 'A budget is required when a budget line is selected.');
  }
  if (!Array.isArray(attachmentIds) || new Set(attachmentIds).size !== attachmentIds.length
    || attachmentIds.some((id) => !(context.authorizedAttachmentIds ?? []).includes(id))) {
    throw new ExpenseError('INVALID_ATTACHMENT', 'Attachments must be authorized private files for this estate.');
  }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
    throw new ExpenseError('INVALID_CURRENCY', 'Currency must be a three-letter uppercase code.');
  }
  const normalizedAmount = normalizeDecimal(amount, currencyScale);
  if (toMinorUnits(normalizedAmount, currencyScale) <= 0n) {
    throw new ExpenseError('INVALID_AMOUNT', 'Expense amount must be greater than zero.');
  }
  if (neededBy !== undefined && neededBy !== null && parseInstant(neededBy) === null) {
    throw new ExpenseError('INVALID_NEEDED_BY', 'Provide a valid needed-by date.');
  }
  const createdAtMs = parseInstant(context.now);
  if (createdAtMs === null) throw new ExpenseError('INVALID_TIMESTAMP', 'A valid creation time is required.');

  return Object.freeze({
    estateId,
    requesterUserId,
    description: description.trim(),
    categoryId: category.id,
    categoryName: category.name,
    payeeReference: payeeReference.trim(),
    amount: normalizedAmount,
    currency,
    currencyScale,
    neededBy: neededBy ? new Date(neededBy).toISOString() : null,
    budgetId: budgetId ?? null,
    budgetLineId: budgetLineId ?? null,
    attachmentIds: Object.freeze([...attachmentIds]),
    status: ExpenseStatus.DRAFT,
    approvalHistory: Object.freeze([]),
    createdAt: new Date(createdAtMs).toISOString(),
  });
}

function planExpenseSubmission(expense, input) {
  if (!expense?.estateId || expense.status !== ExpenseStatus.DRAFT) {
    throw new ExpenseError('INVALID_STATE', 'Only a draft expense can be submitted.');
  }
  const { actorUserId, now, approvalPolicy } = input ?? {};
  const submittedAtMs = parseInstant(now);
  if (!actorUserId || actorUserId !== expense.requesterUserId || submittedAtMs === null
    || !approvalPolicy?.version || !Array.isArray(approvalPolicy.stages) || approvalPolicy.stages.length === 0) {
    throw new ExpenseError('APPROVAL_POLICY_REQUIRED', 'The requester, timestamp and configured approval stages are required.');
  }
  if (expense.budgetLineId) {
    const budget = input?.budget;
    if (!budget || budget.id !== expense.budgetId || budget.estateId !== expense.estateId
      || budget.currency !== expense.currency || budget.status !== 'approved'
      || !(budget.lines ?? []).some((line) => line.id === expense.budgetLineId
        && line.budgetId === budget.id && line.estateId === budget.estateId)) {
      throw new ExpenseError('INVALID_BUDGET_SCOPE', 'Selected budget line must be approved and belong to this estate and currency.');
    }
  } else if (expense.budgetId) {
    throw new ExpenseError('INVALID_BUDGET_LINE', 'Select a budget line or omit the budget reference.');
  }

  const submittedAt = new Date(submittedAtMs).toISOString();
  return Object.freeze({
    transactionRequired: true,
    expenseId: expense.id ?? null,
    estateId: expense.estateId,
    nextStatus: ExpenseStatus.PENDING_APPROVAL,
    nextStageIndex: 0,
    effects: Object.freeze([Object.freeze({
      type: 'expense.submitted',
      expenseId: expense.id ?? null,
      estateId: expense.estateId,
      from: ExpenseStatus.DRAFT,
      to: ExpenseStatus.PENDING_APPROVAL,
      approvalPolicyVersion: approvalPolicy.version,
      approvalStageIndex: 0,
      submittedByUserId: actorUserId,
      submittedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: expense.estateId,
      action: 'expense.submit',
      targetType: 'expense',
      targetId: expense.id ?? null,
      outcome: 'success',
      occurredAt: submittedAt,
    }),
  });
}

function planExpenseDecision(expense, input) {
  if (!expense?.id || !expense.estateId || expense.status !== ExpenseStatus.PENDING_APPROVAL) {
    throw new ExpenseError('INVALID_STATE', 'Only a pending expense can receive an approval decision.');
  }
  const { decision, actorUserId, now, reason, approvalPolicy, actorPermissions, budget, budgetRemaining, paymentDestination } = input ?? {};
  const timestamp = parseInstant(now);
  if (!actorUserId || timestamp === null || !['approve', 'reject'].includes(decision)) {
    throw new ExpenseError('INVALID_DECISION', 'An authorized actor, timestamp and approve/reject decision are required.');
  }
  if (!approvalPolicy?.version || approvalPolicy.version !== expense.approvalPolicyVersion
    || !Array.isArray(approvalPolicy.stages)) {
    throw new ExpenseError('APPROVAL_POLICY_CHANGED', 'Expense approval policy changed; resubmit for review.');
  }
  const stage = approvalPolicy.stages[expense.approvalStageIndex];
  if (!stage || typeof stage.permission !== 'string' || !Array.isArray(actorPermissions)
    || !actorPermissions.includes(stage.permission)) {
    throw new ExpenseError('PERMISSION_DENIED', 'The actor cannot decide this expense approval stage.');
  }
  if (decision === 'approve' && approvalPolicy.preventRequesterApproval === true
    && expense.requesterUserId === actorUserId) {
    throw new ExpenseError('SEGREGATION_OF_DUTIES', 'The requester cannot approve their own expense.');
  }
  if (approvalPolicy.requireDistinctApprovers === true
    && (expense.approvalHistory ?? []).some((record) => record.actorUserId === actorUserId)) {
    throw new ExpenseError('DISTINCT_APPROVER_REQUIRED', 'A different authorized approver is required for this stage.');
  }

  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (decision === 'reject' && !normalizedReason) {
    throw new ExpenseError('REASON_REQUIRED', 'A reason is required to reject an expense.');
  }
  const amountMinor = toMinorUnits(expense.amount, expense.currencyScale);
  if (decision === 'approve' && stage.maximumAmount !== undefined && stage.maximumAmount !== null
    && amountMinor > toMinorUnits(stage.maximumAmount, expense.currencyScale)) {
    throw new ExpenseError('APPROVAL_LIMIT_EXCEEDED', 'The current approval stage cannot approve this amount.');
  }

  const decidedAt = new Date(timestamp).toISOString();
  const nextStageIndex = decision === 'approve' ? expense.approvalStageIndex + 1 : expense.approvalStageIndex;
  let nextStatus = decision === 'reject' ? ExpenseStatus.REJECTED
    : nextStageIndex >= approvalPolicy.stages.length ? ExpenseStatus.APPROVED
      : ExpenseStatus.PENDING_APPROVAL;
  const effects = [{
    type: 'expense.approval_recorded',
    expenseId: expense.id,
    estateId: expense.estateId,
    stageIndex: expense.approvalStageIndex,
    actorUserId,
    decision,
    permission: stage.permission,
    reason: normalizedReason || null,
    decidedAt,
    nextStageIndex,
    nextStatus,
  }];

  if (decision === 'approve' && nextStatus === ExpenseStatus.APPROVED) {
    if (!paymentDestination?.verified || paymentDestination.estateId !== expense.estateId
      || paymentDestination.payeeReference !== expense.payeeReference
      || paymentDestination.currency !== expense.currency
      || typeof paymentDestination.destinationReference !== 'string'
      || !paymentDestination.destinationReference) {
      throw new ExpenseError('PAYEE_NOT_VERIFIED', 'Verify a same-estate payee and payment destination before final approval.');
    }
    effects.push({
      type: 'expense.payment_destination_snapshotted',
      expenseId: expense.id,
      estateId: expense.estateId,
      payeeReference: expense.payeeReference,
      destinationReference: paymentDestination.destinationReference,
      currency: expense.currency,
    });
    if (expense.budgetLineId) {
      if (!budget || budget.id !== expense.budgetId || budget.estateId !== expense.estateId
        || budget.currency !== expense.currency || budget.status !== 'approved'
        || !(budget.lines ?? []).some((line) => line.id === expense.budgetLineId
          && line.budgetId === budget.id && line.estateId === budget.estateId)
        || typeof budgetRemaining !== 'string') {
        throw new ExpenseError('INVALID_BUDGET', 'An approved same-estate budget and current remaining amount are required.');
      }
      if (amountMinor > toMinorUnits(budgetRemaining, expense.currencyScale)) {
        if (approvalPolicy.allowOverBudget !== true) {
          throw new ExpenseError('BUDGET_EXCEEDED', 'The expense exceeds the available budget.');
        }
      }
      if (approvalPolicy.reserveBudgetOnApproval === true) {
        effects.push({
          type: 'budget.reservation.create',
          budgetId: budget.id,
          budgetLineId: expense.budgetLineId,
          expenseId: expense.id,
          estateId: expense.estateId,
          amount: expense.amount,
          currency: expense.currency,
        });
      }
    } else if (approvalPolicy.allowUnbudgeted !== true) {
      throw new ExpenseError('BUDGET_REQUIRED', 'Policy requires a budget line before approval.');
    }
  }

  return Object.freeze({
    transactionRequired: true,
    expenseId: expense.id,
    estateId: expense.estateId,
    nextStatus,
    nextStageIndex,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: expense.estateId,
      action: `expense.${decision}`,
      targetType: 'expense',
      targetId: expense.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: decidedAt,
    }),
  });
}

function deriveExpensePaymentStatus(expense, allocations) {
  if (!expense?.id || !Array.isArray(allocations)) {
    throw new ExpenseError('INVALID_PAYMENT_HISTORY', 'Expense and trusted payment allocation history are required.');
  }
  if (![ExpenseStatus.APPROVED, ExpenseStatus.PARTIALLY_PAID, ExpenseStatus.PAID].includes(expense.status)) {
    throw new ExpenseError('EXPENSE_NOT_PAYABLE', 'Only approved expenses can receive payment allocations.');
  }
  const totalMinor = toMinorUnits(expense.amount, expense.currencyScale);
  const paidMinor = allocations.reduce((sum, allocation) => {
    if (!allocation || allocation.expenseId !== expense.id || allocation.currency !== expense.currency
      || !['applied', 'reversed'].includes(allocation.state)) {
      throw new ExpenseError('INVALID_PAYMENT_ALLOCATION', 'Allocations must be scoped to this expense and currency.');
    }
    if (allocation.state === 'reversed') return sum;
    if (allocation.paymentState !== 'succeeded' || !allocation.paymentVerifiedAt) {
      throw new ExpenseError('UNVERIFIED_PAYMENT', 'Only verified payment allocations count as paid.');
    }
    return sum + toMinorUnits(allocation.amount, expense.currencyScale);
  }, 0n);
  if (paidMinor > totalMinor) throw new ExpenseError('OVERPAID_EXPENSE', 'Verified allocations exceed the approved expense.');
  return Object.freeze({
    status: paidMinor === 0n ? ExpenseStatus.APPROVED
      : paidMinor === totalMinor ? ExpenseStatus.PAID : ExpenseStatus.PARTIALLY_PAID,
    approvedAmount: expense.amount,
    paidAmount: fromMinorUnits(paidMinor, expense.currencyScale),
    outstandingAmount: fromMinorUnits(totalMinor - paidMinor, expense.currencyScale),
    currency: expense.currency,
  });
}

function planExpensePaymentAllocation(input) {
  const {
    expense,
    payment,
    amount,
    expenseAllocations,
    paymentAllocations,
    idempotencyKey,
    actorUserId,
    now,
  } = input ?? {};
  const timestamp = parseInstant(now);
  if (!expense?.id || !expense.estateId || !payment?.id || !actorUserId || timestamp === null) {
    throw new ExpenseError('INVALID_ALLOCATION', 'Expense, trusted payment, actor and timestamp are required.');
  }
  if (expense.status !== ExpenseStatus.APPROVED && expense.status !== ExpenseStatus.PARTIALLY_PAID) {
    throw new ExpenseError('EXPENSE_NOT_PAYABLE', 'Only an approved expense with an outstanding balance can receive payment.');
  }
  if (payment.state !== 'succeeded' || !payment.verifiedAt || !payment.providerTransactionId
    || payment.currency !== expense.currency
    || payment.destinationReference !== expense.paymentDestinationReference) {
    throw new ExpenseError('PAYMENT_NOT_VERIFIED', 'Payment must be verified and match the expense destination and currency.');
  }
  if (typeof idempotencyKey !== 'string' || !idempotencyKey.trim()
    || !Array.isArray(expenseAllocations) || !Array.isArray(paymentAllocations)) {
    throw new ExpenseError('ALLOCATION_HISTORY_REQUIRED', 'An idempotency key and scoped allocation history are required.');
  }

  const scale = expense.currencyScale;
  const allocationMinor = toMinorUnits(amount, scale);
  if (allocationMinor <= 0n) throw new ExpenseError('INVALID_ALLOCATION_AMOUNT', 'Allocation must be greater than zero.');
  const sumFor = (allocations, scopeField, scopeId) => allocations.reduce((sum, allocation) => {
    if (!allocation || allocation[scopeField] !== scopeId || allocation.currency !== expense.currency
      || !['applied', 'reversed'].includes(allocation.state)) {
      throw new ExpenseError('INVALID_PAYMENT_ALLOCATION', 'Allocation history must be scoped to the target and currency.');
    }
    if (allocation.state === 'applied'
      && (allocation.paymentState !== 'succeeded' || !allocation.paymentVerifiedAt)) {
      throw new ExpenseError('UNVERIFIED_PAYMENT', 'Only verified payment allocations can be committed.');
    }
    return allocation.state === 'applied' ? sum + toMinorUnits(allocation.amount, scale) : sum;
  }, 0n);
  const expenseTotal = toMinorUnits(expense.amount, scale);
  const expenseAllocated = sumFor(expenseAllocations, 'expenseId', expense.id);
  const paymentTotal = toMinorUnits(payment.amount, scale);
  const paymentAllocated = sumFor(paymentAllocations, 'paymentId', payment.id);
  if (expenseAllocated > expenseTotal || paymentAllocated > paymentTotal) {
    throw new ExpenseError('OVERALLOCATED_BALANCE', 'Existing allocations exceed the approved expense or payment.');
  }
  if (allocationMinor > expenseTotal - expenseAllocated) {
    throw new ExpenseError('EXPENSE_OVERPAYMENT', 'Allocation exceeds the expense outstanding amount.');
  }
  if (allocationMinor > paymentTotal - paymentAllocated) {
    throw new ExpenseError('PAYMENT_OVERALLOCATION', 'Allocation exceeds the unallocated verified payment.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  const normalizedAmount = fromMinorUnits(allocationMinor, scale);
  return Object.freeze({
    transactionRequired: true,
    expenseId: expense.id,
    paymentId: payment.id,
    estateId: expense.estateId,
    amount: normalizedAmount,
    idempotencyKey: idempotencyKey.trim(),
    effects: Object.freeze([Object.freeze({
      type: 'expense_payment_allocation.create',
      expenseId: expense.id,
      paymentId: payment.id,
      estateId: expense.estateId,
      amount: normalizedAmount,
      currency: expense.currency,
      idempotencyKey: idempotencyKey.trim(),
      occurredAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: expense.estateId,
      action: 'expense.payment_allocated',
      targetType: 'expense',
      targetId: expense.id,
      outcome: 'success',
      occurredAt,
    }),
  });
}

module.exports = {
  ExpenseError,
  ExpenseStatus,
  deriveExpensePaymentStatus,
  planExpenseDecision,
  planExpensePaymentAllocation,
  planExpenseSubmission,
  prepareExpenseDraft,
};
