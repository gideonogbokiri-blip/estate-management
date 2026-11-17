(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function apiBase() { return typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : ''; }
  function incidentUrl() {
    const custom = config().securityIncidentUrl || config().incidentUrl;
    return typeof custom === 'string' && custom.trim()
      ? custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()))
      : apiBase() ? `${apiBase()}/api/estate/estates/${encodeURIComponent(estateId())}/incidents` : '';
  }
  const modal = document.getElementById('securityIncidentModal');
  if (!estateId() || !incidentUrl() || !document.getElementById('moduleContent')) return;
  const form = modal?.querySelector('.resident-form-modal');
  const submit = form?.querySelector('[data-action="submit-security-incident"]');
  let generation = 0;
  let searchTimer;
  const listState = { page: 1, pageSize: 10, totalPages: 0, status: '', search: '' };
  function endpoint() {
    return new URL(incidentUrl(), window.location.href).toString();
  }
  function listUrl() {
    const url = new URL(endpoint());
    url.searchParams.set('page', String(listState.page));
    url.searchParams.set('pageSize', String(listState.pageSize));
    if (listState.status) url.searchParams.set('status', listState.status);
    if (listState.search) url.searchParams.set('search', listState.search);
    return url.toString();
  }
  async function request(url, method = 'GET', payload) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('Security incident reporting requires the host authenticated API request adapter.');
    const response = await adapter({ url, method, payload, credentials: 'same-origin' });
    let body = response;
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error(`Estate security service returned an error (${response.status}).`);
      body = response.status === 204 ? null : await response.json();
    }
    return body?.data ?? body;
  }
  function date(value) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 'Time unavailable'
      : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(parsed);
  }
  function title(value) { return String(value || 'reported').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()); }
  function reportNotice(message, error = false) {
    const notice = document.querySelector('#moduleContent .incident-live-note');
    if (!notice) return;
    notice.textContent = message;
    notice.dataset.state = error ? 'error' : 'ready';
    notice.setAttribute('role', error ? 'alert' : 'status');
    notice.setAttribute('aria-live', 'polite');
  }
  function renderRows(items) {
    const container = document.querySelector('#moduleContent .incident-list');
    if (!container) return;
    container.replaceChildren();
    if (!items.length) {
      const empty = document.createElement('p');
      empty.className = 'incident-live-empty';
      empty.textContent = 'No incidents are assigned to your current security scope.';
      container.append(empty);
      return;
    }
    items.forEach((incident) => {
      const row = document.createElement('article');
      row.className = 'incident-row';
      const mark = document.createElement('span');
      mark.className = 'incident-mark incident-mark-warm';
      mark.textContent = '!';
      const copy = document.createElement('div');
      const name = document.createElement('strong');
      name.textContent = title(incident.category);
      const detail = document.createElement('small');
      detail.textContent = `${incident.gateLabel || incident.locationDescription || 'Assigned security area'} · Reported ${date(incident.createdAt)}${incident.reporterDisplayName ? ` by ${incident.reporterDisplayName}` : ''}`;
      copy.append(name, detail);
      const badge = document.createElement('span');
      badge.className = 'status-pill status-review';
      const dot = document.createElement('i');
      badge.append(dot, document.createTextNode(title(incident.status)));
      row.append(mark, copy, badge);
      container.append(row);
    });
  }
  async function load() {
    const currentGeneration = ++generation;
    const currentEstate = estateId();
    const container = document.querySelector('#moduleContent .incident-list');
    if (!container) return;
    container.replaceChildren();
    const loading = document.createElement('p');
    loading.className = 'incident-live-empty';
    loading.textContent = 'Loading incidents for your assigned security scope…';
    container.append(loading);
    try {
      const result = await request(listUrl());
      if (currentGeneration !== generation || currentEstate !== estateId()) return;
      const allowed = new Set(['incidentId', 'estateId', 'category', 'status', 'createdAt', 'observedAt', 'locationDescription', 'reporterDisplayName', 'gateLabel']);
      if (!result || !Array.isArray(result.items) || result.items.length > listState.pageSize
        || result.page !== listState.page || result.pageSize !== listState.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || !Number.isSafeInteger(result.totalPages) || result.totalPages !== Math.ceil(result.total / result.pageSize)
        || result.items.some((item) => !item || Object.keys(item).some((key) => !allowed.has(key))
          || String(item.estateId) !== currentEstate || !item.incidentId
          || !['reported', 'acknowledged', 'assigned', 'investigating', 'contained', 'resolved', 'closed', 'reopened'].includes(item.status)
          || typeof item.category !== 'string' || !item.category.trim() || !Number.isFinite(new Date(item.createdAt).getTime())
          || !Number.isFinite(new Date(item.observedAt).getTime()))) {
        throw new Error('The security service returned an invalid or out-of-scope incident list.');
      }
      listState.totalPages = result.totalPages;
      renderRows(result.items);
      const summary = document.querySelector('#moduleContent [data-incident-summary]');
      if (summary) summary.textContent = `Showing ${result.items.length} of ${result.total} authorized incidents`;
      const page = document.querySelector('#moduleContent [data-incident-page-label]');
      if (page) page.textContent = result.totalPages ? `${listState.page} / ${result.totalPages}` : '0 pages';
      const previous = document.querySelector('#moduleContent [data-incident-page="previous"]');
      const next = document.querySelector('#moduleContent [data-incident-page="next"]');
      if (previous) previous.disabled = listState.page <= 1;
      if (next) next.disabled = listState.page >= result.totalPages;
      reportNotice(`${result.total} incidents in your authorized security view.`);
    } catch (error) {
      if (currentGeneration !== generation || currentEstate !== estateId()) return;
      const container = document.querySelector('#moduleContent .incident-list');
      if (container) {
        container.replaceChildren();
        const message = document.createElement('p');
        message.className = 'incident-live-empty';
        message.textContent = error instanceof Error ? error.message : 'Incidents could not be loaded.';
        container.append(message);
      }
      reportNotice(error instanceof Error ? error.message : 'Incidents could not be loaded.', true);
    }
  }

  window.openSecurityIncidentForm = () => {
    if (!modal || !form) return;
    document.getElementById('securityIncidentCategory').value = 'security_concern';
    document.getElementById('securityIncidentPriority').value = 'normal';
    document.getElementById('securityIncidentLocation').value = '';
    document.getElementById('securityIncidentDescription').value = '';
    document.getElementById('securityIncidentObservedAt').value = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    document.getElementById('securityIncidentError').textContent = '';
    modal.classList.remove('hidden');
    document.getElementById('securityIncidentLocation').focus();
  };
  window.submitSecurityIncidentReport = async () => {
    if (!modal || !form || !submit) return;
    const locationDescription = document.getElementById('securityIncidentLocation').value.trim();
    const description = document.getElementById('securityIncidentDescription').value.trim();
    const observedValue = document.getElementById('securityIncidentObservedAt').value;
    const observedAt = new Date(observedValue);
    const errorNode = document.getElementById('securityIncidentError');
    if (!locationDescription || !description) { errorNode.textContent = 'Add a location and describe what happened.'; return; }
    if (!observedValue || Number.isNaN(observedAt.getTime()) || observedAt > new Date()) { errorNode.textContent = 'Choose a valid time that is not in the future.'; return; }
    submit.disabled = true;
    submit.textContent = 'Submitting…';
    errorNode.textContent = '';
    try {
      const result = await request(endpoint(), 'POST', {
        category: document.getElementById('securityIncidentCategory').value,
        priority: document.getElementById('securityIncidentPriority').value,
        locationDescription,
        description,
        observedAt: observedAt.toISOString(),
      });
      if (!result || !result.incidentId || String(result.estateId) !== estateId() || result.status !== 'reported') {
        throw new Error('The incident service did not confirm this report.');
      }
      modal.classList.add('hidden');
      reportNotice('Incident report sent to the authorized estate team.');
      await load();
    } catch (error) {
      errorNode.textContent = error instanceof Error ? error.message : 'The incident could not be submitted.';
    } finally {
      submit.disabled = false;
      submit.textContent = 'Submit report';
    }
  };
  window.closeSecurityIncidentForm = () => modal?.classList.add('hidden');
  const moduleContent = document.getElementById('moduleContent');
  function ensureListControls() {
    const panel = moduleContent.querySelector('.incident-panel');
    const header = panel?.querySelector('.panel-header');
    const footer = panel?.querySelector('.module-table-foot');
    if (!panel || !header || !footer) return;
    if (!panel.querySelector('[data-incident-status-filter]')) {
      const toolbar = document.createElement('div');
      toolbar.className = 'incident-live-toolbar';
      const statusLabel = document.createElement('label');
      statusLabel.append(document.createTextNode('Status'));
      const status = document.createElement('select');
      status.dataset.incidentStatusFilter = 'true';
      [['', 'All statuses'], ['reported', 'Reported'], ['acknowledged', 'Acknowledged'], ['assigned', 'Assigned'], ['investigating', 'Investigating'], ['contained', 'Contained'], ['resolved', 'Resolved'], ['closed', 'Closed'], ['reopened', 'Reopened']]
        .forEach(([value, label]) => { const option = document.createElement('option'); option.value = value; option.textContent = label; status.append(option); });
      statusLabel.append(status);
      const searchLabel = document.createElement('label');
      searchLabel.append(document.createTextNode('Search'));
      const search = document.createElement('input');
      search.type = 'search';
      search.placeholder = 'Location, category or reporter';
      search.dataset.incidentSearch = 'true';
      searchLabel.append(search);
      toolbar.append(statusLabel, searchLabel);
      header.after(toolbar);
    }
    if (!footer.querySelector('[data-incident-page]')) {
      const historyButton = footer.querySelector('[data-action="incident-history"]');
      historyButton?.remove();
      const summary = footer.querySelector('span');
      if (summary) summary.dataset.incidentSummary = 'true';
      const pager = document.createElement('div');
      pager.className = 'incident-live-pager';
      const previous = document.createElement('button');
      previous.type = 'button'; previous.className = 'table-action'; previous.dataset.incidentPage = 'previous'; previous.textContent = 'Previous';
      const label = document.createElement('span'); label.dataset.incidentPageLabel = 'true';
      const next = document.createElement('button');
      next.type = 'button'; next.className = 'table-action'; next.dataset.incidentPage = 'next'; next.textContent = 'Next';
      pager.append(previous, label, next);
      footer.append(pager);
    }
  }
  new MutationObserver(() => {
    if (!document.querySelector('#moduleContent .incident-list')) return;
    ensureListControls();
    const note = document.querySelector('#moduleContent .security-footnote');
    if (note) note.textContent = 'Pass verification and entry/exit recording remain subject to assigned-gate checks by the security service.';
    load();
  }).observe(moduleContent, { childList: true });
  document.addEventListener('change', (event) => {
    if (event.target.matches('[data-incident-status-filter]')) {
      listState.status = event.target.value;
      listState.page = 1;
      load();
    }
  });
  document.addEventListener('input', (event) => {
    if (!event.target.matches('[data-incident-search]')) return;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { listState.search = event.target.value.trim().slice(0, 100); listState.page = 1; load(); }, 250);
  });
  document.addEventListener('click', (event) => {
    const button = event.target.closest('[data-incident-page]');
    if (!button) return;
    const page = listState.page + (button.dataset.incidentPage === 'next' ? 1 : -1);
    if (page < 1 || page > listState.totalPages) return;
    listState.page = page;
    load();
  });
  modal?.addEventListener('click', (event) => { if (event.target === modal) window.closeSecurityIncidentForm(); });
  window.addEventListener('estate:context-changed', load);
})();
