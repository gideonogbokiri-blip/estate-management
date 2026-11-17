(() => {
  let generation = 0;
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().structureListUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/structure` : '';
  }
  function connected() { return Boolean(estateId() && endpoint()); }
  function make(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (value !== undefined && value !== null) node.textContent = value;
    return node;
  }
  async function get(url) {
    const adapter = config().request;
    if (typeof adapter === 'function') {
      const response = await adapter({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && response instanceof Response) {
        if (!response.ok) throw new Error(`Structure service returned an error (${response.status}).`);
        const body = await response.json();
        return body?.data ?? body;
      }
      return response?.data ?? response;
    }
    const response = await fetch(url, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
    if (!response.ok) throw new Error(`Structure service returned an error (${response.status}).`);
    const body = await response.json();
    return body?.data ?? body;
  }
  function validate(result, selectedEstateId) {
    const allowed = new Set(['id', 'estateId', 'type', 'name', 'code', 'parentId', 'parentName', 'linkedPropertyCount', 'status']);
    const seen = new Set();
    if (!result || !Array.isArray(result.items)) return false;
    for (const node of result.items) {
      const key = node?.id === undefined || node?.id === null ? '' : String(node.id);
      if (!key || seen.has(key)) return false;
      seen.add(key);
    }
    return Boolean(result && Array.isArray(result.items) && result.total === result.items.length
      && Number.isSafeInteger(result.activeCount) && result.activeCount >= 0 && result.activeCount <= result.total
      && result.items.every((node) => node && node.id !== undefined && node.id !== null
        && Object.keys(node).every((field) => allowed.has(field))
        && String(node.estateId) === selectedEstateId
        && ['zone', 'street', 'building', 'floor'].includes(node.type)
        && typeof node.name === 'string' && node.name.trim() && node.name.length <= 120
        && (node.code === null || node.code === undefined || (typeof node.code === 'string' && node.code.length <= 60))
        && (node.parentId === null || node.parentId === undefined || ['string', 'number'].includes(typeof node.parentId))
        && (node.parentName === null || node.parentName === undefined || typeof node.parentName === 'string')
        && (node.linkedPropertyCount === null || node.linkedPropertyCount === undefined
          || (Number.isSafeInteger(node.linkedPropertyCount) && node.linkedPropertyCount >= 0))
        && ['active', 'archived'].includes(node.status)));
  }
  function updateCounts(result) {
    const active = document.getElementById('structureNodeCount');
    const tab = document.querySelector('[data-register-tab="structure"] span');
    const totalProperties = document.getElementById('structurePropertyCount');
    if (active) active.textContent = String(result.activeCount);
    if (tab) tab.textContent = `${result.activeCount} nodes`;
    if (totalProperties && Number.isSafeInteger(window.currentEstatePropertyTotal)) {
      totalProperties.textContent = String(window.currentEstatePropertyTotal);
    } else if (totalProperties) {
      totalProperties.textContent = '—';
    }
  }
  function render(items) {
    const body = document.getElementById('structureRows');
    body.replaceChildren();
    const byId = new Map(items.map((node) => [String(node.id), node]));
    items.forEach((node) => {
      const row = document.createElement('tr');
      const nameCell = document.createElement('td');
      const name = make('span', `structure-name structure-depth-${node.type}`);
      const glyph = make('i', 'structure-node-glyph');
      glyph.setAttribute('aria-hidden', 'true');
      name.append(glyph, make('strong', '', node.name), make('small', '', node.code || 'No code'));
      nameCell.append(name);
      const parent = node.parentId === null || node.parentId === undefined ? null : byId.get(String(node.parentId));
      const parentLabel = node.parentName || parent?.name || (node.parentId ? 'Parent unavailable' : 'Estate');
      const status = make('span', `structure-status ${node.status === 'active' ? '' : 'is-archived'}`, node.status === 'active' ? 'Active' : 'Archived');
      row.append(
        nameCell,
        make('td', '', ({ zone: 'Zone / phase', street: 'Street', building: 'Building', floor: 'Floor' })[node.type]),
        make('td', '', parentLabel),
        make('td', '', node.linkedPropertyCount === null || node.linkedPropertyCount === undefined
          ? '—' : `${node.linkedPropertyCount} ${node.type === 'floor' ? 'units' : 'properties'}`),
        (() => { const cell = document.createElement('td'); cell.append(status); return cell; })(),
        document.createElement('td'),
      );
      body.append(row);
    });
    if (!items.length) {
      const row = document.createElement('tr');
      const cell = make('td', 'structure-live-empty', 'No structure nodes have been configured for this estate.');
      cell.colSpan = 6;
      row.append(cell);
      body.append(row);
    }
  }
  function showState(message, className) {
    const body = document.getElementById('structureRows');
    if (!body) return;
    body.replaceChildren();
    const row = document.createElement('tr');
    const cell = make('td', className, message);
    cell.colSpan = 6;
    if (className.includes('error')) cell.setAttribute('role', 'alert');
    row.append(cell);
    body.append(row);
  }
  async function load() {
    if (!connected() || document.getElementById('estateStructurePanel')?.classList.contains('hidden')) return;
    const currentEstate = estateId();
    const currentGeneration = ++generation;
    const add = document.querySelector('#estateStructurePanel [data-action="add-structure-node"]');
    if (add) { add.disabled = true; add.title = 'Structure changes are not connected to the estate service.'; }
    showState('Loading authorized estate structure…', 'structure-live-loading');
    try {
      const url = new URL(endpoint(), window.location.href);
      url.searchParams.set('estateId', currentEstate);
      url.searchParams.set('includeArchived', 'false');
      const result = await get(url.toString());
      if (currentGeneration !== generation || currentEstate !== estateId()) return;
      if (!validate(result, currentEstate)) throw new Error('The structure service returned an invalid or out-of-scope result.');
      render(result.items);
      updateCounts(result);
    } catch {
      if (currentGeneration !== generation || currentEstate !== estateId()) return;
      showState('Estate structure is unavailable. Check the service connection and retry.', 'structure-live-error');
      document.getElementById('structureNodeCount').textContent = '—';
      const tab = document.querySelector('[data-register-tab="structure"] span');
      if (tab) tab.textContent = 'Unavailable';
    }
  }
  function bind() {
    if (!connected()) return;
    document.querySelector('#estateStructurePanel .structure-preview-note')?.classList.add('hidden');
    const add = document.querySelector('#estateStructurePanel [data-action="add-structure-node"]');
    if (add) { add.disabled = true; add.title = 'Structure changes are not connected to the estate service.'; }
    load();
  }
  window.refreshEstateStructure = load;
  window.addEventListener('estate:property-tab-changed', (event) => { if (event.detail?.tab === 'structure') bind(); });
  window.addEventListener('estate:context-changed', bind);
  bind();
})();
