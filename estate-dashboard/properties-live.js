(() => {
  const state = { generation: 0, page: 1, pageSize: 25, totalPages: 0, search: '' };
  let debounceTimer;

  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().propertyListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/properties` : '';
  }
  function detailEndpoint(propertyId) {
    const custom = config().propertyDetailUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId()))
        .replaceAll('{propertyId}', encodeURIComponent(propertyId))
        .replace(':estateId', encodeURIComponent(estateId())).replace(':propertyId', encodeURIComponent(propertyId));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/properties/${encodeURIComponent(propertyId)}` : '';
  }
  function connected() { return Boolean(estateId() && endpoint()); }
  function onPropertyView() { return !document.getElementById('propertyRegister')?.classList.contains('hidden'); }
  function make(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }
  async function get(url) {
    const adapter = config().request;
    if (typeof adapter === 'function') {
      const response = await adapter({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw new Error(`Property service returned an error (${response.status}).`);
        const body = await response.json();
        return body?.data ?? body;
      }
      return response?.data ?? response;
    }
    const response = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
    if (!response.ok) throw new Error(`Property service returned an error (${response.status}).`);
    const body = await response.json();
    return body?.data ?? body;
  }
  function queryUrl() {
    const target = new URL(endpoint(), window.location.href);
    target.searchParams.set('estateId', estateId());
    target.searchParams.set('page', String(state.page));
    target.searchParams.set('pageSize', String(state.pageSize));
    if (state.search) target.searchParams.set('search', state.search);
    return target.toString();
  }
  function statusLabel(value) {
    const labels = {
      active: 'Operational', under_development: 'Under development', reserved: 'Reserved',
      under_maintenance: 'Under maintenance', inactive: 'Inactive', archived: 'Archived',
    };
    return labels[value] || 'Status unavailable';
  }
  function statusClass(value) {
    if (value === 'active') return 'status-active';
    if (value === 'under_maintenance') return 'status-maint';
    if (value === 'reserved' || value === 'under_development') return 'status-vacant';
    return 'status-review';
  }
  function safeRow(item) {
    const row = document.createElement('tr');
    row.dataset.propertyId = String(item.id);
    const propertyCell = document.createElement('td');
    const marker = make('span', 'property-thumb', item.unitNumber || '—');
    const copy = make('span', 'request-name');
    copy.append(make('strong', '', item.code), make('small', '', item.structureLabel || ''));
    propertyCell.append(marker, copy);
    const status = make('span', `status-pill ${statusClass(item.status)}`, statusLabel(item.status));
    status.prepend(document.createElement('i'));
    const details = make('button', 'table-action property-detail-action', 'Details');
    details.type = 'button';
    details.dataset.action = 'property-detail';
    details.dataset.propertyId = String(item.id);
    details.disabled = !detailEndpoint(item.id);
    if (details.disabled) details.title = 'Property detail requires its authorized detail endpoint.';
    row.append(
      propertyCell,
      make('td', '', item.propertyType),
      make('td', '', item.ownershipLabel || '—'),
      make('td', '', item.occupancyLabel || (item.occupancyStatus === 'occupied' ? 'Occupied' : item.occupancyStatus === 'vacant' ? 'Vacant' : '—')),
      (() => { const cell = document.createElement('td'); cell.append(status); return cell; })(),
      (() => { const cell = document.createElement('td'); cell.append(details); return cell; })(),
    );
    return row;
  }
  function renderPagination(result) {
    const pagination = document.querySelector('#propertyRegister .pagination');
    if (!pagination) return;
    pagination.replaceChildren();
    pagination.append(make('span', '', result.total ? `Page ${result.page} of ${Math.max(1, result.totalPages)} · ${result.total} properties` : 'No properties'));
    const controls = document.createElement('div');
    const previous = make('button', '', 'Previous');
    previous.type = 'button';
    previous.disabled = result.page <= 1;
    previous.setAttribute('aria-label', 'Previous property page');
    previous.addEventListener('click', () => { if (state.page > 1) { state.page -= 1; load(); } });
    const next = make('button', '', 'Next');
    next.type = 'button';
    next.disabled = result.page >= result.totalPages;
    next.setAttribute('aria-label', 'Next property page');
    next.addEventListener('click', () => { if (state.page < state.totalPages) { state.page += 1; load(); } });
    controls.append(previous, next);
    pagination.append(controls);
  }
  function setUnavailable(message, className) {
    const body = document.getElementById('propertyRows');
    if (!body) return;
    body.replaceChildren();
    const row = document.createElement('tr');
    const cell = make('td', className, message);
    cell.colSpan = 6;
    if (className.includes('error')) cell.setAttribute('role', 'alert');
    row.append(cell);
    body.append(row);
    document.getElementById('resultsCount').textContent = message;
  }
  function connectedShell() {
    const mapButton = document.querySelector('[data-property-view="map"]');
    if (mapButton) {
      mapButton.disabled = true;
      mapButton.title = 'The estate asset map is illustrative until an authorized map service is connected.';
    }
    const mapPanel = document.getElementById('propertyMapPanel');
    if (mapPanel) mapPanel.classList.add('hidden');
    document.querySelector('#propertyRegister .table-wrap.full-table')?.classList.remove('hidden');
    document.querySelector('#propertyRegister .pagination')?.classList.remove('hidden');
    const addButton = document.querySelector('#propertyRegister [data-action="add-property"]');
    if (addButton) {
      addButton.disabled = true;
      addButton.title = 'Property creation is not connected to the estate service.';
    }
    const scale = document.querySelector('#propertyMapPanel .map-scale span');
    if (scale) scale.textContent = 'Preview map';
  }
  function validResult(result, selectedEstateId) {
    const itemFields = new Set(['id', 'estateId', 'code', 'propertyType', 'status', 'unitNumber', 'occupancyStatus', 'structureLabel', 'occupancyLabel', 'ownershipLabel', 'tenancyLabel']);
    return Boolean(result && Array.isArray(result.items) && result.items.length <= state.pageSize
      && result.page === state.page && result.pageSize === state.pageSize
      && Number.isSafeInteger(result.total) && result.total >= result.items.length
      && Number.isInteger(result.totalPages) && result.totalPages === Math.ceil(result.total / state.pageSize)
      && result.items.every((item) => item && item.id !== undefined && item.id !== null
        && Object.keys(item).every((field) => itemFields.has(field))
        && String(item.estateId) === selectedEstateId && typeof item.code === 'string' && item.code.trim()
        && typeof item.propertyType === 'string' && item.propertyType.trim()
        && ['active', 'under_development', 'reserved', 'under_maintenance', 'inactive', 'archived'].includes(item.status)
        && (item.occupancyStatus === null || item.occupancyStatus === undefined || ['occupied', 'vacant'].includes(item.occupancyStatus))
        && ['unitNumber', 'structureLabel', 'occupancyLabel', 'ownershipLabel', 'tenancyLabel'].every((field) =>
          item[field] === null || item[field] === undefined || typeof item[field] === 'string')));
  }
  function optionalText(value, max = 500) {
    return value === null || value === undefined || (typeof value === 'string' && value.length <= max);
  }
  function validDetail(result, selectedEstateId, propertyId) {
    const propertyFields = new Set(['id', 'estateId', 'code', 'propertyType', 'status', 'unitNumber', 'address', 'description']);
    const ownerFields = new Set(['id', 'displayName', 'ownershipShare', 'effectiveFrom', 'effectiveTo', 'status', 'verificationStatus']);
    const occupancyFields = new Set(['id', 'displayName', 'relationship', 'effectiveFrom', 'effectiveTo', 'status']);
    const property = result?.property;
    return Boolean(result && Object.keys(result).every((field) => ['property', 'ownershipRecords', 'occupancyRecords'].includes(field))
      && property && String(property.id) === String(propertyId) && String(property.estateId) === selectedEstateId
      && Object.keys(property).every((field) => propertyFields.has(field))
      && typeof property.code === 'string' && property.code.length <= 80
      && typeof property.propertyType === 'string' && property.propertyType.length <= 80
      && ['active', 'under_development', 'reserved', 'under_maintenance', 'inactive', 'archived'].includes(property.status)
      && ['unitNumber', 'address', 'description'].every((field) => optionalText(property[field], field === 'description' ? 700 : 240))
      && Array.isArray(result.ownershipRecords) && result.ownershipRecords.length <= 200
      && result.ownershipRecords.every((record) => record?.id && Object.keys(record).every((field) => ownerFields.has(field))
        && ['displayName', 'ownershipShare', 'effectiveFrom', 'effectiveTo', 'status', 'verificationStatus'].every((field) => optionalText(record[field], 200)))
      && Array.isArray(result.occupancyRecords) && result.occupancyRecords.length <= 200
      && result.occupancyRecords.every((record) => record?.id && Object.keys(record).every((field) => occupancyFields.has(field))
        && ['displayName', 'relationship', 'effectiveFrom', 'effectiveTo', 'status'].every((field) => optionalText(record[field], 200))));
  }
  function clearDetailView(message) {
    document.getElementById('propertyDetailTitle').textContent = 'Property details';
    document.getElementById('propertyDetailAddress').textContent = message;
    document.getElementById('propertyDetailCode').textContent = '';
    document.getElementById('propertyDetailFacts').replaceChildren();
    document.getElementById('propertyOwnershipRecords').replaceChildren(make('p', 'property-occupancy-empty', message));
    document.getElementById('propertyOccupancyRecords').replaceChildren(make('p', 'property-occupancy-empty', message));
    document.getElementById('propertyLifecycleHistory').replaceChildren(make('p', 'property-occupancy-empty', 'Lifecycle history is not included in this property summary.'));
    document.getElementById('propertyDetailDocuments').textContent = 'Documents and charges require their own authorized services.';
  }
  function renderLiveDetail(result) {
    const property = result.property;
    document.querySelector('#propertyDetailModal > .eyebrow').textContent = 'PROPERTY RECORD · LIVE SUMMARY';
    document.getElementById('propertyDetailTitle').textContent = property.code;
    document.getElementById('propertyDetailAddress').textContent = property.address || property.description || 'Address not provided';
    document.getElementById('propertyDetailCode').textContent = property.code;
    const facts = document.getElementById('propertyDetailFacts');
    facts.replaceChildren();
    appendPropertyFact('PROPERTY TYPE', property.propertyType);
    if (property.unitNumber) appendPropertyFact('UNIT / HOUSE NUMBER', property.unitNumber);
    appendPropertyFact('OPERATIONAL STATUS', statusLabel(property.status));
    appendPropertyFact('OCCUPANCY RECORDS', String(result.occupancyRecords.length));
    const owners = document.getElementById('propertyOwnershipRecords');
    owners.replaceChildren();
    result.ownershipRecords.forEach((owner) => {
      const item = make('article', 'property-owner-record');
      const detail = make('div');
      detail.append(make('strong', '', owner.displayName || 'Name unavailable'), make('small', '', [owner.status, owner.verificationStatus, owner.effectiveFrom, owner.effectiveTo].filter(Boolean).join(' · ') || 'Ownership dates unavailable'));
      item.append(detail, make('span', 'ownership-share', owner.ownershipShare || 'Share not recorded'));
      owners.append(item);
    });
    if (!result.ownershipRecords.length) owners.append(make('p', 'property-occupancy-empty', 'No ownership records are visible for this account.'));
    const occupancy = document.getElementById('propertyOccupancyRecords');
    occupancy.replaceChildren();
    result.occupancyRecords.forEach((record) => {
      const item = make('article', 'property-owner-record');
      const detail = make('div');
      detail.append(make('strong', '', record.displayName || 'Name unavailable'), make('small', '', [record.relationship, record.effectiveFrom, record.effectiveTo].filter(Boolean).join(' · ') || 'Occupancy dates unavailable'));
      item.append(detail, make('span', `ownership-status ${record.status === 'active' ? '' : 'is-ended'}`, record.status || 'Status unavailable'));
      occupancy.append(item);
    });
    if (!result.occupancyRecords.length) occupancy.append(make('p', 'property-occupancy-empty', 'No occupancy records are visible for this account.'));
    document.getElementById('propertyLifecycleHistory').replaceChildren(make('p', 'property-occupancy-empty', 'Lifecycle history is not included in this property summary.'));
    document.getElementById('propertyDetailDocuments').textContent = property.description || 'Documents and charges require their own authorized services.';
    document.querySelector('#propertyDetailModal [data-action="add-ownership"]').disabled = true;
    document.querySelector('#propertyDetailModal [data-action="add-occupant"]').disabled = true;
    document.querySelector('#propertyDetailModal [data-action="archive-property"]').disabled = true;
    document.querySelector('.property-detail-preview-note').textContent = 'Live property summary. Relationship records are limited to the fields authorized by the estate service.';
  }
  let detailGeneration = 0;
  function openLivePropertyDetail(propertyId) {
    const target = detailEndpoint(propertyId);
    if (!target || !connected()) return false;
    loadLivePropertyDetail(propertyId, target);
    return true;
  }
  async function loadLivePropertyDetail(propertyId, target) {
    const context = estateId();
    const generation = ++detailGeneration;
    clearDetailView('Loading authorized property details…');
    document.querySelector('#propertyDetailModal > .eyebrow').textContent = 'PROPERTY RECORD · LOADING';
    document.getElementById('propertyDetailModal').classList.remove('hidden');
    try {
      const url = new URL(target, window.location.href);
      url.searchParams.set('estateId', context);
      const result = await get(url.toString());
      if (generation !== detailGeneration || context !== estateId()) return;
      if (!validDetail(result, context, propertyId)) throw new Error('Invalid property detail result.');
      renderLiveDetail(result);
    } catch {
      if (generation !== detailGeneration || context !== estateId()) return;
      clearDetailView('Property details are unavailable. Check the estate service connection and retry.');
      document.querySelector('#propertyDetailModal > .eyebrow').textContent = 'PROPERTY RECORD · UNAVAILABLE';
      document.querySelector('.property-detail-preview-note').textContent = 'No sample relationship data was shown.';
    }
  }
  function cancelLivePropertyDetail() { detailGeneration += 1; }
  async function load() {
    if (!connected() || !onPropertyView()) return;
    const context = estateId();
    const generation = ++state.generation;
    connectedShell();
    setUnavailable('Loading authorized property records…', 'property-live-loading');
    try {
      const result = await get(queryUrl());
      if (generation !== state.generation || context !== estateId()) return;
      if (!validResult(result, context)) throw new Error('The property service returned an invalid or out-of-scope page.');
      const body = document.getElementById('propertyRows');
      body.replaceChildren();
      if (result.items.length) result.items.forEach((item) => body.append(safeRow(item)));
      else {
        const row = document.createElement('tr');
        const cell = make('td', 'property-live-empty', 'No properties match this view.');
        cell.colSpan = 6;
        row.append(cell);
        body.append(row);
      }
      state.totalPages = result.totalPages;
      window.currentEstatePropertyTotal = result.total;
      const structurePropertyCount = document.getElementById('structurePropertyCount');
      if (structurePropertyCount) structurePropertyCount.textContent = String(result.total);
      document.getElementById('resultsCount').textContent = `Showing ${result.items.length} of ${result.total} properties · page ${result.page}`;
      const countTab = document.querySelector('[data-register-tab="properties"] span');
      if (countTab) countTab.textContent = String(result.total);
      renderPagination(result);
      document.querySelectorAll('#propertyRegister [data-action="add-property"]').forEach((button) => {
        button.disabled = true;
        button.title = 'Property creation is not connected to the estate service.';
      });
    } catch {
      if (generation !== state.generation || context !== estateId()) return;
      setUnavailable('Property records are unavailable. Check the estate service connection and retry.', 'property-live-error');
      const pagination = document.querySelector('#propertyRegister .pagination');
      if (pagination) pagination.replaceChildren();
    }
  }
  function bind() {
    if (!connected()) return;
    connectedShell();
    const search = document.getElementById('propertySearch');
    if (search && !search.dataset.propertyLive) {
      search.dataset.propertyLive = 'true';
      search.addEventListener('input', () => {
        window.clearTimeout(debounceTimer);
        debounceTimer = window.setTimeout(() => { state.search = search.value.trim(); state.page = 1; load(); }, 250);
      });
    }
    document.querySelectorAll('#propertyRegister [data-action="add-property"]').forEach((button) => {
      button.disabled = true;
      button.title = 'Property creation is not connected to the estate service.';
    });
    load();
  }
  window.refreshEstateProperties = load;
  window.openLivePropertyDetail = openLivePropertyDetail;
  window.cancelLivePropertyDetail = cancelLivePropertyDetail;
  window.addEventListener('estate:view-changed', bind);
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view !== 'properties') {
      cancelLivePropertyDetail();
      document.getElementById('propertyDetailModal')?.classList.add('hidden');
    }
  });
  window.addEventListener('estate:context-changed', () => {
    state.page = 1;
    cancelLivePropertyDetail();
    document.getElementById('propertyDetailModal')?.classList.add('hidden');
    bind();
  });
  bind();
})();
