(() => {
  const liveView = document.getElementById('liveDashboardView');
  const status = document.getElementById('liveDashboardStatus');
  const metrics = document.getElementById('liveDashboardMetrics');
  const sources = document.getElementById('liveDashboardSources');
  if (!liveView || !status || !metrics || !sources) return;

  function hostConfig() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = hostConfig().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function resolveSummaryUrl() {
    const config = hostConfig();
    if (typeof config.dashboardSummaryUrl === 'string' && config.dashboardSummaryUrl.trim()) {
      return config.dashboardSummaryUrl.replace(/\/$/, '');
    }
    const apiBase = typeof config.apiBaseUrl === 'string' && config.apiBaseUrl.trim()
      ? config.apiBaseUrl.replace(/\/$/, '')
      : '';
    return apiBase && estateId() ? `${apiBase}/api/estate/reports/dashboard` : '';
  }
  const liveMode = Boolean(resolveSummaryUrl());
  let lastSummary = null;
  let requestGeneration = 0;
  const sectionLabels = {
    properties: 'Properties and occupancy',
    residents: 'Residents and landlords',
    tenancies: 'Tenancies',
    finance: 'Financial summary',
    visitors: 'Visitor activity',
    maintenance: 'Maintenance',
  };
  const statusLabels = {
    available: 'Available',
    incomplete: 'Incomplete source data',
    pending_reconciliation: 'Pending reconciliation',
    unavailable: 'Unavailable',
  };
  const freshnessLabels = {
    current: 'Current',
    stale: 'Stale',
    delayed: 'Delayed',
    unavailable: 'Unavailable',
  };

  function textElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = text;
    return element;
  }

  function numberLabel(value) {
    return new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(value);
  }

  function exactMoneyLabel(amount, currency, scale) {
    const [whole = '0', fraction = ''] = amount.split('.');
    const sign = whole.startsWith('-') ? '-' : '';
    const digits = sign ? whole.slice(1) : whole;
    const grouped = digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return `${currency} ${sign}${grouped}${scale ? `.${fraction.padEnd(scale, '0')}` : ''}`;
  }

  function sourceTime(value, timeZone) {
    if (!value) return 'Source update time unavailable';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'Source update time unavailable';
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone,
    }).format(date);
  }

  function isIsoTimestamp(value) {
    return typeof value === 'string' && value.includes('T') && Number.isFinite(Date.parse(value));
  }

  function validSummary(summary) {
    const sectionNames = new Set(Object.keys(sectionLabels));
    const sectionStates = new Set(['available', 'incomplete', 'pending_reconciliation', 'unavailable']);
    const freshnessStates = new Set(['current', 'stale', 'delayed', 'unavailable']);
    if (!summary || typeof summary !== 'object' || Array.isArray(summary)
      || (estateId() && String(summary.estateId) !== estateId())
      || !isIsoTimestamp(summary.asOf)
      || !summary.period || !isIsoTimestamp(summary.period.startAt) || !isIsoTimestamp(summary.period.endAt)
      || Date.parse(summary.period.endAt) <= Date.parse(summary.period.startAt)
      || typeof summary.period.timeZone !== 'string' || !summary.period.timeZone.trim()
      || !summary.sections || typeof summary.sections !== 'object' || Array.isArray(summary.sections)
      || !summary.sourceFreshness || typeof summary.sourceFreshness !== 'object' || Array.isArray(summary.sourceFreshness)) return false;
    try { new Intl.DateTimeFormat('en-US', { timeZone: summary.period.timeZone }).format(new Date(summary.asOf)); } catch { return false; }
    const nonNegativeAmount = (value, scale) => typeof value === 'string'
      && new RegExp(scale ? `^(?:0|[1-9]\\d*)(?:\\.\\d{1,${scale}})?$` : '^(?:0|[1-9]\\d*)$').test(value);
    const signedExactAmount = (value, scale) => typeof value === 'string'
      && new RegExp(`^-?(?:0|[1-9]\\d*)${scale ? `\\.${'\\d'.repeat(scale)}` : ''}$`).test(value);
    for (const [section, source] of Object.entries(summary.sections)) {
      if (!sectionNames.has(section) || !source || typeof source !== 'object' || !sectionStates.has(source.status)) return false;
      if (source.status === 'unavailable') continue;
      const countFields = {
        properties: ['totalProperties', 'occupiedProperties', 'vacantProperties'],
        residents: ['totalRegisteredResidents', 'activeLandlords'],
        tenancies: ['activeTenants', 'activeTenancies'],
        visitors: ['activityCount', 'currentlyCheckedIn'],
        maintenance: ['openRequests'],
      }[section];
      if (countFields && countFields.some((field) => !Number.isSafeInteger(source[field]) || source[field] < 0)) return false;
      if (section === 'properties' && source.occupiedProperties + source.vacantProperties > source.totalProperties) return false;
      if (section === 'finance') {
        const scale = source.currencyScale;
        if (typeof source.currency !== 'string' || !/^[A-Z]{3}$/.test(source.currency)
          || !Number.isInteger(scale) || scale < 0 || scale > 6
          || !['rent', 'estateFees', 'otherCharges'].every((key) => source[key] && ['billed', 'collected', 'outstanding'].every((field) => nonNegativeAmount(source[key][field], scale)))
          || !nonNegativeAmount(source.expensesPaid, scale) || !signedExactAmount(source.netOperatingPosition, scale)) return false;
      }
    }
    for (const [section, freshness] of Object.entries(summary.sourceFreshness)) {
      if (!sectionNames.has(section) || !summary.sections[section] || !freshness || !freshnessStates.has(freshness.status)
        || (freshness.sourceAsOf !== null && freshness.sourceAsOf !== undefined && !isIsoTimestamp(freshness.sourceAsOf))
        || (freshness.status !== 'unavailable' && !isIsoTimestamp(freshness.sourceAsOf))) return false;
    }
    return Object.keys(summary.sections).every((section) => Boolean(summary.sourceFreshness[section]));
  }

  function addMetric(label, value, detail, sourceStatus) {
    const card = document.createElement('article');
    card.className = 'live-dashboard-metric';
    card.dataset.status = sourceStatus;
    card.append(
      textElement('span', 'live-dashboard-metric-label', label),
      textElement('strong', 'live-dashboard-metric-value', value),
    );
    if (detail) card.append(textElement('small', 'live-dashboard-metric-detail', detail));
    if (sourceStatus !== 'available') {
      card.append(textElement('span', 'live-dashboard-metric-status', statusLabels[sourceStatus] || sourceStatus));
    }
    metrics.append(card);
  }

  function renderSection(section, source) {
    const sourceStatus = source.status;
    if (sourceStatus === 'unavailable') {
      addMetric(sectionLabels[section] || section, 'Unavailable', 'This source is not available for this estate.', sourceStatus);
      return;
    }
    const data = source;
    if (section === 'properties') {
      const rate = data.totalProperties ? `${((data.occupiedProperties / data.totalProperties) * 100).toFixed(1)}%` : '—';
      addMetric('Total properties', numberLabel(data.totalProperties), 'Active estate properties', sourceStatus);
      addMetric('Occupancy rate', rate, `${numberLabel(data.occupiedProperties)} occupied · ${numberLabel(data.vacantProperties)} vacant`, sourceStatus);
    } else if (section === 'residents') {
      addMetric('Registered residents', numberLabel(data.totalRegisteredResidents), 'Estate resident records', sourceStatus);
      addMetric('Active landlords', numberLabel(data.activeLandlords), 'Current verified landlord relationships', sourceStatus);
    } else if (section === 'tenancies') {
      addMetric('Active tenants', numberLabel(data.activeTenants), 'Tenants with current estate access', sourceStatus);
      addMetric('Active tenancies', numberLabel(data.activeTenancies), 'Current tenancy agreements', sourceStatus);
    } else if (section === 'finance') {
      const money = (amount) => exactMoneyLabel(amount, data.currency, data.currencyScale);
      for (const [key, label] of [['rent', 'Rent'], ['estateFees', 'Estate fees'], ['otherCharges', 'Other charges']]) {
        const stream = data[key];
        addMetric(`${label} collected`, money(stream.collected), `Billed ${money(stream.billed)} · outstanding ${money(stream.outstanding)}`, sourceStatus);
      }
      addMetric('Expenses paid', money(data.expensesPaid), `Currency ${data.currency}`, sourceStatus);
      addMetric('Net operating position', money(data.netOperatingPosition), 'Collected income less paid expenses', sourceStatus);
    } else if (section === 'visitors') {
      addMetric('Visitor activity', numberLabel(data.activityCount), 'Pass activity in the selected period', sourceStatus);
      addMetric('Currently checked in', numberLabel(data.currentlyCheckedIn), 'Visitors on site now', sourceStatus);
    } else if (section === 'maintenance') {
      addMetric('Open maintenance requests', numberLabel(data.openRequests), 'Requests awaiting completion', sourceStatus);
    }
  }

  function renderSummary(summary) {
    lastSummary = summary;
    metrics.replaceChildren();
    sources.replaceChildren();
    const config = hostConfig();
    const estateName = typeof config.currentEstate?.name === 'string' && config.currentEstate.name.trim()
      ? config.currentEstate.name.trim()
      : 'Selected estate';
    document.querySelector('.estate-meta strong').textContent = estateName;
    document.querySelector('.estate-meta small').textContent = [config.currentEstate?.locationLabel].filter(Boolean).join('') || 'Connected estate';
    document.querySelector('.estate-avatar').textContent = estateName.slice(0, 1).toUpperCase();
    document.querySelector('.breadcrumb > span').textContent = estateName;
    document.getElementById('pageTitle').textContent = `${estateName} overview`;
    const inclusiveEnd = new Date(Date.parse(summary.period.endAt) - 1);
    const range = `${sourceTime(summary.period.startAt, summary.period.timeZone).split(',')[0]} – ${sourceTime(inclusiveEnd.toISOString(), summary.period.timeZone).split(',')[0]}`;
    const asOf = sourceTime(summary.asOf, summary.period.timeZone);
    const state = document.createElement('span');
    state.textContent = `${estateName} · ${range} · Updated ${asOf}`;
    const refresh = document.createElement('button');
    refresh.type = 'button';
    refresh.className = 'live-dashboard-refresh';
    refresh.textContent = 'Refresh';
    refresh.addEventListener('click', refreshSummary);
    status.replaceChildren(state, refresh);
    const heading = document.querySelector('.page-heading .eyebrow');
    if (heading) heading.firstChild.textContent = 'LIVE ESTATE SUMMARY ';
    const subtitle = document.getElementById('pageSubtitle');
    subtitle.textContent = 'Metrics are limited to your estate permissions and show the source update status below.';
    const actions = document.querySelector('.page-heading .heading-actions');
    if (actions) actions.classList.add('hidden');
    const systemStatus = document.querySelector('.today-label');
    if (systemStatus) systemStatus.textContent = 'Live estate summary';
    const dateControl = document.querySelector('.date-button');
    if (dateControl) dateControl.classList.add('hidden');

    const sectionEntries = Object.entries(summary.sections || {});
    if (!sectionEntries.length) {
      addMetric('Dashboard metrics', 'Unavailable', 'No report sections are available to this account.', 'unavailable');
    }
    for (const [section, source] of sectionEntries) renderSection(section, source);
    for (const [section, freshness] of Object.entries(summary.sourceFreshness || {})) {
      const sourceCard = document.createElement('article');
      sourceCard.className = 'live-dashboard-source';
      sourceCard.dataset.freshness = freshness.status;
      sourceCard.append(
        textElement('strong', '', sectionLabels[section] || section),
        textElement('small', '', `${freshnessLabels[freshness.status] || freshness.status} · ${sourceTime(freshness.sourceAsOf, summary.period.timeZone)}`),
      );
      sources.append(sourceCard);
    }
  }

  function applyConnectedShell() {
    const config = hostConfig();
    const user = config.currentUser && typeof config.currentUser === 'object' ? config.currentUser : {};
    const name = typeof user.displayName === 'string' && user.displayName.trim() ? user.displayName.trim() : 'Signed-in user';
    const role = typeof user.estateRole === 'string' && user.estateRole.trim() ? user.estateRole.trim() : 'Estate account';
    const profileName = document.querySelector('.profile-meta strong');
    const profileRole = document.querySelector('.profile-meta small');
    const avatar = document.querySelector('.profile-avatar');
    if (profileName) profileName.textContent = name;
    if (profileRole) profileRole.textContent = role;
    if (avatar) avatar.textContent = name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
    document.querySelectorAll('.nav-count, .nav-dot').forEach((badge) => badge.classList.add('hidden'));
    const systemStatus = document.querySelector('.today-label');
    if (systemStatus) systemStatus.textContent = 'Live estate summary';
    const actions = document.querySelector('.page-heading .heading-actions');
    if (actions) actions.classList.add('hidden');
  }

  async function requestSummary() {
    const config = hostConfig();
    const url = resolveSummaryUrl();
    if (!url) throw new Error('Connect the selected estate dashboard endpoint before loading live metrics.');
    if (typeof config.request === 'function') {
      const result = await config.request({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && result instanceof Response) {
        if (!result.ok) throw new Error(`The dashboard service returned an error (${result.status}).`);
        return result.json();
      }
      return result;
    }
    const response = await fetch(url, {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) {
      const message = response.status === 401 ? 'Sign in to view estate dashboard metrics.'
        : response.status === 403 ? 'Your account cannot view these dashboard sections.'
          : `The dashboard service returned an error (${response.status}).`;
      throw new Error(message);
    }
    return response.json();
  }

  async function refreshSummary() {
    if (!liveMode) return;
    const generation = ++requestGeneration;
    const requestedEstate = estateId();
    lastSummary = null;
    status.dataset.state = 'loading';
    status.replaceChildren(textElement('span', '', 'Loading authorized estate metrics...'));
    metrics.replaceChildren();
    sources.replaceChildren();
    try {
      const response = await requestSummary();
      const summary = response?.data || response;
      if (generation !== requestGeneration || requestedEstate !== estateId()) return;
      if (!validSummary(summary)) throw new Error('The dashboard service returned a summary for a different estate or an invalid response.');
      renderSummary(summary);
      status.dataset.state = 'ready';
    } catch (error) {
      if (generation !== requestGeneration || requestedEstate !== estateId()) return;
      lastSummary = null;
      status.dataset.state = 'error';
      const message = textElement('span', '', error.message || 'Dashboard metrics could not be loaded.');
      const retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'live-dashboard-refresh live-dashboard-error-action';
      retry.textContent = 'Try again';
      retry.addEventListener('click', refreshSummary);
      status.replaceChildren(message, retry);
      metrics.replaceChildren();
      sources.replaceChildren();
    }
  }

  function applyView(view) {
    if (!liveMode) return;
    applyConnectedShell();
    const isOverview = view === 'overview';
    liveView.classList.toggle('hidden', !isOverview);
    const actions = document.querySelector('.page-heading .heading-actions');
    if (actions) actions.classList.toggle('hidden', isOverview);
    const dateControl = document.querySelector('.date-button');
    if (dateControl) dateControl.classList.toggle('hidden', isOverview);
    document.querySelectorAll('.summary-grid, .content-grid, .bottom-grid').forEach((part) => {
      part.classList.toggle('hidden', isOverview);
    });
    if (isOverview && lastSummary) renderSummary(lastSummary);
    else if (isOverview && status.dataset.state !== 'loading') refreshSummary();
    else if (isOverview) {
      const config = hostConfig();
      const name = typeof config.currentEstate?.name === 'string' && config.currentEstate.name.trim()
        ? config.currentEstate.name.trim() : 'Selected estate';
      document.getElementById('pageTitle').textContent = `${name} overview`;
      document.getElementById('pageSubtitle').textContent = 'Loading authorized estate metrics...';
    }
  }

  window.refreshEstateDashboardSummary = refreshSummary;
  if (!liveMode) return;
  window.addEventListener('estate:view-changed', (event) => applyView(event.detail?.view));
  window.addEventListener('estate:context-changed', refreshSummary);
  const activeView = document.querySelector('.nav-item.active')?.dataset.view || 'overview';
  applyView(activeView);
})();
