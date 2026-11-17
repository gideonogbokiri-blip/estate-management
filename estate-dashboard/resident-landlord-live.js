(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function endpoint() {
    const custom = config().landlordPortfolioUrl;
    if (typeof custom === 'string' && custom.trim()) {
      return custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()));
    }
    const base = typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
    return base ? `${base}/api/estate/estates/${encodeURIComponent(estateId())}/landlord/portfolio` : '';
  }
  if (!estateId() || !endpoint()) return;

  const root = document.querySelector('[data-screen="landlord"]');
  if (!root) return;
  const state = { generation: 0 };

  async function request(url) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('The landlord portfolio needs the host authenticated API adapter.');
    const response = await adapter({ url, method: 'GET', credentials: 'same-origin' });
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error(`Landlord portfolio service returned an error (${response.status}).`);
      const body = await response.json();
      return body?.data ?? body;
    }
    return response?.data ?? response;
  }
  function rowMarkup() {
    const cards = document.createElement('div');
    cards.className = 'landlord-live-properties';
    cards.id = 'landlordPortfolioProperties';
    return cards;
  }
  function textElement(tag, className, value) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = value;
    return element;
  }
  function render(items) {
    const heading = root.querySelector('.landlord-heading');
    const oldBadge = heading?.querySelector('.preview-badge');
    if (oldBadge) oldBadge.remove();
    let portfolioSection = root.querySelector('#landlordPortfolioSection');
    if (!portfolioSection) {
      portfolioSection = document.createElement('section');
      portfolioSection.id = 'landlordPortfolioSection';
      const sectionHeading = document.createElement('div');
      sectionHeading.className = 'landlord-section-heading';
      sectionHeading.append(textElement('h2', '', 'My properties'));
      portfolioSection.append(sectionHeading);
      const anchor = root.querySelector('.landlord-metrics');
      anchor ? anchor.after(portfolioSection) : root.append(portfolioSection);
    }
    const liveGrid = rowMarkup();
    if (!items.length) liveGrid.append(textElement('p', 'resident-live-empty', 'No properties are linked to a verified landlord relationship in this estate.'));
    items.forEach((item) => {
      const card = document.createElement('article');
      card.className = 'landlord-property-card';
      const art = document.createElement('div');
      art.className = 'landlord-property-art';
      art.append(textElement('span', '', item.estateName));
      const body = document.createElement('div');
      body.className = 'landlord-property-body';
      const title = document.createElement('div');
      title.append(textElement('strong', '', item.propertyLabel), textElement('span', `mini-status ${item.occupancyStatus === 'rented' ? 'status-checked' : 'status-review'}`, item.occupancyStatus === 'rented' ? 'Rented' : 'Not currently rented'));
      body.append(title, textElement('p', '', [item.estateLocation, item.propertyType].filter(Boolean).join(' · ') || 'Property details'));
      if (item.tenantDisplayName) {
        const tenantLine = document.createElement('div');
        tenantLine.className = 'landlord-tenant-line';
        tenantLine.append(textElement('span', 'visitor-record-avatar visitor-blue', item.tenantDisplayName.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase() || '').join('')));
        const tenantInfo = document.createElement('span');
        tenantInfo.append(textElement('strong', '', item.tenantDisplayName), textElement('small', '', item.tenancyEndDate ? `Tenancy ends ${item.tenancyEndDate}` : `Tenancy ${String(item.tenancyStatus || '').replaceAll('_', ' ')}`));
        tenantLine.append(tenantInfo);
        body.append(tenantLine);
      }
      card.append(art, body);
      liveGrid.append(card);
    });
    portfolioSection.querySelector('#landlordPortfolioProperties')?.remove();
    portfolioSection.append(liveGrid);
    root.querySelectorAll('.landlord-section-heading').forEach((element) => {
      if (element !== portfolioSection.querySelector('.landlord-section-heading') && element.textContent.includes('My properties')) element.remove();
    });
    root.querySelectorAll('.landlord-property-card').forEach((card) => card.remove());

    const metrics = root.querySelector('.landlord-metrics');
    if (metrics) {
      metrics.replaceChildren();
      const rentHistory = textElement('button', 'wide-outline', 'View verified rent payments and invoices');
      rentHistory.type = 'button';
      rentHistory.dataset.screenLink = 'payments';
      metrics.append(rentHistory);
    }
    const rentHeading = [...root.querySelectorAll('.landlord-section-heading')].find((element) => element.textContent.includes('Rent status'));
    rentHeading?.remove();
    root.querySelectorAll('.landlord-rent-card').forEach((card) => card.remove());
    root.querySelectorAll('.privacy-note').forEach((note) => note.remove());
    const portfolioSummary = root.querySelector('.landlord-heading p');
    if (portfolioSummary) portfolioSummary.textContent = `${items.length} verified ${items.length === 1 ? 'property' : 'properties'}`;
  }
  function showError(error, generation) {
    if (generation !== state.generation) return;
    const heading = root.querySelector('.landlord-heading');
    const badge = heading?.querySelector('.preview-badge');
    if (badge) badge.remove();
    root.querySelectorAll('.landlord-property-card, .landlord-rent-card').forEach((card) => card.remove());
    const notice = root.querySelector('.landlord-live-error') || textElement('p', 'landlord-live-error', '');
    notice.setAttribute('role', 'alert');
    notice.textContent = error instanceof Error ? error.message : 'Landlord portfolio could not be loaded.';
    root.querySelector('.landlord-heading')?.after(notice);
    const metrics = root.querySelector('.landlord-metrics');
    if (metrics) metrics.replaceChildren();
    const summary = root.querySelector('.landlord-heading p');
    if (summary) summary.textContent = 'Portfolio unavailable';
  }
  async function load() {
    const requestEstateId = estateId();
    const generation = ++state.generation;
    root.querySelector('#landlordPortfolioSection')?.remove();
    root.querySelector('.landlord-heading .preview-badge')?.remove();
    root.querySelectorAll('.landlord-property-card').forEach((card) => card.remove());
    [...root.querySelectorAll('.landlord-section-heading')].filter((element) => element.textContent.includes('My properties')).forEach((element) => element.remove());
    [...root.querySelectorAll('.landlord-section-heading')].filter((element) => element.textContent.includes('Rent status')).forEach((element) => element.remove());
    root.querySelectorAll('.landlord-rent-card, .privacy-note').forEach((card) => card.remove());
    const metrics = root.querySelector('.landlord-metrics');
    if (metrics) metrics.replaceChildren(textElement('p', 'resident-live-loading', 'Loading verified landlord properties…'));
    const summary = root.querySelector('.landlord-heading p');
    if (summary) summary.textContent = 'Loading portfolio…';
    try {
      const result = await request(endpoint());
      if (generation !== state.generation || requestEstateId !== estateId()) return;
      if (!result || !Array.isArray(result.items) || result.items.length > 100) {
        throw new Error('The landlord service returned an invalid portfolio.');
      }
      const invalidItem = result.items.some((item) => !item || String(item.estateId) !== requestEstateId || !item.propertyId
        || !item.estateName || !item.propertyLabel || !item.operationalStatus
        || !['not_currently_rented', 'rented'].includes(item.occupancyStatus)
        || (item.tenancyStatus && (!item.tenancyStartDate
          || (item.rentAmount && (!item.currency || !Number.isInteger(item.currencyScale))))));
      if (invalidItem || new Set(result.items.map((item) => String(item.propertyId))).size !== result.items.length) {
        throw new Error('The landlord service returned an invalid portfolio.');
      }
      render(result.items);
      const notice = root.querySelector('.landlord-live-error');
      notice?.remove();
    } catch (error) {
      showError(error, generation);
    }
  }
  window.addEventListener('estate:context-changed', load);
  document.addEventListener('click', (event) => {
    const link = event.target.closest('[data-screen-link="landlord"]');
    if (link) load();
  });
  window.refreshResidentLandlordPortfolio = load;
  load();
})();
