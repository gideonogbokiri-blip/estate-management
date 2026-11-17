const { deriveExpensePaymentStatus, ExpenseStatus } = require('./expense');
const { toMinorUnits } = require('../billing/money');

class ExpenseListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ExpenseListError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(ExpenseStatus));
const decisions = new Set(['approve', 'reject']);
const projectionFields = new Set([
  'reference', 'description', 'categoryName', 'requesterDisplayName', 'payeeLabel',
  'budgetLineName', 'neededBy', 'requestedAt', 'allowedCommands',
]);

function normalizeQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) throw new ExpenseListError('INVALID_QUERY', 'Expense filters must be an object.');
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new ExpenseListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status !== undefined && query.status !== '' && !statuses.has(query.status)) {
    throw new ExpenseListError('INVALID_STATUS', 'Choose a supported expense status.');
  }
  if (query.search !== undefined && typeof query.search !== 'string') throw new ExpenseListError('INVALID_SEARCH', 'Expense search must be text.');
  const search = query.search?.trim() || '';
  if (search.length > 100) throw new ExpenseListError('INVALID_SEARCH', 'Expense search must be 100 characters or fewer.');
  return Object.freeze({ page, pageSize, filters: Object.freeze({ ...(query.status ? { status: query.status } : {}), ...(search ? { search } : {}) }) });
}

function label(value, field, maxLength, required = false) {
  if (value === null || value === undefined) {
    if (required) throw new ExpenseListError('INVALID_PROJECTION', `${field} is required.`);
    return null;
  }
  if (typeof value !== 'string' || value.length > maxLength || (required && !value.trim())) {
    throw new ExpenseListError('INVALID_PROJECTION', `${field} is not a safe display value.`);
  }
  return value;
}

function projectExpense(expense, payment, projection, estateId) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))) {
    throw new ExpenseListError('INVALID_PROJECTION', 'Expense summaries may contain only allowlisted display fields.');
  }
  if (typeof expense.description !== 'string' || !expense.description.trim() || expense.description.length > 600
    || typeof expense.categoryName !== 'string' || !expense.categoryName.trim() || expense.categoryName.length > 80
    || typeof projection.requestedAt !== 'string' || Number.isNaN(Date.parse(projection.requestedAt))
    || (projection.neededBy !== null && projection.neededBy !== undefined
      && (typeof projection.neededBy !== 'string' || Number.isNaN(Date.parse(projection.neededBy))))
    || projection.neededBy !== (expense.neededBy ?? null)
    || projection.description !== expense.description || projection.categoryName !== expense.categoryName
    || projection.requestedAt !== (expense.submittedAt ?? expense.createdAt)
    || !Array.isArray(projection.allowedCommands) || projection.allowedCommands.some((command) => !decisions.has(command))
    || new Set(projection.allowedCommands).size !== projection.allowedCommands.length) {
    throw new ExpenseListError('INVALID_PROJECTION', 'Expense display data or allowed decisions do not match the source record.');
  }
  return Object.freeze({
    id: expense.id, estateId,
    reference: label(projection.reference, 'reference', 100, true),
    description: expense.description,
    categoryName: expense.categoryName,
    requesterDisplayName: label(projection.requesterDisplayName, 'requesterDisplayName', 160, true),
    payeeLabel: label(projection.payeeLabel, 'payeeLabel', 160, true),
    budgetLineName: label(projection.budgetLineName, 'budgetLineName', 120),
    amount: payment?.approvedAmount ?? expense.amount,
    paidAmount: payment?.paidAmount ?? null,
    outstandingAmount: payment?.outstandingAmount ?? null,
    currency: expense.currency,
    currencyScale: expense.currencyScale,
    status: payment?.status ?? expense.status,
    neededBy: expense.neededBy ?? null,
    requestedAt: projection.requestedAt,
    allowedCommands: Object.freeze([...projection.allowedCommands]),
  });
}

function createEstateExpenseListUseCase({ transaction, requireEstatePermission, queryExpenses, loadExpenseAllocations, projectExpenseForActor } = {}) {
  const ports = { transaction, requireEstatePermission, queryExpenses, loadExpenseAllocations, projectExpenseForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ExpenseListError('MISSING_ADAPTER', `Expense list adapters are required: ${missing.join(', ')}.`);

  return async function listEstateExpenses({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new ExpenseListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    const normalized = normalizeQuery(query);
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'finance.expense.view', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new ExpenseListError('ESTATE_ACCESS_DENIED', 'The actor cannot view expenses in this estate.');
      }
      // The repository applies estate and actor row scope before status/search, count and pagination.
      const result = await queryExpenses(tx, { actorUserId, estateContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || (result.items.length && (normalized.page - 1) * normalized.pageSize >= result.total)) {
        throw new ExpenseListError('INVALID_REPOSITORY_RESULT', 'The expense repository returned an invalid scoped page.');
      }
      const seen = new Set();
      const items = [];
      for (const expense of result.items) {
        if (!expense?.id || String(expense.estateId) !== String(estateId) || !statuses.has(expense.status)
          || typeof expense.amount !== 'string' || typeof expense.currency !== 'string' || !/^[A-Z]{3}$/.test(expense.currency)
          || !Number.isInteger(expense.currencyScale) || expense.currencyScale < 0 || expense.currencyScale > 6) {
          throw new ExpenseListError('ESTATE_SCOPE_VIOLATION', 'The expense repository returned an invalid or out-of-estate record.');
        }
        try { toMinorUnits(expense.amount, expense.currencyScale); } catch {
          throw new ExpenseListError('INVALID_AMOUNT', 'Expense amounts must use exact decimal values at configured currency precision.');
        }
        if (seen.has(String(expense.id))) throw new ExpenseListError('DUPLICATE_RESULT', 'The expense repository returned a duplicate record.');
        seen.add(String(expense.id));
        const allocations = await loadExpenseAllocations(tx, { actorUserId, estateContext, expense });
        if (!Array.isArray(allocations)) throw new ExpenseListError('INVALID_ALLOCATIONS', 'Expense payment allocations must be a list.');
        if (allocations.some((allocation) => !allocation || String(allocation.expenseId) !== String(expense.id)
          || allocation.currency !== expense.currency || !['applied', 'reversed'].includes(allocation.state))) {
          throw new ExpenseListError('INVALID_ALLOCATIONS', 'Expense allocations must belong to this expense and currency.');
        }
        let payment = null;
        if ([ExpenseStatus.APPROVED, ExpenseStatus.PARTIALLY_PAID, ExpenseStatus.PAID].includes(expense.status)) {
          try { payment = deriveExpensePaymentStatus(expense, allocations); } catch {
            throw new ExpenseListError('INVALID_PAYMENT_HISTORY', 'Expense payment status must reconcile to verified allocation records.');
          }
        } else if (allocations.some((allocation) => allocation?.state === 'applied')) {
          throw new ExpenseListError('INVALID_PAYMENT_HISTORY', 'Unapproved expenses cannot contain applied payment allocations.');
        }
        const projection = await projectExpenseForActor({ actorUserId, estateContext, expense, payment, tx });
        items.push(projectExpense(expense, payment, projection, estateId));
      }
      return Object.freeze({ items: Object.freeze(items), page: normalized.page, pageSize: normalized.pageSize,
        total: result.total, totalPages: Math.ceil(result.total / normalized.pageSize) });
    });
  };
}

module.exports = { ExpenseListError, createEstateExpenseListUseCase, normalizeQuery, projectExpense };
