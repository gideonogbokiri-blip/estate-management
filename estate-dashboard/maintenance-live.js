(() => {
  function config() { return window.ZvendEstateConfig || {}; }
  function estateId() {
    const value = config().currentEstateId;
    return value === undefined || value === null ? '' : String(value);
  }
  function apiBase() { return typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : ''; }
  function queueUrl() {
    const custom = config().maintenanceQueueUrl;
    return typeof custom === 'string' && custom.trim()
      ? custom.trim().replaceAll('{estateId}', encodeURIComponent(estateId())).replace(':estateId', encodeURIComponent(estateId()))
      : apiBase() ? `${apiBase()}/api/estate/maintenance/requests` : '';
  }
  if (!estateId() || !queueUrl()) return;

  const state = { items: [], staff: [], capabilities: { canAssign: false, canAddInternalNote: false }, filter: 'open', search: '', page: 1, pageSize: 50, totalPages: 1, generation: 0, loading: false };
  let debounceTimer;
  function endpoint(path = '', query = {}) {
    const url = new URL(`${queueUrl().replace(/\/$/, '')}${path}`, window.location.href);
    if (url.origin !== window.location.origin) throw new Error('Maintenance services must use the authenticated same-origin host.');
    url.searchParams.set('estateId', estateId());
    Object.entries(query).forEach(([key, value]) => {
      if (value === undefined || value === null || value === '') return;
      url.searchParams.set(key, Array.isArray(value) ? value.join(',') : String(value));
    });
    return url.toString();
  }
  async function request(url, method = 'GET', payload) {
    const adapter = config().request;
    if (typeof adapter !== 'function') throw new Error('Maintenance review requires the host authenticated API request adapter.');
    const response = await adapter({ url, method, payload, credentials: 'same-origin' });
    let body = response;
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) throw new Error('The maintenance service could not complete this request.');
      body = response.status === 204 ? null : await response.json();
    }
    return body?.data ?? body;
  }
  function statusName(value) {
    return String(value || 'unknown').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
  function statusClass(value) {
    return ({ in_progress: 'status-progress', awaiting_parts: 'status-review', resolved: 'status-paid', closed: 'status-paid', assigned: 'status-assigned', rejected: 'status-overdue', reopened: 'status-review' })[value] || 'status-review';
  }
  function priorityClass(value) { return ({ urgent: 'priority-high', high: 'priority-high', normal: 'priority-medium', low: 'priority-low' })[value] || 'priority-medium'; }
  function element(tag, className, value) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (value !== undefined) node.textContent = value;
    return node;
  }
  function formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }
  function validInstant(value) {
    return typeof value === 'string' && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString() === value;
  }
  function validQueueItem(item, selectedEstateId) {
    const fields = new Set(['id', 'estateId', 'reference', 'title', 'category', 'priority', 'status', 'submittedAt', 'propertyLabel', 'requesterDisplayName', 'assigneeUserId', 'assigneeDisplayName', 'description', 'residentVisibleUpdates', 'allowedCommands']);
    const statuses = new Set(['submitted', 'under_review', 'assigned', 'in_progress', 'awaiting_parts', 'resolved', 'closed', 'rejected', 'reopened']);
    const commands = new Set(['review', 'assign', 'start', 'await_parts', 'resume', 'resolve', 'close', 'reject', 'reopen']);
    const label = (value, max) => value === null || typeof value === 'string' && value.length <= max;
    return Boolean(item && Object.keys(item).every((field) => fields.has(field))
      && (typeof item.id === 'string' || typeof item.id === 'number') && String(item.estateId) === selectedEstateId
      && typeof item.reference === 'string' && item.reference.trim() && item.reference.length <= 80
      && label(item.title, 160) && ['plumbing', 'electrical', 'security', 'cleaning', 'other'].includes(item.category)
      && ['low', 'normal', 'high', 'urgent'].includes(item.priority) && statuses.has(item.status)
      && validInstant(item.submittedAt) && label(item.propertyLabel, 160) && label(item.requesterDisplayName, 160)
      && (item.assigneeUserId === null || typeof item.assigneeUserId === 'string' || typeof item.assigneeUserId === 'number')
      && label(item.assigneeDisplayName, 160) && typeof item.description === 'string' && item.description.trim() && item.description.length <= 700
      && Array.isArray(item.residentVisibleUpdates) && item.residentVisibleUpdates.length <= 100
      && item.residentVisibleUpdates.every((update) => update && Object.keys(update).every((field) => ['body', 'occurredAt'].includes(field))
        && typeof update.body === 'string' && update.body.trim() && update.body.length <= 700 && validInstant(update.occurredAt))
      && Array.isArray(item.allowedCommands) && item.allowedCommands.every((command) => commands.has(command))
      && new Set(item.allowedCommands).size === item.allowedCommands.length);
  }
  function renderRows() {
    const body = document.getElementById('maintenanceQueueRows');
    if (!body) return;
    body.replaceChildren();
    const items = state.items;
    if (!items.length) {
      const row = document.createElement('tr');
      const cell = element('td', 'maintenance-live-empty', state.loading ? 'Loading maintenance requests…' : 'No maintenance requests match this view.');
      cell.colSpan = 7;
      row.append(cell);
      body.append(row);
      return;
    }
    items.forEach((item) => {
      const row = document.createElement('tr');
      row.dataset.maintenanceId = String(item.id);
      const issue = document.createElement('td');
      const symbol = element('span', `request-symbol ${String(item.category || 'general').toLowerCase()}`, String(item.category || '•').slice(0, 1).toUpperCase());
      const title = document.createElement('span');
      title.className = 'request-name';
      const strong = element('strong', '', item.title || `${statusName(item.category)} request`);
      const small = element('small', '', `${statusName(item.category)} · ${formatDate(item.submittedAt)} · ${item.reference || item.id}`);
      title.append(strong, small);
      issue.append(symbol, title);
      row.append(issue, element('td', '', item.propertyLabel || 'Property'), element('td', '', item.requesterDisplayName || 'Resident'),
        element('td', '', item.assigneeDisplayName || 'Unassigned'));
      const priority = document.createElement('td');
      priority.append(element('span', `priority ${priorityClass(item.priority)}`, statusName(item.priority)));
      row.append(priority);
      const status = document.createElement('td');
      status.className = 'maintenance-status';
      const pill = element('span', `status-pill ${statusClass(item.status)}`, statusName(item.status));
      pill.prepend(document.createElement('i'));
      status.append(pill);
      row.append(status);
      const action = document.createElement('td');
      const review = element('button', 'table-action', 'Review');
      review.type = 'button';
      review.dataset.action = 'maintenance-review';
      review.dataset.id = String(item.id);
      action.append(review);
      row.append(action);
      body.append(row);
    });
  }
  function clearPreviewRows() {
    const body = document.getElementById('maintenanceQueueRows');
    if (body) body.replaceChildren();
  }
  function renderLiveNotice(message, error = false) {
    const table = document.querySelector('#moduleContent .maintenance-live-note');
    if (table) {
      table.textContent = message;
      table.dataset.state = error ? 'error' : 'ready';
      table.setAttribute('role', error ? 'alert' : 'status');
      table.setAttribute('aria-live', 'polite');
    }
  }
  function renderReviewNotice(message, error = false) {
    const note = document.querySelector('#maintenanceReviewModal .maintenance-live-note');
    if (note) {
      note.textContent = message;
      note.dataset.state = error ? 'error' : 'ready';
      note.setAttribute('role', error ? 'alert' : 'status');
      note.setAttribute('aria-live', 'polite');
    }
  }
  function setupFilters() {
    const filters = document.querySelectorAll('#moduleContent [data-maintenance-filter]');
    filters.forEach((button) => {
      button.onclick = () => {
        state.filter = button.dataset.maintenanceFilter;
        state.page = 1;
        filters.forEach((candidate) => candidate.classList.toggle('selected', candidate === button));
        load();
      };
    });
    const input = document.getElementById('maintenanceSearch');
    if (input && !input.dataset.liveBound) {
      input.dataset.liveBound = 'true';
      input.addEventListener('input', () => {
        window.clearTimeout(debounceTimer);
        debounceTimer = window.setTimeout(() => { state.search = input.value.trim(); state.page = 1; load(); }, 250);
      });
    }
    const previous = document.getElementById('maintenancePagePrevious');
    const next = document.getElementById('maintenancePageNext');
    if (previous && next && !previous.dataset.liveBound) {
      previous.dataset.liveBound = 'true';
      previous.addEventListener('click', () => { if (state.page > 1) { state.page -= 1; load(); } });
      next.addEventListener('click', () => { if (state.page < state.totalPages) { state.page += 1; load(); } });
    }
  }
  function setupLiveView() {
    if (!document.getElementById('maintenanceQueueRows')) return;
    const note = document.querySelector('#moduleContent .maintenance-preview-note');
    if (note) note.className = 'maintenance-live-note';
    const counts = document.querySelectorAll('#moduleContent .module-stats article');
    if (counts[0]) { counts[0].querySelector('strong').textContent = '—'; counts[0].querySelector('span').textContent = 'OPEN ON THIS PAGE'; counts[0].querySelector('small').textContent = 'Live estate requests'; }
    if (counts[1]) { counts[1].querySelector('strong').textContent = '—'; counts[1].querySelector('span').textContent = 'IN PROGRESS ON THIS PAGE'; counts[1].querySelector('small').textContent = 'Live estate requests'; }
    if (counts[2]) { counts[2].querySelector('strong').textContent = '—'; counts[2].querySelector('span').textContent = 'RESOLVED ON THIS PAGE'; counts[2].querySelector('small').textContent = 'Live estate requests'; }
    clearPreviewRows();
    setupFilters();
    load();
  }
  async function load() {
    const body = document.getElementById('maintenanceQueueRows');
    if (!body) return;
    const requestEstateId = estateId();
    const generation = ++state.generation;
    state.loading = true;
    state.items = [];
    renderRows();
    const filterStatuses = state.filter === 'open'
      ? ['submitted', 'under_review', 'assigned', 'in_progress', 'awaiting_parts', 'reopened']
      : state.filter === 'in_progress' ? ['in_progress']
      : state.filter === 'resolved' ? ['resolved', 'closed', 'rejected'] : [];
    renderLiveNotice('Loading estate maintenance requests…');
    document.querySelectorAll('#moduleContent .module-stats article strong').forEach((node) => { node.textContent = '—'; });
    try {
      const result = await request(endpoint('', {
        page: state.page,
        pageSize: state.pageSize,
        statuses: filterStatuses,
        search: state.search,
      }));
      if (generation !== state.generation || requestEstateId !== estateId()) return;
      if (!result || !Array.isArray(result.items) || !Array.isArray(result.assignableStaff)
        || !Number.isInteger(result.total) || result.total < 0
        || result.page !== state.page || result.pageSize !== state.pageSize
        || !Number.isInteger(result.totalPages) || result.totalPages < 0
        || result.totalPages !== Math.ceil(result.total / result.pageSize)
        || result.items.some((item) => !validQueueItem(item, requestEstateId))
        || new Set(result.items.map((item) => String(item.id))).size !== result.items.length
        || result.assignableStaff.length > 100
        || result.assignableStaff.some((member) => !member || Object.keys(member).some((field) => !['userId', 'displayName'].includes(field))
          || !(typeof member.userId === 'string' || typeof member.userId === 'number')
          || typeof member.displayName !== 'string' || !member.displayName.trim() || member.displayName.length > 160)
        || new Set(result.assignableStaff.map((member) => String(member.userId))).size !== result.assignableStaff.length
        || !result.capabilities || Object.keys(result.capabilities).some((field) => !['canAssign', 'canAddInternalNote'].includes(field))
        || typeof result.capabilities.canAssign !== 'boolean'
        || typeof result.capabilities.canAddInternalNote !== 'boolean'
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new Error('The maintenance service returned an invalid or out-of-scope queue.');
      }
      const pageItems = result.items;
      state.items = result.items;
      state.staff = result.assignableStaff;
      state.capabilities = result.capabilities;
      state.totalPages = Math.max(1, Number(result.totalPages) || 1);
      renderRows();
      renderLiveNotice(`${result.total} maintenance request${result.total === 1 ? '' : 's'} in this view.`);
      const counts = document.querySelectorAll('#moduleContent .module-stats article strong');
      if (counts[0]) counts[0].textContent = String(pageItems.filter((item) => !['resolved', 'closed', 'rejected'].includes(item.status)).length);
      if (counts[1]) counts[1].textContent = String(pageItems.filter((item) => item.status === 'in_progress').length);
      if (counts[2]) counts[2].textContent = String(pageItems.filter((item) => ['resolved', 'closed', 'rejected'].includes(item.status)).length);
      const pageSummary = document.getElementById('maintenancePageSummary');
      if (pageSummary) pageSummary.textContent = `Page ${state.page} of ${state.totalPages} · ${result.total} requests`;
      const previous = document.getElementById('maintenancePagePrevious');
      const next = document.getElementById('maintenancePageNext');
      if (previous) previous.disabled = state.page <= 1;
      if (next) next.disabled = state.page >= state.totalPages;
    } catch {
      if (generation !== state.generation || requestEstateId !== estateId()) return;
      state.items = [];
      state.totalPages = 1;
      renderRows();
      renderLiveNotice('Maintenance requests could not be loaded. Refresh to try again.', true);
      const summary = document.getElementById('maintenancePageSummary');
      if (summary) summary.textContent = 'Maintenance queue unavailable';
      document.getElementById('maintenancePagePrevious').disabled = true;
      document.getElementById('maintenancePageNext').disabled = true;
    } finally {
      if (generation === state.generation) state.loading = false;
    }
  }
  function openReview(requestId) {
    const requestData = state.items.find((item) => String(item.id) === String(requestId));
    if (!requestData) return;
    window.__liveMaintenanceRequestId = String(requestData.id);
    document.getElementById('maintenanceReviewTitle').textContent = requestData.title || `${statusName(requestData.category)} request`;
    document.getElementById('maintenanceReviewSummary').textContent = `${requestData.reference || requestData.id} · ${requestData.propertyLabel || 'Property'} · ${requestData.requesterDisplayName || 'Resident'}`;
    const status = document.getElementById('maintenanceReviewStatus');
    status.className = `status-pill ${statusClass(requestData.status)}`;
    status.replaceChildren(document.createElement('i'), document.createTextNode(statusName(requestData.status)));
    document.getElementById('maintenanceReviewDescription').textContent = requestData.description || '';
    document.getElementById('maintenanceReviewCategory').textContent = statusName(requestData.category);
    document.getElementById('maintenanceReviewPriority').textContent = `${statusName(requestData.priority)} priority`;
    document.getElementById('maintenanceReviewCreated').textContent = `Submitted ${formatDate(requestData.submittedAt)}`;
    const assignee = document.getElementById('maintenanceAssignee');
    assignee.replaceChildren(new Option(requestData.assigneeUserId ? 'Keep current assignee' : 'Unassigned', requestData.assigneeUserId || ''));
    state.staff.forEach((member) => assignee.add(new Option(member.displayName, member.userId)));
    if (requestData.assigneeUserId && !state.staff.some((member) => String(member.userId) === String(requestData.assigneeUserId))) {
      assignee.add(new Option(requestData.assigneeDisplayName || 'Current assignee', requestData.assigneeUserId));
    }
    assignee.value = requestData.assigneeUserId || '';
    assignee.disabled = !state.capabilities.canAssign;
    const nextStatus = document.getElementById('maintenanceNextStatus');
    nextStatus.replaceChildren(new Option('No status change', ''));
    const commands = {
      review: ['Under review', 'review'], assign: ['Assigned', 'assign'], start: ['In progress', 'start'],
      await_parts: ['Awaiting parts', 'await_parts'], resume: ['Resume work', 'resume'],
      resolve: ['Resolved', 'resolve'], close: ['Closed', 'close'], reject: ['Rejected', 'reject'], reopen: ['Reopen', 'reopen'],
    };
    (requestData.allowedCommands || []).forEach((command) => {
      const option = commands[command];
      if (option) nextStatus.add(new Option(option[0], command));
    });
    document.getElementById('maintenanceTransitionReason').value = '';
    document.getElementById('maintenancePublicUpdate').value = '';
    document.getElementById('maintenanceInternalNote').value = '';
    document.getElementById('maintenanceInternalNote').disabled = !state.capabilities.canAddInternalNote;
    const internalField = document.querySelector('.internal-note-field');
    internalField.classList.toggle('hidden', !state.capabilities.canAddInternalNote);
    const history = document.getElementById('maintenanceReviewHistory');
    history.replaceChildren();
    (requestData.residentVisibleUpdates || []).forEach((update) => {
      const entry = document.createElement('article');
      entry.append(element('small', '', formatDate(update.occurredAt)), element('p', '', update.body));
      history.append(entry);
    });
    const previewNote = document.querySelector('#maintenanceReviewModal .maintenance-preview-note');
    previewNote.className = 'maintenance-live-note';
    previewNote.textContent = 'Connected to estate maintenance service. Private notes are sent only through the staff permission checked by the server.';
    document.querySelector('[data-action="save-maintenance-review"]').textContent = 'Save changes';
    document.getElementById('maintenanceReviewModal').classList.remove('hidden');
  }
  async function saveReview() {
    const requestId = window.__liveMaintenanceRequestId;
    if (!requestId) return;
    const command = document.getElementById('maintenanceNextStatus').value || null;
    const requestData = state.items.find((item) => String(item.id) === String(requestId));
    const selectedAssignee = document.getElementById('maintenanceAssignee').value || null;
    const assigneeUserId = command === 'assign' ? selectedAssignee
      : selectedAssignee && selectedAssignee !== (requestData?.assigneeUserId || null) ? selectedAssignee : null;
    const residentUpdate = document.getElementById('maintenancePublicUpdate').value.trim();
    const internalNote = document.getElementById('maintenanceInternalNote').value.trim();
    if (!command && !assigneeUserId && !residentUpdate && !internalNote) {
      renderReviewNotice('Add a status change, assignment or update before saving.', true);
      return;
    }
    if (command === 'assign' && !assigneeUserId) {
      renderReviewNotice('Choose an active staff member to assign this request.', true);
      document.getElementById('maintenanceAssignee').focus();
      return;
    }
    if (assigneeUserId && command && command !== 'assign') {
      renderReviewNotice('Save a status change and assignment separately, or choose Assigned as the status change.', true);
      return;
    }
    const reason = document.getElementById('maintenanceTransitionReason').value.trim();
    const resolutionSummary = command === 'resolve' ? document.getElementById('maintenanceTransitionReason').value.trim() : '';
    const button = document.querySelector('[data-action="save-maintenance-review"]');
    button.disabled = true;
    button.textContent = 'Saving…';
    try {
      const result = await request(endpoint(`/${encodeURIComponent(requestId)}/review`), 'POST', {
        command, assigneeUserId, reason, resolutionSummary, residentUpdate, internalNote,
      });
      if (!result || String(result.requestId) !== String(requestId) || String(result.estateId) !== estateId()) {
        throw new Error('The maintenance service did not confirm these changes.');
      }
      document.getElementById('maintenanceReviewModal').classList.add('hidden');
      window.__liveMaintenanceRequestId = '';
      await load();
    } catch {
      renderReviewNotice('Maintenance changes could not be saved. Review the request and try again.', true);
    } finally {
      button.disabled = false;
      button.textContent = 'Save changes';
    }
  }

  window.openLiveMaintenanceReview = openReview;
  window.saveLiveMaintenanceReview = saveReview;
  const content = document.getElementById('moduleContent');
  new MutationObserver(() => setupLiveView()).observe(content, { childList: true });
  window.addEventListener('estate:context-changed', () => {
    state.page = 1;
    state.totalPages = 1;
    state.items = [];
    setupLiveView();
  });
  window.refreshMaintenanceQueue = load;
  if (document.getElementById('maintenanceQueueRows')) setupLiveView();
})();
