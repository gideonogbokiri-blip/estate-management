(() => {
  const previewStatus = (row) => {
    const value = row.querySelector('.application-state')?.textContent.trim().toLowerCase() || '';
    if (value.includes('under review')) return 'under_review';
    if (value.includes('approved')) return 'approved';
    if (value.includes('rejected')) return 'rejected';
    if (value.includes('information')) return 'more_information_required';
    return 'submitted';
  };

  function createControl(tag, attributes = {}, text = '') {
    const element = document.createElement(tag);
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value));
    element.textContent = text;
    return element;
  }

  function getElements() {
    const root = document.getElementById('moduleContent');
    const toolbar = root?.querySelector('.application-queue-toolbar');
    const table = root?.querySelector('.module-table table');
    const tbody = table?.querySelector('tbody');
    if (!root || !toolbar || !tbody) return null;
    return {
      root,
      toolbar,
      tbody,
      status: toolbar.querySelector('[data-queue-status]'),
      search: toolbar.querySelector('[data-queue-search]'),
      state: root.querySelector('[data-queue-state]'),
      summary: root.querySelector('[data-queue-summary]'),
      previous: root.querySelector('[data-queue-previous]'),
      next: root.querySelector('[data-queue-next]'),
    };
  }

  function ensureControls() {
    const root = document.getElementById('moduleContent');
    const actions = root?.querySelector('.application-heading-actions');
    const panel = root?.querySelector('.module-panel');
    if (!root || !actions || !panel) return false;
    actions.querySelector('[data-action="application-filter"]')?.remove();
    if (!root.querySelector('.application-queue-toolbar')) {
      const toolbar = document.createElement('div');
      toolbar.className = 'application-queue-toolbar';
      const searchLabel = createControl('label', {}, 'Search applications');
      const search = createControl('input', { type: 'search', placeholder: 'Estate, applicant or location', 'data-queue-search': '' });
      searchLabel.append(search);
      const statusLabel = createControl('label', {}, 'Status');
      const status = createControl('select', { 'data-queue-status': '' });
      [['open', 'Open applications'], ['all', 'All statuses'], ['submitted', 'Submitted'], ['under_review', 'Under review'], ['more_information_required', 'More information'], ['approved', 'Approved'], ['rejected', 'Rejected']]
        .forEach(([value, label]) => status.append(createControl('option', { value }, label)));
      statusLabel.append(status);
      const refresh = createControl('button', { class: 'button button-secondary', type: 'button', 'data-queue-refresh': '' }, 'Refresh');
      toolbar.append(searchLabel, statusLabel, refresh);
      const panelHeader = panel.querySelector('.panel-header');
      panelHeader?.after(toolbar);

      const state = createControl('p', { class: 'application-queue-state', role: 'status', 'aria-live': 'polite', 'data-queue-state': '' }, 'Local preview data · not connected to live services.');
      toolbar.after(state);
      const footer = panel.querySelector('.module-table-foot');
      if (footer) {
        const pagination = document.createElement('div');
        pagination.className = 'module-table-foot application-queue-pagination';
        const summary = createControl('span', { 'data-queue-summary': '' }, 'Showing sample applications');
        const buttons = document.createElement('div');
        buttons.append(
          createControl('button', { class: 'button button-secondary', type: 'button', 'data-queue-previous': '', disabled: '' }, 'Previous'),
          createControl('button', { class: 'button button-secondary', type: 'button', 'data-queue-next': '', disabled: '' }, 'Next'),
        );
        pagination.append(summary, buttons);
        footer.before(pagination);
      }
    }
    return true;
  }

  function setState(elements, message, state = 'ready') {
    if (!elements?.state) return;
    elements.state.textContent = message;
    elements.state.dataset.state = state;
  }

  function filterPreview() {
    const elements = getElements();
    if (!elements) return;
    const status = elements.status.value;
    const search = elements.search.value.trim().toLocaleLowerCase();
    const rows = [...elements.tbody.querySelectorAll('tr[data-application-id]')];
    let visible = 0;
    rows.forEach((row) => {
      const id = row.dataset.applicationId;
      const detail = elements.tbody.querySelector(`[data-details-for="${CSS.escape(id)}"]`);
      const matchesStatus = status === 'all' || status === 'open' && ['submitted', 'under_review'].includes(previewStatus(row)) || previewStatus(row) === status;
      const matchesSearch = !search || `${row.textContent} ${detail?.textContent || ''}`.toLocaleLowerCase().includes(search);
      const show = matchesStatus && matchesSearch;
      row.classList.toggle('hidden', !show);
      if (detail) {
        detail.classList.toggle('hidden', !show || !detail.dataset.expanded);
        if (!show) detail.dataset.expanded = '';
      }
      if (show) visible += 1;
    });
    elements.summary.textContent = `${visible} sample application${visible === 1 ? '' : 's'}`;
    elements.previous.disabled = true;
    elements.next.disabled = true;
    setState(elements, 'Local preview data · not connected to live services.');
  }

  function appendLiveRows(elements, payload) {
    elements.tbody.replaceChildren();
    if (!Array.isArray(payload.items)) throw new Error('The application queue response is invalid.');
    if (!payload.items.length) {
      const row = document.createElement('tr');
      const cell = createControl('td', { colspan: '7', class: 'application-queue-empty' }, 'No applications match these filters.');
      row.append(cell);
      elements.tbody.append(row);
      return;
    }
    payload.items.forEach((item) => {
      if (!item?.id || !item.applicant || !item.location || !item.documentSummary
        || typeof item.applicant.displayName !== 'string'
        || typeof item.proposedName !== 'string'
        || Number.isNaN(new Date(item.submittedAt).getTime())
        || !Number.isSafeInteger(item.documentSummary.count) || item.documentSummary.count < 0
        || !Number.isSafeInteger(item.documentSummary.pendingReview) || item.documentSummary.pendingReview < 0
        || item.documentSummary.pendingReview > item.documentSummary.count) {
        throw new Error('An application queue record is incomplete.');
      }
      const row = document.createElement('tr');
      row.dataset.applicationId = String(item.id);
      row.dataset.liveApplication = 'true';
      row.dataset.applicationStatus = item.status;
      const estateCell = document.createElement('td');
      const avatar = createControl('span', { class: 'estate-table-avatar' }, String(item.proposedName || 'E').slice(0, 1).toUpperCase());
      const estateName = document.createElement('span');
      estateName.className = 'request-name';
      estateName.append(createControl('strong', {}, item.proposedName || 'Estate application'));
      estateName.append(createControl('small', {}, item.applicationCode ? `Application · ${item.applicationCode}` : 'Estate application'));
      estateCell.append(avatar, estateName);
      const location = [item.location.lga, item.location.state].filter(Boolean).join(', ') || 'Location not provided';
      const statusLabels = { submitted: 'Submitted', under_review: 'Under review', more_information_required: 'More information', approved: 'Approved', rejected: 'Rejected' };
      const cells = [item.applicant.displayName, location, item.estateType || 'Not specified', new Date(item.submittedAt).toLocaleDateString('en-NG'), statusLabels[item.status] || item.status];
      const statusCell = document.createElement('td');
      statusCell.className = 'application-state';
      const statusPill = createControl('span', { class: `status-pill ${['approved'].includes(item.status) ? 'status-active' : ['rejected'].includes(item.status) ? 'status-overdue' : 'status-review'}` });
      statusPill.append(document.createElement('i'), document.createTextNode(statusLabels[item.status] || item.status));
      statusCell.append(statusPill);
      row.append(estateCell);
      cells.slice(0, 4).forEach((value) => row.append(createControl('td', {}, String(value ?? ''))));
      row.append(statusCell);
      const actionCell = document.createElement('td');
      actionCell.append(createControl('button', { class: 'table-action', type: 'button', 'data-queue-expand': String(item.id) }, 'Summary'));
      row.append(actionCell);
      const detail = document.createElement('tr');
      detail.className = 'application-queue-detail hidden';
      detail.dataset.detailsFor = String(item.id);
      const detailCell = createControl('td', { colspan: '7' });
      const summary = document.createElement('strong');
      summary.textContent = `${item.documentSummary.count} supporting document${item.documentSummary.count === 1 ? '' : 's'} · ${item.documentSummary.pendingReview} awaiting review`;
      detailCell.append(summary, document.createElement('br'), document.createTextNode(`Application status: ${statusLabels[item.status] || item.status}. Select Summary to load authorized application details.`));
      detail.append(detailCell);
      elements.tbody.append(row, detail);
    });
  }

  async function loadApplicationDetail(applicationId, detailCell, button) {
    const config = window.ZvendEstateConfig;
    const baseUrl = typeof config?.apiBaseUrl === 'string' ? config.apiBaseUrl.replace(/\/$/, '') : '';
    const queueUrl = typeof config?.applicationQueueUrl === 'string'
      ? config.applicationQueueUrl.replace(/\/$/, '')
      : baseUrl ? `${baseUrl}/api/estate/platform/applications` : '';
    const detailBase = typeof config?.applicationDetailUrlBase === 'string'
      ? config.applicationDetailUrlBase.replace(/\/$/, '')
      : queueUrl;
    if (!detailBase) return false;
    detailCell.replaceChildren(createControl('span', {}, 'Loading application details…'));
    button.disabled = true;
    try {
      const response = await fetch(`${detailBase}/${encodeURIComponent(applicationId)}`, {
        method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' },
      });
      if (!response.ok) throw new Error(response.status === 403 ? 'You do not have permission to view this application.' : response.status === 401 ? 'Sign in to view this application.' : `Application details unavailable (${response.status}).`);
      const result = await response.json();
      const detail = result?.data || result;
      if (!detail?.applicant || !detail.location || !Array.isArray(detail.documents)) throw new Error('The application detail response is invalid.');
      const content = document.createElement('div');
      content.className = 'application-queue-detail-grid';
      const facts = [
        ['APPLICANT', detail.applicant.displayName],
        ['CONTACT', [detail.applicant.email, detail.applicant.phone].filter(Boolean).join(' · ') || 'Not provided'],
        ['OPERATOR', detail.managementEntityName || 'Not provided'],
        ['LOCATION', [detail.location.address, detail.location.lga, detail.location.state].filter(Boolean).join(', ') || 'Not provided'],
        ['ESTATE STRUCTURE', detail.structureSummary || detail.estateType || 'Not provided'],
        ['MAP PIN', detail.mapPinProvided ? 'Provided' : 'Not provided'],
      ];
      facts.forEach(([label, value]) => {
        const fact = document.createElement('div');
        fact.append(createControl('span', {}, label), createControl('strong', {}, String(value || 'Not provided')));
        content.append(fact);
      });
      const applicationRow = getElements()?.tbody.querySelector(`[data-application-id="${CSS.escape(String(applicationId))}"]`);
      if (applicationRow?.dataset.applicationStatus === 'submitted') {
        const actions = document.createElement('div');
        actions.className = 'application-queue-actions';
        actions.append(createControl('button', { class: 'table-action approve-action', type: 'button', 'data-queue-start-review': String(applicationId) }, 'Start review'));
        content.append(actions);
      } else if (applicationRow?.dataset.applicationStatus === 'under_review') {
        const actions = document.createElement('div');
        actions.className = 'application-queue-actions';
        actions.append(
          createControl('button', { class: 'table-action', type: 'button', 'data-action': 'request-info', 'data-id': String(applicationId) }, 'Request information'),
          createControl('button', { class: 'table-action reject-action', type: 'button', 'data-action': 'reject-estate', 'data-id': String(applicationId) }, 'Reject application'),
        );
        content.append(actions);
      }
      const documents = document.createElement('div');
      documents.className = 'application-queue-documents';
      documents.append(createControl('strong', {}, `Supporting documents (${detail.documents.length})`));
      const list = document.createElement('ul');
      detail.documents.forEach((documentMetadata) => {
        const item = document.createElement('li');
        const label = document.createElement('span');
        label.textContent = `${documentMetadata.label || documentMetadata.category || 'Document'} · ${documentMetadata.reviewStatus || 'Pending review'} `;
        item.append(label);
        if (typeof documentMetadata.accessId === 'string' && documentMetadata.accessId) {
          const accessBase = typeof config?.documentAccessUrlBase === 'string'
            ? config.documentAccessUrlBase.replace(/\/$/, '')
            : `${detailBase}/${encodeURIComponent(applicationId)}/documents`;
          const link = createControl('a', {
            href: `${accessBase}/${encodeURIComponent(documentMetadata.accessId)}/access`,
            target: '_blank', rel: 'noopener noreferrer',
          }, 'Open file');
          item.append(link);
        }
        list.append(item);
      });
      if (!detail.documents.length) list.append(createControl('li', {}, 'No documents attached.'));
      documents.append(list, createControl('small', {}, 'File contents open only through the authorized private document service.'));
      detailCell.replaceChildren(content, documents);
      return true;
    } catch (error) {
      detailCell.replaceChildren(createControl('span', { class: 'application-queue-detail-error' }, error.message || 'Unable to load application details.'));
      return false;
    } finally {
      button.disabled = false;
    }
  }

  async function loadLiveQueue(page = 1) {
    const elements = getElements();
    if (!elements) return;
    const config = window.ZvendEstateConfig;
    const baseUrl = typeof config?.apiBaseUrl === 'string' ? config.apiBaseUrl.replace(/\/$/, '') : '';
    const endpoint = typeof config?.applicationQueueUrl === 'string'
      ? config.applicationQueueUrl
      : baseUrl ? `${baseUrl}/api/estate/platform/applications` : '';
    if (!endpoint) return filterPreview();
    setState(elements, 'Loading applications…', 'loading');
    elements.tbody.setAttribute('aria-busy', 'true');
    const params = new URLSearchParams({ page: String(page), pageSize: '25', status: elements.status.value, search: elements.search.value.trim() });
    try {
      const response = await fetch(`${endpoint}?${params}`, { method: 'GET', credentials: 'same-origin', headers: { Accept: 'application/json' } });
      if (!response.ok) throw new Error(response.status === 403 ? 'You do not have permission to view these applications.' : response.status === 401 ? 'Sign in to view estate applications.' : `Application queue unavailable (${response.status}).`);
      const result = await response.json();
      const payload = result?.data || result;
      if (!Number.isSafeInteger(payload.total) || payload.total < 0
        || !Number.isSafeInteger(payload.totalPages) || payload.totalPages < 0) {
        throw new Error('The application queue response is invalid.');
      }
      appendLiveRows(elements, payload);
      const total = Number(payload.total) || 0;
      const totalPages = Math.max(1, Number(payload.totalPages) || 1);
      elements.summary.textContent = `${total ? (page - 1) * 25 + 1 : 0}–${Math.min(page * 25, total)} of ${total} applications`;
      elements.previous.disabled = page <= 1;
      elements.next.disabled = page >= totalPages;
      elements.previous.dataset.page = String(page - 1);
      elements.next.dataset.page = String(page + 1);
      setState(elements, 'Live application data · reviewer scope enforced by the estate service.');
    } catch (error) {
      elements.tbody.replaceChildren();
      const row = document.createElement('tr');
      row.append(createControl('td', { colspan: '7', class: 'application-queue-empty' }, error.message || 'Unable to load applications.'));
      elements.tbody.append(row);
      elements.summary.textContent = 'Queue unavailable';
      setState(elements, error.message || 'Unable to load applications.', 'error');
    } finally {
      elements.tbody.removeAttribute('aria-busy');
    }
  }

  function getQueueBaseUrl() {
    const config = window.ZvendEstateConfig;
    const baseUrl = typeof config?.apiBaseUrl === 'string' ? config.apiBaseUrl.replace(/\/$/, '') : '';
    return typeof config?.applicationQueueUrl === 'string'
      ? config.applicationQueueUrl.replace(/\/$/, '')
      : baseUrl ? `${baseUrl}/api/estate/platform/applications` : '';
  }

  async function startReview(applicationId, button) {
    const queueBase = getQueueBaseUrl();
    if (!queueBase) return;
    button.disabled = true;
    try {
      const response = await fetch(`${queueBase}/${encodeURIComponent(applicationId)}/start-review`, {
        method: 'POST', credentials: 'same-origin', headers: { Accept: 'application/json', 'Content-Type': 'application/json' }, body: '{}',
      });
      if (!response.ok) throw new Error(response.status === 403 ? 'You do not have permission to start this review.' : response.status === 409 ? 'This application has already changed. Refresh and try again.' : `Review could not be started (${response.status}).`);
      setState(getElements(), 'Review started · reloading the assigned application queue.');
      await loadLiveQueue(1);
    } catch (error) {
      button.disabled = false;
      setState(getElements(), error.message || 'Review could not be started.', 'error');
    }
  }

  let searchTimer;
  document.addEventListener('click', (event) => {
    const elements = getElements();
    if (!elements) return;
    const live = Boolean(window.ZvendEstateConfig?.applicationQueueUrl || window.ZvendEstateConfig?.apiBaseUrl);
    const expand = event.target.closest('[data-queue-expand]');
    if (expand) {
      const detail = elements.tbody.querySelector(`[data-details-for="${CSS.escape(expand.dataset.queueExpand)}"]`);
      if (detail) {
        detail.dataset.expanded = detail.dataset.expanded ? '' : 'true';
        detail.classList.toggle('hidden', !detail.dataset.expanded);
        expand.textContent = detail.dataset.expanded ? 'Close' : 'Summary';
        if (live && detail.dataset.expanded && !detail.dataset.loaded) {
          detail.dataset.loaded = 'loading';
          loadApplicationDetail(expand.dataset.queueExpand, detail.firstElementChild, expand)
            .then((loaded) => { detail.dataset.loaded = loaded ? 'true' : ''; });
        }
      }
      return;
    }
    const pageButton = event.target.closest('[data-queue-previous], [data-queue-next]');
    if (live && pageButton && !pageButton.disabled) void loadLiveQueue(Number(pageButton.dataset.page));
    if (event.target.closest('[data-queue-refresh]')) live ? void loadLiveQueue(1) : filterPreview();
    const startReviewButton = event.target.closest('[data-queue-start-review]');
    if (startReviewButton) void startReview(startReviewButton.dataset.queueStartReview, startReviewButton);
  });

  window.initializeEstateApplicationQueue = function initializeEstateApplicationQueue() {
    if (!ensureControls()) return;
    const elements = getElements();
    const live = Boolean(window.ZvendEstateConfig?.applicationQueueUrl || window.ZvendEstateConfig?.apiBaseUrl);
    if (live) void loadLiveQueue(1);
    else filterPreview();
    elements.status.addEventListener('change', () => live ? void loadLiveQueue(1) : filterPreview());
    elements.search.addEventListener('input', () => {
      if (!live) return filterPreview();
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => { void loadLiveQueue(1); }, 300);
    });
  };
  window.refreshEstateApplicationQueue = function refreshEstateApplicationQueue() {
    return loadLiveQueue(1);
  };
})();
