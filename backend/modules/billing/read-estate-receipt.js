const { toMinorUnits, fromMinorUnits } = require('./money');

class ReceiptReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ReceiptReadError';
    this.code = code;
  }
}

function timestamp(value, field) {
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new ReceiptReadError('INVALID_RECEIPT', `${field} must be a valid timestamp.`);
  }
  return new Date(value).toISOString();
}

function displayText(value, field, maxLength = 180, nullable = true) {
  if (nullable && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new ReceiptReadError('INVALID_PROJECTION', `${field} must be a bounded display string.`);
  }
  return value;
}

/** Read metadata for a receipt issued against a verified settlement; file access is a separate service. */
function createEstateReceiptReadUseCase({ transaction, resolveReceiptReadAccess, findReceiptEvidence } = {}) {
  const ports = { transaction, resolveReceiptReadAccess, findReceiptEvidence };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ReceiptReadError('MISSING_ADAPTER', `Receipt read adapters are required: ${missing.join(', ')}.`);

  return async function readEstateReceipt({ actorUserId, estateId, receiptId } = {}) {
    if (!actorUserId || !estateId || !receiptId) {
      throw new ReceiptReadError('INVALID_INPUT', 'Actor, estate and receipt are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveReceiptReadAccess(tx, { actorUserId, estateId, receiptId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)) {
        throw new ReceiptReadError('RECEIPT_NOT_FOUND', 'The receipt was not found in the authorized context.');
      }
      const evidence = await findReceiptEvidence(tx, { access, receiptId });
      const { receipt, allocation, payment, invoice, projection } = evidence || {};
      if (!receipt?.id || String(receipt.id) !== String(receiptId)
        || String(receipt.estateId) !== String(estateId) || receipt.status !== 'issued'
        || !allocation?.id || String(allocation.id) !== String(receipt.allocationId)
        || String(allocation.estateId) !== String(estateId)
        || !['applied', 'reversed'].includes(allocation.state)
        || String(allocation.invoiceId) !== String(receipt.invoiceId)
        || String(allocation.paymentId) !== String(receipt.paymentId)
        || !payment?.id || String(payment.id) !== String(receipt.paymentId)
        || !['succeeded', 'reversed', 'refunded'].includes(payment.state)
        || !payment.providerTransactionId || !payment.verifiedAt
        || !invoice?.id || String(invoice.id) !== String(receipt.invoiceId)
        || String(invoice.estateId) !== String(estateId)
        || String(invoice.payerUserId) !== String(receipt.payerUserId)
        || payment.currency !== receipt.currency || invoice.currency !== receipt.currency
        || payment.destinationReference !== invoice.destinationReference) {
        throw new ReceiptReadError('UNVERIFIED_RECEIPT', 'Receipt must reference a verified payment allocation and invoice in this estate.');
      }
      let receiptAmount;
      let allocationAmount;
      try {
        receiptAmount = fromMinorUnits(toMinorUnits(receipt.amount, invoice.currencyScale), invoice.currencyScale);
        allocationAmount = fromMinorUnits(toMinorUnits(allocation.amount, invoice.currencyScale), invoice.currencyScale);
      } catch {
        throw new ReceiptReadError('INVALID_RECEIPT_AMOUNT', 'Receipt and allocation amounts must use the configured invoice precision.');
      }
      if (receiptAmount !== allocationAmount || allocation.currency !== receipt.currency
        || new Date(timestamp(receipt.settledAt, 'settledAt')).getTime() !== new Date(timestamp(payment.verifiedAt, 'verifiedAt')).getTime()) {
        throw new ReceiptReadError('RECEIPT_RECONCILIATION_FAILED', 'Receipt values do not match the verified settlement allocation.');
      }
      const allowedProjection = new Set(['receiptNumber', 'invoiceNumber', 'description', 'payerDisplayName', 'payeeDisplayName', 'propertyCode']);
      if (!projection || typeof projection !== 'object' || Array.isArray(projection)
        || Object.keys(projection).some((key) => !allowedProjection.has(key))) {
        throw new ReceiptReadError('UNSAFE_PROJECTION', 'Receipt projection contains fields outside the authorized metadata contract.');
      }
      if (typeof projection.receiptNumber !== 'string' || !projection.receiptNumber.trim()
        || projection.receiptNumber.length > 100 || typeof projection.invoiceNumber !== 'string'
        || projection.invoiceNumber !== invoice.invoiceNumber) {
        throw new ReceiptReadError('INVALID_PROJECTION', 'Receipt and invoice references must be projected from the linked records.');
      }
      return Object.freeze({
        receiptId: receipt.id,
        receiptNumber: projection.receiptNumber,
        invoiceId: invoice.id,
        invoiceNumber: projection.invoiceNumber,
        description: displayText(projection.description, 'description', 240),
        payerDisplayName: displayText(projection.payerDisplayName, 'payerDisplayName'),
        payeeDisplayName: displayText(projection.payeeDisplayName, 'payeeDisplayName'),
        propertyCode: displayText(projection.propertyCode, 'propertyCode', 80),
        amount: receiptAmount,
        currency: receipt.currency,
        settledAt: timestamp(receipt.settledAt, 'settledAt'),
        allocationState: allocation.state,
        verificationStatus: 'verified',
      });
    });
  };
}

module.exports = { ReceiptReadError, createEstateReceiptReadUseCase };
