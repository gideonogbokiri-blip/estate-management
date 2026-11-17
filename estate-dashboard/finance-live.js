(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function listUrl() {
    const custom = config().expenseListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/expenses` : '';
  }
  function budgetUrl() {
    const custom = config().budgetSummaryUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/finance/budgets` : '';
  }
  if (!estateId() || !listUrl()) return;
  const state = { generation: 0, filter: '', search: '', page: 1, pageSize: 50, totalPages: 0 };
  let debounceTimer;

  async function request(url) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('Finance requires the host authenticated API request adapter.');
    const response = await adapter({ url, method: 'GET', credentials: 'same-origin' });
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error(`Expense service returned an error (${response.status}).`);
      const body = await response.json();
      return body?.data ?? body;
    }
    return response?.data ?? response;
  }
  function url() {
    const target = new URL(listUrl(), window.location.href);
    target.searchParams.set('estateId', estateId());
    target.searchParams.set('page', String(state.page));
    target.searchParams.set('pageSize', String(state.pageSize));
    if (state.filter) target.searchParams.set('status', state.filter);
    if (state.search) target.searchParams.set('search', state.search);
    return target.toString();
  }
  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function amount(item, value) {
    if (typeof value !== 'string' || !/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(value)) return 'Amount unavailable';
    const negative = value.startsWith('-');
    const [whole, fraction = ''] = (negative ? value.slice(1) : value).split('.');
    const grouped = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(BigInt(whole));
    const decimal = item.currencyScale ? `.${fraction.padEnd(item.currencyScale, '0').slice(0, item.currencyScale)}` : '';
    return `${item.currency} ${negative ? '−' : ''}${grouped}${decimal}`;
  }
  function budgetPercent(committed, total, scale, clamp = true) {
    try {
      const validMoney = (value) => typeof value === 'string' && /^\d+(?:\.\d+)?$/.test(value);
      if (!validMoney(committed) || !validMoney(total) || !Number.isInteger(scale) || scale < 0 || scale > 6) return 0;
      const committedMinor = BigInt(String(committed).replace('.', '').padEnd(String(committed).split('.')[0].length + scale, '0'));
      const totalMinor = BigInt(String(total).replace('.', '').padEnd(String(total).split('.')[0].length + scale, '0'));
      if (totalMinor <= 0n) return 0;
      const ratio = (committedMinor * 100n) / totalMinor;
      const value = Number(ratio > 10000n ? 10000n : ratio);
      return clamp ? Math.max(0, Math.min(100, value)) : value;
    } catch { return 0; }
  }
  function budgetNotice(message) {
    const panel = document.querySelector('#moduleContent .budget-panel');
    if (!panel) return;
    panel.querySelector('.budget-list')?.remove();
    const note = panel.querySelector('.finance-live-budget-note') || el('p', 'finance-live-budget-note', '');
    note.textContent = message;
    const title = panel.querySelector('.panel-header p');
    if (title) title.textContent = message;
    if (!note.isConnected) panel.append(note);
  }
  function renderBudgets(result) {
    const panel = document.querySelector('#moduleContent .budget-panel');
    if (!panel) return;
    if (!result.items.length) {
      budgetNotice('No approved budget is available for this estate.');
      return;
    }
    // The server marks effective periods from its trusted estate-local business date.
    const budget = result.items[0];
    panel.querySelector('.finance-live-budget-note')?.remove();
    const heading = panel.querySelector('.panel-header');
    if (heading) {
      const title = heading.querySelector('p');
      if (title) title.textContent = `${budget.periodStart} to ${budget.periodEnd} · ${budget.name}`;
    }
    let list = panel.querySelector('.budget-list');
    if (!list) { list = document.createElement('div'); list.className = 'budget-list'; panel.append(list); }
    list.replaceChildren();
    budget.lines.forEach((line) => {
      const row = el('div', 'budget-line');
      const summary = document.createElement('div');
      summary.append(el('span', '', line.categoryName), el('strong', '', `${amount(line, line.committed)} committed · ${amount(line, line.allocated)} allocated`));
      const track = el('div', 'budget-track');
      const fill = document.createElement('i');
      fill.style.width = `${budgetPercent(line.committed, line.allocated, line.currencyScale)}%`;
      track.append(fill);
      row.append(summary, track, el('small', 'finance-live-budget-remaining', `${amount(line, line.paid)} paid · ${amount(line, line.available)} available`));
      list.append(row);
    });
    const stats = document.querySelectorAll('#moduleContent .module-stats article');
    if (stats[2]) {
      stats[2].querySelector('strong').textContent = `${budgetPercent(budget.committed, budget.total, budget.currencyScale, false)}%`;
      stats[2].querySelector('span').textContent = 'BUDGET COMMITTED';
      stats[2].querySelector('small').textContent = `${amount(budget, budget.committed)} of ${amount(budget, budget.total)}`;
    }
  }
  async function loadBudgets(context, generation) {
    budgetNotice('Loading authorized budget data…');
    if (!budgetUrl()) {
      budgetNotice('Budget summary is not connected for this host.');
      const stats = document.querySelectorAll('#moduleContent .module-stats article');
      if (stats[2]) {
        stats[2].querySelector('strong').textContent = '—';
        stats[2].querySelector('span').textContent = 'BUDGET SUMMARY';
        stats[2].querySelector('small').textContent = 'Not connected';
      }
      return;
    }
    try {
      const result = await request(budgetUrl());
      if (generation !== state.generation || context !== estateId()) return;
      const validMoney = (value) => typeof value === 'string' && /^\d+(?:\.\d+)?$/.test(value);
      if (!result || !Array.isArray(result.items) || result.items.length > 24
        || result.items.some((budget) => !budget || String(budget.estateId) !== context || !budget.id
          || budget.status !== 'approved' || typeof budget.effective !== 'boolean'
          || !/^\d{4}-\d{2}-\d{2}$/.test(budget.periodStart) || !/^\d{4}-\d{2}-\d{2}$/.test(budget.periodEnd)
          || !Array.isArray(budget.lines) || !budget.lines.length || !budget.currency || !Number.isInteger(budget.currencyScale)
          || budget.currencyScale < 0 || budget.currencyScale > 6
          || !validMoney(budget.total) || !validMoney(budget.committed) || !validMoney(budget.paid) || !validMoney(budget.available)
          || budget.lines.some((line) => !line?.id || !line.name || !line.categoryName || line.currency !== budget.currency
            || line.currencyScale !== budget.currencyScale || !validMoney(line.allocated) || !validMoney(line.committed)
            || !validMoney(line.paid) || !validMoney(line.available)))) {
        throw new Error('The finance service returned an invalid budget summary.');
      }
      if (result.items[0]?.effective !== true && result.items.some((budget) => budget.effective)) {
        throw new Error('The finance service did not put the effective budget first.');
      }
      renderBudgets(result);
    } catch {
      if (generation !== state.generation || context !== estateId()) return;
      budgetNotice('Budget summary unavailable.');
      const stats = document.querySelectorAll('#moduleContent .module-stats article');
      if (stats[2]) {
        stats[2].querySelector('strong').textContent = '—';
        stats[2].querySelector('span').textContent = 'BUDGET SUMMARY';
        stats[2].querySelector('small').textContent = 'Unavailable';
      }
    }
  }
  function statusLabel(value) { return String(value || 'unknown').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()); }
  function dateLabel(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(date);
  }
  function render(result) {
    const body = document.getElementById('expenseRows');
    if (!body) return;
    body.replaceChildren();
    result.items.forEach((item) => {
      const row = document.createElement('tr');
      row.dataset.expenseStatus = item.status;
      row.dataset.search = `${item.description} ${item.categoryName} ${item.payeeLabel} ${item.requesterDisplayName}`.toLowerCase();
      const description = document.createElement('td');
      const copy = el('span', 'request-name');
      copy.append(el('strong', '', item.description), el('small', '', item.reference));
      description.append(copy);
      row.append(description, el('td', '', item.categoryName), el('td', '', item.requesterDisplayName), el('td', '', item.payeeLabel));
      const paymentValue = item.paidAmount ? `${amount(item, item.paidAmount)} paid · ${amount(item, item.outstandingAmount)} remaining` : amount(item, item.amount);
      row.append(el('td', 'amount-cell', paymentValue), el('td', '', dateLabel(item.neededBy || item.requestedAt)));
      const stateCell = el('td', 'expense-state');
      const status = el('span', `status-pill ${item.status === 'paid' ? 'status-paid' : ['approved', 'partially_paid'].includes(item.status) ? 'status-active' : item.status === 'rejected' ? 'status-overdue' : 'status-review'}`, statusLabel(item.status));
      const icon = document.createElement('i');
      status.prepend(icon);
      stateCell.append(status);
      if (item.allowedCommands?.length) {
        const pending = el('small', 'finance-live-permissions', `Available: ${item.allowedCommands.map(statusLabel).join(', ')}`);
        stateCell.append(pending);
      }
      row.append(stateCell);
      body.append(row);
    });
    if (!result.items.length) {
      const row = document.createElement('tr');
      const cell = el('td', 'finance-live-empty', 'No expense requests match this view.');
      cell.colSpan = 7;
      row.append(cell);
      body.append(row);
    }
    const stats = document.querySelectorAll('#moduleContent .module-stats article');
    if (stats[0]) { stats[0].querySelector('strong').textContent = String(result.items.filter((item) => ['approved', 'partially_paid', 'paid'].includes(item.status)).length); stats[0].querySelector('span').textContent = 'APPROVED / PAID ON PAGE'; stats[0].querySelector('small').textContent = 'Current filtered page'; }
    if (stats[1]) { stats[1].querySelector('strong').textContent = String(result.items.filter((item) => item.status === 'pending_approval').length); stats[1].querySelector('span').textContent = 'PENDING ON PAGE'; stats[1].querySelector('small').textContent = 'Current filtered page'; }
    document.querySelectorAll('#moduleContent [data-action="new-expense"]').forEach((button) => { button.disabled = true; button.title = 'Expense creation is not connected to a finance service.'; });
    const foot = document.querySelector('#moduleContent .finance-note');
    if (foot) foot.textContent = `${result.total} authorized expense request${result.total === 1 ? '' : 's'} · payment figures derive from verified allocations.`;
    const controls = document.getElementById('expensePageControls');
    if (controls) {
      controls.querySelector('[data-page-summary]').textContent = `Page ${result.page} of ${Math.max(1, result.totalPages)} · ${result.total} expenses`;
      controls.querySelector('[data-page-prev]').disabled = result.page <= 1;
      controls.querySelector('[data-page-next]').disabled = result.page >= result.totalPages;
    }
  }
  async function load() {
    const root = document.getElementById('moduleContent');
    if (!root?.querySelector('#expenseRows')) return;
    const context = estateId();
    const generation = ++state.generation;
    const body = document.getElementById('expenseRows');
    const stats = document.querySelectorAll('#moduleContent .module-stats article');
    stats.forEach((article, index) => {
      const strong = article.querySelector('strong');
      const labelNode = article.querySelector('span');
      const small = article.querySelector('small');
      if (strong) strong.textContent = '—';
      if (labelNode) labelNode.textContent = ['APPROVED / PAID ON PAGE', 'PENDING ON PAGE', 'BUDGET SUMMARY'][index] || 'FINANCE';
      if (small) small.textContent = 'Loading authorized records';
    });
    document.querySelectorAll('#moduleContent [data-action="new-expense"]').forEach((button) => { button.disabled = true; button.title = 'Expense creation is not connected to a finance service.'; });
    loadBudgets(context, generation);
    body.replaceChildren();
    const row = document.createElement('tr');
    const cell = el('td', 'finance-live-loading', 'Loading authorized expense requests…');
    cell.colSpan = 7;
    row.append(cell);
    body.append(row);
    try {
      const result = await request(url());
      if (generation !== state.generation || context !== estateId()) return;
      if (!result || !Array.isArray(result.items) || result.items.length > state.pageSize
        || result.page !== state.page || result.pageSize !== state.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || !Number.isInteger(result.totalPages) || result.totalPages !== Math.ceil(result.total / result.pageSize)
        || result.items.some((item) => !item || String(item.estateId) !== context || !item.id || !item.reference
          || !item.currency || !Number.isInteger(item.currencyScale) || !item.status)) {
        throw new Error('The finance service returned an invalid or out-of-scope expense page.');
      }
      state.totalPages = result.totalPages;
      render(result);
    } catch (error) {
      if (generation !== state.generation || context !== estateId()) return;
      body.replaceChildren();
      const row = document.createElement('tr');
      const cell = el('td', 'finance-live-error', error instanceof Error ? error.message : 'Expenses could not be loaded.');
      cell.colSpan = 7;
      cell.setAttribute('role', 'alert');
      row.append(cell);
      body.append(row);
      [...stats].slice(0, 2).forEach((article) => {
        const strong = article.querySelector('strong');
        const small = article.querySelector('small');
        if (strong) strong.textContent = '—';
        if (small) small.textContent = 'Unavailable';
      });
    }
  }
  function bind() {
    if (!document.getElementById('expenseRows')) return;
    document.querySelectorAll('#moduleContent [data-expense-filter]').forEach((button) => {
      button.classList.toggle('selected', (state.filter === 'pending_approval' && button.dataset.expenseFilter === 'pending')
        || (state.filter === 'approved' && button.dataset.expenseFilter === 'approved')
        || (state.filter === 'paid' && button.dataset.expenseFilter === 'paid')
        || (!state.filter && button.dataset.expenseFilter === 'all'));
      button.onclick = () => {
        state.filter = button.dataset.expenseFilter === 'pending' ? 'pending_approval'
          : button.dataset.expenseFilter === 'approved' ? 'approved'
            : button.dataset.expenseFilter === 'paid' ? 'paid' : '';
        state.page = 1;
        load();
      };
    });
    const search = document.getElementById('expenseSearch');
    if (search && !search.dataset.financeLive) search.value = state.search;
    if (search && !search.dataset.financeLive) {
      search.dataset.financeLive = 'true';
      search.addEventListener('input', () => {
        window.clearTimeout(debounceTimer);
        debounceTimer = window.setTimeout(() => { state.search = search.value.trim(); state.page = 1; load(); }, 250);
      });
    }
    const toolbar = document.querySelector('#moduleContent .module-toolbar');
    if (toolbar && !document.getElementById('expensePageControls')) {
      const controls = document.createElement('div');
      controls.id = 'expensePageControls';
      controls.className = 'finance-live-pagination';
      controls.append(el('button', '', 'Previous'), el('span', '', 'Page 1'), el('button', '', 'Next'));
      controls.querySelector('button').dataset.pagePrev = '';
      controls.querySelectorAll('button')[1].dataset.pageNext = '';
      controls.querySelector('span').dataset.pageSummary = '';
      controls.querySelector('[data-page-prev]').onclick = () => { if (state.page > 1) { state.page -= 1; load(); } };
      controls.querySelector('[data-page-next]').onclick = () => { if (state.page < state.totalPages) { state.page += 1; load(); } };
      toolbar.after(controls);
    }
    load();
  }
  new MutationObserver(bind).observe(document.getElementById('moduleContent'), { childList: true });
  window.addEventListener('estate:context-changed', () => { state.page = 1; bind(); });
  window.refreshEstateExpenses = load;
  bind();
})();
