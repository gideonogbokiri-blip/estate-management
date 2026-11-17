(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function apiBase() { return typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : ''; }
  function collectionUrl() {
    const custom = config().residentVisitorPassesUrl || config().visitorPassesUrl;
    return typeof custom === 'string' && custom.trim()
      ? custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()))
      : apiBase() ? `${apiBase()}/api/estate/estates/${encodeURIComponent(estateId())}/visitor-passes` : '';
  }
  if (!estateId() || !collectionUrl()) return;

  const modal = document.getElementById('visitorPassModal');
  const formPanel = document.getElementById('visitorPassFormPanel');
  const form = modal.querySelector('.resident-form-modal');
  const submit = form.querySelector('[data-action="issue-pass-preview"]');
  const list = document.getElementById('residentVisitorList');
  const credentialLabel = document.querySelector('.visitor-demo-code span');
  const resultTitle = document.querySelector('#visitorPassResult h3');
  const warning = document.querySelector('.visitor-demo-warning');
  const copyButton = modal.querySelector('[data-action="copy-pass-preview"]');
  const status = { items: [], generation: 0 };
  let pendingCreateKey = '';

  function urlFor(suffix = '') {
    const url = new URL(collectionUrl().replace(/\/$/, '') + suffix, window.location.href);
    return url.toString();
  }
  async function request(url, method = 'GET', payload, headers = {}) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('Visitor passes require the host authenticated API request adapter.');
    const response = await adapter({ url, method, payload, headers, credentials: 'same-origin' });
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) {
        let body = null;
        try { body = await response.json(); } catch {}
        const error = new Error(body?.error?.message || body?.message || `Estate visitor service returned an error (${response.status}).`);
        error.status = response.status;
        error.code = body?.error?.code || body?.code || '';
        throw error;
      }
      const body = response.status === 204 ? null : await response.json();
      return body?.data ?? body;
    }
    return response?.data ?? response;
  }
  function dateLabel(value) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 'Time unavailable'
      : new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(parsed);
  }
  function render() {
    list.replaceChildren();
    if (!status.items.length) {
      const empty = document.createElement('div');
      empty.className = 'resident-live-empty';
      empty.textContent = 'You have no visitor passes for this estate.';
      list.append(empty);
      return;
    }
    status.items.forEach((pass) => {
      const card = document.createElement('article');
      card.className = 'mobile-list-card visitor-record';
      const avatar = document.createElement('span');
      avatar.className = 'visitor-record-avatar visitor-violet';
      avatar.textContent = String(pass.visitorDisplayName || 'Visitor').trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase() || '').join('');
      const copy = document.createElement('div');
      copy.className = 'mobile-list-copy';
      const name = document.createElement('strong');
      name.textContent = pass.visitorDisplayName || 'Visitor';
      const windowLabel = document.createElement('small');
      windowLabel.textContent = `${dateLabel(pass.validFrom)} – ${dateLabel(pass.validUntil)}`;
      const vehicle = document.createElement('b');
      vehicle.textContent = `${Math.max(0, Number(pass.allowedUses) - Number(pass.useCount))} entries remaining · ${pass.vehicleSummary || 'No vehicle'}`;
      copy.append(name, windowLabel, vehicle);
      const badge = document.createElement('span');
      badge.className = `mini-status ${pass.status === 'active' ? 'status-checked' : 'status-review'}`;
      badge.textContent = pass.status === 'active' ? 'Active' : String(pass.status || 'Unknown').replaceAll('_', ' ');
      card.append(avatar, copy, badge);
      if (pass.status === 'active') {
        const revoke = document.createElement('button');
        revoke.type = 'button';
        revoke.className = 'visitor-preview-revoke';
        revoke.dataset.action = 'open-visitor-revoke';
        revoke.dataset.passId = String(pass.passId);
        revoke.textContent = 'Revoke pass';
        card.append(revoke);
      }
      list.append(card);
    });
  }
  async function load() {
    const requestedEstateId = estateId();
    const generation = ++status.generation;
    list.replaceChildren();
    const loading = document.createElement('div');
    loading.className = 'resident-live-loading';
    loading.textContent = 'Loading your visitor passes…';
    list.append(loading);
    try {
      const result = await request(urlFor('/mine'));
      if (generation !== status.generation || requestedEstateId !== estateId()) return;
      const allowedFields = new Set(['passId', 'estateId', 'propertyId', 'visitorDisplayName', 'validFrom', 'validUntil', 'allowedUses', 'useCount', 'revokedAt', 'vehicleSummary', 'status']);
      const passIds = new Set();
      if (!result || !Array.isArray(result.items) || result.items.length > 100) throw new Error('The visitor service returned an invalid pass list.');
      if (result.items.some((pass) => {
        const id = pass?.passId == null ? '' : String(pass.passId);
        const from = new Date(pass?.validFrom);
        const until = new Date(pass?.validUntil);
        const valid = pass && id && !passIds.has(id) && Object.keys(pass).every((key) => allowedFields.has(key))
          && String(pass.estateId) === requestedEstateId && ['string', 'number'].includes(typeof pass.propertyId)
          && typeof pass.visitorDisplayName === 'string' && pass.visitorDisplayName.trim() && pass.visitorDisplayName.length <= 100
          && !Number.isNaN(from.getTime()) && !Number.isNaN(until.getTime()) && until > from
          && Number.isInteger(pass.allowedUses) && pass.allowedUses > 0 && Number.isInteger(pass.useCount)
          && pass.useCount >= 0 && pass.useCount <= pass.allowedUses
          && (pass.vehicleSummary === null || (typeof pass.vehicleSummary === 'string' && pass.vehicleSummary.length <= 80))
          && (pass.revokedAt === null || !Number.isNaN(new Date(pass.revokedAt).getTime()))
          && ['active', 'revoked', 'expired', 'exhausted'].includes(pass.status);
        if (valid) passIds.add(id);
        return !valid;
      })) {
        throw new Error('The visitor service returned a pass outside the selected estate.');
      }
      status.items = result.items;
      render();
    } catch (error) {
      if (generation !== status.generation || requestedEstateId !== estateId()) return;
      list.replaceChildren();
      const message = document.createElement('div');
      message.className = 'resident-live-empty';
      message.setAttribute('role', 'alert');
      message.textContent = error instanceof Error ? error.message : 'Visitor passes could not be loaded.';
      list.append(message);
    }
  }
  function showError(message) {
    document.getElementById('visitorPassError').textContent = message;
  }
  function newIdempotencyKey() {
    if (!window.crypto?.getRandomValues) throw new Error('Secure visitor request keys are unavailable in this browser.');
    const bytes = new Uint8Array(24);
    window.crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }

  document.querySelectorAll('.visitor-record[data-preview-pass]').forEach((card) => card.remove());
  credentialLabel.textContent = 'ONE-TIME VISITOR CREDENTIAL';
  resultTitle.textContent = 'Visitor pass created';
  warning.textContent = 'Share this credential with your guest. It is shown once and is valid only during the selected visit window.';
  copyButton.textContent = 'Copy visitor credential';
  form.querySelector('.resident-form-preview').textContent = 'Connected to your estate visitor service.';

  window.submitResidentVisitorPass = async () => {
    const name = document.getElementById('visitorPassName').value.trim();
    const fromValue = document.getElementById('visitorPassFrom').value;
    const untilValue = document.getElementById('visitorPassUntil').value;
    const from = new Date(fromValue);
    const until = new Date(untilValue);
    const withVehicle = document.getElementById('visitorPassVehicleEnabled').checked;
    const vehicle = document.getElementById('visitorPassVehicle').value.trim();
    if (!name) return showError('Enter your visitor’s name.');
    if (!fromValue || !untilValue || Number.isNaN(from.getTime()) || Number.isNaN(until.getTime()) || from <= new Date() || until <= from) {
      return showError('Choose a future start time and an end time after it.');
    }
    if (!pendingCreateKey) {
      try { pendingCreateKey = newIdempotencyKey(); }
      catch (error) { return showError(error instanceof Error ? error.message : 'Secure visitor request keys are unavailable.'); }
    }
    const createFields = ['visitorPassName', 'visitorPassFrom', 'visitorPassUntil', 'visitorPassVehicleEnabled', 'visitorPassVehicle']
      .map((id) => document.getElementById(id)).filter(Boolean);
    createFields.forEach((field) => { field.disabled = true; });
    submit.disabled = true;
    submit.textContent = 'Creating…';
    showError('');
    try {
      const result = await request(urlFor(), 'POST', {
        visitorDisplayName: name,
        validFrom: from.toISOString(),
        validUntil: until.toISOString(),
        ...(withVehicle && vehicle ? { vehicleSummary: vehicle } : {}),
      }, { 'Idempotency-Key': pendingCreateKey });
      if (!result || !result.passId || typeof result.credential !== 'string' || !result.credential
        || String(result.estateId) !== estateId()) {
        throw new Error('The visitor service did not confirm pass creation.');
      }
      document.getElementById('visitorPassResultSummary').textContent = `${result.visitorDisplayName || name} · ${dateLabel(result.validFrom)} – ${dateLabel(result.validUntil)}`;
      document.getElementById('visitorPassCredential').textContent = result.credential;
      pendingCreateKey = '';
      formPanel.classList.add('hidden');
      document.getElementById('visitorPassResult').classList.remove('hidden');
      await load();
    } catch (error) {
      if (error?.code === 'VISITOR_PASS_ALREADY_CREATED' || error?.status === 409) {
        await load();
        showError('This request may already have created a pass. Credentials are shown only once; check your pass list before issuing another.');
      } else {
        showError(error instanceof Error ? error.message : 'The visitor pass could not be created.');
      }
    } finally {
      createFields.forEach((field) => { field.disabled = false; });
      submit.disabled = false;
      submit.textContent = 'Create pass';
    }
  };
  window.copyResidentVisitorCredential = async () => {
    const credential = document.getElementById('visitorPassCredential').textContent;
    if (!credential) return;
    try {
      await navigator.clipboard.writeText(credential);
      if (typeof window.showResidentMessage === 'function') window.showResidentMessage('Visitor credential copied.');
    } catch {
      showError('Select and copy the visitor credential manually.');
    }
  };
  window.openResidentVisitorRevoke = (passId) => {
    if (!status.items.some((pass) => String(pass.passId) === String(passId) && pass.status === 'active')) return;
    document.getElementById('visitorRevokePassId').value = passId;
    document.getElementById('visitorRevokeReason').value = '';
    document.getElementById('visitorRevokeError').textContent = '';
    document.getElementById('visitorRevokeModal').classList.remove('hidden');
    document.getElementById('visitorRevokeReason').focus();
  };
  window.submitResidentVisitorRevocation = async () => {
    const passId = document.getElementById('visitorRevokePassId').value;
    const reason = document.getElementById('visitorRevokeReason').value.trim();
    const errorNode = document.getElementById('visitorRevokeError');
    const button = document.querySelector('[data-action="confirm-visitor-revoke"]');
    if (!reason) { errorNode.textContent = 'Enter a reason for revoking this pass.'; return; }
    button.disabled = true;
    button.textContent = 'Revoking…';
    errorNode.textContent = '';
    try {
      const result = await request(urlFor(`/${encodeURIComponent(passId)}/revoke`), 'POST', { reason });
      if (!result || String(result.passId) !== String(passId) || result.status !== 'revoked' || String(result.estateId) !== estateId()) {
        throw new Error('The visitor service did not confirm pass revocation.');
      }
      document.getElementById('visitorRevokeModal').classList.add('hidden');
      if (typeof window.showResidentMessage === 'function') window.showResidentMessage('Visitor pass revoked.');
      await load();
    } catch (error) {
      errorNode.textContent = error instanceof Error ? error.message : 'The pass could not be revoked.';
    } finally {
      button.disabled = false;
      button.textContent = 'Revoke pass';
    }
  };
  window.addEventListener('estate:context-changed', () => {
    status.items = [];
    pendingCreateKey = '';
    load();
  });
  ['visitorPassName', 'visitorPassFrom', 'visitorPassUntil', 'visitorPassVehicleEnabled', 'visitorPassVehicle'].forEach((id) => {
    document.getElementById(id)?.addEventListener('input', () => { pendingCreateKey = ''; });
    document.getElementById(id)?.addEventListener('change', () => { pendingCreateKey = ''; });
  });
  window.refreshResidentVisitorPasses = load;
  load();
})();
