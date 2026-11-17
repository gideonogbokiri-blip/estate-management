(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function apiBase() { return typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : ''; }
  function incidentUrl() {
    const custom = config().residentIncidentUrl || config().incidentUrl;
    return typeof custom === 'string' && custom.trim()
      ? custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()))
      : apiBase() ? `${apiBase()}/api/estate/estates/${encodeURIComponent(estateId())}/incidents` : '';
  }
  function mineUrl() {
    const custom = config().residentIncidentListUrl || config().incidentListUrl;
    return typeof custom === 'string' && custom.trim()
      ? custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()))
      : incidentUrl() ? `${incidentUrl().replace(/\/$/, '')}/mine` : '';
  }
  if (!estateId() || !incidentUrl() || !mineUrl()) return;

  const modal = document.getElementById('incidentReportModal');
  const form = modal.querySelector('.resident-form-modal');
  const submit = form.querySelector('[data-action="submit-incident"]');
  const list = document.getElementById('residentIncidentList');
  const formNote = form.querySelector('.resident-form-preview');

  function requestUrl(base) {
    const url = new URL(base, window.location.href);
    if (url.origin !== window.location.origin) throw new Error('Incident services must use the authenticated same-origin host.');
    return url.toString();
  }
  async function request(url, method = 'GET', payload) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('Incident reporting requires the host authenticated API request adapter.');
    const response = await adapter({ url, method, payload, credentials: 'same-origin' });
    let body = response;
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error('The incident service could not complete this request.');
      body = response.status === 204 ? null : await response.json();
    }
    return body?.data ?? body;
  }
  function label(value) { return String(value || 'reported').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()); }
  function date(value) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 'Date unavailable'
      : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(parsed);
  }
  function appendText(parent, tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = value;
    parent.append(node);
    return node;
  }
  function validInstant(value) {
    return typeof value === 'string' && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString() === value;
  }
  function validIncident(item) {
    const fields = new Set(['incidentId', 'estateId', 'category', 'priority', 'status', 'description', 'locationDescription', 'observedAt', 'createdAt']);
    return Boolean(item && Object.keys(item).every((field) => fields.has(field))
      && (typeof item.incidentId === 'string' || typeof item.incidentId === 'number')
      && String(item.estateId) === estateId()
      && typeof item.category === 'string' && item.category.trim() && item.category.length <= 80
      && typeof item.priority === 'string' && item.priority.trim() && item.priority.length <= 32
      && ['reported', 'acknowledged', 'assigned', 'investigating', 'contained', 'resolved', 'closed', 'reopened'].includes(item.status)
      && typeof item.description === 'string' && item.description.trim() && item.description.length <= 1000
      && (item.locationDescription === null || typeof item.locationDescription === 'string' && item.locationDescription.length <= 120)
      && validInstant(item.observedAt) && validInstant(item.createdAt));
  }
  function render(items) {
    list.replaceChildren();
    if (!items.length) {
      const empty = document.createElement('div');
      empty.className = 'resident-live-empty';
      empty.textContent = 'You have not submitted an incident report in this estate.';
      list.append(empty);
      return;
    }
    items.forEach((incident) => {
      const card = document.createElement('article');
      card.className = 'request-card resident-incident-live-card';
      const top = document.createElement('div');
      top.className = 'request-card-top';
      appendText(top, 'span', 'request-kind electrical-kind', '!');
      appendText(top, 'span', 'mini-status status-review', label(incident.status));
      card.append(top);
      appendText(card, 'strong', '', label(incident.category));
      appendText(card, 'p', '', incident.description);
      const meta = document.createElement('div');
      meta.className = 'request-meta';
      appendText(meta, 'span', '', incident.incidentId);
      appendText(meta, 'span', '', `Reported ${date(incident.createdAt)}`);
      card.append(meta);
      if (incident.locationDescription) appendText(card, 'small', 'incident-live-location', `Location: ${incident.locationDescription}`);
      list.append(card);
    });
  }
  async function load() {
    list.replaceChildren();
    const loading = document.createElement('div');
    loading.className = 'resident-live-loading';
    loading.textContent = 'Loading your incident reports…';
    list.append(loading);
    const context = estateId();
    try {
      const result = await request(requestUrl(mineUrl()));
      if (context !== estateId()) return;
      if (!result || !Array.isArray(result.items) || result.items.length > 100
        || result.items.some((item) => !validIncident(item))
        || new Set(result.items.map((item) => String(item.incidentId))).size !== result.items.length) {
        throw new Error('The incident service returned an invalid or out-of-scope report list.');
      }
      render(result.items);
    } catch {
      if (context !== estateId()) return;
      list.replaceChildren();
      const message = document.createElement('div');
      message.className = 'resident-live-empty';
      message.setAttribute('role', 'alert');
      message.textContent = 'Your incident reports could not be loaded. Refresh to try again.';
      list.append(message);
    }
  }
  function showError(message) { document.getElementById('incidentReportError').textContent = message; }

  formNote.textContent = 'Connected to your estate incident service.';
  window.submitResidentIncidentReport = async () => {
    const description = document.getElementById('incidentDescription').value.trim();
    const locationDescription = document.getElementById('incidentLocation').value.trim();
    const observedValue = document.getElementById('incidentObservedAt').value;
    const observedAt = new Date(observedValue);
    if (!locationDescription) { showError('Add the location where this happened.'); document.getElementById('incidentLocation').focus(); return; }
    if (!description) { showError('Describe what happened.'); document.getElementById('incidentDescription').focus(); return; }
    if (!observedValue || Number.isNaN(observedAt.getTime()) || observedAt > new Date()) { showError('Choose a valid time that is not in the future.'); return; }
    submit.disabled = true;
    submit.textContent = 'Submitting…';
    showError('');
    try {
      const result = await request(requestUrl(incidentUrl()), 'POST', {
        category: document.getElementById('incidentCategory').value,
        priority: document.getElementById('incidentPriority').value,
        locationDescription,
        description,
        observedAt: observedAt.toISOString(),
      });
      if (!result || !result.incidentId || String(result.estateId) !== estateId() || result.status !== 'reported') {
        throw new Error('The incident service did not confirm this report.');
      }
      modal.classList.add('hidden');
      document.getElementById('incidentDescription').value = '';
      await load();
      if (typeof window.showResidentMessage === 'function') window.showResidentMessage('Incident report submitted to your estate team.');
    } catch {
      showError('The incident report could not be submitted. Check your connection and try again.');
    } finally {
      submit.disabled = false;
      submit.textContent = 'Submit report';
    }
  };
  window.addEventListener('estate:context-changed', load);
  window.refreshResidentIncidentReports = load;
  load();
})();
