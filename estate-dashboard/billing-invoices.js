(() => {
  const moduleContent = document.getElementById('moduleContent');
  if (!moduleContent) return;

  function hostConfig() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = hostConfig().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function listUrl() {
    const config = hostConfig();
    if (typeof config.invoiceListUrl === 'string' && config.invoiceListUrl.trim()) return config.invoiceListUrl.trim();
    const apiBase = typeof config.apiBaseUrl === 'string' ? config.apiBaseUrl.replace(/\/$/, '') : '';
    return apiBase && estateId() ? `${apiBase}/api/estate/invoices` : '';
  }
  const connected = Boolean(listUrl());
  if (!connected) return;

  const state = { page: 1, pageSize: 25, status: '', search: '', requestNumber: 0 };
  const statuses = new Set(['draft', 'issued', 'partially_paid', 'paid', 'cancelled']);

  function node(tag, className, content) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (content !== undefined) element.textContent = content;
    return element;
  }

  function endpoint() {
    const base = listUrl();
    const url = new URL(base, window.location.href);
    const selectedEstate = estateId();
    if (selectedEstate) url.searchParams.set('estateId', selectedEstate);
    url.searchParams.set('page', String(state.page));
    url.searchParams.set('pageSize', String(state.pageSize));
    if (state.status) url.searchParams.set('status', state.status);
    if (state.search) url.searchParams.set('search', state.search);
    return url.toString();
  }

  function detailEndpoint(invoiceId) {
    const config = hostConfig();
    let base = '';
    if (typeof config.invoiceDetailUrl === 'string' && config.invoiceDetailUrl.trim()) {
      base = config.invoiceDetailUrl.trim().replaceAll('{invoiceId}', encodeURIComponent(invoiceId)).replace(':invoiceId', encodeURIComponent(invoiceId));
    } else if (typeof config.apiBaseUrl === 'string' && config.apiBaseUrl.trim()) {
      base = `${config.apiBaseUrl.replace(/\/$/, '')}/api/estate/invoices/${encodeURIComponent(invoiceId)}`;
    }
    if (!base) return '';
    const url = new URL(base, window.location.href);
    if (estateId()) url.searchParams.set('estateId', estateId());
    return url.toString();
  }

  async function request(url) {
    const config = hostConfig();
    if (typeof config.request === 'function') {
      const result = await config.request({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && result instanceof Response) {
        if (!result.ok) throw new Error(`Invoice service returned an error (${result.status}).`);
        return result.json();
      }
      return result;
    }
    const response = await fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
    if (!response.ok) {
      const message = response.status === 401 ? 'Sign in to view estate invoices.'
        : response.status === 403 ? 'Your account cannot view these invoices.'
          : `Invoice service returned an error (${response.status}).`;
      throw new Error(message);
    }
    return response.json();
  }

  function moneyLabel(amount, currency) {
    if (typeof amount !== 'string' || !/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(amount)) return 'Amount unavailable';
    const negative = amount.startsWith('-');
    const digits = negative ? amount.slice(1) : amount;
    const [whole, fraction] = digits.split('.');
    return `${currency} ${negative ? '-' : ''}${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}${fraction ? `.${fraction}` : ''}`;
  }

  function dateLabel(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(date);
  }

  function statusInfo(invoice) {
    if (invoice.overdue) return ['Overdue', 'status-overdue'];
    const labels = {
      draft: ['Draft', 'status-review'],
      issued: ['Issued', 'status-invited'],
      partially_paid: ['Part paid', 'status-partial'],
      paid: ['Paid', 'status-paid'],
      cancelled: ['Cancelled', 'status-review'],
    };
    return labels[invoice.status] || ['Unavailable', 'status-review'];
  }

  function validateResponse(response) {
    const result = response?.data || response;
    if (!result || !Array.isArray(result.items) || !Number.isInteger(result.page)
      || !Number.isInteger(result.pageSize) || !Number.isSafeInteger(result.total)
      || !Number.isSafeInteger(result.totalPages)) {
      throw new Error('Invoice service returned an incomplete register response.');
    }
    if (result.items.some((item) => !item?.id || !statuses.has(item.status)
      || typeof item.invoiceNumber !== 'string' || typeof item.category !== 'string'
      || typeof item.total !== 'string' || !/^[A-Z]{3}$/.test(item.currency)
      || !Number.isFinite(Date.parse(item.dueAt)))) {
      throw new Error('Invoice service returned an invalid invoice summary.');
    }
    const selectedEstate = estateId();
    if (selectedEstate && result.estateId && String(result.estateId) !== selectedEstate) {
      throw new Error('Invoice service returned records for a different estate.');
    }
    return result;
  }

  function makeShell() {
    moduleContent.replaceChildren();
    const heading = document.createElement('div');
    heading.className = 'module-heading';
    const headingCopy = document.createElement('div');
    headingCopy.append(node('span', 'eyebrow', 'ESTATE FINANCE'), node('h2', '', 'Billing & rent'),
      node('p', '', 'Invoices and payment status from the authorized estate records.'));
    const refresh = node('button', 'button button-secondary', 'Refresh');
    refresh.type = 'button';
    refresh.addEventListener('click', loadInvoices);
    heading.append(headingCopy, refresh);

    const panel = document.createElement('article');
    panel.className = 'panel module-panel connected-invoice-panel';
    const toolbar = document.createElement('div');
    toolbar.className = 'module-toolbar connected-invoice-toolbar';
    const filters = document.createElement('div');
    filters.className = 'connected-invoice-filters';
    const statusSelect = document.createElement('select');
    statusSelect.className = 'filter-button';
    statusSelect.setAttribute('aria-label', 'Filter invoices by status');
    for (const [value, label] of [['', 'All invoices'], ['draft', 'Draft'], ['issued', 'Issued'], ['partially_paid', 'Part paid'], ['paid', 'Paid'], ['cancelled', 'Cancelled']]) {
      const option = node('option', '', label);
      option.value = value;
      statusSelect.append(option);
    }
    statusSelect.value = state.status;
    statusSelect.addEventListener('change', () => { state.status = statusSelect.value; state.page = 1; loadInvoices(); });
    filters.append(statusSelect);
    const search = document.createElement('input');
    search.className = 'filter-button connected-invoice-search';
    search.type = 'search';
    search.placeholder = 'Search invoice or payer';
    search.setAttribute('aria-label', 'Search invoices');
    search.value = state.search;
    let timer;
    search.addEventListener('input', () => {
      clearTimeout(timer);
      timer = setTimeout(() => { state.search = search.value.trim(); state.page = 1; loadInvoices(); }, 250);
    });
    filters.append(search);
    toolbar.append(filters);

    const status = node('div', 'connected-invoice-state', 'Loading invoices...');
    status.id = 'connectedInvoiceStatus';
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    const tableWrap = document.createElement('div');
    tableWrap.className = 'table-wrap module-table connected-invoice-table';
    const table = document.createElement('table');
    const head = document.createElement('thead');
    const headerRow = document.createElement('tr');
    for (const label of ['INVOICE', 'PAYER / PROPERTY', 'DUE DATE', 'TOTAL', 'BALANCE', 'STATUS']) headerRow.append(node('th', '', label));
    if (detailEndpoint('invoice-id')) headerRow.append(node('th', '', 'DETAILS'));
    head.append(headerRow);
    const body = document.createElement('tbody');
    body.id = 'connectedInvoiceRows';
    table.append(head, body);
    tableWrap.append(table);
    const footer = document.createElement('div');
    footer.className = 'module-table-foot connected-invoice-footer';
    const count = node('span', '', '');
    count.id = 'connectedInvoiceCount';
    const pagination = document.createElement('div');
    pagination.className = 'connected-invoice-pagination';
    const previous = node('button', 'table-action', 'Previous');
    previous.type = 'button';
    previous.addEventListener('click', () => { if (state.page > 1) { state.page -= 1; loadInvoices(); } });
    const pageLabel = node('span', '', '');
    pageLabel.id = 'connectedInvoicePage';
    const next = node('button', 'table-action', 'Next');
    next.type = 'button';
    next.addEventListener('click', () => { state.page += 1; loadInvoices(); });
    pagination.append(previous, pageLabel, next);
    footer.append(count, pagination);
    const note = node('div', 'finance-note', 'Payment status reflects the trusted payment service. Returning from a payment provider does not confirm settlement.');
    panel.append(toolbar, status, tableWrap, footer, note);
    moduleContent.append(heading, panel);
    return { status, body, count, pageLabel, previous, next };
  }

  let elements = null;
  async function loadInvoices() {
    if (document.getElementById('crumbCurrent')?.textContent !== 'Billing & rent') return;
    const requestId = ++state.requestNumber;
    elements = makeShell();
    try {
      const response = await request(endpoint());
      if (requestId !== state.requestNumber || document.getElementById('crumbCurrent')?.textContent !== 'Billing & rent') return;
      const result = validateResponse(response);
      elements.body.replaceChildren();
      if (!result.items.length) {
        elements.status.textContent = 'No invoices match these filters.';
        elements.status.dataset.state = 'empty';
      } else {
        elements.status.textContent = `Showing ${result.items.length} of ${result.total} authorized invoices`;
        elements.status.dataset.state = 'ready';
        for (const invoice of result.items) {
          const row = document.createElement('tr');
          const identity = document.createElement('td');
          identity.append(node('strong', '', invoice.invoiceNumber), node('small', 'cell-sub', invoice.category));
          const payer = document.createElement('td');
          payer.append(node('span', '', invoice.payerDisplayName || 'Payer'), node('small', 'cell-sub', invoice.propertyCode || invoice.tenancyLabel || ''));
          const [label, className] = statusInfo(invoice);
          const statusCell = document.createElement('td');
          statusCell.append(node('span', `status-pill ${className}`, label));
          row.append(identity, payer, node('td', '', dateLabel(invoice.dueAt)), node('td', 'amount-cell', moneyLabel(invoice.total, invoice.currency)),
            node('td', 'amount-cell', invoice.balance === null ? '—' : moneyLabel(invoice.balance, invoice.currency)), statusCell);
          if (detailEndpoint(invoice.id)) {
            const detailCell = document.createElement('td');
            const detail = node('button', 'table-action', 'Details');
            detail.type = 'button';
            detail.addEventListener('click', () => loadInvoiceDetail(invoice.id));
            detailCell.append(detail);
            row.append(detailCell);
          }
          elements.body.append(row);
        }
      }
      elements.count.textContent = `${result.total} invoice${result.total === 1 ? '' : 's'}`;
      elements.pageLabel.textContent = `Page ${result.page} of ${Math.max(1, result.totalPages)}`;
      elements.previous.disabled = result.page <= 1;
      elements.next.disabled = result.page >= result.totalPages;
    } catch (error) {
      if (requestId !== state.requestNumber || document.getElementById('crumbCurrent')?.textContent !== 'Billing & rent') return;
      elements.body.replaceChildren();
      elements.status.textContent = error.message || 'Invoices could not be loaded.';
      elements.status.dataset.state = 'error';
      elements.count.textContent = '';
      elements.pageLabel.textContent = '';
      elements.previous.disabled = true;
      elements.next.disabled = true;
      const retry = node('button', 'text-button connected-invoice-retry', 'Try again');
      retry.type = 'button';
      retry.addEventListener('click', loadInvoices);
      elements.status.append(' ', retry);
    }
  }

  async function loadInvoiceDetail(invoiceId) {
    const url = detailEndpoint(invoiceId);
    if (!url) return;
    const requestId = ++state.requestNumber;
    moduleContent.replaceChildren();
    const heading = document.createElement('div');
    heading.className = 'module-heading';
    const copy = document.createElement('div');
    copy.append(node('span', 'eyebrow', 'ESTATE FINANCE'), node('h2', '', 'Invoice details'),
      node('p', '', 'Issued terms and confirmed payment history.'));
    const back = node('button', 'button button-secondary', 'Back to invoices');
    back.type = 'button';
    back.addEventListener('click', loadInvoices);
    heading.append(copy, back);
    const panel = document.createElement('article');
    panel.className = 'panel module-panel connected-invoice-panel';
    const status = node('div', 'connected-invoice-state', 'Loading invoice details...');
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    const content = document.createElement('div');
    content.className = 'connected-invoice-detail';
    panel.append(status, content);
    moduleContent.append(heading, panel);
    try {
      const response = await request(url);
      if (requestId !== state.requestNumber || document.getElementById('crumbCurrent')?.textContent !== 'Billing & rent') return;
      const invoice = response?.data || response;
      if (!invoice?.id || String(invoice.id) !== String(invoiceId) || !Array.isArray(invoice.lines)
        || !Array.isArray(invoice.paymentHistory) || !/^[A-Z]{3}$/.test(invoice.currency)
        || typeof invoice.total !== 'string' || !statuses.has(invoice.status)
        || typeof invoice.invoiceNumber !== 'string' || typeof invoice.category !== 'string'
        || invoice.lines.some((line) => !line || typeof line.description !== 'string'
          || typeof line.amount !== 'string' || line.currency !== invoice.currency)
        || invoice.paymentHistory.some((payment) => !payment || !['applied', 'reversed'].includes(payment.state)
          || typeof payment.amount !== 'string' || !/^[A-Z]{3}$/.test(payment.currency))) {
        throw new Error('Invoice service returned an incomplete detail response.');
      }
      status.textContent = `${invoice.invoiceNumber} · ${invoice.status}${invoice.overdue ? ' · overdue' : ''}`;
      status.dataset.state = 'ready';
      const summary = document.createElement('dl');
      summary.className = 'connected-invoice-summary';
      for (const [label, value] of [
        ['Payer', invoice.payerDisplayName || '—'], ['Payee', invoice.payeeDisplayName || '—'],
        ['Property', invoice.propertyCode || invoice.tenancyLabel || '—'], ['Category', invoice.category],
        ['Issued', invoice.issuedAt ? dateLabel(invoice.issuedAt) : 'Draft'], ['Due', dateLabel(invoice.dueAt)],
        ['Total', moneyLabel(invoice.total, invoice.currency)], ['Paid', invoice.allocated === null ? '—' : moneyLabel(invoice.allocated, invoice.currency)],
        ['Balance', invoice.balance === null ? '—' : moneyLabel(invoice.balance, invoice.currency)],
      ]) {
        const item = document.createElement('div');
        item.append(node('dt', '', label), node('dd', '', value));
        summary.append(item);
      }
      const lineSection = document.createElement('section');
      lineSection.className = 'connected-invoice-detail-section';
      lineSection.append(node('h3', '', 'Invoice lines'));
      const lines = document.createElement('div');
      lines.className = 'connected-invoice-line-list';
      for (const line of invoice.lines) {
        const item = document.createElement('div');
        item.append(node('span', '', line.description), node('strong', '', moneyLabel(line.amount, invoice.currency)));
        lines.append(item);
      }
      lineSection.append(lines);
      const paymentSection = document.createElement('section');
      paymentSection.className = 'connected-invoice-detail-section';
      paymentSection.append(node('h3', '', 'Confirmed payment history'));
      const payments = document.createElement('div');
      payments.className = 'connected-invoice-line-list';
      if (!invoice.paymentHistory.length) payments.append(node('p', 'connected-invoice-muted', 'No confirmed payments recorded.'));
      for (const payment of invoice.paymentHistory) {
        const item = document.createElement('div');
        const label = `${payment.state === 'reversed' ? 'Reversed allocation' : 'Payment allocation'} · ${dateLabel(payment.occurredAt)}`;
        item.append(node('span', '', label), node('strong', '', moneyLabel(payment.amount, payment.currency)));
        payments.append(item);
      }
      paymentSection.append(payments);
      content.append(summary, lineSection, paymentSection);
    } catch (error) {
      if (requestId !== state.requestNumber || document.getElementById('crumbCurrent')?.textContent !== 'Billing & rent') return;
      status.textContent = error.message || 'Invoice details could not be loaded.';
      status.dataset.state = 'error';
      const retry = node('button', 'text-button connected-invoice-retry', 'Try again');
      retry.type = 'button';
      retry.addEventListener('click', () => loadInvoiceDetail(invoiceId));
      status.append(' ', retry);
    }
  }

  window.refreshEstateInvoiceRegister = loadInvoices;
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view === 'billing') loadInvoices();
    else state.requestNumber += 1;
  });
  window.addEventListener('estate:context-changed', () => {
    state.page = 1;
    if (document.getElementById('crumbCurrent')?.textContent === 'Billing & rent') loadInvoices();
  });
  if (document.getElementById('crumbCurrent')?.textContent === 'Billing & rent') loadInvoices();
})();
