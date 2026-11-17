(() => {
  const config = () => window.ZvendEstateConfig || {};
  const modal = document.getElementById('joinRequestModal');
  const estateSelect = document.getElementById('joinEstate');
  const propertySelect = document.getElementById('joinProperty');
  const requestList = document.getElementById('residentJoinRequests');
  if (!modal || !estateSelect || !propertySelect || !requestList) return;

  const targets = Array.isArray(config().residentJoinTargets) ? config().residentJoinTargets : [];
  const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
  const collectionUrl = typeof config().residentJoinRequestUrl === 'string' && config().residentJoinRequestUrl.trim()
    ? config().residentJoinRequestUrl.trim()
    : base ? `${base}/api/estate/residents/join-requests` : '';
  const listUrl = typeof config().residentJoinRequestsUrl === 'string' && config().residentJoinRequestsUrl.trim()
    ? config().residentJoinRequestsUrl.trim()
    : collectionUrl ? `${collectionUrl.replace(/\/$/, '')}/mine` : '';
  if (!collectionUrl || !listUrl || !targets.length) return;

  function safeTargets() {
    const seen = new Set();
    return targets.filter((estate) => {
      if (!estate || !['string', 'number'].includes(typeof estate.id) || !String(estate.id).trim()
        || typeof estate.name !== 'string' || !estate.name.trim() || !Array.isArray(estate.properties)) return false;
      const id = String(estate.id);
      if (seen.has(id)) return false;
      seen.add(id);
      return estate.properties.every((property) => property && ['string', 'number'].includes(typeof property.id)
        && String(property.id).trim() && typeof property.label === 'string' && property.label.trim());
    });
  }
  const estates = safeTargets();
  if (!estates.length) return;
  let generation = 0;

  function resolveUrl(value) {
    return new URL(value, window.location.href).toString();
  }
  async function request(url, method = 'GET', payload) {
    if (typeof config().request !== 'function') throw new Error('Join requests require the host authenticated API request adapter.');
    const response = await config().request({ url, method, payload, credentials: 'same-origin' });
    let body = response;
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error(`Estate access service returned an error (${response.status}).`);
      body = response.status === 204 ? null : await response.json();
    }
    return body?.data ?? body;
  }
  function selectedEstate() { return estates.find((estate) => String(estate.id) === estateSelect.value); }
  function populateEstates() {
    const current = estateSelect.value;
    estateSelect.replaceChildren(new Option('Choose an estate', ''));
    estates.forEach((estate) => {
      const label = [estate.name, estate.locationLabel].filter(Boolean).join(' · ');
      estateSelect.add(new Option(label, String(estate.id)));
    });
    estateSelect.value = estates.some((estate) => String(estate.id) === current) ? current : '';
    populateProperties();
  }
  function populateProperties() {
    const estate = selectedEstate();
    propertySelect.replaceChildren(new Option(estate ? 'No property selected' : 'Select an estate first', ''));
    estate?.properties.forEach((property) => propertySelect.add(new Option(property.label, String(property.id))));
    propertySelect.disabled = !estate;
  }
  function statusLabel(value) {
    return String(value || 'submitted').replaceAll('_', ' ').replace(/\b\w/g, (part) => part.toUpperCase());
  }
  function render(items) {
    requestList.replaceChildren();
    if (!items.length) {
      const empty = document.createElement('article');
      empty.className = 'join-request-empty';
      empty.append(Object.assign(document.createElement('strong'), { textContent: 'No access requests yet' }),
        Object.assign(document.createElement('span'), { textContent: 'Requests you submit will appear here.' }));
      requestList.append(empty);
      return;
    }
    items.forEach((item) => {
      const card = document.createElement('article');
      card.className = 'join-request-card';
      const copy = document.createElement('div');
      const title = document.createElement('strong');
      title.textContent = item.estateName || 'Estate access request';
      const detail = document.createElement('span');
      detail.textContent = `${item.propertyLabel || 'No property selected'} · ${statusLabel(item.relationship)}`;
      const submitted = document.createElement('small');
      const date = new Date(item.submittedAt);
      submitted.textContent = Number.isNaN(date.getTime()) ? statusLabel(item.status)
        : `Submitted ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(date)}`;
      copy.append(title, detail, submitted);
      const badge = document.createElement('span');
      badge.className = `mini-status ${item.status === 'approved' ? 'status-checked' : item.status === 'rejected' ? 'status-due' : 'status-review'}`;
      badge.textContent = statusLabel(item.status);
      card.append(copy, badge);
      requestList.append(card);
    });
  }
  async function load() {
    const currentGeneration = ++generation;
    const loading = document.createElement('article');
    loading.className = 'join-request-empty';
    loading.setAttribute('role', 'status');
    loading.textContent = 'Loading your access requests...';
    requestList.replaceChildren(loading);
    try {
      const result = await request(resolveUrl(listUrl));
      if (currentGeneration !== generation) return;
      if (!result || !Array.isArray(result.items)
        || result.items.some((item) => !item || !item.requestId || !item.estateId || !item.status)) {
        throw new Error('The access service returned an invalid request list.');
      }
      render(result.items);
    } catch (error) {
      if (currentGeneration !== generation) return;
      const message = document.createElement('article');
      message.className = 'join-request-empty';
      message.setAttribute('role', 'alert');
      message.textContent = error instanceof Error ? error.message : 'Access requests could not be loaded.';
      requestList.replaceChildren(message);
    }
  }

  populateEstates();
  const previewNote = modal.querySelector('.resident-form-preview');
  if (previewNote) previewNote.textContent = 'Connected to estate access. Your membership is enabled only after the estate team approves your request.';
  estateSelect.addEventListener('change', populateProperties);
  window.populateResidentJoinOptions = populateEstates;
  window.submitResidentJoinRequest = async () => {
    const estate = selectedEstate();
    const propertyId = propertySelect.value || null;
    const relationship = document.getElementById('joinRelationship').value;
    const note = document.getElementById('joinRequestNote').value.trim();
    const file = document.getElementById('joinProofReference').files?.[0] || null;
    const error = document.getElementById('joinRequestError');
    const submit = modal.querySelector('[data-action="submit-join-request"]');
    if (!estate || !relationship) { error.textContent = 'Choose an estate and your relationship before sending the request.'; return; }
    if (propertyId && !estate.properties.some((property) => String(property.id) === propertyId)) {
      error.textContent = 'Choose a property from the selected estate.'; return;
    }
    submit.disabled = true;
    submit.textContent = 'Sending...';
    error.textContent = '';
    try {
      const evidenceDocumentIds = [];
      if (file) {
        if (typeof config().uploadResidentJoinEvidence !== 'function') {
          throw new Error('Supporting documents need the host private-file upload service. Remove the file or try again later.');
        }
        const idempotencyKey = window.crypto?.randomUUID?.() || `join-${Date.now()}-${Math.random().toString(16).slice(2)}`;
        const uploaded = await config().uploadResidentJoinEvidence({ file, estateId: estate.id, idempotencyKey });
        if (!uploaded?.documentId) throw new Error('The private-file service did not confirm the uploaded document.');
        evidenceDocumentIds.push(uploaded.documentId);
      }
      const result = await request(resolveUrl(collectionUrl), 'POST', {
        estateId: estate.id,
        propertyId,
        relationship,
        note,
        evidenceDocumentIds,
      });
      if (!result?.requestId || result.status !== 'submitted') throw new Error('The access service did not confirm this request.');
      modal.classList.add('hidden');
      document.getElementById('joinRequestNote').value = '';
      document.getElementById('joinProofReference').value = '';
      await load();
      if (typeof window.showResidentMessage === 'function') window.showResidentMessage('Your access request was sent to the estate team.');
    } catch (failure) {
      error.textContent = failure instanceof Error ? failure.message : 'The access request could not be sent.';
    } finally {
      submit.disabled = false;
      submit.textContent = 'Send request';
    }
  };
  window.refreshResidentJoinRequests = load;
  window.addEventListener('estate:context-changed', load);
  load();
})();
