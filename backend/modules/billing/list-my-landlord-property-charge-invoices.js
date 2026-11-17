class LandlordPropertyChargeInvoiceListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'LandlordPropertyChargeInvoiceListError';
    this.code = code;
  }
}

const visibleStatuses = new Set(['issued', 'partially_paid', 'paid']);

/** List only server-configured property-charge categories for the actor's authorized landlord context. */
function createMyLandlordPropertyChargeInvoiceListUseCase({
  listEstateInvoices,
  propertyChargeCategories,
  rentCategory,
} = {}) {
  if (typeof listEstateInvoices !== 'function') {
    throw new LandlordPropertyChargeInvoiceListError(
      'MISSING_ADAPTER',
      'The authorized estate invoice list service is required.',
    );
  }
  if (!Array.isArray(propertyChargeCategories)
    || propertyChargeCategories.length < 1
    || propertyChargeCategories.length > 50
    || propertyChargeCategories.some((category) => typeof category !== 'string'
      || !category.trim() || category.length > 80)
    || new Set(propertyChargeCategories).size !== propertyChargeCategories.length) {
    throw new LandlordPropertyChargeInvoiceListError(
      'INVALID_CHARGE_CATEGORIES',
      'A bounded list of unique property-charge categories must be configured by the server.',
    );
  }
  if (typeof rentCategory !== 'string' || !rentCategory.trim()
    || !rentCategory.trim()) {
    throw new LandlordPropertyChargeInvoiceListError(
      'INVALID_CHARGE_CATEGORIES',
      'Property-charge categories must be configured separately from the rent category.',
    );
  }
  const categories = Object.freeze(propertyChargeCategories.map((category) => category.trim()));
  if (new Set(categories).size !== categories.length
    || categories.includes(rentCategory.trim())) {
    throw new LandlordPropertyChargeInvoiceListError(
      'INVALID_CHARGE_CATEGORIES',
      'Configured charge categories must be unique after normalization and distinct from rent.',
    );
  }

  return async function listMyLandlordPropertyChargeInvoices({
    actorUserId,
    estateId,
    page = 1,
    pageSize = 25,
  } = {}) {
    if (!actorUserId || !estateId) {
      throw new LandlordPropertyChargeInvoiceListError(
        'INVALID_INPUT',
        'Authenticated actor and estate context are required.',
      );
    }
    const result = await listEstateInvoices({
      actorUserId,
      estateId,
      query: { categories, page, pageSize },
    });
    if (!result || !Array.isArray(result.items)) {
      throw new LandlordPropertyChargeInvoiceListError(
        'INVALID_INVOICE_RESULT',
        'The authorized invoice service returned an invalid result.',
      );
    }
    const allowed = new Set(categories);
    for (const invoice of result.items) {
      if (!allowed.has(invoice.category) || !visibleStatuses.has(invoice.status)) {
        throw new LandlordPropertyChargeInvoiceListError(
          'UNSAFE_INVOICE_RESULT',
          'The landlord property-charge list may contain only issued configured charge invoices.',
        );
      }
    }
    return result;
  };
}

module.exports = {
  LandlordPropertyChargeInvoiceListError,
  createMyLandlordPropertyChargeInvoiceListUseCase,
};
