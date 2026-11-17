const { deriveInvoiceBalance, InvoiceError, InvoiceStatus, AllocationState } = require('./invoice');
const { fromMinorUnits, toMinorUnits } = require('./money');

class InvoiceDetailError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'InvoiceDetailError';
    this.code = code;
  }
}

const statuses = new Set(Object.values(InvoiceStatus));

function safeText(value, field, maxLength = 180, nullable = true) {
  if (nullable && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new InvoiceDetailError('INVALID_PROJECTION', `${field} must be a bounded display string.`);
  }
  return value;
}

function validTimestamp(value, nullable = false) {
  if (nullable && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new InvoiceDetailError('INVALID_INVOICE_TIMESTAMP', 'Invoice and payment history timestamps must be valid ISO dates.');
  }
  return new Date(value).toISOString();
}

function safeInvoiceDetail(invoice, balance, projection, paymentHistory) {
  const allowedProjection = new Set(['invoiceNumber', 'category', 'payerDisplayName', 'propertyCode', 'tenancyLabel', 'payeeDisplayName']);
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => !allowedProjection.has(key))) {
    throw new InvoiceDetailError('UNSAFE_PROJECTION', 'Invoice details contain fields outside the actor-safe projection.');
  }
  if (typeof projection.invoiceNumber !== 'string' || !projection.invoiceNumber.trim()
    || projection.invoiceNumber.length > 100 || projection.invoiceNumber !== invoice.invoiceNumber
    || typeof projection.category !== 'string' || !projection.category.trim()
    || projection.category.length > 80 || projection.category !== invoice.category) {
    throw new InvoiceDetailError('INVALID_PROJECTION', 'Invoice identity and category must match the scoped invoice.');
  }
  if (!Array.isArray(invoice.lines) || invoice.lines.length === 0 || invoice.lines.length > 200) {
    throw new InvoiceDetailError('INVALID_INVOICE_LINES', 'Invoice line snapshots must contain between 1 and 200 lines.');
  }
  let lineTotalMinor = 0n;
  const lines = invoice.lines.map((line) => {
    if (!line || typeof line.description !== 'string' || !line.description.trim() || line.description.length > 300
      || line.currency !== invoice.currency) {
      throw new InvoiceDetailError('INVALID_INVOICE_LINES', 'An invoice line snapshot is invalid.');
    }
    try { lineTotalMinor += toMinorUnits(line.amount, invoice.currencyScale); } catch {
      throw new InvoiceDetailError('INVALID_INVOICE_LINES', 'Invoice line amounts must use the configured currency precision.');
    }
    return Object.freeze({ description: line.description, amount: line.amount, currency: line.currency });
  });
  if (lineTotalMinor !== toMinorUnits(invoice.total, invoice.currencyScale)) {
    throw new InvoiceDetailError('INVALID_INVOICE_LINES', 'Invoice line snapshots do not reconcile to the invoice total.');
  }
  return Object.freeze({
    id: invoice.id,
    invoiceNumber: projection.invoiceNumber,
    category: projection.category,
    status: balance?.status || invoice.status,
    issuedAt: validTimestamp(invoice.issuedAt, true),
    dueAt: validTimestamp(invoice.dueAt),
    currency: invoice.currency,
    total: invoice.total,
    allocated: balance?.allocated ?? null,
    balance: balance?.balance ?? null,
    overdue: balance?.overdue || false,
    disputed: balance?.disputed ?? Boolean(invoice.disputed),
    payerDisplayName: safeText(projection.payerDisplayName, 'payerDisplayName'),
    payeeDisplayName: safeText(projection.payeeDisplayName, 'payeeDisplayName'),
    propertyCode: safeText(projection.propertyCode, 'propertyCode', 80),
    tenancyLabel: safeText(projection.tenancyLabel, 'tenancyLabel', 120),
    lines: Object.freeze(lines),
    paymentHistory: Object.freeze(paymentHistory),
  });
}

/** Read one invoice through trusted estate or payer/landlord relationship access. */
function createEstateInvoiceDetailUseCase({
  transaction,
  resolveInvoiceReadAccess,
  findInvoiceForRead,
  loadInvoiceAllocationsWithPayments,
  projectInvoiceForActor,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveInvoiceReadAccess, findInvoiceForRead, loadInvoiceAllocationsWithPayments, projectInvoiceForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new InvoiceDetailError('MISSING_ADAPTER', `Invoice detail adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new InvoiceDetailError('INVALID_CLOCK', 'An invoice detail clock function is required.');

  return async function readEstateInvoice({ actorUserId, estateId, invoiceId } = {}) {
    if (!actorUserId || !estateId || !invoiceId) {
      throw new InvoiceDetailError('INVALID_INPUT', 'Actor, estate and invoice context are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveInvoiceReadAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)) {
        throw new InvoiceDetailError('INVOICE_NOT_FOUND', 'The invoice was not found in the authorized context.');
      }
      const invoice = await findInvoiceForRead(tx, { access, invoiceId });
      if (!invoice?.id || String(invoice.id) !== String(invoiceId) || String(invoice.estateId) !== String(estateId)) {
        throw new InvoiceDetailError('INVOICE_NOT_FOUND', 'The invoice was not found in the authorized context.');
      }
      if (!statuses.has(invoice.status) || typeof invoice.currency !== 'string' || !/^[A-Z]{3}$/.test(invoice.currency)) {
        throw new InvoiceDetailError('INVALID_INVOICE', 'The invoice state or currency is invalid.');
      }
      try { toMinorUnits(invoice.total, invoice.currencyScale); } catch {
        throw new InvoiceDetailError('INVALID_INVOICE_AMOUNT', 'Invoice totals must use exact decimal amounts at configured currency precision.');
      }
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new InvoiceDetailError('INVALID_CLOCK', 'A valid invoice detail timestamp is required.');
      const rows = await loadInvoiceAllocationsWithPayments(tx, { access, invoice });
      if (!Array.isArray(rows) || rows.length > 500) {
        throw new InvoiceDetailError('INVALID_REPOSITORY_RESULT', 'Invoice payment history must be a bounded list.');
      }
      const allocations = [];
      const history = [];
      const allocationIds = new Set();
      for (const row of rows) {
        const { allocation, payment, receipt = null } = row || {};
        if (!allocation?.id || String(allocation.invoiceId) !== String(invoice.id)
          || ![AllocationState.APPLIED, AllocationState.REVERSED].includes(allocation.state)
          || !payment?.id || String(allocation.paymentId) !== String(payment.id)
          || payment.state !== 'succeeded' || !payment.providerTransactionId
          || !payment.verifiedAt || payment.currency !== invoice.currency
          || payment.destinationReference !== invoice.destinationReference) {
          throw new InvoiceDetailError('UNVERIFIED_PAYMENT_HISTORY', 'Payment history must contain only confirmed payments allocated to this invoice.');
        }
        const allocationKey = String(allocation.id);
        if (allocationIds.has(allocationKey)) throw new InvoiceDetailError('DUPLICATE_ALLOCATION', 'Payment history contains a duplicate allocation.');
        allocationIds.add(allocationKey);
        try { toMinorUnits(allocation.amount, invoice.currencyScale); } catch {
          throw new InvoiceDetailError('INVALID_ALLOCATION_AMOUNT', 'Payment allocation amounts must use the invoice currency precision.');
        }
        allocations.push(allocation);
        let receiptId = null;
        if (receipt !== null) {
          if (!receipt?.id || String(receipt.estateId) !== String(estateId)
            || String(receipt.invoiceId) !== String(invoice.id)
            || String(receipt.paymentId) !== String(payment.id)
            || String(receipt.allocationId) !== String(allocation.id)
            || receipt.status !== 'issued' || receipt.currency !== invoice.currency
            || fromMinorUnits(toMinorUnits(receipt.amount, invoice.currencyScale), invoice.currencyScale)
              !== fromMinorUnits(toMinorUnits(allocation.amount, invoice.currencyScale), invoice.currencyScale)) {
            throw new InvoiceDetailError('INVALID_RECEIPT_LINK', 'The receipt must be an issued record for this verified invoice allocation.');
          }
          receiptId = receipt.id;
        }
        history.push(Object.freeze({
          state: allocation.state,
          amount: allocation.amount,
          currency: invoice.currency,
          occurredAt: validTimestamp(allocation.occurredAt),
          verifiedAt: validTimestamp(payment.verifiedAt),
          receiptId,
        }));
      }
      let balance = null;
      if ([InvoiceStatus.ISSUED, InvoiceStatus.PARTIALLY_PAID, InvoiceStatus.PAID].includes(invoice.status)) {
        try { balance = deriveInvoiceBalance(invoice, allocations, now); } catch (error) {
          if (error instanceof InvoiceError) throw error;
          throw new InvoiceDetailError('INVALID_INVOICE_BALANCE', 'The invoice balance could not be derived safely.');
        }
      } else if (allocations.some((allocation) => allocation.state === AllocationState.APPLIED)) {
        throw new InvoiceDetailError('INVALID_INVOICE_BALANCE', 'Unissued invoices cannot contain applied payment allocations.');
      }
      const projection = await projectInvoiceForActor({ actorUserId, access, invoice, balance, tx });
      history.sort((left, right) => Date.parse(right.occurredAt) - Date.parse(left.occurredAt));
      return safeInvoiceDetail(invoice, balance, projection, history);
    });
  };
}

module.exports = { InvoiceDetailError, createEstateInvoiceDetailUseCase, safeInvoiceDetail };
