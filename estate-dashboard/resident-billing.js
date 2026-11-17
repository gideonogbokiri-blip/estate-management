(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function apiBase() {
    return typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
  }
  function collectionUrl() {
    const url = config().residentInvoiceListUrl || config().invoiceListUrl;
    if (typeof url === 'string' && url.trim()) return url.trim();
    return apiBase() ? `${apiBase()}/api/estate/invoices` : '';
  }
  const connected = Boolean(estateId() && collectionUrl());
  if (!connected) return;

  const modal = document.getElementById('invoiceDetailModal');
  const state = { invoices: [], total: 0, byId: new Map(), currentInvoice: null, attemptId: '', attemptInvoiceId: '', idempotencyKeys: new Map() };

  function element(tag, className, text) {
    const value = document.createElement(tag);
    if (className) value.className = className;
    if (text !== undefined) value.textContent = text;
    return value;
  }

  function money(value, currency) {
    if (typeof value !== 'string' || !/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(value)) return `${currency} —`;
    const negative = value.startsWith('-');
    const [whole, fraction] = (negative ? value.slice(1) : value).split('.');
    return `${currency} ${negative ? '-' : ''}${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}${fraction ? `.${fraction}` : ''}`;
  }

  function date(value, options = { dateStyle: 'medium' }) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat(undefined, options).format(parsed);
  }

  function addEstate(url) {
    const endpoint = new URL(url, window.location.href);
    endpoint.searchParams.set('estateId', estateId());
    return endpoint.toString();
  }

  function invoiceDetailUrl(invoiceId) {
    const custom = config().residentInvoiceDetailUrl || config().invoiceDetailUrl;
    let url = '';
    if (typeof custom === 'string' && custom.trim()) {
      url = custom.trim().replaceAll('{invoiceId}', encodeURIComponent(invoiceId)).replace(':invoiceId', encodeURIComponent(invoiceId));
    } else if (apiBase()) url = `${apiBase()}/api/estate/invoices/${encodeURIComponent(invoiceId)}`;
    return url ? addEstate(url) : '';
  }

  function paymentRequestUrl(invoiceId) {
    const custom = config().residentPaymentRequestUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return addEstate(custom.trim().replaceAll('{invoiceId}', encodeURIComponent(invoiceId)).replace(':invoiceId', encodeURIComponent(invoiceId)));
    }
    return apiBase() ? addEstate(`${apiBase()}/api/estate/invoices/${encodeURIComponent(invoiceId)}/payments`) : '';
  }

  function attemptUrl(attemptId) {
    const custom = config().residentPaymentAttemptUrl || config().paymentAttemptUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return addEstate(custom.trim().replaceAll('{attemptId}', encodeURIComponent(attemptId)).replace(':attemptId', encodeURIComponent(attemptId)));
    }
    return apiBase() ? addEstate(`${apiBase()}/api/estate/payments/${encodeURIComponent(attemptId)}`) : '';
  }

  function receiptUrl(receiptId) {
    const custom = config().residentReceiptUrl || config().receiptUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return addEstate(custom.trim().replaceAll('{receiptId}', encodeURIComponent(receiptId)).replace(':receiptId', encodeURIComponent(receiptId)));
    }
    return apiBase() ? addEstate(`${apiBase()}/api/estate/receipts/${encodeURIComponent(receiptId)}`) : '';
  }

  async function apiRequest(url, method = 'GET', payload) {
    const adapter = config().request;
    if (typeof adapter === 'function') {
      const response = await adapter({ url, method, payload, credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw new Error(`Estate payment service returned an error (${response.status}).`);
        return response.json();
      }
      return response;
    }
    if (method !== 'GET') throw new Error('Payment actions require the host authenticated API request adapter.');
    const response = await fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
    if (!response.ok) {
      throw new Error(response.status === 401 ? 'Sign in to view your invoices.'
        : response.status === 403 ? 'Your account cannot view these invoices.'
          : `Estate invoice service returned an error (${response.status}).`);
    }
    return response.json();
  }

  function dataOf(response) { return response?.data || response; }

  function invoiceListStatus() {
    let status = document.getElementById('residentInvoiceStatus');
    if (!status) {
      status = element('div', 'resident-live-invoice-status');
      status.id = 'residentInvoiceStatus';
      status.setAttribute('role', 'status');
      status.setAttribute('aria-live', 'polite');
      const payments = document.querySelector('[data-screen="payments"]');
      const title = payments?.querySelector('.section-title.list-title');
      if (title) title.after(status);
    }
    return status;
  }

  function invoiceListContainer() {
    let list = document.getElementById('residentInvoiceList');
    if (list) return list;
    const payments = document.querySelector('[data-screen="payments"]');
    if (!payments) return null;
    list = element('div', 'resident-live-invoice-list');
    list.id = 'residentInvoiceList';
    const detailButton = payments.querySelector('.invoice-detail-link');
    if (detailButton) detailButton.before(list);
    else payments.append(list);
    payments.querySelectorAll(':scope > .mobile-list-card').forEach((card) => card.remove());
    const filterButton = payments.querySelector('.filter-pill[data-action="invoice-filter"]');
    if (filterButton) {
      const filter = document.createElement('select');
      filter.id = 'residentInvoiceFilter';
      filter.className = 'filter-pill resident-live-invoice-filter';
      filter.setAttribute('aria-label', 'Filter invoices');
      for (const [value, label] of [['all', 'All'], ['issued', 'Due'], ['partially_paid', 'Part paid'], ['paid', 'Paid'], ['draft', 'Draft'], ['cancelled', 'Cancelled']]) {
        const option = element('option', '', label);
        option.value = value;
        filter.append(option);
      }
      filter.addEventListener('change', () => {
        document.querySelectorAll('.resident-invoice-card').forEach((card) => {
          card.classList.toggle('hidden', filter.value !== 'all' && card.dataset.invoiceState !== filter.value);
        });
      });
      filterButton.replaceWith(filter);
    }
    return list;
  }

  function hasPositiveAmount(value) {
    return typeof value === 'string' && /^\d+(?:\.\d+)?$/.test(value)
      && value.replace('.', '').replace(/0/g, '') !== '';
  }

  function openStatus(message, stateName = 'pending', addCheck = true) {
    let status = document.getElementById('residentPaymentRequestStatus');
    if (!status) {
      status = element('p', 'resident-payment-request-status');
      status.id = 'residentPaymentRequestStatus';
      status.setAttribute('role', 'status');
      status.setAttribute('aria-live', 'polite');
      modal?.querySelector('.invoice-modal-actions')?.after(status);
    }
    status.replaceChildren(document.createTextNode(message));
    status.dataset.state = stateName;
    status.classList.remove('hidden');
    if (addCheck && state.attemptId) {
      const check = element('button', 'resident-payment-check', 'Check status');
      check.type = 'button';
      check.dataset.action = 'check-payment-status';
      status.append(' ', check);
    }
    return status;
  }

  function statusLabel(invoice) {
    if (invoice.overdue) return ['Overdue', 'status-due'];
    if (invoice.status === 'paid') return ['Paid', 'status-paid'];
    if (invoice.status === 'partially_paid') return ['Part paid', 'status-review'];
    if (invoice.status === 'draft') return ['Draft', 'status-review'];
    if (invoice.status === 'cancelled') return ['Cancelled', 'status-review'];
    return ['Due', 'status-due'];
  }

  function makeInvoiceCard(invoice) {
    const card = element('article', 'mobile-list-card resident-invoice-card');
    card.tabIndex = 0;
    card.setAttribute('role', 'button');
    card.dataset.action = 'invoice-details';
    card.dataset.invoiceId = String(invoice.id);
    card.dataset.invoiceState = invoice.status;
    const mark = element('span', `invoice-mark${invoice.status === 'paid' ? ' paid-mark' : ''}`, '▤');
    const copy = element('span', 'mobile-list-copy');
    copy.append(element('strong', '', invoice.category || 'Estate charge'),
      element('small', '', `${invoice.invoiceNumber} · Due ${date(invoice.dueAt)}`),
      element('b', '', money(invoice.balance === null ? invoice.total : invoice.balance, invoice.currency)));
    const [label, statusClass] = statusLabel(invoice);
    card.append(mark, copy, element('span', `mini-status ${statusClass}`, label));
    card.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openResidentInvoice(invoice.id);
      }
    });
    return card;
  }

  function dueInvoices() {
    return state.invoices.filter((invoice) => ['issued', 'partially_paid'].includes(invoice.status)
      && hasPositiveAmount(invoice.balance));
  }

  function sumOutstanding(invoices) {
    if (!invoices.length) return null;
    const currency = invoices[0].currency;
    if (invoices.some((invoice) => invoice.currency !== currency || typeof invoice.balance !== 'string')) return { currency: '', total: 'Multiple currencies' };
    const scale = Math.max(0, ...invoices.map((invoice) => (invoice.balance.split('.')[1] || '').length));
    const totalMinor = invoices.reduce((sum, invoice) => {
      const [whole, fraction = ''] = invoice.balance.split('.');
      return sum + BigInt(whole) * (10n ** BigInt(scale)) + BigInt(fraction.padEnd(scale, '0') || '0');
    }, 0n);
    const digits = totalMinor.toString().padStart(scale + 1, '0');
    const amount = scale ? `${digits.slice(0, -scale)}.${digits.slice(-scale)}` : digits;
    return { currency, total: money(amount, currency) };
  }

  function updateHomeInvoice() {
    const due = dueInvoices().sort((a, b) => Date.parse(a.dueAt) - Date.parse(b.dueAt));
    const card = document.querySelector('.due-card');
    const payButton = card?.querySelector('.pay-button');
    if (!due.length) {
      if (card) {
        card.querySelector('.due-status').textContent = state.total > state.invoices.length ? 'MORE RECORDS' : 'ALL CLEAR';
        card.querySelector('.due-label').textContent = state.total > state.invoices.length ? 'More invoices available' : 'No outstanding invoice';
        card.querySelector('.due-amount').textContent = '—';
        card.querySelector('.due-meta').textContent = state.total > state.invoices.length
          ? 'Open My payments to review the full invoice list.' : 'Your current invoices are settled.';
      }
      if (payButton) {
        payButton.dataset.invoiceId = '';
        if (state.total > state.invoices.length) {
          payButton.removeAttribute('data-action');
          payButton.dataset.screenLink = 'payments';
          payButton.disabled = false;
          payButton.textContent = 'View invoices →';
        } else {
          payButton.removeAttribute('data-screen-link');
          payButton.dataset.action = 'pay-now';
          payButton.disabled = true;
        }
      }
      return;
    }
    const invoice = due[0];
    if (card) {
      card.querySelector('.due-status').textContent = invoice.overdue ? 'OVERDUE' : 'PAYMENT DUE';
      card.querySelector('.due-label').textContent = invoice.category;
      card.querySelector('.due-amount').textContent = money(invoice.balance, invoice.currency);
      card.querySelector('.due-meta').textContent = `Due ${date(invoice.dueAt)} · ${invoice.propertyCode || 'Your property'}`;
    }
    if (payButton) {
      payButton.removeAttribute('data-screen-link');
      payButton.dataset.action = 'pay-now';
      payButton.disabled = false;
      payButton.dataset.invoiceId = String(invoice.id);
    }
  }

  function updateOutstandingCard() {
    const card = document.querySelector('[data-screen="payments"] .balance-card');
    if (!card) return;
    const due = dueInvoices();
    const total = sumOutstanding(due);
    card.querySelector('strong').textContent = state.total > state.invoices.length ? 'More invoices' : total?.total || 'No balance due';
    card.querySelector('small').textContent = state.total > state.invoices.length
      ? `Showing ${state.invoices.length} of ${state.total} invoices`
      : `${due.length} invoice${due.length === 1 ? '' : 's'} outstanding`;
    const button = card.querySelector('button');
    const first = due[0];
    if (button) {
      button.dataset.invoiceId = first ? String(first.id) : '';
      if (!first && state.total > state.invoices.length) {
        button.removeAttribute('data-action');
        button.dataset.screenLink = 'payments';
        button.disabled = false;
        button.textContent = 'View invoice list →';
      } else {
        button.removeAttribute('data-screen-link');
        button.dataset.action = 'pay-now';
        button.disabled = !first;
        button.textContent = first ? 'Pay next invoice →' : 'No payment due';
      }
    }
  }

  function renderInvoiceList() {
    const list = invoiceListContainer();
    const status = invoiceListStatus();
    if (!list) return;
    list.replaceChildren(...state.invoices.map(makeInvoiceCard));
    status.textContent = state.invoices.length
      ? `Showing ${state.invoices.length} of ${state.total} authorized invoice${state.total === 1 ? '' : 's'}.`
      : 'No invoices are available for this property.';
    status.dataset.state = state.invoices.length ? 'ready' : 'empty';
    const firstDue = dueInvoices()[0] || state.invoices[0];
    const detailsButton = document.querySelector('.invoice-detail-link');
    if (detailsButton) {
      detailsButton.dataset.invoiceId = firstDue ? String(firstDue.id) : '';
      detailsButton.disabled = !firstDue;
    }
  }

  async function loadInvoices() {
    const status = invoiceListStatus();
    const list = invoiceListContainer();
    status.textContent = 'Loading your invoices...';
    status.dataset.state = 'loading';
    if (list) list.replaceChildren();
    const dueCard = document.querySelector('.due-card');
    const duePayButton = dueCard?.querySelector('.pay-button');
    if (duePayButton) { duePayButton.disabled = true; duePayButton.dataset.invoiceId = ''; }
    if (dueCard) {
      dueCard.querySelector('.due-label').textContent = 'Loading invoices';
      dueCard.querySelector('.due-amount').textContent = '—';
      dueCard.querySelector('.due-meta').textContent = 'Your estate billing records are loading.';
    }
    const balanceCard = document.querySelector('[data-screen="payments"] .balance-card');
    if (balanceCard) {
      balanceCard.querySelector('strong').textContent = '—';
      balanceCard.querySelector('small').textContent = 'Loading invoices...';
      const button = balanceCard.querySelector('[data-action="pay-now"]');
      if (button) button.disabled = true;
    }
    const detailsButton = document.querySelector('.invoice-detail-link');
    if (detailsButton) detailsButton.disabled = true;
    try {
      const url = new URL(collectionUrl(), window.location.href);
      url.searchParams.set('estateId', estateId());
      url.searchParams.set('page', '1');
      url.searchParams.set('pageSize', '100');
      const response = dataOf(await apiRequest(url.toString()));
      if (!response || !Array.isArray(response.items) || response.items.some((invoice) => !invoice?.id
        || typeof invoice.invoiceNumber !== 'string' || !/^[A-Z]{3}$/.test(invoice.currency)
        || typeof invoice.total !== 'string' || typeof invoice.status !== 'string')) {
        throw new Error('Invoice service returned an incomplete response.');
      }
      state.invoices = response.items;
      state.total = Number.isSafeInteger(response.total) && response.total >= response.items.length ? response.total : response.items.length;
      state.byId = new Map(state.invoices.map((invoice) => [String(invoice.id), invoice]));
      renderInvoiceList();
      updateHomeInvoice();
      updateOutstandingCard();
      document.querySelector('.preview-badge').textContent = 'LIVE';
      const history = document.getElementById('residentPaymentHistory');
      if (history) {
        history.replaceChildren(element('p', 'payment-history-note', 'Payment records appear after a confirmed allocation. Open an invoice to view its verified payment history.'));
      }
    } catch (error) {
      state.invoices = [];
      state.total = 0;
      state.byId.clear();
      if (list) list.replaceChildren();
      status.textContent = error.message || 'Your invoices could not be loaded.';
      status.dataset.state = 'error';
      if (dueCard) {
        dueCard.querySelector('.due-status').textContent = 'UNAVAILABLE';
        dueCard.querySelector('.due-label').textContent = 'Invoices could not be loaded';
        dueCard.querySelector('.due-amount').textContent = '—';
        dueCard.querySelector('.due-meta').textContent = 'Refresh the page or contact your estate administrator.';
      }
      updateOutstandingCard();
      const history = document.getElementById('residentPaymentHistory');
      if (history) history.replaceChildren(element('p', 'payment-history-note', 'Verified payment history is unavailable until the invoice service reconnects.'));
      document.querySelector('.preview-badge').textContent = 'SERVICE UNAVAILABLE';
    }
  }

  function renderPaymentHistory(invoice) {
    const history = document.getElementById('residentPaymentHistory');
    if (!history) return;
    history.replaceChildren();
    const title = document.createElement('div');
    title.className = 'section-title list-title';
    const copy = document.createElement('div');
    copy.append(element('h2', '', 'Verified payment history'), element('p', '', invoice.invoiceNumber));
    title.append(copy, element('span', 'verified-history-label', 'Settled allocations'));
    history.append(title);
    if (!invoice.paymentHistory.length) {
      history.append(element('p', 'payment-history-note', 'No confirmed allocations for this invoice.'));
      return;
    }
    for (const payment of invoice.paymentHistory) {
      const record = document.createElement('article');
      record.className = 'payment-history-card';
      record.append(element('span', `payment-state-mark ${payment.state === 'applied' ? 'settled-mark' : 'pending-mark'}`, payment.state === 'applied' ? '✓' : '↶'));
      const details = document.createElement('div');
      details.append(element('strong', '', payment.state === 'applied' ? 'Verified payment allocation' : 'Allocation reversed'),
        element('small', '', `Confirmed ${date(payment.verifiedAt)}`),
        element('b', '', `${money(payment.amount, payment.currency)} · ${date(payment.occurredAt)}`));
      record.append(details);
      if (payment.receiptId) {
        const receipt = element('button', 'payment-receipt-link', 'View receipt');
        receipt.type = 'button';
        receipt.dataset.action = 'receipt-detail';
        receipt.dataset.receiptId = String(payment.receiptId);
        record.append(receipt);
      }
      history.append(record);
    }
  }

  async function openResidentInvoice(invoiceId) {
    const selectedId = invoiceId || (dueInvoices()[0]?.id ?? state.invoices[0]?.id);
    if (!selectedId) { residentMessage('There are no invoices available for this estate account.'); return; }
    if (state.attemptInvoiceId && String(state.attemptInvoiceId) !== String(selectedId)) {
      state.attemptId = '';
      state.attemptInvoiceId = '';
    }
    const detailUrl = invoiceDetailUrl(selectedId);
    const baseRecord = state.byId.get(String(selectedId));
    state.currentInvoice = baseRecord || null;
    const title = document.getElementById('invoiceDetailTitle');
    const subtitle = modal.querySelector('.invoice-detail-subtitle');
    const lines = modal.querySelector('.invoice-detail-lines');
    const paymentNote = modal.querySelector('.invoice-payment-note span');
    const payButton = modal.querySelector('[data-action="begin-payment"]');
    const previewNote = modal.querySelector('.invoice-preview-disclaimer');
    title.textContent = baseRecord?.category || 'Invoice details';
    subtitle.textContent = 'Loading authorized invoice details...';
    lines.replaceChildren(element('span', '', 'Loading invoice lines...'));
    document.getElementById('residentPaymentRequestStatus')?.classList.add('hidden');
    modal.classList.remove('hidden');
    payButton.disabled = true;
    if (!detailUrl) {
      if (baseRecord) {
        state.currentInvoice = baseRecord;
        title.textContent = baseRecord.category;
        subtitle.textContent = `${baseRecord.invoiceNumber} · Due ${date(baseRecord.dueAt)}`;
        lines.replaceChildren();
        for (const [label, value] of [['Invoice total', money(baseRecord.total, baseRecord.currency)], ['Balance due', money(baseRecord.balance, baseRecord.currency)]]) {
          const row = document.createElement('div'); row.append(element('span', '', label), element('strong', '', value)); lines.append(row);
        }
        payButton.disabled = !['issued', 'partially_paid'].includes(baseRecord.status) || !hasPositiveAmount(baseRecord.balance);
        if (previewNote) previewNote.textContent = 'Invoice detail service is not configured.';
      }
      return;
    }
    try {
      const invoice = dataOf(await apiRequest(detailUrl));
      if (!invoice?.id || String(invoice.id) !== String(selectedId) || !Array.isArray(invoice.lines)
        || !Array.isArray(invoice.paymentHistory) || !/^[A-Z]{3}$/.test(invoice.currency)) {
        throw new Error('Invoice service returned incomplete details.');
      }
      state.currentInvoice = invoice;
      state.byId.set(String(invoice.id), invoice);
      title.textContent = invoice.category;
      subtitle.textContent = `${invoice.invoiceNumber} · ${invoice.issuedAt ? `Issued ${date(invoice.issuedAt)} · ` : ''}Due ${date(invoice.dueAt)} · ${invoice.propertyCode || 'Your property'}`;
      lines.replaceChildren();
      for (const line of invoice.lines) {
        const row = document.createElement('div'); row.append(element('span', '', line.description), element('strong', '', money(line.amount, invoice.currency))); lines.append(row);
      }
      for (const [label, value] of [['Amount paid', invoice.allocated === null ? '—' : money(invoice.allocated, invoice.currency)], ['Balance due', invoice.balance === null ? '—' : money(invoice.balance, invoice.currency)]]) {
        const row = document.createElement('div'); row.append(element('span', '', label), element('strong', '', value)); lines.append(row);
      }
      const payable = ['issued', 'partially_paid'].includes(invoice.status) && hasPositiveAmount(invoice.balance);
      payButton.disabled = !payable;
      payButton.textContent = payable ? 'Continue to payment' : 'No payment due';
      if (paymentNote) paymentNote.textContent = 'A payment request stays pending until Zvend confirms settlement.';
      if (previewNote) previewNote.classList.add('hidden');
      renderPaymentHistory(invoice);
    } catch (error) {
      subtitle.textContent = error.message || 'Invoice details could not be loaded.';
      lines.replaceChildren();
      payButton.disabled = true;
      if (previewNote) previewNote.textContent = 'Refresh your invoice list or contact your estate administrator.';
    }
  }

  function newIdempotencyKey(invoiceId) {
    if (state.idempotencyKeys.has(String(invoiceId))) return state.idempotencyKeys.get(String(invoiceId));
    const storageKey = `zvend.estate.payment.${estateId()}.${String(invoiceId)}`;
    let key = '';
    try { key = window.sessionStorage.getItem(storageKey) || ''; } catch { /* Storage can be disabled by the browser. */ }
    if (!key) {
      key = typeof window.crypto?.randomUUID === 'function' ? window.crypto.randomUUID()
        : `${Date.now()}-${Math.random().toString(36).slice(2)}-${String(invoiceId)}`;
      try { window.sessionStorage.setItem(storageKey, key); } catch { /* The in-memory key still supports retries during this page session. */ }
    }
    state.idempotencyKeys.set(String(invoiceId), key);
    return key;
  }

  function clearIdempotencyKey(invoiceId) {
    if (!invoiceId) return;
    state.idempotencyKeys.delete(String(invoiceId));
    try { window.sessionStorage.removeItem(`zvend.estate.payment.${estateId()}.${String(invoiceId)}`); } catch { /* Storage can be disabled by the browser. */ }
  }

  async function beginPayment() {
    const invoice = state.currentInvoice;
    if (!invoice?.id) { openStatus('Open an invoice before requesting payment.', 'error', false); return; }
    const endpoint = paymentRequestUrl(invoice.id);
    if (!endpoint || typeof config().request !== 'function') {
      openStatus('Payment actions require the host authenticated Zvend payment adapter.', 'error', false);
      return;
    }
    const button = modal.querySelector('[data-action="begin-payment"]');
    button.disabled = true;
    button.textContent = 'Requesting payment...';
    try {
      const response = dataOf(await apiRequest(endpoint, 'POST', { idempotencyKey: newIdempotencyKey(invoice.id) }));
      if (!response?.attemptId || !['created', 'pending', 'succeeded', 'failed', 'expired', 'reversed', 'refunded'].includes(response.state)) {
        throw new Error('Payment service returned an incomplete attempt.');
      }
      state.attemptId = response.attemptId;
      state.attemptInvoiceId = String(invoice.id);
      const message = response.state === 'succeeded'
        ? 'Payment confirmed by Zvend.'
        : `Payment request ${response.state}. This is not a settlement confirmation.`;
      openStatus(message, response.state, response.state !== 'succeeded');
      await refreshPaymentAttempt();
      if (typeof config().openPaymentAttempt === 'function' && ['created', 'pending'].includes(response.state)) {
        try {
          await config().openPaymentAttempt({ attemptId: response.attemptId, invoiceId: invoice.id, state: response.state, amount: response.amount, currency: response.currency });
        } catch {
          openStatus('Your payment request was saved, but the Zvend payment screen could not be opened. Check its status or try again.', 'pending', true);
        }
      }
    } catch (error) {
      openStatus(error.message || 'Payment request could not be created.', 'error', false);
      button.disabled = false;
      button.textContent = 'Retry payment request';
    }
  }

  async function refreshPaymentAttempt() {
    if (!state.attemptId || !state.currentInvoice?.id
      || String(state.currentInvoice.id) !== String(state.attemptInvoiceId)) return;
    const endpoint = attemptUrl(state.attemptId);
    if (!endpoint) return;
    try {
      const result = dataOf(await apiRequest(endpoint));
      if (String(result.attemptId) !== String(state.attemptId)
        || !['created', 'pending', 'succeeded', 'failed', 'expired', 'reversed', 'refunded'].includes(result.state)) {
        throw new Error('Payment service returned an invalid attempt status.');
      }
      const message = result.state === 'succeeded'
        ? `Payment confirmed ${result.confirmedAt ? date(result.confirmedAt) : 'by Zvend'}.`
        : `Payment status: ${result.state}. This is not a settlement confirmation.`;
      openStatus(message, result.state, result.state !== 'succeeded');
      if (result.state === 'succeeded') {
        clearIdempotencyKey(state.currentInvoice?.id);
        await loadInvoices();
        if (state.currentInvoice?.id) await openResidentInvoice(state.currentInvoice.id);
      } else if (['failed', 'expired', 'reversed', 'refunded'].includes(result.state)) {
        clearIdempotencyKey(state.currentInvoice?.id);
        const button = modal.querySelector('[data-action="begin-payment"]');
        if (button && state.currentInvoice?.status !== 'paid') {
          button.disabled = false;
          button.textContent = 'Try payment again';
        }
      }
    } catch (error) {
      openStatus(error.message || 'Payment status could not be refreshed.', 'error', true);
    }
  }

  async function openResidentReceipt(receiptId) {
    if (!receiptId) return;
    const url = receiptUrl(receiptId);
    const receiptModal = document.getElementById('receiptDetailModal');
    const lines = document.getElementById('receiptDetailLines');
    const title = document.getElementById('receiptDetailTitle');
    const verified = receiptModal.querySelector('.receipt-verified-label');
    const privacy = receiptModal.querySelector('.receipt-privacy-note');
    const successMark = receiptModal.querySelector('.receipt-success-mark');
    title.textContent = 'Payment receipt';
    verified.textContent = 'Loading verified receipt…';
    successMark.classList.add('hidden');
    lines.replaceChildren();
    receiptModal.classList.remove('hidden');
    if (!url) {
      verified.textContent = 'Receipt service unavailable';
      privacy.textContent = 'Connect the authorized Zvend receipt service to retrieve this record.';
      return;
    }
    try {
      const receipt = dataOf(await apiRequest(url));
      if (!receipt || String(receipt.receiptId) !== String(receiptId)
        || receipt.verificationStatus !== 'verified' || !/^[A-Z]{3}$/.test(receipt.currency)
        || typeof receipt.amount !== 'string' || typeof receipt.receiptNumber !== 'string') {
        throw new Error('Receipt service returned an incomplete or unverified record.');
      }
      title.textContent = 'Payment receipt';
      verified.textContent = receipt.allocationState === 'reversed'
        ? 'Original settlement verified · allocation later reversed'
        : 'Verified settled payment';
      successMark.textContent = receipt.allocationState === 'reversed' ? '↶' : '✓';
      successMark.classList.remove('hidden');
      lines.replaceChildren();
      const fields = [
        ['Receipt reference', receipt.receiptNumber], ['Invoice', receipt.invoiceNumber],
        ['Description', receipt.description || 'Estate payment'], ['Payer', receipt.payerDisplayName || '—'],
        ['Payee', receipt.payeeDisplayName || '—'], ['Property', receipt.propertyCode || '—'],
        ['Settled on', date(receipt.settledAt, { dateStyle: 'medium', timeStyle: 'short' })],
        ['Amount received', money(receipt.amount, receipt.currency)],
      ];
      for (const [label, value] of fields) {
        const row = document.createElement('div');
        row.append(element('span', '', label), element('strong', '', value));
        lines.append(row);
      }
      privacy.textContent = 'Verified receipt metadata is shown. Receipt file download is not connected in this workspace.';
    } catch (error) {
      verified.textContent = 'Receipt unavailable';
      successMark.classList.add('hidden');
      privacy.textContent = error.message || 'The verified receipt could not be loaded.';
    }
  }

  window.openResidentInvoice = openResidentInvoice;
  window.openResidentReceipt = openResidentReceipt;
  window.beginResidentInvoicePayment = beginPayment;
  window.refreshResidentPaymentAttempt = refreshPaymentAttempt;
  const previewBadge = document.querySelector('.preview-badge');
  if (previewBadge) previewBadge.textContent = 'CONNECTING';
  invoiceListContainer();
  const previewHistory = document.getElementById('residentPaymentHistory');
  if (previewHistory) previewHistory.replaceChildren(element('p', 'payment-history-note', 'Loading confirmed payment history from your invoices...'));
  loadInvoices();
  window.addEventListener('focus', () => { if (state.attemptId) refreshPaymentAttempt(); });
})();
