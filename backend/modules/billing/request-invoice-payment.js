const { deriveInvoiceBalance, InvoiceError, InvoiceStatus, AllocationState } = require('./invoice');
const { toMinorUnits, fromMinorUnits } = require('./money');
const paymentAttemptStates = new Set(['created', 'pending', 'succeeded', 'failed', 'expired', 'reversed', 'refunded']);

function createInvoicePaymentRequestUseCase({
  transaction,
  resolveInvoicePaymentAccess,
  findInvoiceForUpdate,
  loadInvoiceAllocations,
  getInvoicePaymentPolicy,
  findPaymentAttemptByIdempotencyKey,
  createPaymentAttemptAndOutbox,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const adapters = {
    transaction,
    resolveInvoicePaymentAccess,
    findInvoiceForUpdate,
    loadInvoiceAllocations,
    getInvoicePaymentPolicy,
    findPaymentAttemptByIdempotencyKey,
    createPaymentAttemptAndOutbox,
    appendAuditEvent,
  };
  const missing = Object.entries(adapters).filter(([, adapter]) => typeof adapter !== 'function').map(([name]) => name);
  if (missing.length) throw new InvoiceError('MISSING_ADAPTER', `Invoice payment adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new InvoiceError('INVALID_CLOCK', 'An invoice payment clock function is required.');

  return async function requestInvoicePayment({ actorUserId, estateId, invoiceId, amount, idempotencyKey } = {}) {
    if (!actorUserId || !estateId || !invoiceId) {
      throw new InvoiceError('INVALID_INPUT', 'Authenticated payer, estate and invoice context are required.');
    }
    if (typeof idempotencyKey !== 'string' || !idempotencyKey.trim() || idempotencyKey.trim().length > 160) {
      throw new InvoiceError('IDEMPOTENCY_KEY_REQUIRED', 'A stable payment request idempotency key is required.');
    }
    return transaction(async (tx) => {
      const access = await resolveInvoicePaymentAccess(tx, { actorUserId, estateId, invoiceId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId) || !access.payerUserId) {
        throw new InvoiceError('PAYMENT_ACCESS_DENIED', 'The actor cannot pay this invoice in the selected estate.');
      }
      const invoice = await findInvoiceForUpdate(tx, { access, invoiceId });
      if (!invoice?.id || String(invoice.id) !== String(invoiceId)
        || String(invoice.estateId) !== String(estateId)
        || String(invoice.payerUserId) !== String(access.payerUserId)) {
        throw new InvoiceError('INVOICE_NOT_FOUND', 'The payable invoice was not found for this payer.');
      }
      const key = idempotencyKey.trim();
      const existing = await findPaymentAttemptByIdempotencyKey(tx, {
        estateId,
        invoiceId,
        payerUserId: access.payerUserId,
        idempotencyKey: key,
      });
      if (existing) {
        let existingAmount;
        let requestedAgain;
        try {
          existingAmount = fromMinorUnits(toMinorUnits(existing.amount, invoice.currencyScale), invoice.currencyScale);
          requestedAgain = amount === undefined || amount === null || amount === ''
            ? existingAmount
            : fromMinorUnits(toMinorUnits(amount, invoice.currencyScale), invoice.currencyScale);
        } catch {
          throw new InvoiceError('INVALID_EXISTING_ATTEMPT', 'The existing idempotent payment attempt has an invalid amount.');
        }
        if (String(existing.estateId) !== String(estateId) || String(existing.invoiceId) !== String(invoiceId)
          || String(existing.payerUserId) !== String(access.payerUserId)
          || existingAmount !== requestedAgain || existing.currency !== invoice.currency
          || !paymentAttemptStates.has(existing.state)
          || typeof existing.createdAt !== 'string' || Number.isNaN(Date.parse(existing.createdAt))) {
          throw new InvoiceError('IDEMPOTENCY_KEY_REUSED', 'This idempotency key was already used for a different or invalid payment request.');
        }
        return Object.freeze({
          attemptId: existing.id,
          state: existing.state,
          amount: existing.amount,
          currency: existing.currency,
          createdAt: new Date(existing.createdAt).toISOString(),
          reused: true,
        });
      }
      const policy = await getInvoicePaymentPolicy(tx, { access, invoice });
      if (!policy || typeof policy.paymentCategory !== 'string' || !policy.paymentCategory.trim()
        || policy.allowPartialPayment !== true && policy.allowPartialPayment !== false
        || policy.allowDisputed !== true && policy.allowDisputed !== false) {
        throw new InvoiceError('PAYMENT_POLICY_REQUIRED', 'Load the server payment and dispute policy before initiating payment.');
      }
      if (typeof invoice.destinationReference !== 'string' || !invoice.destinationReference.trim()) {
        throw new InvoiceError('PAYMENT_DESTINATION_MISSING', 'The issued invoice does not contain its trusted settlement destination snapshot.');
      }
      const allocations = await loadInvoiceAllocations(tx, { access, invoice });
      if (!Array.isArray(allocations) || allocations.some((allocation) => !allocation
        || String(allocation.invoiceId) !== String(invoice.id)
        || ![AllocationState.APPLIED, AllocationState.REVERSED].includes(allocation.state))) {
        throw new InvoiceError('ALLOCATION_SCOPE_VIOLATION', 'Invoice payment history must be scoped to this invoice.');
      }
      const now = new Date(clock());
      if (Number.isNaN(now.getTime())) throw new InvoiceError('INVALID_CLOCK', 'The invoice payment clock returned an invalid time.');
      const balance = deriveInvoiceBalance(invoice, allocations, now);
      if (balance.status === InvoiceStatus.PAID || toMinorUnits(balance.balance, invoice.currencyScale) <= 0n) {
        throw new InvoiceError('INVOICE_ALREADY_PAID', 'The invoice has no remaining payable balance.');
      }
      if (balance.disputed && !policy.allowDisputed) {
        throw new InvoiceError('INVOICE_DISPUTED', 'Payment is blocked while this invoice is disputed.');
      }

      const requestedMinor = amount === undefined || amount === null || amount === ''
        ? toMinorUnits(balance.balance, invoice.currencyScale)
        : toMinorUnits(amount, invoice.currencyScale);
      const remainingMinor = toMinorUnits(balance.balance, invoice.currencyScale);
      if (requestedMinor <= 0n || requestedMinor > remainingMinor
        || (!policy.allowPartialPayment && requestedMinor !== remainingMinor)) {
        throw new InvoiceError('INVALID_PAYMENT_AMOUNT', 'Payment amount must be positive, within the outstanding balance, and satisfy the estate partial-payment policy.');
      }
      const normalizedAmount = fromMinorUnits(requestedMinor, invoice.currencyScale);
      const attempt = await createPaymentAttemptAndOutbox(tx, {
        estateId,
        invoiceId,
        payerUserId: access.payerUserId,
        amount: normalizedAmount,
        currency: invoice.currency,
        currencyScale: invoice.currencyScale,
        paymentCategory: policy.paymentCategory,
        destinationReference: invoice.destinationReference,
        idempotencyKey: key,
        createdAt: now.toISOString(),
      }, { access, invoice });
      if (!attempt?.id || String(attempt.estateId) !== String(estateId)
        || String(attempt.invoiceId) !== String(invoiceId)
        || String(attempt.payerUserId) !== String(access.payerUserId)
        || attempt.amount !== normalizedAmount || attempt.currency !== invoice.currency
        || !['created', 'pending'].includes(attempt.state)
        || typeof attempt.createdAt !== 'string' || Number.isNaN(Date.parse(attempt.createdAt))) {
        throw new InvoiceError('INVALID_ATTEMPT_RESULT', 'The payment adapter did not persist a pending attempt for this invoice.');
      }
      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'invoice.payment_requested',
        targetType: 'invoice',
        targetId: invoice.id,
        outcome: 'success',
        occurredAt: now.toISOString(),
      });
      return Object.freeze({
        attemptId: attempt.id,
        state: attempt.state,
        amount: attempt.amount,
        currency: attempt.currency,
        createdAt: new Date(attempt.createdAt).toISOString(),
        reused: false,
      });
    });
  };
}

module.exports = { createInvoicePaymentRequestUseCase };
