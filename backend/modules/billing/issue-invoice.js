const { planInvoiceIssue, InvoiceError, InvoiceStatus } = require('./invoice');

function createInvoiceIssueUseCase({
  transaction,
  requireEstatePermission,
  findInvoiceForUpdate,
  resolveSettlementPolicy,
  commitInvoiceIssue,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const adapters = {
    transaction,
    requireEstatePermission,
    findInvoiceForUpdate,
    resolveSettlementPolicy,
    commitInvoiceIssue,
    appendAuditEvent,
  };
  const missing = Object.entries(adapters).filter(([, adapter]) => typeof adapter !== 'function').map(([name]) => name);
  if (missing.length) throw new InvoiceError('MISSING_ADAPTER', `Invoice issue adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new InvoiceError('INVALID_CLOCK', 'An invoice issue clock function is required.');

  return async function issueInvoice({ actorUserId, estateId, invoiceId } = {}) {
    if (!actorUserId || !estateId || !invoiceId) {
      throw new InvoiceError('INVALID_INPUT', 'Authenticated actor, estate context and invoice are required.');
    }
    return transaction(async (tx) => {
      const context = await requireEstatePermission(actorUserId, estateId, 'invoice.issue', tx);
      if (!context || String(context.estateId) !== String(estateId)) {
        throw new InvoiceError('ESTATE_ACCESS_DENIED', 'An active authorized estate context is required to issue invoices.');
      }

      const invoice = await findInvoiceForUpdate(tx, { invoiceId, estateContext: context });
      if (!invoice || String(invoice.id) !== String(invoiceId) || String(invoice.estateId) !== String(estateId)) {
        throw new InvoiceError('INVOICE_NOT_FOUND', 'The invoice was not found in the authorized estate.');
      }
      const settlementPolicy = await resolveSettlementPolicy(tx, {
        estateContext: context,
        invoice,
        settlementPolicyId: invoice.destinationPolicyId,
      });
      const plan = planInvoiceIssue(invoice, {
        actorUserId,
        now: clock(),
        settlementPolicy,
      });
      const updated = await commitInvoiceIssue(tx, plan, { invoice, settlementPolicy });
      if (!updated || String(updated.id) !== String(invoice.id)
        || String(updated.estateId) !== String(estateId) || updated.status !== InvoiceStatus.ISSUED) {
        throw new InvoiceError('INVALID_COMMIT_RESULT', 'The invoice issue adapter did not return the issued invoice.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        invoiceId: updated.id,
        estateId: updated.estateId,
        status: updated.status,
        issuedAt: plan.effects[0].issuedAt,
      });
    });
  };
}

module.exports = { createInvoiceIssueUseCase };
