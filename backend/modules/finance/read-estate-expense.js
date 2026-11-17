const { ExpenseError, ExpenseStatus, deriveExpensePaymentStatus } = require('./expense');
const { toMinorUnits } = require('../billing/money');

class ExpenseReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ExpenseReadError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(ExpenseStatus));
const historyFields = new Set([
  'stageIndex', 'decision', 'actorDisplayName', 'permission', 'reason', 'decidedAt',
]);

function readInstant(value, name, optional = false) {
  if (value === null || value === undefined) {
    if (optional) return null;
    throw new ExpenseReadError('INVALID_PROJECTION', `${name} is required.`);
  }
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new ExpenseReadError('INVALID_PROJECTION', `${name} is invalid.`);
  }
  return new Date(Date.parse(value)).toISOString();
}

/** Read an actor-authorized expense detail and its immutable approval history. */
function readEstateExpenseUseCase({
  transaction,
  findExpense,
  resolveExpenseReadAccess,
  loadExpenseApprovalPolicy,
  loadExpenseAllocations,
  projectExpenseForActor,
  projectApprovalActor,
} = {}) {
  const ports = {
    transaction,
    findExpense,
    resolveExpenseReadAccess,
    loadExpenseApprovalPolicy,
    loadExpenseAllocations,
    projectExpenseForActor,
    projectApprovalActor,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new ExpenseReadError('MISSING_ADAPTER', `Expense detail adapters are required: ${missing.join(', ')}.`);
  }

  return async function readEstateExpense({ actorUserId, expenseId } = {}) {
    if (!actorUserId || !expenseId) {
      throw new ExpenseReadError('INVALID_INPUT', 'Authenticated actor and expense are required.');
    }
    return transaction(async (tx) => {
      const expense = await findExpense(tx, { actorUserId, expenseId });
      if (!expense?.id || String(expense.id) !== String(expenseId)
        || !expense.estateId || !statuses.has(expense.status)) {
        throw new ExpenseReadError('EXPENSE_NOT_FOUND', 'The expense was not found.');
      }
      const access = await resolveExpenseReadAccess(tx, { actorUserId, expense });
      if (!access || String(access.userId) !== String(actorUserId)
        || String(access.estateId) !== String(expense.estateId)
        || access.mayView !== true) {
        throw new ExpenseReadError('EXPENSE_NOT_FOUND', 'The expense was not found.');
      }
      const policy = await loadExpenseApprovalPolicy(tx, {
        actorUserId,
        estateId: expense.estateId,
        version: expense.approvalPolicyVersion,
      });
      if (!policy || policy.version !== expense.approvalPolicyVersion
        || !Array.isArray(policy.stages) || !Number.isInteger(expense.approvalStageIndex)
        || expense.approvalStageIndex < 0) {
        throw new ExpenseReadError('APPROVAL_HISTORY_UNAVAILABLE', 'The expense approval policy history is unavailable.');
      }
      const stage = policy.stages[expense.approvalStageIndex] ?? null;
      const projection = await projectExpenseForActor({ actorUserId, access, expense, tx });
      if (!projection || typeof projection !== 'object' || Array.isArray(projection)) {
        throw new ExpenseReadError('INVALID_PROJECTION', 'The expense detail projection is invalid.');
      }
      const history = expense.approvalHistory ?? [];
      if (!Array.isArray(history)) {
        throw new ExpenseReadError('INVALID_APPROVAL_HISTORY', 'Expense approval history must be a list.');
      }
      const decisions = [];
      for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (!entry || entry.estateId !== expense.estateId || entry.expenseId !== expense.id
          || !['approve', 'reject'].includes(entry.decision)
          || !Number.isInteger(entry.stageIndex) || entry.stageIndex < 0
          || !entry.actorUserId) {
          throw new ExpenseReadError('INVALID_APPROVAL_HISTORY', 'Approval history does not match this expense.');
        }
        const actor = await projectApprovalActor({ actorUserId, access, expense, entry, tx });
        if (!actor || typeof actor !== 'object' || Array.isArray(actor)
          || Object.keys(actor).some((field) => !historyFields.has(field))
          || actor.stageIndex !== entry.stageIndex || actor.decision !== entry.decision
          || actor.permission !== entry.permission || actor.reason !== (entry.reason ?? null)
          || actor.decidedAt !== entry.decidedAt) {
          throw new ExpenseReadError('INVALID_APPROVAL_HISTORY', 'Approval history contains unsafe or mismatched fields.');
        }
        if (typeof actor.actorDisplayName !== 'string' || !actor.actorDisplayName.trim()
          || actor.actorDisplayName.length > 160
          || (actor.reason !== null && (typeof actor.reason !== 'string' || actor.reason.length > 500))) {
          throw new ExpenseReadError('INVALID_APPROVAL_HISTORY', 'Approval history display fields are invalid.');
        }
        decisions.push(Object.freeze({
          stageIndex: actor.stageIndex,
          stageLabel: typeof policy.stages[entry.stageIndex]?.label === 'string'
            ? policy.stages[entry.stageIndex].label
            : `Approval stage ${entry.stageIndex + 1}`,
          decision: actor.decision,
          actorDisplayName: actor.actorDisplayName,
          permission: actor.permission,
          reason: actor.reason,
          decidedAt: readInstant(actor.decidedAt, 'decidedAt'),
        }));
      }

      const allocations = access.mayViewPaymentSummary === true
        ? await loadExpenseAllocations(tx, { actorUserId, access, expense })
        : [];
      if (!Array.isArray(allocations)) throw new ExpenseReadError('INVALID_ALLOCATIONS', 'Payment allocations must be a list.');
      let paymentSummary = null;
      if (access.mayViewPaymentSummary === true
        && [ExpenseStatus.APPROVED, ExpenseStatus.PARTIALLY_PAID, ExpenseStatus.PAID].includes(expense.status)) {
        try { paymentSummary = deriveExpensePaymentStatus(expense, allocations); } catch {
          throw new ExpenseReadError('INVALID_PAYMENT_HISTORY', 'Expense payments do not reconcile to trusted allocations.');
        }
      }
      const allowed = new Set([
        'reference', 'description', 'categoryName', 'requesterDisplayName', 'payeeLabel',
        'amount', 'currency', 'requestedAt', 'neededBy', 'budgetLineName', 'requesterNote',
      ]);
      if (Object.keys(projection).some((field) => !allowed.has(field))
        || projection.description !== expense.description
        || projection.categoryName !== expense.categoryName
        || projection.amount !== expense.amount || projection.currency !== expense.currency
        || projection.requestedAt !== (expense.submittedAt ?? expense.createdAt)) {
        throw new ExpenseReadError('INVALID_PROJECTION', 'Expense detail fields do not match the source request.');
      }
      const displayText = (value, name, max, required = true) => {
        if (value === null || value === undefined) {
          if (!required) return null;
          throw new ExpenseReadError('INVALID_PROJECTION', `${name} is required.`);
        }
        if (typeof value !== 'string' || value.length > max || (required && !value.trim())) {
          throw new ExpenseReadError('INVALID_PROJECTION', `${name} is invalid.`);
        }
        return value;
      };
      try { toMinorUnits(projection.amount, expense.currencyScale); } catch {
        throw new ExpenseReadError('INVALID_PROJECTION', 'Expense amount is invalid.');
      }
      if (typeof projection.currency !== 'string' || !/^[A-Z]{3}$/.test(projection.currency)
        || projection.currency !== expense.currency
        || !Number.isInteger(expense.currencyScale) || expense.currencyScale < 0 || expense.currencyScale > 6) {
        throw new ExpenseReadError('INVALID_PROJECTION', 'Expense currency is invalid.');
      }
      displayText(projection.reference, 'reference', 100);
      displayText(projection.requesterDisplayName, 'requesterDisplayName', 160);
      displayText(projection.payeeLabel, 'payeeLabel', 160);
      displayText(projection.budgetLineName, 'budgetLineName', 120, false);
      displayText(projection.requesterNote, 'requesterNote', 1000, false);
      return Object.freeze({
        id: String(expense.id),
        estateId: String(expense.estateId),
        status: expense.status,
        approvalPolicyVersion: expense.approvalPolicyVersion ?? null,
        currentStageIndex: stage ? expense.approvalStageIndex : null,
        currentStageLabel: stage
          ? (typeof stage.label === 'string' && stage.label.trim()
              ? stage.label
              : `Approval stage ${expense.approvalStageIndex + 1}`)
          : null,
        stageCount: policy.stages.length,
        requesterNote: projection.requesterNote ?? null,
        paymentSummary,
        request: Object.freeze({
          reference: displayText(projection.reference, 'reference', 100),
          description: projection.description,
          category: projection.categoryName,
          requesterName: displayText(projection.requesterDisplayName, 'requesterDisplayName', 160),
          payeeName: displayText(projection.payeeLabel, 'payeeLabel', 160),
          amount: projection.amount,
          currency: projection.currency,
          requestedAt: readInstant(projection.requestedAt, 'requestedAt'),
          neededBy: readInstant(projection.neededBy, 'neededBy', true),
          budgetLineName: displayText(projection.budgetLineName, 'budgetLineName', 120, false),
        }),
        approvalHistory: Object.freeze(decisions),
      });
    }).catch((error) => {
      if (error instanceof ExpenseReadError) throw error;
      if (error instanceof ExpenseError) throw new ExpenseReadError(error.code, error.message);
      throw error;
    });
  };
}

module.exports = { ExpenseReadError, readEstateExpenseUseCase };
