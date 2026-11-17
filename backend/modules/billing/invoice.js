const { fromMinorUnits, normalizeDecimal, toMinorUnits } = require('./money');

class InvoiceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'InvoiceError';
    this.code = code;
  }
}

const InvoiceStatus = Object.freeze({
  DRAFT: 'draft',
  ISSUED: 'issued',
  PARTIALLY_PAID: 'partially_paid',
  PAID: 'paid',
  CANCELLED: 'cancelled',
});

const AllocationState = Object.freeze({ APPLIED: 'applied', REVERSED: 'reversed' });

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function sumAllocations(allocations, currencyScale, currency, scopeField, scopeId) {
  if (!Array.isArray(allocations)) {
    throw new InvoiceError('INVALID_ALLOCATIONS', 'Verified allocations must be provided as a list.');
  }
  return allocations.reduce((total, allocation) => {
    if (!allocation || ![AllocationState.APPLIED, AllocationState.REVERSED].includes(allocation.state)
      || allocation[scopeField] !== scopeId) {
      throw new InvoiceError('INVALID_ALLOCATION_SCOPE', 'Allocation history must be loaded for the target record only.');
    }
    if (allocation.state === AllocationState.REVERSED) return total;
    if (allocation?.currency !== currency) {
      throw new InvoiceError('ALLOCATION_CURRENCY_MISMATCH', 'Applied allocations must match the target currency.');
    }
    return total + toMinorUnits(allocation.amount, currencyScale);
  }, 0n);
}

function prepareInvoiceDraft(input, currencyScale, now) {
  const {
    estateId,
    invoiceNumber,
    payerUserId,
    propertyId,
    propertyEstateId,
    tenancyId,
    tenancyEstateId,
    category,
    currency,
    destinationPolicyId,
    dueAt,
    lines,
  } = input ?? {};
  const createdAt = parseInstant(now);
  const dueTime = parseInstant(dueAt);

  if (!estateId || typeof invoiceNumber !== 'string' || !invoiceNumber.trim()
    || !payerUserId || typeof category !== 'string' || !category.trim() || !destinationPolicyId) {
    throw new InvoiceError('INVALID_INVOICE', 'Estate, invoice number, payer, category, and settlement policy are required.');
  }
  if ((propertyId !== undefined && propertyId !== null && propertyId !== '' && propertyEstateId !== estateId)
    || (tenancyId !== undefined && tenancyId !== null && tenancyId !== '' && tenancyEstateId !== estateId)) {
    throw new InvoiceError('CROSS_ESTATE_INVOICE_LINK', 'Property and tenancy links must belong to the invoice estate.');
  }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
    throw new InvoiceError('INVALID_CURRENCY', 'Currency must be a three-letter uppercase code.');
  }
  if (createdAt === null || dueTime === null || dueTime < createdAt) {
    throw new InvoiceError('INVALID_DUE_DATE', 'A valid due date on or after invoice creation is required.');
  }
  if (!Array.isArray(lines) || lines.length === 0) {
    throw new InvoiceError('EMPTY_INVOICE', 'An invoice must contain at least one line.');
  }

  const lineSnapshots = lines.map((line) => {
    if (typeof line?.description !== 'string' || !line.description.trim()) {
      throw new InvoiceError('INVALID_LINE', 'Each invoice line needs a description.');
    }
    const amount = normalizeDecimal(line.amount, currencyScale);
    if (toMinorUnits(amount, currencyScale) <= 0n) {
      throw new InvoiceError('INVALID_LINE_AMOUNT', 'Invoice line amounts must be greater than zero.');
    }
    return Object.freeze({
      description: line.description.trim(),
      amount,
      currency,
      sourceType: typeof line.sourceType === 'string' ? line.sourceType : null,
      sourceId: line.sourceId ?? null,
    });
  });
  const totalMinor = lineSnapshots.reduce((total, line) => total + toMinorUnits(line.amount, currencyScale), 0n);

  return Object.freeze({
    estateId,
    invoiceNumber: invoiceNumber.trim(),
    payerUserId,
    propertyId: propertyId ?? null,
    tenancyId: tenancyId ?? null,
    category: category.trim(),
    currency,
    currencyScale,
    destinationPolicyId,
    dueAt: new Date(dueTime).toISOString(),
    status: InvoiceStatus.DRAFT,
    lines: Object.freeze(lineSnapshots),
    total: fromMinorUnits(totalMinor, currencyScale),
    createdAt: new Date(createdAt).toISOString(),
  });
}

function planInvoiceIssue(invoice, { actorUserId, now, settlementPolicy } = {}) {
  const issuedAtMs = parseInstant(now);
  if (!invoice?.id || !invoice.estateId || !actorUserId) {
    throw new InvoiceError('INVALID_ISSUE', 'A persisted invoice and authorized actor are required.');
  }
  if (invoice.status !== InvoiceStatus.DRAFT) {
    throw new InvoiceError('INVALID_STATE', 'Only a draft invoice can be issued.');
  }
  if (issuedAtMs === null || parseInstant(invoice.dueAt) === null || issuedAtMs > parseInstant(invoice.dueAt)) {
    throw new InvoiceError('INVALID_DUE_DATE', 'The invoice due date must be valid and not precede issue time.');
  }
  if (!settlementPolicy?.id || settlementPolicy.id !== invoice.destinationPolicyId
    || settlementPolicy.estateId !== invoice.estateId
    || settlementPolicy.currency !== invoice.currency
    || settlementPolicy.status !== 'active'
    || !settlementPolicy.destinationReference) {
    throw new InvoiceError('INVALID_SETTLEMENT_POLICY', 'Resolve an active matching settlement policy before issue.');
  }

  const issuedAt = new Date(issuedAtMs).toISOString();
  return Object.freeze({
    transactionRequired: true,
    invoiceId: invoice.id,
    estateId: invoice.estateId,
    nextStatus: InvoiceStatus.ISSUED,
    effects: Object.freeze([Object.freeze({
      type: 'invoice.issued',
      invoiceId: invoice.id,
      estateId: invoice.estateId,
      expectedStatus: InvoiceStatus.DRAFT,
      issuedAt,
      settlementPolicyId: settlementPolicy.id,
      destinationReference: settlementPolicy.destinationReference,
      total: invoice.total,
      currency: invoice.currency,
      lineSnapshots: invoice.lines,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: invoice.estateId,
      action: 'invoice.issue',
      targetType: 'invoice',
      targetId: invoice.id,
      outcome: 'success',
      occurredAt: issuedAt,
    }),
  });
}

function deriveInvoiceBalance(invoice, allocations, asOf) {
  const now = parseInstant(asOf);
  const dueAt = parseInstant(invoice?.dueAt);
  if (!invoice?.id || now === null || dueAt === null) {
    throw new InvoiceError('INVALID_INVOICE_BALANCE_INPUT', 'Invoice and as-of time are required.');
  }
  if (![InvoiceStatus.ISSUED, InvoiceStatus.PARTIALLY_PAID, InvoiceStatus.PAID].includes(invoice.status)) {
    throw new InvoiceError('INVOICE_NOT_ISSUED', 'Only issued invoices can have a payable balance.');
  }
  const totalMinor = toMinorUnits(invoice.total, invoice.currencyScale);
  const allocatedMinor = sumAllocations(allocations, invoice.currencyScale, invoice.currency, 'invoiceId', invoice.id);
  if (allocatedMinor > totalMinor) {
    throw new InvoiceError('OVERALLOCATED_INVOICE', 'Verified allocations exceed the invoice total.');
  }
  const balanceMinor = totalMinor - allocatedMinor;
  const status = balanceMinor === 0n
    ? InvoiceStatus.PAID
    : allocatedMinor > 0n ? InvoiceStatus.PARTIALLY_PAID : InvoiceStatus.ISSUED;

  return Object.freeze({
    status,
    overdue: balanceMinor > 0n && now >= dueAt,
    disputed: Boolean(invoice.disputed),
    total: fromMinorUnits(totalMinor, invoice.currencyScale),
    allocated: fromMinorUnits(allocatedMinor, invoice.currencyScale),
    balance: fromMinorUnits(balanceMinor, invoice.currencyScale),
    currency: invoice.currency,
    asOf: new Date(now).toISOString(),
  });
}

function planPaymentAllocation({
  invoice,
  payment,
  amount,
  invoiceAllocations,
  paymentAllocations,
  idempotencyKey,
  actorUserId,
  now,
  allowDisputed = false,
} = {}) {
  const timestamp = parseInstant(now);
  if (!invoice?.id || !invoice.estateId || !payment?.id || !actorUserId || timestamp === null) {
    throw new InvoiceError('INVALID_ALLOCATION', 'Invoice, verified payment, actor, and timestamp are required.');
  }
  if (typeof idempotencyKey !== 'string' || !idempotencyKey.trim()) {
    throw new InvoiceError('IDEMPOTENCY_KEY_REQUIRED', 'A stable allocation idempotency key is required.');
  }
  if (invoice.status !== InvoiceStatus.ISSUED && invoice.status !== InvoiceStatus.PARTIALLY_PAID) {
    throw new InvoiceError('INVOICE_NOT_PAYABLE', 'Only an issued invoice with a balance can receive payment.');
  }
  if (invoice.disputed && !allowDisputed) {
    throw new InvoiceError('INVOICE_DISPUTED', 'Policy does not allow allocation while this invoice is disputed.');
  }
  if (payment.state !== 'succeeded' || !payment.verifiedAt || !payment.providerTransactionId
    || payment.currency !== invoice.currency
    || payment.destinationReference !== invoice.destinationReference) {
    throw new InvoiceError('PAYMENT_NOT_VERIFIED', 'Payment must be verified and match invoice currency and destination.');
  }
  if (!Array.isArray(invoiceAllocations) || !Array.isArray(paymentAllocations)) {
    throw new InvoiceError('ALLOCATION_HISTORY_REQUIRED', 'Load applied allocations before allocating more funds.');
  }

  const currencyScale = invoice.currencyScale;
  const allocationMinor = toMinorUnits(amount, currencyScale);
  if (allocationMinor <= 0n) {
    throw new InvoiceError('INVALID_ALLOCATION_AMOUNT', 'Allocation amount must be greater than zero.');
  }
  const totalMinor = toMinorUnits(invoice.total, currencyScale);
  const invoiceAllocatedMinor = sumAllocations(invoiceAllocations, currencyScale, invoice.currency, 'invoiceId', invoice.id);
  const paymentTotalMinor = toMinorUnits(payment.amount, currencyScale);
  const paymentAllocatedMinor = sumAllocations(paymentAllocations, currencyScale, invoice.currency, 'paymentId', payment.id);
  if (invoiceAllocatedMinor > totalMinor || paymentAllocatedMinor > paymentTotalMinor) {
    throw new InvoiceError('OVERALLOCATED_BALANCE', 'Existing allocations exceed the invoice or verified payment.');
  }
  if (allocationMinor > totalMinor - invoiceAllocatedMinor) {
    throw new InvoiceError('INVOICE_OVERPAYMENT', 'Allocation exceeds the remaining invoice balance.');
  }
  if (allocationMinor > paymentTotalMinor - paymentAllocatedMinor) {
    throw new InvoiceError('PAYMENT_OVERALLOCATION', 'Allocation exceeds the unallocated verified payment amount.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  const normalizedAmount = fromMinorUnits(allocationMinor, currencyScale);
  return Object.freeze({
    transactionRequired: true,
    invoiceId: invoice.id,
    paymentId: payment.id,
    estateId: invoice.estateId,
    allocationAmount: normalizedAmount,
    idempotencyKey: idempotencyKey.trim(),
    effects: Object.freeze([
      Object.freeze({
        type: 'payment_allocation.create',
        invoiceId: invoice.id,
        paymentId: payment.id,
        estateId: invoice.estateId,
        amount: normalizedAmount,
        currency: invoice.currency,
        idempotencyKey: idempotencyKey.trim(),
        occurredAt,
      }),
      Object.freeze({
        type: 'receipt.eligible_for_verified_allocation',
        invoiceId: invoice.id,
        paymentId: payment.id,
        allocationKey: idempotencyKey.trim(),
        amount: normalizedAmount,
        currency: invoice.currency,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: invoice.estateId,
      action: 'invoice.payment_allocated',
      targetType: 'invoice',
      targetId: invoice.id,
      outcome: 'success',
      occurredAt,
    }),
  });
}

module.exports = {
  InvoiceError,
  AllocationState,
  InvoiceStatus,
  deriveInvoiceBalance,
  planInvoiceIssue,
  planPaymentAllocation,
  prepareInvoiceDraft,
};
