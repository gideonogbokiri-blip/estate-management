const { toMinorUnits, fromMinorUnits } = require('./money');

const paymentAttemptStates = new Set(['created', 'pending', 'succeeded', 'failed', 'expired', 'reversed', 'refunded']);

class PaymentAttemptReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'PaymentAttemptReadError';
    this.code = code;
  }
}

function isoTimestamp(value, field, required = true) {
  if (!required && (value === null || value === undefined)) return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new PaymentAttemptReadError('INVALID_ATTEMPT', `${field} must be a valid timestamp.`);
  }
  return new Date(value).toISOString();
}

/** Read payment state from the trusted Zvend attempt record, never from a browser return. */
function createPaymentAttemptReadUseCase({
  transaction,
  resolvePaymentAttemptReadAccess,
  findPaymentAttemptForRead,
} = {}) {
  const ports = { transaction, resolvePaymentAttemptReadAccess, findPaymentAttemptForRead };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new PaymentAttemptReadError('MISSING_ADAPTER', `Payment attempt read adapters are required: ${missing.join(', ')}.`);

  return async function readPaymentAttempt({ actorUserId, estateId, attemptId } = {}) {
    if (!actorUserId || !estateId || !attemptId) {
      throw new PaymentAttemptReadError('INVALID_INPUT', 'Actor, estate and payment attempt are required.');
    }
    return transaction(async (tx) => {
      const access = await resolvePaymentAttemptReadAccess(tx, { actorUserId, estateId, attemptId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)) {
        throw new PaymentAttemptReadError('PAYMENT_ATTEMPT_NOT_FOUND', 'The payment attempt was not found in the authorized context.');
      }
      const attempt = await findPaymentAttemptForRead(tx, { access, attemptId });
      if (!attempt?.id || String(attempt.id) !== String(attemptId)
        || String(attempt.estateId) !== String(estateId)
        || !paymentAttemptStates.has(attempt.state)
        || !attempt.invoiceId || typeof attempt.currency !== 'string' || !/^[A-Z]{3}$/.test(attempt.currency)) {
        throw new PaymentAttemptReadError('PAYMENT_ATTEMPT_NOT_FOUND', 'The payment attempt was not found in the authorized context.');
      }
      let amount;
      try { amount = fromMinorUnits(toMinorUnits(attempt.amount, attempt.currencyScale), attempt.currencyScale); } catch {
        throw new PaymentAttemptReadError('INVALID_ATTEMPT', 'The payment attempt amount does not match configured currency precision.');
      }
      const verifiedAt = attempt.state === 'succeeded' ? isoTimestamp(attempt.verifiedAt, 'verifiedAt') : null;
      return Object.freeze({
        attemptId: attempt.id,
        invoiceId: attempt.invoiceId,
        state: attempt.state,
        amount,
        currency: attempt.currency,
        createdAt: isoTimestamp(attempt.createdAt, 'createdAt'),
        updatedAt: isoTimestamp(attempt.updatedAt, 'updatedAt', false),
        confirmedAt: verifiedAt,
      });
    });
  };
}

module.exports = { PaymentAttemptReadError, createPaymentAttemptReadUseCase };
