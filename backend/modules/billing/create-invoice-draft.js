const { prepareInvoiceDraft, InvoiceError } = require('./invoice');

/** Create a finance-reviewed draft from same-estate, server-resolved billing context. */
function createInvoiceDraftUseCase({
  transaction,
  requireEstatePermission,
  resolveInvoiceDraftContext,
  generateInvoiceNumber,
  createInvoiceRecord,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const adapters = {
    transaction,
    requireEstatePermission,
    resolveInvoiceDraftContext,
    generateInvoiceNumber,
    createInvoiceRecord,
    appendAuditEvent,
  };
  const missing = Object.entries(adapters).filter(([, adapter]) => typeof adapter !== 'function').map(([name]) => name);
  if (missing.length) throw new InvoiceError('MISSING_ADAPTER', `Invoice draft adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new InvoiceError('INVALID_CLOCK', 'An invoice draft clock function is required.');

  return async function createInvoiceDraft({ actorUserId, estateId, invoiceDraft } = {}) {
    if (!actorUserId || !estateId || !invoiceDraft || typeof invoiceDraft !== 'object' || Array.isArray(invoiceDraft)) {
      throw new InvoiceError('INVALID_INPUT', 'Authenticated actor, estate context and invoice draft are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'invoice.manage', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new InvoiceError('ESTATE_ACCESS_DENIED', 'The actor cannot create invoice drafts in this estate.');
      }

      const resolved = await resolveInvoiceDraftContext(tx, { estateContext, invoiceDraft });
      const settlementPolicy = resolved?.settlementPolicy;
      if (!resolved || resolved.payerEligible !== true
        || String(resolved.payerUserId) !== String(invoiceDraft.payerUserId)
        || !Number.isInteger(resolved.currencyScale)
        || !settlementPolicy?.id || String(settlementPolicy.estateId) !== String(estateId)
        || settlementPolicy.status !== 'active' || typeof settlementPolicy.currency !== 'string'
        || (invoiceDraft.propertyId && (String(resolved.propertyId) !== String(invoiceDraft.propertyId)
          || String(resolved.propertyEstateId) !== String(estateId)))
        || (invoiceDraft.tenancyId && (String(resolved.tenancyId) !== String(invoiceDraft.tenancyId)
          || String(resolved.tenancyEstateId) !== String(estateId)))) {
        throw new InvoiceError('INVALID_INVOICE_CONTEXT', 'Payer, property, tenancy and settlement terms must be verified in the selected estate.');
      }

      const invoiceNumber = await generateInvoiceNumber(tx, { estateContext });
      const timestamp = new Date(clock());
      if (Number.isNaN(timestamp.getTime())) throw new InvoiceError('INVALID_CLOCK', 'The invoice draft clock returned an invalid time.');
      const invoice = prepareInvoiceDraft({
        estateId,
        invoiceNumber,
        payerUserId: invoiceDraft.payerUserId,
        propertyId: invoiceDraft.propertyId,
        propertyEstateId: resolved.propertyEstateId,
        tenancyId: invoiceDraft.tenancyId,
        tenancyEstateId: resolved.tenancyEstateId,
        category: invoiceDraft.category,
        currency: settlementPolicy.currency,
        destinationPolicyId: settlementPolicy.id,
        dueAt: invoiceDraft.dueAt,
        lines: invoiceDraft.lines,
      }, resolved.currencyScale, timestamp);
      const created = await createInvoiceRecord(tx, invoice, { estateContext });
      if (!created?.id || String(created.estateId) !== String(estateId)
        || created.invoiceNumber !== invoice.invoiceNumber || created.status !== invoice.status
        || created.total !== invoice.total || created.currency !== invoice.currency) {
        throw new InvoiceError('INVALID_CREATE_RESULT', 'The invoice repository did not persist the validated draft in this estate.');
      }
      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'invoice.draft_created',
        targetType: 'invoice',
        targetId: created.id,
        outcome: 'success',
        occurredAt: timestamp.toISOString(),
      });
      return Object.freeze({
        invoiceId: created.id,
        estateId,
        invoiceNumber: created.invoiceNumber,
        status: created.status,
        total: created.total,
        currency: created.currency,
      });
    });
  };
}

module.exports = { createInvoiceDraftUseCase };
