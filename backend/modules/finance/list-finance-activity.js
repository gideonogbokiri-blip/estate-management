const { toMinorUnits } = require('../billing/money');

class FinanceActivityListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'FinanceActivityListError';
    this.code = code;
  }
}

const eventTypes = new Set(['expense_approved', 'expense_rejected', 'payment_allocated']);

function normalizeQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new FinanceActivityListError('INVALID_QUERY', 'Finance activity filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize)
    || pageSize < 1 || pageSize > 100) {
    throw new FinanceActivityListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  const type = query.type ?? 'all';
  if (!['all', 'decisions', 'payments'].includes(type)) {
    throw new FinanceActivityListError('INVALID_TYPE', 'Choose all activity, expense decisions or verified payments.');
  }
  const search = query.search === undefined ? '' : query.search;
  if (typeof search !== 'string' || search.trim().length > 100) {
    throw new FinanceActivityListError('INVALID_SEARCH', 'Activity search must be at most 100 characters.');
  }
  const startAt = query.startAt ?? null;
  const endAt = query.endAt ?? null;
  for (const [name, value] of [['startAt', startAt], ['endAt', endAt]]) {
    if (value !== null && (typeof value !== 'string' || Number.isNaN(Date.parse(value)))) {
      throw new FinanceActivityListError('INVALID_DATE_RANGE', `${name} must be an ISO timestamp.`);
    }
  }
  if (startAt && endAt && Date.parse(startAt) > Date.parse(endAt)) {
    throw new FinanceActivityListError('INVALID_DATE_RANGE', 'The activity start must be before its end.');
  }
  const eventType = type === 'decisions'
    ? ['expense_approved', 'expense_rejected']
    : type === 'payments' ? ['payment_allocated'] : [...eventTypes];
  return Object.freeze({
    page,
    pageSize,
    filters: Object.freeze({
      eventTypes: Object.freeze(eventType),
      ...(search.trim() ? { search: search.trim() } : {}),
      ...(startAt ? { startAt: new Date(Date.parse(startAt)).toISOString() } : {}),
      ...(endAt ? { endAt: new Date(Date.parse(endAt)).toISOString() } : {}),
    }),
  });
}

function projectActivity(record, projection, estateId) {
  if (!record || !eventTypes.has(record.type) || String(record.estateId) !== String(estateId)
    || !record.id || !record.sourceId || !projection || typeof projection !== 'object'
    || Array.isArray(projection)) {
    throw new FinanceActivityListError('INVALID_ACTIVITY_RECORD', 'Finance activity must match an authorized source record.');
  }
  const allowed = new Set(['reference', 'description', 'actorDisplayName']);
  if (Object.keys(projection).some((field) => !allowed.has(field))) {
    throw new FinanceActivityListError('INVALID_PROJECTION', 'Finance activity contains unsupported display fields.');
  }
  if (!['expense', 'payment_allocation'].includes(record.sourceType)
    || (record.type.startsWith('expense_') && record.sourceType !== 'expense')
    || (record.type === 'payment_allocated' && record.sourceType !== 'payment_allocation')
    || typeof record.occurredAt !== 'string' || Number.isNaN(Date.parse(record.occurredAt))
    || !projection.reference || typeof projection.reference !== 'string' || projection.reference.length > 100
    || typeof projection.description !== 'string' || !projection.description.trim() || projection.description.length > 240
    || typeof projection.actorDisplayName !== 'string' || !projection.actorDisplayName.trim() || projection.actorDisplayName.length > 160
    || typeof record.amount !== 'string' || typeof record.currency !== 'string' || !/^[A-Z]{3}$/.test(record.currency)
    || !Number.isInteger(record.currencyScale) || record.currencyScale < 0 || record.currencyScale > 6) {
    throw new FinanceActivityListError('INVALID_ACTIVITY_RECORD', 'Finance activity fields are invalid.');
  }
  try { toMinorUnits(record.amount, record.currencyScale); } catch {
    throw new FinanceActivityListError('INVALID_ACTIVITY_AMOUNT', 'Activity amounts must use configured exact currency precision.');
  }
  if (record.type === 'payment_allocated'
    && (record.allocationState !== 'applied' || record.paymentState !== 'succeeded'
      || typeof record.paymentVerifiedAt !== 'string'
      || Number.isNaN(Date.parse(record.paymentVerifiedAt))
      || record.allocationAmount !== record.amount
      || record.allocationCurrency !== record.currency
      || record.allocationCurrencyScale !== record.currencyScale)) {
    throw new FinanceActivityListError('UNVERIFIED_PAYMENT_ACTIVITY', 'Only applied allocations from verified successful payments can be shown.');
  }
  if (record.type.startsWith('expense_')
    && (record.decision !== (record.type === 'expense_approved' ? 'approve' : 'reject')
      || !record.decisionAt || Number.isNaN(Date.parse(record.decisionAt))
      || Date.parse(record.decisionAt) !== Date.parse(record.occurredAt)
      || typeof record.decisionAmount !== 'string'
      || record.decisionAmount !== record.amount
      || record.decisionCurrency !== record.currency
      || record.decisionCurrencyScale !== record.currencyScale)) {
    throw new FinanceActivityListError('INVALID_EXPENSE_DECISION_ACTIVITY', 'Expense activity must match an immutable decision record.');
  }
  return Object.freeze({
    id: String(record.id),
    estateId: String(estateId),
    type: record.type,
    sourceId: String(record.sourceId),
    reference: projection.reference,
    description: projection.description,
    actorDisplayName: projection.actorDisplayName,
    amount: record.amount,
    currency: record.currency,
    currencyScale: record.currencyScale,
    occurredAt: new Date(Date.parse(record.occurredAt)).toISOString(),
    verifiedAt: record.type === 'payment_allocated'
      ? new Date(Date.parse(record.paymentVerifiedAt)).toISOString()
      : null,
  });
}

/** List estate-scoped expense decisions and verified payment allocations. */
function createFinanceActivityListUseCase({
  transaction,
  requireEstatePermission,
  queryFinanceActivity,
  projectFinanceActivityForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryFinanceActivity, projectFinanceActivityForActor };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new FinanceActivityListError('MISSING_ADAPTER', `Finance activity adapters are required: ${missing.join(', ')}.`);
  }
  return async function listFinanceActivity({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) {
      throw new FinanceActivityListError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    }
    const normalized = normalizeQuery(query);
    return transaction(async (tx) => {
      const context = await requireEstatePermission(actorUserId, estateId, 'report.financial.view', tx);
      if (!context || String(context.estateId) !== String(estateId)) {
        throw new FinanceActivityListError('ESTATE_ACCESS_DENIED', 'The actor cannot view financial activity in this estate.');
      }
      // Scope source rows to the actor's estate and finance capability before
      // applying filters, counting results or paginating.
      const result = await queryFinanceActivity(tx, {
        actorUserId,
        estateContext: context,
        ...normalized,
      });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || (result.items.length && (normalized.page - 1) * normalized.pageSize >= result.total)) {
        throw new FinanceActivityListError('INVALID_REPOSITORY_RESULT', 'Finance activity returned an invalid page.');
      }
      const seen = new Set();
      const items = [];
      for (const record of result.items) {
        const key = `${record?.type}:${record?.id}`;
        if (seen.has(key)) throw new FinanceActivityListError('DUPLICATE_RESULT', 'Finance activity contains a duplicate event.');
        seen.add(key);
        const projection = await projectFinanceActivityForActor({
          actorUserId,
          estateContext: context,
          record,
          tx,
        });
        items.push(projectActivity(record, projection, estateId));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
      });
    });
  };
}

module.exports = {
  FinanceActivityListError,
  createFinanceActivityListUseCase,
  normalizeQuery,
  projectActivity,
};
