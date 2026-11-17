const { deriveInvoiceBalance, InvoiceError, InvoiceStatus, AllocationState } = require('./invoice');
const { toMinorUnits } = require('./money');

class InvoiceListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'InvoiceListError';
    this.code = code;
  }
}

const listableStatuses = new Set(Object.values(InvoiceStatus));
const dateFields = ['dueFrom', 'dueTo', 'issuedFrom', 'issuedTo'];

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function normalizeInvoiceQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new InvoiceListError('INVALID_QUERY', 'Invoice filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new InvoiceListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status && !listableStatuses.has(query.status)) {
    throw new InvoiceListError('INVALID_STATUS_FILTER', 'Choose a supported invoice status.');
  }
  for (const field of dateFields) {
    if (query[field] !== undefined && query[field] !== '' && !validDate(query[field])) {
      throw new InvoiceListError('INVALID_DATE_FILTER', `${field} must be a valid YYYY-MM-DD date.`);
    }
  }
  for (const [from, to] of [['dueFrom', 'dueTo'], ['issuedFrom', 'issuedTo']]) {
    if (query[from] && query[to] && query[from] > query[to]) {
      throw new InvoiceListError('INVALID_DATE_RANGE', `${from}/${to} range is reversed.`);
    }
  }
  const filters = {};
  for (const field of ['status', 'category', 'payerUserId', 'propertyId', 'tenancyId', ...dateFields]) {
    const value = query[field];
    if (value === undefined || value === null || value === '') continue;
    if (['payerUserId', 'propertyId', 'tenancyId'].includes(field)) {
      if (!['string', 'number'].includes(typeof value) || !String(value).trim()) {
        throw new InvoiceListError('INVALID_FILTER', `${field} is invalid.`);
      }
      filters[field] = value;
    } else if (['status', ...dateFields].includes(field)) filters[field] = value;
    else {
      if (typeof value !== 'string' || !value.trim() || value.trim().length > 80) {
        throw new InvoiceListError('INVALID_FILTER', `${field} is invalid.`);
      }
      filters[field] = value.trim();
    }
  }
  if (query.categories !== undefined) {
    if (query.category !== undefined || !Array.isArray(query.categories)
      || query.categories.length < 1 || query.categories.length > 50) {
      throw new InvoiceListError('INVALID_FILTER', 'categories must contain 1 to 50 category values and cannot be combined with category.');
    }
    const categories = query.categories.map((category) => {
      if (typeof category !== 'string' || !category.trim() || category.trim().length > 80) {
        throw new InvoiceListError('INVALID_FILTER', 'Each invoice category must be bounded display text.');
      }
      return category.trim();
    });
    if (new Set(categories).size !== categories.length) {
      throw new InvoiceListError('INVALID_FILTER', 'Invoice categories must be unique.');
    }
    filters.categories = Object.freeze(categories);
  }
  if (query.search !== undefined && typeof query.search !== 'string') {
    throw new InvoiceListError('INVALID_SEARCH', 'Search must be text.');
  }
  const search = query.search?.trim() || '';
  if (search.length > 100) throw new InvoiceListError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');
  if (search) filters.search = search;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters), sort: 'dueAt_asc' });
}

function safeLabel(value, field, maxLength = 160, nullable = true) {
  if (nullable && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new InvoiceListError('INVALID_PROJECTION', `${field} is not a safe display value.`);
  }
  return value;
}

function projectInvoiceSummary(invoice, balance, projection) {
  const allowed = new Set(['invoiceNumber', 'category', 'payerDisplayName', 'propertyCode', 'tenancyLabel']);
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => !allowed.has(key))) {
    throw new InvoiceListError('UNSAFE_PROJECTION', 'The invoice projection contains fields outside the list summary contract.');
  }
  if (typeof projection.invoiceNumber !== 'string' || !projection.invoiceNumber.trim() || projection.invoiceNumber.length > 100
    || typeof projection.category !== 'string' || !projection.category.trim() || projection.category.length > 80) {
    throw new InvoiceListError('INVALID_PROJECTION', 'Invoice number and category are required safe display fields.');
  }
  if (projection.invoiceNumber !== invoice.invoiceNumber || projection.category !== invoice.category) {
    throw new InvoiceListError('PROJECTION_RECORD_MISMATCH', 'The displayed invoice identity must match its scoped record.');
  }
  return Object.freeze({
    id: invoice.id,
    invoiceNumber: projection.invoiceNumber,
    category: projection.category,
    status: balance?.status || invoice.status,
    dueAt: invoice.dueAt,
    total: invoice.total,
    allocated: balance?.allocated ?? null,
    balance: balance?.balance ?? null,
    currency: invoice.currency,
    overdue: balance?.overdue || false,
    disputed: balance?.disputed ?? Boolean(invoice.disputed),
    payerDisplayName: safeLabel(projection.payerDisplayName, 'payerDisplayName'),
    propertyCode: safeLabel(projection.propertyCode, 'propertyCode', 80),
    tenancyLabel: safeLabel(projection.tenancyLabel, 'tenancyLabel', 120),
  });
}

/** List authorized invoices with balances derived from scoped allocation history. */
function createEstateInvoiceListUseCase({
  transaction,
  resolveInvoiceReadAccess,
  queryInvoices,
  projectInvoiceForActor,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveInvoiceReadAccess, queryInvoices, projectInvoiceForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new InvoiceListError('MISSING_ADAPTER', `Invoice list adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new InvoiceListError('INVALID_CLOCK', 'An invoice list clock function is required.');

  return async function listEstateInvoices({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new InvoiceListError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizeInvoiceQuery(query);
    return transaction(async (tx) => {
      const access = await resolveInvoiceReadAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)) {
        throw new InvoiceListError('INVOICE_ACCESS_DENIED', 'The actor has no authorized invoice context for this estate.');
      }
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new InvoiceListError('INVALID_CLOCK', 'A valid invoice query timestamp is required.');
      // The adapter scopes by estate and payer/landlord/property relationship before search, count or pagination.
      const result = await queryInvoices(tx, { access, ...normalized, asOf: now.toISOString() });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || ((normalized.page - 1) * normalized.pageSize >= result.total && result.items.length > 0)) {
        throw new InvoiceListError('INVALID_REPOSITORY_RESULT', 'The invoice query must return a bounded page and authorized total.');
      }
      const seen = new Set();
      const items = [];
      for (const row of result.items) {
        const invoice = row?.invoice;
        if (!invoice?.id || String(invoice.estateId) !== String(estateId)
          || !listableStatuses.has(invoice.status) || !Array.isArray(row.allocations)
          || typeof invoice.currency !== 'string' || !/^[A-Z]{3}$/.test(invoice.currency)
          || typeof invoice.dueAt !== 'string' || Number.isNaN(Date.parse(invoice.dueAt))) {
          throw new InvoiceListError('ESTATE_SCOPE_VIOLATION', 'The repository returned an invalid invoice or allocation scope.');
        }
        try { toMinorUnits(invoice.total, invoice.currencyScale); } catch {
          throw new InvoiceListError('INVALID_INVOICE_AMOUNT', 'Invoice totals must use exact decimal amounts at configured currency precision.');
        }
        const key = String(invoice.id);
        if (seen.has(key)) throw new InvoiceListError('DUPLICATE_REPOSITORY_RESULT', 'The invoice query returned a duplicate record.');
        seen.add(key);
        if (row.allocations.some((allocation) => !allocation || String(allocation.invoiceId) !== String(invoice.id)
          || ![AllocationState.APPLIED, AllocationState.REVERSED].includes(allocation.state))) {
          throw new InvoiceListError('ALLOCATION_SCOPE_VIOLATION', 'Invoice allocations must be loaded for that invoice only.');
        }
        let balance = null;
        if ([InvoiceStatus.ISSUED, InvoiceStatus.PARTIALLY_PAID, InvoiceStatus.PAID].includes(invoice.status)) {
          try { balance = deriveInvoiceBalance(invoice, row.allocations, now); } catch (error) {
            if (error instanceof InvoiceError) throw error;
            throw new InvoiceListError('INVALID_INVOICE_BALANCE', 'The invoice balance could not be derived safely.');
          }
        } else if (row.allocations.some((allocation) => allocation.state === AllocationState.APPLIED)) {
          throw new InvoiceListError('INVALID_INVOICE_BALANCE', 'Unissued invoices cannot contain applied payment allocations.');
        }
        const projection = await projectInvoiceForActor({ actorUserId, access, invoice, balance, tx });
        items.push(projectInvoiceSummary(invoice, balance, projection));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
        asOf: now.toISOString(),
      });
    });
  };
}

module.exports = {
  InvoiceListError,
  createEstateInvoiceListUseCase,
  normalizeInvoiceQuery,
  projectInvoiceSummary,
};
