const { toMinorUnits, fromMinorUnits } = require('./money');

class MyReceiptListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyReceiptListError';
    this.code = code;
  }
}

const timestamp = (value) => typeof value === 'string' && !Number.isNaN(Date.parse(value))
  ? new Date(value).toISOString() : null;

function createMyEstateReceiptListUseCase({ transaction, resolveMyReceiptAccess, queryMyEstateReceipts } = {}) {
  const ports = { transaction, resolveMyReceiptAccess, queryMyEstateReceipts };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyReceiptListError('MISSING_ADAPTER', `Receipt list adapters are required: ${missing.join(', ')}.`);

  return async function listMyEstateReceipts({ actorUserId, estateId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyReceiptListError('INVALID_QUERY', 'Authenticated payer, estate and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveMyReceiptAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId) || access.active !== true
        || access.mayViewOwnReceipts !== true) {
        throw new MyReceiptListError('RECEIPT_ACCESS_DENIED', 'The actor cannot view receipts in this estate.');
      }
      // Apply payer/property/tenancy relationship scope before count and pagination.
      const result = await queryMyEstateReceipts(tx, { access, actorUserId, estateId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyReceiptListError('INVALID_LIST_RESULT', 'The receipt repository returned an invalid page.');
      }
      const seen = new Set();
      const items = result.items.map(({ receipt, allocation, payment, invoice, projection } = {}) => {
        const id = String(receipt?.id ?? '');
        const settledAt = timestamp(receipt?.settledAt);
        if (!id || seen.has(id)) throw new MyReceiptListError('DUPLICATE_OR_INVALID_RESULT', 'The receipt repository returned a duplicate or invalid record.');
        seen.add(id);
        if (String(receipt.estateId) !== String(estateId) || receipt.status !== 'issued'
          || String(receipt.payerUserId) !== String(actorUserId)
          || String(receipt.allocationId) !== String(allocation?.id)
          || String(allocation?.estateId) !== String(estateId) || allocation.state !== 'applied'
          || String(allocation.invoiceId) !== String(receipt.invoiceId)
          || String(allocation.paymentId) !== String(receipt.paymentId)
          || String(payment?.id) !== String(receipt.paymentId) || payment.state !== 'succeeded'
          || !payment.providerTransactionId || !timestamp(payment.verifiedAt)
          || String(invoice?.id) !== String(receipt.invoiceId) || String(invoice.estateId) !== String(estateId)
          || String(invoice.payerUserId) !== String(actorUserId)
          || receipt.currency !== invoice.currency || receipt.currency !== payment.currency || !settledAt) {
          throw new MyReceiptListError('UNVERIFIED_RECEIPT', 'Every receipt must match the authenticated payer and a verified applied payment allocation.');
        }
        let amount;
        try {
          amount = fromMinorUnits(toMinorUnits(receipt.amount, invoice.currencyScale), invoice.currencyScale);
          if (toMinorUnits(allocation.amount, invoice.currencyScale) !== toMinorUnits(receipt.amount, invoice.currencyScale)) throw new Error('amount mismatch');
        } catch {
          throw new MyReceiptListError('RECEIPT_RECONCILIATION_FAILED', 'Receipt amount must match its verified invoice allocation.');
        }
        if (!projection || Object.keys(projection).some((key) => !['invoiceNumber', 'propertyLabel', 'description'].includes(key))
          || projection.invoiceNumber !== invoice.invoiceNumber || typeof projection.propertyLabel !== 'string'
          || projection.propertyLabel.length > 160 || typeof receipt.receiptNumber !== 'string'
          || !receipt.receiptNumber.trim() || receipt.receiptNumber.length > 100
          || typeof receipt.currency !== 'string' || !/^[A-Z]{3}$/.test(receipt.currency)) {
          throw new MyReceiptListError('INVALID_PROJECTION', 'Receipt display fields must match safe bounded invoice data.');
        }
        return Object.freeze({ receiptId: id, receiptNumber: receipt.receiptNumber,
          invoiceNumber: projection.invoiceNumber, propertyLabel: projection.propertyLabel.trim(),
          description: typeof projection.description === 'string' ? projection.description.slice(0, 240) : null,
          amount, currency: receipt.currency, settledAt, verificationStatus: 'verified' });
      });
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { MyReceiptListError, createMyEstateReceiptListUseCase };
