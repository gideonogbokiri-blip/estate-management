(() => {
  const state = { generation: 0, page: 1, pageSize: 25, total: 0, totalPages: 0, search: '', status: '' };
  let searchTimer;

  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().facilityBookingListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/facility-bookings` : '';
  }
  function connected() { return Boolean(estateId() && endpoint()); }
  function onView() { return document.getElementById('moduleContent')?.dataset.view === 'facilities'; }
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
        if (!response.ok) throw new Error(`Facility booking service returned an error (${response.status}).`);
        response = await response.json();
      }
    } else {
      const result = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!result.ok) throw new Error(`Facility booking service returned an error (${result.status}).`);
      response = await result.json();
    }
    return response?.data ?? response;
  }
  function validInstant(value) {
    if (typeof value !== 'string') return false;
    const date = new Date(value);
    return !Number.isNaN(date.getTime()) && date.toISOString() === value;
  }
  function validate(result) {
    const allowed = new Set(['id', 'estateId', 'facilityLabel', 'requesterLabel', 'propertyLabel', 'startsAt', 'endsAt', 'attendeeCount', 'status']);
    const statuses = ['requested', 'pending_review', 'pending_payment', 'confirmed', 'declined', 'expired', 'cancelled', 'completed'];
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
        && String(item.estateId) === estateId()
        && typeof item.facilityLabel === 'string' && item.facilityLabel.trim() && item.facilityLabel.length <= 160
        && typeof item.requesterLabel === 'string' && item.requesterLabel.trim() && item.requesterLabel.length <= 160
        && (item.propertyLabel === null || (typeof item.propertyLabel === 'string' && item.propertyLabel.trim() && item.propertyLabel.length <= 160))
        && validInstant(item.startsAt) && validInstant(item.endsAt) && item.endsAt > item.startsAt
        && Number.isSafeInteger(item.attendeeCount) && item.attendeeCount > 0
        && statuses.includes(item.status);
    });
  }
  function dateLabel(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(date);
  }
  function statusLabel(value) {
    return ({ requested: 'Requested', pending_review: 'Needs review', pending_payment: 'Payment pending', confirmed: 'Confirmed', declined: 'Declined', expired: 'Expired', cancelled: 'Cancelled', completed: 'Completed' })[value];
  }
  function statusClass(value) {
    if (value === 'confirmed' || value === 'completed') return 'status-active';
    if (value === 'pending_review' || value === 'requested' || value === 'pending_payment') return 'status-review';
    return '';
  }
  function setState(message, kind = 'ready') {
    const node = document.querySelector('#moduleContent [data-facility-live-state]');
    if (!node) return;
    node.textContent = message;
    node.dataset.state = kind;
  }
  function ensureControls() {
    const root = document.getElementById('moduleContent');
    const header = root?.querySelector('.module-panel .panel-header');
    const table = root?.querySelector('.module-panel .module-table table');
    const footer = root?.querySelector('.module-panel .module-table-foot');
    if (!root || !header || !table || !footer) return false;
    header.querySelector('.segmented')?.remove();
    if (!root.querySelector('[data-facility-live-filter]')) {
      const toolbar = make('div', 'facility-live-toolbar');
      const statusLabel = make('label', '', 'Status');
      const status = document.createElement('select');
      status.dataset.facilityLiveFilter = 'true';
      [['', 'All bookings'], ['requested', 'Requested'], ['pending_review', 'Needs review'], ['pending_payment', 'Payment pending'], ['confirmed', 'Confirmed'], ['declined', 'Declined'], ['expired', 'Expired'], ['cancelled', 'Cancelled'], ['completed', 'Completed']]
        .forEach(([value, label]) => { const option = document.createElement('option'); option.value = value; option.textContent = label; status.append(option); });
      statusLabel.append(status);
      const searchLabel = make('label', '', 'Search bookings');
      const search = document.createElement('input');
      search.type = 'search';
      search.placeholder = 'Facility, resident or property';
      search.dataset.facilityLiveSearch = 'true';
      searchLabel.append(search);
      toolbar.append(statusLabel, searchLabel);
      header.after(toolbar);
      const liveStatus = make('p', 'facility-live-status', '');
      liveStatus.setAttribute('role', 'status');
      liveStatus.setAttribute('aria-live', 'polite');
      liveStatus.dataset.facilityLiveState = 'true';
      toolbar.after(liveStatus);
    }
    if (!footer.querySelector('[data-facility-page]')) {
      footer.replaceChildren(make('span', '', ''));
      footer.querySelector('span').dataset.facilitySummary = 'true';
      const pager = make('div', 'facility-live-pager');
      const previous = make('button', 'table-action', 'Previous');
      previous.type = 'button'; previous.dataset.facilityPage = 'previous';
      const label = make('span', '', ''); label.dataset.facilityPageLabel = 'true';
      const next = make('button', 'table-action', 'Next');
      next.type = 'button'; next.dataset.facilityPage = 'next';
      pager.append(previous, label, next);
      footer.append(pager);
    }
    return true;
  }
  function render(items) {
    const body = document.querySelector('#moduleContent .module-panel .module-table tbody');
    if (!body) return;
    body.replaceChildren();
    body.dataset.live = 'true';
    for (const item of items) {
      const row = document.createElement('tr');
      row.dataset.bookingId = String(item.id);
      const facility = document.createElement('td');
      const name = make('span', 'request-name');
      name.append(make('strong', '', item.facilityLabel), make('small', '', `${dateLabel(item.startsAt)} – ${dateLabel(item.endsAt)}`));
      facility.append(name);
      row.append(facility, make('td', '', item.requesterLabel), make('td', '', item.propertyLabel || '—'), make('td', '', String(item.attendeeCount)));
      const pill = make('span', `status-pill ${statusClass(item.status)}`, statusLabel(item.status));
      pill.prepend(document.createElement('i'));
      const status = document.createElement('td'); status.append(pill);
      row.append(status, make('td', '', ''));
      body.append(row);
    }
    if (!items.length) {
      const row = document.createElement('tr');
      const cell = make('td', 'facility-live-empty', 'No bookings match this view.');
      cell.colSpan = 6;
      row.append(cell);
      body.append(row);
    }
    const summary = document.querySelector('#moduleContent [data-facility-summary]');
    if (summary) summary.textContent = `Showing ${items.length} of ${state.total} bookings`;
    const previous = document.querySelector('#moduleContent [data-facility-page="previous"]');
    const next = document.querySelector('#moduleContent [data-facility-page="next"]');
    if (previous) previous.disabled = state.page <= 1;
    if (next) next.disabled = state.page >= state.totalPages;
    const page = document.querySelector('#moduleContent [data-facility-page-label]');
    if (page) page.textContent = state.totalPages ? `${state.page} / ${state.totalPages}` : '0 pages';
  }
  function queryUrl() {
    const url = new URL(endpoint(), window.location.href);
    url.searchParams.set('estateId', estateId());
    url.searchParams.set('page', String(state.page));
    url.searchParams.set('pageSize', String(state.pageSize));
    if (state.status) url.searchParams.set('status', state.status);
    if (state.search) url.searchParams.set('search', state.search);
    return url.toString();
  }
  async function load() {
    if (!onView() || !ensureControls()) return;
    const current = ++state.generation;
    const body = document.querySelector('#moduleContent .module-panel .module-table tbody');
    if (!body) return;
    body.replaceChildren();
    body.dataset.live = 'true';
    const row = document.createElement('tr');
    const cell = make('td', 'facility-live-empty', connected() ? 'Loading facility bookings…' : 'Connect the estate booking service to view authorized requests.');
    cell.colSpan = 6;
    row.append(cell); body.append(row);
    document.querySelector('#moduleContent .module-stats')?.classList.add('hidden');
    document.querySelector('#moduleContent .facility-card-grid')?.classList.add('hidden');
    const heading = document.querySelector('#moduleContent .module-heading');
    if (heading) {
      heading.querySelector('h2').textContent = 'Facility bookings';
      heading.querySelector('p').textContent = 'Review requests for shared estate spaces.';
    }
    const addFacility = document.querySelector('#moduleContent [data-action="add-facility"]');
    if (addFacility) { addFacility.disabled = true; addFacility.title = 'Facility configuration requires a connected management service.'; }
    document.querySelector('#moduleContent [data-action="booking-calendar"]')?.remove();
    if (!connected()) {
      setState('No live booking service is configured. Sample bookings and facility cards are hidden.', 'unavailable');
      return;
    }
    setState('Loading facility bookings…', 'loading');
    try {
      const result = await get(queryUrl());
      if (current !== state.generation || !onView()) return;
      if (!validate(result)) throw new Error('Facility booking service returned an invalid or out-of-scope list.');
      state.total = result.total;
      state.totalPages = result.totalPages;
      render(result.items);
      setState(`${result.total} booking${result.total === 1 ? '' : 's'} in this view. Decisions require the connected booking workflow.`);
    } catch (error) {
      if (current !== state.generation || !onView()) return;
      body.replaceChildren();
      const errorRow = document.createElement('tr');
      const errorCell = make('td', 'facility-live-empty', error instanceof Error ? error.message : 'Facility bookings could not be loaded.');
      errorCell.colSpan = 6;
      errorRow.append(errorCell); body.append(errorRow);
      setState(error instanceof Error ? error.message : 'Facility bookings could not be loaded.', 'error');
    }
  }
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view === 'facilities') { state.page = 1; state.search = ''; state.status = ''; load(); }
    else state.generation += 1;
  });
  window.refreshEstateFacilityBookings = () => { state.page = 1; load(); };
  const refreshForEstateContext = () => { if (onView()) window.refreshEstateFacilityBookings(); };
  window.addEventListener('estate:context-changed', refreshForEstateContext);
  window.addEventListener('estate:estate-context-changed', refreshForEstateContext);
  document.addEventListener('change', (event) => {
    if (event.target.matches('[data-facility-live-filter]') && onView()) { state.status = event.target.value; state.page = 1; load(); }
  });
  document.addEventListener('input', (event) => {
    if (!event.target.matches('[data-facility-live-search]') || !onView()) return;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { state.search = event.target.value.trim().slice(0, 100); state.page = 1; load(); }, 250);
  });
  document.addEventListener('click', (event) => {
    const button = event.target.closest('[data-facility-page]');
    if (!button || !onView()) return;
    const page = state.page + (button.dataset.facilityPage === 'next' ? 1 : -1);
    if (page < 1 || page > state.totalPages) return;
    state.page = page;
    load();
  });
})();
