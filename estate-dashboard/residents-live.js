(() => {
  const state = { generation: 0, page: 1, pageSize: 25, total: 0, totalPages: 0, search: '', status: 'submitted' };
  let searchTimer;

  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().residentJoinRequestListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/residents/join-requests` : '';
  }
  function connected() { return Boolean(estateId() && endpoint()); }
  function onView() { return document.getElementById('moduleContent')?.dataset.view === 'residents'; }
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
        if (!response.ok) throw new Error(`Resident service returned an error (${response.status}).`);
        response = await response.json();
      }
    } else {
      const result = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!result.ok) throw new Error(`Resident service returned an error (${result.status}).`);
      response = await result.json();
    }
    return response?.data ?? response;
  }
  function validTimestamp(value) {
    if (typeof value !== 'string') return false;
    const timestamp = new Date(value);
    return !Number.isNaN(timestamp.getTime()) && timestamp.toISOString() === value;
  }
  function validate(result) {
    const allowed = new Set(['id', 'applicantName', 'applicantEmail', 'propertyLabel', 'relationship', 'submittedAt', 'status']);
    const seen = new Set();
    if (!result || !Array.isArray(result.items) || result.items.length > state.pageSize
      || result.page !== state.page || result.pageSize !== state.pageSize
      || !Number.isSafeInteger(result.total) || result.total < result.items.length
      || !Number.isSafeInteger(result.totalPages) || result.totalPages !== Math.ceil(result.total / result.pageSize)) return false;
    return result.items.every((item) => {
      const id = item?.id === undefined || item?.id === null ? '' : String(item.id);
      if (!id || seen.has(id)) return false;
      seen.add(id);
      return Object.keys(item).every((key) => allowed.has(key))
        && typeof item.applicantName === 'string' && item.applicantName.trim() && item.applicantName.length <= 160
        && (item.applicantEmail === null || (typeof item.applicantEmail === 'string' && item.applicantEmail.length <= 254))
        && (item.propertyLabel === null || (typeof item.propertyLabel === 'string' && item.propertyLabel.trim() && item.propertyLabel.length <= 160))
        && ['owner', 'tenant', 'household_member', 'authorized_occupant'].includes(item.relationship)
        && validTimestamp(item.submittedAt)
        && ['submitted', 'approved', 'rejected', 'withdrawn'].includes(item.status);
    });
  }
  function relationLabel(value) {
    return ({ owner: 'Owner', tenant: 'Tenant', household_member: 'Household member', authorized_occupant: 'Authorized occupant' })[value];
  }
  function statusLabel(value) {
    return ({ submitted: 'Pending review', approved: 'Approved', rejected: 'Rejected', withdrawn: 'Withdrawn' })[value];
  }
  function statusClass(value) { return value === 'approved' ? 'status-active' : value === 'submitted' ? 'status-review' : ''; }
  function dateLabel(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(date);
  }
  function queryUrl() {
    const url = new URL(endpoint(), window.location.href);
    url.searchParams.set('estateId', estateId());
    url.searchParams.set('page', String(state.page));
    url.searchParams.set('pageSize', String(state.pageSize));
    if (state.search) url.searchParams.set('search', state.search);
    if (state.status) url.searchParams.set('status', state.status);
    return url.toString();
  }
  function setState(message, kind = 'ready') {
    const stateNode = document.querySelector('#moduleContent [data-residents-live-state]');
    if (!stateNode) return;
    stateNode.textContent = message;
    stateNode.dataset.state = kind;
  }
  function ensureControls() {
    const root = document.getElementById('moduleContent');
    const toolbar = root?.querySelector('.module-toolbar');
    const footer = root?.querySelector('.module-table-foot');
    if (!root || !toolbar || !footer) return false;
    if (!root.querySelector('[data-residents-live-state]')) {
      const status = make('p', 'live-resident-status', '');
      status.setAttribute('role', 'status');
      status.setAttribute('aria-live', 'polite');
      status.dataset.residentsLiveState = 'true';
      toolbar.after(status);
    }
    if (!footer.querySelector('[data-residents-page]')) {
      footer.replaceChildren(make('span', '', ''));
      footer.querySelector('span').dataset.residentsLiveSummary = 'true';
      const pager = make('div', 'live-resident-pager');
      const previous = make('button', 'table-action', 'Previous');
      previous.type = 'button';
      previous.dataset.residentsPage = 'previous';
      const label = make('span', '', '');
      label.dataset.residentsPageLabel = 'true';
      const next = make('button', 'table-action', 'Next');
      next.type = 'button';
      next.dataset.residentsPage = 'next';
      pager.append(previous, label, next);
      footer.append(pager);
    }
    return true;
  }
  function render(items) {
    const body = document.getElementById('residentRows');
    if (!body) return;
    body.replaceChildren();
    body.dataset.live = 'true';
    for (const item of items) {
      const row = document.createElement('tr');
      row.dataset.residentRow = item.status === 'submitted' ? 'pending' : item.status;
      row.dataset.residentId = String(item.id);
      const identity = document.createElement('td');
      const person = make('span', 'request-name');
      person.append(make('strong', '', item.applicantName), make('small', '', item.applicantEmail || 'Contact details unavailable'));
      identity.append(person);
      const status = make('span', `status-pill ${statusClass(item.status)}`, statusLabel(item.status));
      status.prepend(document.createElement('i'));
      const statusCell = document.createElement('td');
      statusCell.append(status);
      row.append(identity, make('td', '', item.propertyLabel || 'Property not specified'), make('td', '', relationLabel(item.relationship)), make('td', '', dateLabel(item.submittedAt)), statusCell, make('td', '', ''));
      body.append(row);
    }
    if (!items.length) {
      const row = document.createElement('tr');
      const cell = make('td', 'live-resident-state', 'No join requests match this view.');
      cell.colSpan = 6;
      row.append(cell);
      body.append(row);
    }
    const stats = document.querySelector('#moduleContent .module-stats');
    if (stats) stats.classList.add('hidden');
    const invite = document.querySelector('#moduleContent [data-action="invite"]');
    if (invite) { invite.disabled = true; invite.title = 'Resident invitations require a connected membership service.'; }
    const activeTab = document.querySelector('#moduleContent [data-resident-filter="active"]');
    if (activeTab) activeTab.classList.add('hidden');
    const pendingTab = document.querySelector('#moduleContent [data-resident-filter="pending"]');
    if (pendingTab) pendingTab.textContent = 'Pending requests';
    const allTab = document.querySelector('#moduleContent [data-resident-filter="all"]');
    if (allTab) allTab.textContent = 'All requests';
    const summary = document.querySelector('#moduleContent [data-residents-live-summary]');
    if (summary) summary.textContent = `Showing ${items.length} of ${state.total} join requests`;
    const previous = document.querySelector('#moduleContent [data-residents-page="previous"]');
    const next = document.querySelector('#moduleContent [data-residents-page="next"]');
    if (previous) previous.disabled = state.page <= 1;
    if (next) next.disabled = state.page >= state.totalPages;
    const pageLabel = document.querySelector('#moduleContent [data-residents-page-label]');
    if (pageLabel) pageLabel.textContent = state.totalPages ? `${state.page} / ${state.totalPages}` : '0 pages';
    setState('Live join-request records · decisions require a connected review command.', 'ready');
  }
  async function load() {
    if (!onView()) return;
    if (!ensureControls()) return;
    const requestGeneration = ++state.generation;
    const body = document.getElementById('residentRows');
    if (!body) return;
    body.dataset.live = 'true';
    body.replaceChildren();
    const placeholder = document.createElement('tr');
    const message = make('td', 'live-resident-state', connected() ? 'Loading resident requests…' : 'Connect the estate resident request service to view authorized records.');
    message.colSpan = 6;
    placeholder.append(message);
    body.append(placeholder);
    document.querySelector('#moduleContent .module-stats')?.classList.add('hidden');
    const invite = document.querySelector('#moduleContent [data-action="invite"]');
    if (invite) { invite.disabled = true; invite.title = 'Connect resident services to enable this action.'; }
    document.querySelector('#moduleContent [data-resident-filter="active"]')?.classList.add('hidden');
    if (!connected()) {
      setState('No live resident service is configured. Sample records are not shown.', 'unavailable');
      return;
    }
    setState('Loading resident requests…', 'loading');
    try {
      const result = await get(queryUrl());
      if (requestGeneration !== state.generation || !onView()) return;
      if (!validate(result)) throw new Error('Resident service returned an invalid list response.');
      state.total = result.total;
      state.totalPages = result.totalPages;
      render(result.items);
    } catch (error) {
      if (requestGeneration !== state.generation || !onView()) return;
      body.replaceChildren();
      const row = document.createElement('tr');
      const cell = make('td', 'live-resident-state', error instanceof Error ? error.message : 'Unable to load resident requests.');
      cell.colSpan = 6;
      row.append(cell);
      body.append(row);
      setState(error instanceof Error ? error.message : 'Unable to load resident requests.', 'error');
    }
  }
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view === 'residents') {
      state.page = 1;
      state.search = '';
      state.status = 'submitted';
      load();
    } else state.generation += 1;
  });
  window.refreshEstateResidentRequests = () => { state.page = 1; load(); };
  const refreshForEstateContext = () => { if (onView()) window.refreshEstateResidentRequests(); };
  window.addEventListener('estate:context-changed', refreshForEstateContext);
  window.addEventListener('estate:estate-context-changed', refreshForEstateContext);
  window.addEventListener('estate:resident-filter', (event) => {
    if (!onView()) return;
    state.status = event.detail?.filter === 'pending' ? 'submitted' : null;
    state.page = 1;
    load();
  });
  window.addEventListener('estate:resident-search', (event) => {
    if (!onView()) return;
    state.search = typeof event.detail?.search === 'string' ? event.detail.search.trim().slice(0, 100) : '';
    state.page = 1;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(load, 250);
  });
  document.addEventListener('click', (event) => {
    const button = event.target.closest('[data-residents-page]');
    if (!button || !onView()) return;
    const page = state.page + (button.dataset.residentsPage === 'next' ? 1 : -1);
    if (page < 1 || page > state.totalPages) return;
    state.page = page;
    load();
  });
})();
