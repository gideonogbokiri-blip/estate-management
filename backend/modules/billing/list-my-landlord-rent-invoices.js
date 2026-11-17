class LandlordRentInvoiceListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'LandlordRentInvoiceListError';
    this.code = code;
  }
}

const visibleStatuses = new Set(['issued', 'partially_paid', 'paid']);

/**
 * Compose the landlord rent view from the actor-scoped invoice list contract.
 * The supplied service must use the authenticated actor and estate access
 * resolver documented by list-estate-invoices.js; callers cannot supply a
 * payer, payee, property, tenancy or invoice filter.
 */
function createMyLandlordRentInvoiceListUseCase({
  listEstateInvoices,
  rentCategory,
} = {}) {
  if (typeof listEstateInvoices !== 'function') {
    throw new LandlordRentInvoiceListError(
      'MISSING_ADAPTER',
      'The authorized estate invoice list service is required.',
    );
  }
  if (typeof rentCategory !== 'string' || !rentCategory.trim()
    || rentCategory.length > 80) {
    throw new LandlordRentInvoiceListError(
      'INVALID_RENT_CATEGORY',
      'A bounded, server-configured rent invoice category is required.',
    );
  }

  return async function listMyLandlordRentInvoices({
    actorUserId,
    estateId,
    page = 1,
    pageSize = 25,
  } = {}) {
    if (!actorUserId || !estateId) {
      throw new LandlordRentInvoiceListError(
        'INVALID_INPUT',
        'Authenticated actor and estate context are required.',
      );
    }
    const result = await listEstateInvoices({
      actorUserId,
      estateId,
      query: { category: rentCategory, page, pageSize },
    });
    if (!result || !Array.isArray(result.items)) {
      throw new LandlordRentInvoiceListError(
        'INVALID_INVOICE_RESULT',
        'The authorized invoice service returned an invalid result.',
      );
    }
    for (const invoice of result.items) {
      if (invoice.category !== rentCategory
        || !visibleStatuses.has(invoice.status)) {
        throw new LandlordRentInvoiceListError(
          'UNSAFE_INVOICE_RESULT',
          'The landlord rent list may contain only issued rent invoices.',
        );
      }
    }
    return result;
  };
}

module.exports = {
  LandlordRentInvoiceListError,
  createMyLandlordRentInvoiceListUseCase,
};
