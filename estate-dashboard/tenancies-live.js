(() => {
  const state = { generation: 0, page: 1, pageSize: 25, totalPages: 0, search: '' };
  let searchTimer;

  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().tenancyListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/tenancies` : '';
  }
  function connected() { return Boolean(estateId() && endpoint()); }
  function onView() { return document.getElementById('moduleContent')?.dataset.view === 'tenancies'; }
  function make(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }
  async function get(url) {
    const adapter = config().request;
    let response;
    if (typeof adapter === 'function') {
      response = await adapter({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw new Error(`Tenancy service returned an error (${response.status}).`);
        response = await response.json();
      }
    } else {
      const result = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!result.ok) throw new Error(`Tenancy service returned an error (${result.status}).`);
      response = await result.json();
    }
    return response?.data ?? response;
  }
  function validate(result, selectedEstateId) {
    const allowed = new Set(['id', 'propertyLabel', 'tenantLabel', 'landlordLabel', 'rentAmount', 'currency', 'rentFrequency', 'startDate', 'endDate', 'nextDueDate', 'status']);
    const seen = new Set();
    const validDate = (value) => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
      && !Number.isNaN(new Date(`${value}T00:00:00.000Z`).getTime())
      && new Date(`${value}T00:00:00.000Z`).toISOString().slice(0, 10) === value;
    if (!result || !Array.isArray(result.items) || result.items.length > state.pageSize
      || !Number.isSafeInteger(result.page) || result.page !== state.page
      || !Number.isSafeInteger(result.pageSize) || result.pageSize !== state.pageSize
      || !Number.isSafeInteger(result.total) || result.total < result.items.length
      || !Number.isSafeInteger(result.totalPages) || result.totalPages !== Math.ceil(result.total / result.pageSize)) return false;
    return result.items.every((item) => {
      const id = item?.id === undefined || item?.id === null ? '' : String(item.id);
      if (!id || seen.has(id)) return false;
      seen.add(id);
      return Object.keys(item).every((key) => allowed.has(key))
        && typeof item.propertyLabel === 'string' && item.propertyLabel.trim() && item.propertyLabel.length <= 160
        && typeof item.tenantLabel === 'string' && item.tenantLabel.trim() && item.tenantLabel.length <= 160
        && (item.landlordLabel === null || (typeof item.landlordLabel === 'string' && item.landlordLabel.length <= 160))
        && typeof item.rentAmount === 'string' && /^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(item.rentAmount)
        && typeof item.currency === 'string' && /^[A-Z]{3}$/.test(item.currency)
        && typeof item.rentFrequency === 'string' && item.rentFrequency.length <= 40
        && validDate(item.startDate) && (item.endDate === null || validDate(item.endDate))
        && (item.nextDueDate === null || validDate(item.nextDueDate))
        && ['draft', 'pending_approval', 'active', 'expiring', 'expired', 'terminated', 'cancelled'].includes(item.status);
    });
  }
  function labelDate(value) {
    if (!value) return '—';
    const [year, month, day] = value.split('-').map(Number);
    return new Intl.DateTimeFormat(undefined, { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(year, month - 1, day, 12));
  }
  function statusLabel(status) {
    return ({ draft: 'Draft', pending_approval: 'Pending approval', active: 'Active', expiring: 'Expiring soon', expired: 'Expired', terminated: 'Terminated', cancelled: 'Cancelled' })[status];
  }
  function statusClass(status) {
    if (status === 'active') return 'status-active';
    if (status === 'expiring') return 'status-expiring';
    if (status === 'pending_approval' || status === 'draft') return 'status-review';
    return '';
  }
  function renderRows(items) {
    const body = document.getElementById('tenancyRows');
    if (!body) return;
    body.dataset.live = 'true';
    body.replaceChildren();
    for (const item of items) {
      const row = document.createElement('tr');
      row.dataset.tenancyId = String(item.id);
      row.dataset.tenancyStatus = item.status;
      row.dataset.search = `${item.propertyLabel} ${item.tenantLabel} ${item.landlordLabel || ''}`.toLowerCase();
      const first = document.createElement('td');
      const copy = make('span', 'request-name');
      copy.append(make('strong', '', item.propertyLabel), make('small', '', `${item.tenantLabel} · Tenant`));
      first.append(copy);
      const rent = make('td', 'amount-cell', `${item.currency} ${item.rentAmount}`);
      rent.append(make('small', 'cell-sub', item.rentFrequency));
      const term = `${labelDate(item.startDate)} – ${labelDate(item.endDate)}`;
      const status = make('span', `status-pill ${statusClass(item.status)}`, statusLabel(item.status));
      status.prepend(document.createElement('i'));
      const statusCell = document.createElement('td');
      statusCell.append(status);
      row.append(first, make('td', '', item.landlordLabel || '—'), rent, make('td', '', term), make('td', '', labelDate(item.nextDueDate)), statusCell, make('td', '', ''));
      body.append(row);
    }
    const footerSummary = document.querySelector('#moduleContent .module-table-foot > span');
    if (footerSummary) footerSummary.textContent = `Showing ${items.length} of ${state.total} authorized tenancy records`;
    const stats = document.querySelector('#moduleContent .module-stats');
    if (stats) stats.classList.add('hidden');
    const create = document.querySelector('#moduleContent [data-action="create-tenancy"]');
    if (create) {
      create.disabled = true;
      create.title = 'Tenancy creation requires a connected command service.';
    }
    const exportButton = document.querySelector('#moduleContent [data-action="tenancy-export"]');
    if (exportButton) exportButton.disabled = true;
    document.getElementById('tenancyPendingCount')?.replaceChildren(document.createTextNode('—'));
    document.getElementById('tenancyPendingFilterCount')?.replaceChildren(document.createTextNode('—'));
    const footer = document.querySelector('#moduleContent .module-table-foot');
    if (footer) {
      let pager = footer.querySelector('.live-tenancy-pager');
      if (!pager) {
        pager = make('div', 'live-tenancy-pager');
        const previous = make('button', 'table-action', 'Previous');
        previous.type = 'button';
        previous.dataset.tenancyPage = 'previous';
        const current = make('span', '', '');
        current.dataset.tenancyPageLabel = 'true';
        const next = make('button', 'table-action', 'Next');
        next.type = 'button';
        next.dataset.tenancyPage = 'next';
        pager.append(previous, current, next);
        footer.append(pager);
      }
      pager.querySelector('[data-tenancy-page="previous"]').disabled = state.page <= 1;
      pager.querySelector('[data-tenancy-page="next"]').disabled = state.page >= state.totalPages;
      pager.querySelector('[data-tenancy-page-label]').textContent = state.totalPages ? `${state.page} / ${state.totalPages}` : '0 pages';
    }
  }
  function queryUrl() {
    const url = new URL(endpoint(), window.location.href);
    url.searchParams.set('estateId', estateId());
    url.searchParams.set('page', String(state.page));
    url.searchParams.set('pageSize', String(state.pageSize));
    if (state.search) url.searchParams.set('search', state.search);
    if (state.filter === 'active' || state.filter === 'expiring') url.searchParams.set('status', state.filter);
    if (state.filter === 'pending') url.searchParams.set('status', 'pending_approval');
    return url.toString();
  }
  async function load() {
    if (!onView()) return;
    const current = ++state.generation;
    const body = document.getElementById('tenancyRows');
    if (!body) return;
    if (!connected()) {
      body.replaceChildren();
      body.dataset.live = 'true';
      const row = document.createElement('tr');
      const cell = make('td', 'live-tenancy-state', 'Connect the estate tenancy list service to view authorized records.');
      cell.colSpan = 7;
      row.append(cell);
      body.append(row);
      const create = document.querySelector('#moduleContent [data-action="create-tenancy"]');
      if (create) { create.disabled = true; create.title = 'Connect the tenancy services to enable this action.'; }
      document.querySelector('#moduleContent .module-stats')?.classList.add('hidden');
      return;
    }
    body.replaceChildren();
    body.dataset.live = 'true';
    const loading = document.createElement('tr');
    const message = make('td', 'live-tenancy-state', 'Loading tenancies…');
    message.colSpan = 7;
    loading.append(message);
    body.append(loading);
    const create = document.querySelector('#moduleContent [data-action="create-tenancy"]');
    if (create) { create.disabled = true; create.title = 'Tenancy creation requires a connected command service.'; }
    document.querySelector('#moduleContent .module-stats')?.classList.add('hidden');
    try {
      const result = await get(queryUrl());
      if (current !== state.generation || !onView()) return;
      if (!validate(result, estateId())) throw new Error('Tenancy service returned an invalid or out-of-scope result.');
      state.total = result.total;
      state.totalPages = result.totalPages;
      renderRows(result.items);
      if (result.items.length === 0) {
        const row = document.createElement('tr');
        const cell = make('td', 'live-tenancy-state', 'No tenancies match this search.');
        cell.colSpan = 7;
        row.append(cell);
        body.append(row);
      }
    } catch (error) {
      if (current !== state.generation || !onView()) return;
      body.replaceChildren();
      const row = document.createElement('tr');
      const cell = make('td', 'live-tenancy-state', error instanceof Error ? error.message : 'Unable to load tenancies.');
      cell.colSpan = 7;
      row.append(cell);
      body.append(row);
    }
  }
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view === 'tenancies') {
      state.page = 1;
      state.search = '';
      state.filter = 'all';
      load();
    } else state.generation += 1;
  });
  window.refreshEstateTenancies = () => { state.page = 1; load(); };
  const refreshForEstateContext = () => { if (onView()) window.refreshEstateTenancies(); };
  window.addEventListener('estate:context-changed', refreshForEstateContext);
  window.addEventListener('estate:estate-context-changed', refreshForEstateContext);
  window.addEventListener('estate:tenancy-search', (event) => {
    if (!onView()) return;
    state.search = typeof event.detail?.search === 'string' ? event.detail.search.trim().slice(0, 100) : '';
    state.page = 1;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(load, 250);
  });
  window.addEventListener('estate:tenancy-filter', (event) => {
    if (!onView()) return;
    state.filter = ['all', 'active', 'pending', 'expiring'].includes(event.detail?.filter) ? event.detail.filter : 'all';
    state.page = 1;
    load();
  });
  document.addEventListener('click', (event) => {
    const button = event.target.closest('[data-tenancy-page]');
    if (!button || !onView()) return;
    const nextPage = state.page + (button.dataset.tenancyPage === 'next' ? 1 : -1);
    if (nextPage < 1 || nextPage > state.totalPages) return;
    state.page = nextPage;
    load();
  });
  window.addEventListener('estate:estate-context-changed', () => { if (onView()) load(); });
  state.total = 0;
})();
