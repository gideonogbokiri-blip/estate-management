const { toMinorUnits, fromMinorUnits } = require('../billing/money');
const { deriveExpensePaymentStatus, ExpenseStatus } = require('./expense');
const { BudgetStatus } = require('./budget');

class BudgetListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'BudgetListError';
    this.code = code;
  }
}

const eligibleExpenseStatuses = new Set([ExpenseStatus.APPROVED, ExpenseStatus.PARTIALLY_PAID, ExpenseStatus.PAID]);
const projectionFields = new Set(['name', 'approvedAt']);

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function projectBudget(row, estateId, businessDate) {
  const budget = row?.budget;
  if (!budget?.id || String(budget.estateId) !== String(estateId) || budget.status !== BudgetStatus.APPROVED
    || !Array.isArray(budget.lines) || !budget.lines.length || budget.lines.length > 100
    || typeof budget.currency !== 'string' || !/^[A-Z]{3}$/.test(budget.currency)
    || !Number.isInteger(budget.currencyScale) || budget.currencyScale < 0 || budget.currencyScale > 6
    || !validDate(budget.periodStart) || !validDate(budget.periodEnd) || budget.periodEnd <= budget.periodStart
    || !row?.lineExpenses || typeof row.lineExpenses !== 'object' || Array.isArray(row.lineExpenses)) {
    throw new BudgetListError('INVALID_BUDGET_RESULT', 'The repository returned an invalid or unapproved budget.');
  }
  const projection = row.projection;
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || typeof projection.name !== 'string' || !projection.name.trim() || projection.name.length > 120
    || projection.name !== budget.name
    || (projection.approvedAt !== null && projection.approvedAt !== undefined
      && (typeof projection.approvedAt !== 'string' || Number.isNaN(Date.parse(projection.approvedAt))))) {
    throw new BudgetListError('INVALID_PROJECTION', 'Budget display fields must be safe and match the approved budget record.');
  }
  const lineIds = new Set();
  const seenExpenseIds = new Set();
  let budgetMinor = 0n;
  let committedMinor = 0n;
  let paidMinor = 0n;
  const lines = budget.lines.map((line) => {
    const lineKey = line?.id ?? line?.categoryId;
    if (!lineKey || (line.budgetId && String(line.budgetId) !== String(budget.id))
      || (line.estateId && String(line.estateId) !== String(estateId))
      || line.currency !== budget.currency || line.name === undefined || typeof line.name !== 'string'
      || !line.name.trim() || line.name.length > 120 || typeof line.categoryName !== 'string'
      || !line.categoryName.trim() || line.categoryName.length > 80 || lineIds.has(String(lineKey))) {
      throw new BudgetListError('INVALID_BUDGET_LINE', 'Budget lines must be unique and belong to the approved budget and estate.');
    }
    lineIds.add(String(lineKey));
    let allocatedMinor;
    try { allocatedMinor = toMinorUnits(line.amount, budget.currencyScale); } catch {
      throw new BudgetListError('INVALID_BUDGET_AMOUNT', 'Budget lines must use exact decimal values at configured currency precision.');
    }
    if (allocatedMinor <= 0n) throw new BudgetListError('INVALID_BUDGET_AMOUNT', 'Budget line amounts must be positive.');
    budgetMinor += allocatedMinor;
    const expenses = row.lineExpenses[String(lineKey)] ?? [];
    if (!Array.isArray(expenses)) throw new BudgetListError('INVALID_EXPENSE_USAGE', 'Budget line expenses must be a list.');
    let lineCommittedMinor = 0n;
    let linePaidMinor = 0n;
    const expenseIds = new Set();
    for (const entry of expenses) {
      const expense = entry?.expense;
      if (!expense?.id || expenseIds.has(String(expense.id)) || seenExpenseIds.has(String(expense.id)) || String(expense.estateId) !== String(estateId)
        || String(expense.budgetId) !== String(budget.id) || String(expense.budgetLineId) !== String(lineKey)
        || expense.currency !== budget.currency || expense.currencyScale !== budget.currencyScale
        || !Object.values(ExpenseStatus).includes(expense.status)) {
        throw new BudgetListError('INVALID_EXPENSE_USAGE', 'Budget usage records must match the estate, budget and line.');
      }
      expenseIds.add(String(expense.id));
      seenExpenseIds.add(String(expense.id));
      const allocations = entry.allocations;
      if (!eligibleExpenseStatuses.has(expense.status)) {
        if (Array.isArray(allocations) && allocations.some((allocation) => allocation?.state === 'applied')) {
          throw new BudgetListError('INVALID_EXPENSE_PAYMENT', 'Unapproved expenses cannot contribute paid or committed budget usage.');
        }
        continue;
      }
      if (!Array.isArray(allocations) || allocations.some((allocation) => !allocation
        || String(allocation.expenseId) !== String(expense.id) || allocation.currency !== budget.currency
        || !['applied', 'reversed'].includes(allocation.state))) {
        throw new BudgetListError('INVALID_EXPENSE_USAGE', 'Expense allocations must belong to the linked budget expense and currency.');
      }
      try {
        lineCommittedMinor += toMinorUnits(expense.amount, budget.currencyScale);
        const payment = deriveExpensePaymentStatus(expense, allocations);
        linePaidMinor += toMinorUnits(payment.paidAmount, budget.currencyScale);
      } catch {
        throw new BudgetListError('INVALID_EXPENSE_PAYMENT', 'Budget paid amounts must reconcile to verified allocation history.');
      }
    }
    committedMinor += lineCommittedMinor;
    paidMinor += linePaidMinor;
    return Object.freeze({
      id: lineKey,
      name: line.name,
      categoryName: line.categoryName,
      allocated: fromMinorUnits(allocatedMinor, budget.currencyScale),
      committed: fromMinorUnits(lineCommittedMinor, budget.currencyScale),
      paid: fromMinorUnits(linePaidMinor, budget.currencyScale),
      available: fromMinorUnits(allocatedMinor - lineCommittedMinor, budget.currencyScale),
      currency: budget.currency,
      currencyScale: budget.currencyScale,
    });
  });
  if (Object.keys(row.lineExpenses).some((key) => !lineIds.has(String(key)))) {
    throw new BudgetListError('INVALID_EXPENSE_USAGE', 'Budget usage contains an unknown line key.');
  }
  const recomputedBudgetMinor = budget.lines.reduce((sum, line) => sum + toMinorUnits(line.amount, budget.currencyScale), 0n);
  if (budget.total !== fromMinorUnits(recomputedBudgetMinor, budget.currencyScale) || recomputedBudgetMinor !== budgetMinor) {
    throw new BudgetListError('BUDGET_TOTAL_MISMATCH', 'Budget total must reconcile exactly to its immutable line snapshots.');
  }
  return Object.freeze({
    id: budget.id, estateId,
    name: projection.name,
    status: budget.status,
    periodStart: budget.periodStart,
    periodEnd: budget.periodEnd,
    approvedAt: projection.approvedAt ?? null,
    effective: budget.periodStart <= businessDate && businessDate <= budget.periodEnd,
    currency: budget.currency,
    currencyScale: budget.currencyScale,
    total: fromMinorUnits(budgetMinor, budget.currencyScale),
    committed: fromMinorUnits(committedMinor, budget.currencyScale),
    paid: fromMinorUnits(paidMinor, budget.currencyScale),
    available: fromMinorUnits(budgetMinor - committedMinor, budget.currencyScale),
    lines: Object.freeze(lines),
  });
}

function createEstateBudgetListUseCase({ transaction, requireEstatePermission, resolveEstateBusinessDate, queryApprovedBudgets, queryBudgetLineExpenses } = {}) {
  const ports = { transaction, requireEstatePermission, resolveEstateBusinessDate, queryApprovedBudgets, queryBudgetLineExpenses };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new BudgetListError('MISSING_ADAPTER', `Budget list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateBudgets({ actorUserId, estateId } = {}) {
    if (!actorUserId || !estateId) throw new BudgetListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'finance.budget.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new BudgetListError('ESTATE_ACCESS_DENIED', 'The actor cannot view budgets in this estate.');
      }
      const businessDate = await resolveEstateBusinessDate(tx, { actorUserId, estateContext });
      if (!validDate(businessDate)) throw new BudgetListError('INVALID_BUSINESS_DATE', 'The estate finance date must be a valid calendar date.');
      // The repository bounds and scopes approved versions by estate before returning their immutable line snapshots.
      const rows = await queryApprovedBudgets(tx, { actorUserId, estateContext, limit: 24 });
      if (!Array.isArray(rows) || rows.length > 24) throw new BudgetListError('INVALID_REPOSITORY_RESULT', 'Budget query must return at most 24 approved versions.');
      const seen = new Set();
      const items = [];
      for (const row of rows) {
        const budgetId = String(row?.budget?.id ?? '');
        if (!budgetId || seen.has(budgetId)) throw new BudgetListError('INVALID_REPOSITORY_RESULT', 'Budget query returned a missing or duplicate version.');
        seen.add(budgetId);
        const lineIds = row.budget.lines.map((line) => String(line.id ?? line.categoryId));
        const lineExpenses = await queryBudgetLineExpenses(tx, { actorUserId, estateContext, budget: row.budget, lineIds });
        items.push(projectBudget({ ...row, lineExpenses }, estateId, businessDate));
      }
      items.sort((left, right) => Number(right.effective) - Number(left.effective)
        || right.periodStart.localeCompare(left.periodStart)
        || String(right.approvedAt ?? '').localeCompare(String(left.approvedAt ?? '')));
      return Object.freeze({ items: Object.freeze(items) });
    });
  };
}

module.exports = { BudgetListError, createEstateBudgetListUseCase, projectBudget };
