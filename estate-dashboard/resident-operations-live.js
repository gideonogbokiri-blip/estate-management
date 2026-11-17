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
    const custom = config().residentMaintenanceRequestsUrl || config().maintenanceRequestsUrl;
    return typeof custom === 'string' && custom.trim() ? custom.trim()
      : apiBase() ? `${apiBase()}/api/estate/maintenance/requests` : '';
  }
  const connected = Boolean(estateId() && collectionUrl());
  if (!connected) return;

  const modal = document.getElementById('maintenanceRequestModal');
  const form = modal.querySelector('.resident-form-modal');
  const submitButton = modal.querySelector('[data-action="submit-request"]');
  const previewLabel = modal.querySelector('.resident-form-preview');
  const list = document.getElementById('residentMaintenanceList');
  const filter = document.getElementById('residentRequestFilter');
  const state = { items: [], page: 0, totalPages: 1, pageSize: 25, generation: 0, detailGeneration: 0, pendingFingerprint: '', pendingKey: '' };

  function endpoint() {
    const url = new URL(collectionUrl(), window.location.href);
    if (url.origin !== window.location.origin) throw new Error('Maintenance services must use the authenticated same-origin host.');
    url.searchParams.set('estateId', estateId());
    return url.toString();
  }
  function mineEndpoint(page) {
    const base = endpoint();
    const url = new URL(base);
    url.pathname = `${url.pathname.replace(/\/$/, '')}/mine`;
    url.searchParams.set('page', String(page));
    url.searchParams.set('pageSize', String(state.pageSize));
    return url.toString();
  }
  function detailEndpoint(requestId) {
    const custom = config().residentMaintenanceRequestDetailUrl;
    if (typeof custom === 'string' && custom.trim()) {
      const value = custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId()))
        .replaceAll('{requestId}', encodeURIComponent(String(requestId)))
        .replace(':estateId', encodeURIComponent(estateId())).replace(':requestId', encodeURIComponent(String(requestId)));
      const url = new URL(value, window.location.href);
      if (url.origin !== window.location.origin) throw new Error('Maintenance services must use the authenticated same-origin host.');
      return url.toString();
    }
    const url = new URL(endpoint());
    url.pathname = `${url.pathname.replace(/\/$/, '')}/${encodeURIComponent(String(requestId))}`;
    return url.toString();
  }
  async function apiRequest(url, method = 'GET', payload, headers = {}) {
    const adapter = config().request;
    if (typeof adapter !== 'function') {
      throw new Error('Maintenance requests require the host authenticated API request adapter.');
    }
    const response = await adapter({ url, method, payload, headers, credentials: 'same-origin' });
    let body = response;
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error('The maintenance service could not complete this request.');
      body = response.status === 204 ? null : await response.json();
    }
    return body?.data ?? body;
  }
  function feedback(message, kind = '') {
    let node = form.querySelector('.resident-live-feedback');
    if (!node) {
      node = document.createElement('p');
      node.className = 'resident-live-feedback';
      node.setAttribute('role', 'status');
      node.setAttribute('aria-live', 'polite');
      form.querySelector('.resident-form-actions').before(node);
    }
    node.textContent = message;
    node.dataset.state = kind;
  }
  function text(parent, tag, className, content) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = content;
    parent.append(node);
    return node;
  }
  function displayCategory(value) { return String(value || 'other').replaceAll('_', ' '); }
  function statusLabel(value) {
    return String(value || 'submitted').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
  function statusClass(value) {
    return ({ in_progress: 'status-progress', resolved: 'status-paid', closed: 'status-paid', rejected: 'status-due', assigned: 'status-review' })[value] || 'status-review';
  }
  function validInstant(value) {
    return typeof value === 'string' && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString() === value;
  }
  function newRequestKey() {
    const bytes = new Uint8Array(24);
    if (!window.crypto?.getRandomValues) throw new Error('Secure request keys are unavailable in this browser.');
    window.crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }
  function validRequest(item, expectedEstate) {
    const fields = new Set(['id', 'requestId', 'estateId', 'reference', 'category', 'priority', 'description', 'status', 'propertyLabel', 'submittedAt', 'updatedAt', 'residentVisibleUpdates']);
    const statuses = new Set(['submitted', 'under_review', 'assigned', 'in_progress', 'awaiting_parts', 'resolved', 'closed', 'rejected', 'reopened']);
    return Boolean(item && Object.keys(item).every((key) => fields.has(key))
      && (typeof item.id === 'string' || typeof item.id === 'number')
      && String(item.requestId) === String(item.id) && String(item.estateId) === expectedEstate
      && typeof item.reference === 'string' && item.reference.trim() && item.reference.length <= 80
      && ['plumbing', 'electrical', 'security', 'cleaning', 'other'].includes(item.category)
      && ['normal', 'high', 'urgent'].includes(item.priority) && statuses.has(item.status)
      && typeof item.description === 'string' && item.description.trim() && item.description.length <= 700
      && (item.propertyLabel === null || typeof item.propertyLabel === 'string' && item.propertyLabel.length <= 160)
      && validInstant(item.submittedAt) && (item.updatedAt === null || validInstant(item.updatedAt))
      && Array.isArray(item.residentVisibleUpdates) && item.residentVisibleUpdates.length <= 100
      && item.residentVisibleUpdates.every((update) => update && Object.keys(update).every((key) => ['body', 'occurredAt'].includes(key))
        && typeof update.body === 'string' && update.body.trim() && update.body.length <= 700 && validInstant(update.occurredAt)));
  }
  function isResolved(value) { return ['resolved', 'closed', 'rejected'].includes(value); }
  function visibleItems() {
    const requested = filter.value;
    return state.items.filter((item) => requested === 'all'
      || (requested === 'resolved' ? isResolved(item.status) : !isResolved(item.status)));
  }
  function render() {
    const items = visibleItems();
    list.replaceChildren();
    if (!items.length) {
      const empty = document.createElement('div');
      empty.className = 'resident-live-empty';
      empty.textContent = state.items.length ? 'No requests match this filter.' : 'You have no maintenance requests for this estate.';
      list.append(empty);
      return;
    }
    items.forEach((item) => {
      const card = document.createElement('article');
      card.className = 'request-card resident-maintenance-card';
      card.dataset.requestStatus = isResolved(item.status) ? 'resolved' : 'open';
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'request-card-button';
      button.setAttribute('aria-label', `View ${displayCategory(item.category)} maintenance request updates`);
      button.addEventListener('click', () => openRequestDetail(item));
      const top = document.createElement('span');
      top.className = 'request-card-top';
      text(top, 'span', 'request-kind plumbing-kind', displayCategory(item.category).slice(0, 1).toUpperCase());
      text(top, 'span', `mini-status ${statusClass(item.status)}`, statusLabel(item.status));
      button.append(top);
      text(button, 'strong', '', `${displayCategory(item.category)} request`);
      text(button, 'span', 'request-card-description', item.description || 'Description unavailable.');
      const meta = document.createElement('span');
      meta.className = 'request-meta';
      text(meta, 'span', '', `${item.reference || item.id} · ${item.propertyLabel || 'Your property'}`);
      text(meta, 'span', '', item.submittedAt ? `Submitted ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(item.submittedAt))}` : 'Submitted');
      button.append(meta);
      card.append(button);
      list.append(card);
    });
    if (state.page < state.totalPages) {
      const more = document.createElement('button');
      more.type = 'button';
      more.className = 'wide-outline resident-maintenance-more';
      more.textContent = 'Load older requests';
      more.addEventListener('click', loadMore);
      list.append(more);
    }
  }
  async function openRequestDetail(item) {
    const generation = ++state.detailGeneration;
    const requestedEstate = estateId();
    document.getElementById('requestDetailReference').textContent = item.reference || item.id;
    document.getElementById('requestDetailTitle').textContent = `${displayCategory(item.category)} request`;
    document.getElementById('requestDetailProperty').textContent = item.propertyLabel || 'Your property';
    const status = document.getElementById('requestDetailStatus');
    status.textContent = statusLabel(item.status);
    status.className = `mini-status ${statusClass(item.status)}`;
    const updatedAt = item.updatedAt || item.submittedAt;
    document.getElementById('requestDetailUpdated').textContent = updatedAt
      ? `Updated ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(updatedAt))}`
      : 'Update time unavailable';
    document.getElementById('requestDetailDescription').textContent = item.description || 'Description unavailable.';
    const timeline = document.getElementById('requestDetailTimeline');
    timeline.replaceChildren();
    const loading = document.createElement('p');
    loading.className = 'resident-live-loading';
    loading.textContent = 'Loading request history…';
    timeline.append(loading);
    document.getElementById('maintenanceDetailModal').classList.remove('hidden');
    try {
      const result = await apiRequest(detailEndpoint(item.id));
      if (generation !== state.detailGeneration || requestedEstate !== estateId()) return;
      if (!result?.item || !validRequest(result.item, requestedEstate) || String(result.item.id) !== String(item.id)) {
        throw new Error('Invalid detail');
      }
      item = result.item;
      document.getElementById('requestDetailReference').textContent = item.reference || item.id;
      document.getElementById('requestDetailTitle').textContent = `${displayCategory(item.category)} request`;
      document.getElementById('requestDetailProperty').textContent = item.propertyLabel || 'Your property';
      const detailStatus = document.getElementById('requestDetailStatus');
      detailStatus.textContent = statusLabel(item.status);
      detailStatus.className = `mini-status ${statusClass(item.status)}`;
      const detailUpdatedAt = item.updatedAt || item.submittedAt;
      document.getElementById('requestDetailUpdated').textContent = detailUpdatedAt
        ? `Updated ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(detailUpdatedAt))}`
        : 'Update time unavailable';
      document.getElementById('requestDetailDescription').textContent = item.description;
    } catch {
      if (generation !== state.detailGeneration || requestedEstate !== estateId()) return;
      timeline.replaceChildren();
      const error = document.createElement('p');
      error.setAttribute('role', 'alert');
      error.textContent = 'Request history could not be loaded. Close this panel and try again.';
      timeline.append(error);
      return;
    }
    const events = [
      ...(item.submittedAt ? [{ body: 'Request submitted to the estate team.', occurredAt: item.submittedAt, title: 'Submitted' }] : []),
      ...(item.residentVisibleUpdates || []).map((update) => ({ ...update, title: 'Update from the estate team' })),
    ].sort((left, right) => new Date(left.occurredAt) - new Date(right.occurredAt));
    if (!events.length) events.push({ title: statusLabel(item.status), body: 'No resident-visible updates have been posted yet.' });
    events.forEach((event) => {
      const entry = document.createElement('article');
      entry.className = 'request-history-item';
      const date = document.createElement('time');
      const parsed = new Date(event.occurredAt);
      date.textContent = Number.isNaN(parsed.getTime()) ? '' : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(parsed);
      const heading = document.createElement('strong');
      heading.textContent = event.title;
      const body = document.createElement('p');
      body.textContent = event.body;
      entry.append(date, heading, body);
      timeline.append(entry);
    });
    document.getElementById('confirmResolution').classList.add('hidden');
    document.getElementById('reopenRequest').classList.add('hidden');
    const note = document.querySelector('#maintenanceDetailModal .resident-form-preview');
    if (note) note.textContent = 'Only updates shared with residents are shown here. Internal staff notes remain private.';
  }
  async function loadPage(page, append) {
    const currentGeneration = ++state.generation;
    const requestedEstate = estateId();
    if (!append) {
      state.items = [];
      state.page = 0;
      state.totalPages = 1;
      list.replaceChildren();
      const loading = document.createElement('div');
      loading.className = 'resident-live-loading';
      loading.textContent = 'Loading your maintenance requests…';
      list.append(loading);
    } else {
      const more = list.querySelector('.resident-maintenance-more');
      if (more) { more.disabled = true; more.textContent = 'Loading…'; }
    }
    try {
      const result = await apiRequest(mineEndpoint(page));
      if (currentGeneration !== state.generation || requestedEstate !== estateId()) return;
      if (!result || !Array.isArray(result.items) || result.items.length > state.pageSize
        || result.page !== page || result.pageSize !== state.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || !Number.isInteger(result.totalPages) || result.totalPages !== Math.ceil(result.total / result.pageSize)
        || result.items.some((item) => !validRequest(item, requestedEstate))
        || new Set(result.items.map((item) => String(item.id))).size !== result.items.length) {
        throw new Error('The maintenance service returned an invalid request list.');
      }
      const pageIds = new Set(result.items.map((item) => String(item.id)));
      if (append && state.items.some((item) => pageIds.has(String(item.id)))) throw new Error('The maintenance service returned duplicate requests across pages.');
      state.items = append ? [...state.items, ...result.items] : result.items;
      state.page = result.page;
      state.totalPages = Math.max(1, result.totalPages);
      render();
    } catch {
      if (currentGeneration !== state.generation || requestedEstate !== estateId()) return;
      list.replaceChildren();
      const message = document.createElement('div');
      message.className = 'resident-live-empty';
      message.setAttribute('role', 'alert');
      message.textContent = 'Your maintenance requests could not be loaded. Refresh to try again.';
      list.append(message);
    }
  }
  function load() { return loadPage(1, false); }
  function loadMore() { if (state.page < state.totalPages) return loadPage(state.page + 1, true); }

  previewLabel.textContent = 'Connected to your estate maintenance service.';
  feedback('');
  window.submitResidentMaintenanceRequest = async () => {
    const requestedEstate = estateId();
    const description = document.getElementById('requestDescription').value.trim();
    if (!description) {
      feedback('Describe the issue before submitting your request.', 'error');
      document.getElementById('requestDescription').focus();
      return;
    }
    submitButton.disabled = true;
    submitButton.textContent = 'Submitting…';
    feedback('Submitting your request…');
    const payload = {
      category: document.getElementById('requestCategory').value.toLowerCase(),
      priority: document.getElementById('requestPriority').value.toLowerCase(),
      description,
    };
    const fingerprint = JSON.stringify([requestedEstate, payload.category, payload.priority, payload.description]);
    try {
      if (state.pendingFingerprint !== fingerprint || !state.pendingKey) {
        state.pendingFingerprint = fingerprint;
        state.pendingKey = newRequestKey();
      }
      const result = await apiRequest(endpoint(), 'POST', payload, { 'Idempotency-Key': state.pendingKey });
      if (requestedEstate !== estateId()) throw new Error('Your selected estate changed. Please review the form and submit again.');
      const resultFields = new Set(['requestId', 'estateId', 'propertyId', 'category', 'priority', 'description', 'status', 'submittedAt', 'replayed']);
      if (!result || Object.keys(result).some((field) => !resultFields.has(field))
        || result.replayed !== undefined && typeof result.replayed !== 'boolean'
        || !(typeof result.requestId === 'string' || typeof result.requestId === 'number')
        || result.status !== 'submitted' || String(result.estateId) !== requestedEstate
        || result.category !== document.getElementById('requestCategory').value.toLowerCase()
        || result.priority !== document.getElementById('requestPriority').value.toLowerCase()
        || typeof result.propertyId !== 'string' && typeof result.propertyId !== 'number'
        || typeof result.description !== 'string' || result.description !== description
        || !validInstant(result.submittedAt)) {
        throw new Error('The maintenance service did not confirm this request.');
      }
      state.pendingFingerprint = '';
      state.pendingKey = '';
      modal.classList.add('hidden');
      feedback('Your request was submitted.', 'success');
      document.getElementById('requestDescription').value = '';
      filter.value = 'open';
      await load();
    } catch {
      feedback('Your request could not be submitted. Check your connection and try again. Retrying unchanged details will not create a duplicate.', 'error');
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = 'Submit request';
    }
  };
  window.showResidentMaintenanceDetail = (requestId) => {
    const item = state.items.find((request) => String(request.id) === String(requestId));
    if (item) openRequestDetail(item);
  };
  window.cancelResidentMaintenanceDetail = () => { state.detailGeneration += 1; };
  filter.addEventListener('change', render);
  window.addEventListener('estate:context-changed', () => {
    state.detailGeneration += 1;
    document.getElementById('maintenanceDetailModal').classList.add('hidden');
    load();
  });
  window.refreshResidentMaintenanceRequests = load;
  load();
})();
