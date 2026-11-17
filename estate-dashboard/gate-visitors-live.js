(() => {
  let generation = 0;
  let pendingCheckInKey = '';
  let pendingManualAdmissionKey = '';

  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() { return config().currentEstateId == null ? '' : String(config().currentEstateId); }
  function gateId() { return config().currentGateId == null ? '' : String(config().currentGateId); }
  function endpoint() {
    const custom = config().gateVisitorsUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId()))
        .replaceAll('{gateId}', encodeURIComponent(gateId()))
        .replace(':estateId', encodeURIComponent(estateId())).replace(':gateId', encodeURIComponent(gateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/security/gates/${encodeURIComponent(gateId())}/visitors/current` : '';
  }
  function checkOutEndpoint(visitId) {
    const custom = config().gateVisitCheckOutUrl;
    if (typeof custom !== 'string' || !custom.trim()) return '';
    return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId()))
      .replaceAll('{gateId}', encodeURIComponent(gateId())).replaceAll('{visitId}', encodeURIComponent(visitId))
      .replace(':estateId', encodeURIComponent(estateId())).replace(':gateId', encodeURIComponent(gateId()))
      .replace(':visitId', encodeURIComponent(visitId));
  }
  function checkInEndpoint() {
    const custom = config().gateVisitCheckInUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{gateId}', encodeURIComponent(gateId()))
        .replace(':gateId', encodeURIComponent(gateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base && gateId() ? `${base}/api/estate/security/gates/${encodeURIComponent(gateId())}/check-in` : '';
  }
  function manualAdmissionEndpoint() {
    const custom = config().manualAdmissionUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{gateId}', encodeURIComponent(gateId())).replace(':gateId', encodeURIComponent(gateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base && gateId() ? `${base}/api/estate/security/gates/${encodeURIComponent(gateId())}/manual-admissions` : '';
  }
  function canManuallyAdmit() {
    return Array.isArray(config().currentPermissions) && config().currentPermissions.includes('visitor.override');
  }
  function onView() { return document.getElementById('moduleContent')?.dataset.view === 'gate'; }
  function make(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (value !== undefined && value !== null) node.textContent = value;
    return node;
  }
  function responseError(status) {
    const error = new Error(`Gate security service returned an error (${status}).`);
    error.status = status;
    return error;
  }
  async function get(url) {
    const request = config().request;
    let response;
    if (typeof request === 'function') {
      response = await request({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw responseError(response.status);
        response = await response.json();
      }
    } else {
      const result = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!result.ok) throw responseError(result.status);
      response = await result.json();
    }
    return response?.data ?? response;
  }
  async function send(url, payload, headers = {}) {
    const request = config().request;
    let response;
    if (typeof request === 'function') {
      response = await request({ url, method: 'POST', payload, headers, credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw responseError(response.status);
        response = response.status === 204 ? null : await response.json();
      }
    } else {
      const result = await fetch(url, { method: 'POST', credentials: 'same-origin', headers: { Accept: 'application/json', 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(payload) });
      if (!result.ok) throw responseError(result.status);
      response = result.status === 204 ? null : await result.json();
    }
    return response?.data ?? response;
  }
  function validTimestamp(value) {
    if (typeof value !== 'string') return false;
    const date = new Date(value);
    return !Number.isNaN(date.getTime()) && date.toISOString() === value;
  }
  function newIdempotencyKey() {
    if (!window.crypto?.getRandomValues) throw new Error('Secure request keys are unavailable in this browser.');
    const bytes = new Uint8Array(24);
    window.crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }
  function validate(result) {
    const fields = new Set(['visitId', 'visitorName', 'hostDisplayName', 'propertyLabel', 'vehicleSummary', 'checkedInAt']);
    const seen = new Set();
    return Boolean(result && String(result.estateId) === estateId() && String(result.gateId) === gateId()
      && Array.isArray(result.items) && result.items.length <= 100 && validTimestamp(result.asOf)
      && result.items.every((item) => {
        const id = item?.visitId == null ? '' : String(item.visitId);
        if (!id || seen.has(id)) return false;
        seen.add(id);
        return Object.keys(item).every((key) => fields.has(key))
          && typeof item.visitorName === 'string' && item.visitorName.trim() && item.visitorName.length <= 100
          && typeof item.hostDisplayName === 'string' && item.hostDisplayName.trim() && item.hostDisplayName.length <= 160
          && typeof item.propertyLabel === 'string' && item.propertyLabel.trim() && item.propertyLabel.length <= 160
          && (item.vehicleSummary === null || (typeof item.vehicleSummary === 'string' && item.vehicleSummary.length <= 80))
          && validTimestamp(item.checkedInAt);
      }));
  }
  function formatTime(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Time unavailable' : new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' }).format(date);
  }
  function stateMessage(message, kind = 'ready') {
    const note = document.querySelector('#moduleContent .gate-live-status');
    if (!note) return;
    note.textContent = message;
    note.dataset.state = kind;
    note.setAttribute('role', kind === 'error' ? 'alert' : 'status');
    note.setAttribute('aria-live', 'polite');
  }
  async function submitCheckIn(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const input = form.querySelector('[name="visitorCredential"]');
    const button = form.querySelector('button[type="submit"]');
    const note = form.querySelector('[data-gate-check-in-note]');
    const credential = input.value.trim();
    const url = checkInEndpoint();
    if (!url || !credential || credential.length > 256) {
      note.textContent = 'Enter a valid visitor pass credential.';
      note.dataset.state = 'error';
      note.setAttribute('role', 'alert');
      return;
    }
    const requestedEstate = estateId();
    const requestedGate = gateId();
    if (!pendingCheckInKey) {
      try { pendingCheckInKey = newIdempotencyKey(); }
      catch (error) {
        note.textContent = error instanceof Error ? error.message : 'Secure request keys are unavailable.';
        note.dataset.state = 'error';
        note.setAttribute('role', 'alert');
        return;
      }
    }
    button.disabled = true;
    input.disabled = true;
    button.textContent = 'Checking…';
    note.textContent = 'Verifying pass and recording entry…';
    note.dataset.state = 'loading';
    note.setAttribute('role', 'status');
    try {
      const result = await send(url, { credential }, { 'Idempotency-Key': pendingCheckInKey });
      if (requestedEstate !== estateId() || requestedGate !== gateId()) return;
      const fields = new Set(['visitId', 'estateId', 'gateId', 'status', 'visitorName', 'propertyLabel', 'hostDisplayName', 'vehicleSummary', 'checkedInAt', 'validUntil']);
      if (!result || Object.keys(result).some((key) => !fields.has(key))
        || String(result.estateId) !== requestedEstate || String(result.gateId) !== requestedGate
        || !result.visitId || result.status !== 'checked_in'
        || typeof result.visitorName !== 'string' || !result.visitorName.trim() || result.visitorName.length > 100
        || typeof result.propertyLabel !== 'string' || !result.propertyLabel.trim() || result.propertyLabel.length > 160
        || typeof result.hostDisplayName !== 'string' || !result.hostDisplayName.trim() || result.hostDisplayName.length > 160
        || !(result.vehicleSummary === null || (typeof result.vehicleSummary === 'string' && result.vehicleSummary.length <= 80))
        || !validTimestamp(result.checkedInAt) || !validTimestamp(result.validUntil)) {
        throw new Error('The gate service did not confirm this entry for the assigned gate.');
      }
      input.value = '';
      pendingCheckInKey = '';
      note.textContent = `Entry recorded for ${result.visitorName} at ${result.propertyLabel}.`;
      note.dataset.state = 'ready';
      note.setAttribute('role', 'status');
      await load();
    } catch (error) {
      if (requestedEstate !== estateId() || requestedGate !== gateId()) return;
      const status = Number.isInteger(error?.status) ? error.status : 0;
      note.textContent = status === 422 || status === 404
        ? 'This credential could not be admitted. Check the code with the host for a current pass.'
        : status === 429 ? 'Too many attempts. Wait briefly before trying again.'
          : status === 403 ? 'This account is not assigned to the selected gate.'
            : status === 401 ? 'Sign in with an account assigned to this gate.'
            : status === 409 ? 'This request could not be replayed safely. Enter the credential again to start a new check-in.'
              : status >= 500 || status === 0 ? 'Entry was not confirmed. Keep the credential unchanged and retry safely.'
                : error instanceof Error ? error.message : 'The pass could not be checked in.';
      note.dataset.state = 'error';
      note.setAttribute('role', 'alert');
    } finally {
      button.disabled = !estateId() || !gateId() || !checkInEndpoint();
      input.disabled = false;
      button.textContent = 'Verify & record entry';
    }
  }
  async function submitManualAdmission(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const name = form.querySelector('[name="manualVisitorName"]');
    const property = form.querySelector('[name="manualPropertyReference"]');
    const reason = form.querySelector('[name="manualAdmissionReason"]');
    const button = form.querySelector('button[type="submit"]');
    const note = form.querySelector('[data-manual-admission-note]');
    const payload = { visitorDisplayName: name.value.trim(), propertyReference: property.value.trim(), reason: reason.value.trim() };
    const url = manualAdmissionEndpoint();
    if (!url || !payload.visitorDisplayName || payload.visitorDisplayName.length > 100
      || !payload.propertyReference || payload.propertyReference.length > 80
      || payload.reason.length < 10 || payload.reason.length > 500) {
      note.textContent = 'Add the visitor name, property reference and a reason of at least 10 characters.';
      note.dataset.state = 'error'; note.setAttribute('role', 'alert'); return;
    }
    const requestedEstate = estateId();
    const requestedGate = gateId();
    if (!pendingManualAdmissionKey) {
      try { pendingManualAdmissionKey = newIdempotencyKey(); }
      catch (error) {
        note.textContent = error instanceof Error ? error.message : 'Secure request keys are unavailable.';
        note.dataset.state = 'error'; note.setAttribute('role', 'alert'); return;
      }
    }
    button.disabled = true;
    [name, property, reason].forEach((field) => { field.disabled = true; });
    note.textContent = 'Recording the authorized manual admission…';
    note.dataset.state = 'loading'; note.setAttribute('role', 'status');
    try {
      const result = await send(url, payload, { 'Idempotency-Key': pendingManualAdmissionKey });
      if (requestedEstate !== estateId() || requestedGate !== gateId()) return;
      const fields = new Set(['visitId', 'estateId', 'gateId', 'status', 'visitorName', 'hostDisplayName', 'propertyLabel', 'vehicleSummary', 'checkedInAt']);
      if (!result || Object.keys(result).some((field) => !fields.has(field))
        || String(result.estateId) !== requestedEstate || String(result.gateId) !== requestedGate
        || !result.visitId || result.status !== 'checked_in' || result.visitorName !== payload.visitorDisplayName
        || result.hostDisplayName !== 'Manual admission' || typeof result.propertyLabel !== 'string'
        || !result.propertyLabel.trim() || result.propertyLabel.length > 160 || result.vehicleSummary !== null
        || !validTimestamp(result.checkedInAt)) throw new Error('The gate service did not confirm this manual admission.');
      pendingManualAdmissionKey = '';
      form.reset();
      note.textContent = `Manual admission recorded for ${result.visitorName} at ${result.propertyLabel}.`;
      note.dataset.state = 'ready'; note.setAttribute('role', 'status');
      await load();
    } catch (error) {
      if (requestedEstate !== estateId() || requestedGate !== gateId()) return;
      const status = Number.isInteger(error?.status) ? error.status : 0;
      note.textContent = status === 403 ? 'Your gate role cannot use manual admission.'
        : status === 422 || status === 404 ? 'Manual admission was not recorded. Check the property reference and required details.'
          : status === 429 ? 'Too many manual admission requests. Wait briefly before trying again.'
            : status >= 500 || status === 0 ? 'Confirmation was not received. Retry without changing these details.'
              : error instanceof Error ? error.message : 'Manual admission could not be recorded.';
      note.dataset.state = 'error'; note.setAttribute('role', 'alert');
    } finally {
      button.disabled = !canManuallyAdmit() || !manualAdmissionEndpoint();
      [name, property, reason].forEach((field) => { field.disabled = false; });
    }
  }
  function ensureManualAdmissionControl(panel) {
    const existing = panel.querySelector('[data-manual-admission-form]')?.closest('.gate-manual-admission');
    if (!canManuallyAdmit() || !manualAdmissionEndpoint()) {
      existing?.remove();
      pendingManualAdmissionKey = '';
      return;
    }
    if (existing) return;
    const details = document.createElement('details');
    details.className = 'gate-manual-admission';
    const summary = document.createElement('summary'); summary.textContent = 'Record manual admission';
    const form = document.createElement('form'); form.dataset.manualAdmissionForm = 'true';
    const addField = (name, labelText, tag, maxLength, required = true) => {
      const label = document.createElement('label'); label.textContent = labelText;
      const field = document.createElement(tag); field.name = name; field.maxLength = maxLength; field.required = required;
      field.addEventListener('input', () => { pendingManualAdmissionKey = ''; });
      label.append(field); return [label, field];
    };
    const [nameLabel] = addField('manualVisitorName', 'Visitor name', 'input', 100);
    const [propertyLabel] = addField('manualPropertyReference', 'Destination property reference', 'input', 80);
    const [reasonLabel, reason] = addField('manualAdmissionReason', 'Reason for override', 'textarea', 500);
    reason.minLength = 10;
    const note = document.createElement('p'); note.dataset.manualAdmissionNote = 'true'; note.setAttribute('role', 'status');
    const submit = document.createElement('button'); submit.type = 'submit'; submit.className = 'button button-secondary'; submit.textContent = 'Record admission';
    form.append(nameLabel, propertyLabel, reasonLabel, note, submit);
    form.addEventListener('submit', submitManualAdmission);
    details.append(summary, form);
    const table = panel.querySelector('.table-wrap');
    if (table) panel.insertBefore(details, table); else panel.append(details);
  }
  function ensureCheckInControl() {
    const panel = document.querySelector('#moduleContent .gate-operations');
    const header = panel?.querySelector('.panel-header');
    if (!panel || !header) return;
    ensureManualAdmissionControl(panel);
    if (panel.querySelector('[data-gate-check-in-form]')) return;
    const form = document.createElement('form');
    form.className = 'gate-check-in-form';
    form.dataset.gateCheckInForm = 'true';
    const label = document.createElement('label');
    label.textContent = 'Visitor pass credential';
    const input = document.createElement('input');
    input.name = 'visitorCredential';
    input.type = 'password';
    input.autocapitalize = 'off';
    input.autocomplete = 'off';
    input.spellcheck = false;
    input.maxLength = 256;
    input.placeholder = 'Scan or enter pass credential';
    input.required = true;
    input.addEventListener('input', () => { pendingCheckInKey = ''; });
    label.append(input);
    const button = document.createElement('button');
    button.type = 'submit';
    button.className = 'button button-primary';
    button.textContent = 'Verify & record entry';
    const note = document.createElement('p');
    note.dataset.gateCheckInNote = 'true';
    note.setAttribute('role', 'status');
    form.append(label, button, note);
    form.addEventListener('submit', submitCheckIn);
    header.after(form);
  }
  async function load() {
    if (!onView()) return;
    const table = document.getElementById('currentVisitors');
    if (!table) return;
    const current = ++generation;
    table.replaceChildren();
    const note = document.querySelector('#moduleContent .security-footnote');
    if (note) {
      note.className = 'gate-live-status';
      note.setAttribute('role', 'status');
      note.setAttribute('aria-live', 'polite');
    }
    const shift = document.querySelector('#moduleContent .gate-live');
    if (shift) shift.replaceChildren(document.createElement('i'), document.createTextNode(estateId() && gateId() ? 'Assigned gate' : 'Gate service unavailable'));
    const heading = document.querySelector('#moduleContent .module-heading p');
    ensureCheckInControl();
    const checkInButton = document.querySelector('#moduleContent [data-gate-check-in-form] button[type="submit"]');
    if (checkInButton) checkInButton.disabled = !estateId() || !gateId() || !checkInEndpoint();
    const gateName = typeof config().currentGate?.name === 'string' ? config().currentGate.name.trim() : '';
    if (heading) heading.textContent = gateId() ? `${gateName || 'Assigned gate'} · Current visitor activity` : 'Connect an authorized gate assignment to view current visits.';
    const reportButtons = document.querySelectorAll('#moduleContent [data-action="report-incident"]');
    reportButtons.forEach((button) => { button.disabled = !estateId() || !gateId(); });
    const appendState = (message) => {
      const row = document.createElement('tr');
      const cell = make('td', 'gate-live-empty', message);
      cell.colSpan = 4;
      row.append(cell);
      table.append(row);
    };
    if (!estateId() || !gateId() || !endpoint()) {
      appendState('Connect an assigned gate to view current visitors. Sample visit data is hidden.');
      stateMessage('Gate visitor service is not connected.', 'unavailable');
      return;
    }
    appendState('Loading current visitors…');
    stateMessage('Loading current visitors…', 'loading');
    try {
      const url = new URL(endpoint(), window.location.href);
      url.searchParams.set('estateId', estateId());
      const result = await get(url.toString());
      if (current !== generation || !onView()) return;
      if (!validate(result)) throw new Error('Gate visitor service returned invalid or out-of-scope visit data.');
      table.replaceChildren();
      if (!result.items.length) appendState('No visitors are currently checked in at this gate.');
      for (const item of result.items) {
        const row = document.createElement('tr');
        row.dataset.visitId = String(item.visitId);
        const visitor = document.createElement('td');
        const copy = make('span', 'request-name');
        copy.append(make('strong', '', item.visitorName), make('small', '', item.vehicleSummary || 'Visitor'));
        visitor.append(copy);
        const host = document.createElement('td');
        host.append(document.createTextNode(item.hostDisplayName), make('small', 'cell-sub', item.propertyLabel));
        row.append(visitor, host, make('td', '', formatTime(item.checkedInAt)));
        const action = document.createElement('td');
        const checkOutUrl = checkOutEndpoint(item.visitId);
        if (checkOutUrl) {
          const button = make('button', 'table-action reject-action', 'Record exit');
          button.type = 'button';
          button.dataset.gateCheckOut = 'true';
          button.dataset.visitId = String(item.visitId);
          action.append(button);
        } else action.textContent = 'Checked in';
        row.append(action);
        table.append(row);
      }
      stateMessage(`${result.items.length} visitor${result.items.length === 1 ? '' : 's'} currently checked in.`, 'ready');
    } catch (error) {
      if (current !== generation || !onView()) return;
      table.replaceChildren();
      appendState(error instanceof Error ? error.message : 'Current visitors could not be loaded.');
      stateMessage(error instanceof Error ? error.message : 'Current visitors could not be loaded.', 'error');
    }
  }
  window.addEventListener('estate:view-changed', (event) => {
    if (event.detail?.view === 'gate') load();
    else generation += 1;
  });
  window.refreshCurrentGateVisitors = load;
  document.addEventListener('click', async (event) => {
    const button = event.target.closest('[data-gate-check-out]');
    if (!button || !onView() || button.disabled) return;
    const visitId = button.dataset.visitId;
    const url = checkOutEndpoint(visitId);
    if (!url || !window.confirm('Record this visitor’s exit from the estate?')) return;
    const requestEstateId = estateId();
    const requestGateId = gateId();
    button.disabled = true;
    button.textContent = 'Recording…';
    try {
      const result = await send(url, { estateId: requestEstateId, gateId: requestGateId });
      if (!result || String(result.visitId) !== String(visitId) || String(result.estateId) !== requestEstateId
        || String(result.gateId) !== requestGateId || result.status !== 'checked_out' || !validTimestamp(result.checkedOutAt)) {
        throw new Error('The gate service did not confirm this visitor’s exit.');
      }
      stateMessage('Visitor exit recorded.', 'ready');
      await load();
    } catch (error) {
      button.disabled = false;
      button.textContent = 'Record exit';
      stateMessage(error instanceof Error ? error.message : 'Visitor exit could not be recorded.', 'error');
    }
  });
  const refreshForContext = () => {
    const form = document.querySelector('#moduleContent [data-gate-check-in-form]');
    if (form) {
      form.reset();
      pendingCheckInKey = '';
      const note = form.querySelector('[data-gate-check-in-note]');
      if (note) { note.textContent = ''; note.dataset.state = 'ready'; }
    }
    const manualForm = document.querySelector('#moduleContent [data-manual-admission-form]');
    if (manualForm) {
      manualForm.reset();
      const manualNote = manualForm.querySelector('[data-manual-admission-note]');
      if (manualNote) { manualNote.textContent = ''; manualNote.dataset.state = 'ready'; }
    }
    pendingManualAdmissionKey = '';
    if (onView()) load();
  };
  window.addEventListener('estate:context-changed', refreshForContext);
  window.addEventListener('estate:estate-context-changed', refreshForContext);
})();
