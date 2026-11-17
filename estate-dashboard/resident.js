const residentToast = document.getElementById('residentToast');
const invoiceDetailModal = document.getElementById('invoiceDetailModal');
const receiptDetailModal = document.getElementById('receiptDetailModal');
const maintenanceRequestModal = document.getElementById('maintenanceRequestModal');
const maintenanceDetailModal = document.getElementById('maintenanceDetailModal');
const facilityBookingModal = document.getElementById('facilityBookingModal');
const incidentReportModal = document.getElementById('incidentReportModal');
const visitorPassModal = document.getElementById('visitorPassModal');
const joinRequestModal = document.getElementById('joinRequestModal');
const staffInvitationModal = document.getElementById('staffInvitationModal');
let toastTimeout;
let pendingBooking = null;
const receiptExamples = {
  'RCT-2026-0287': { receipt: 'RCT-2026-0287', invoice: 'OAK-2026-0287', description: 'Security levy', amount: '₦45,000', paidAt: '5 October 2026 · 10:42 am', method: 'Paystack', transaction: 'ZV-PAY-882104', property: 'Oakwood · 01', payer: 'Amara Okafor' },
  'RCT-2026-0271': { receipt: 'RCT-2026-0271', invoice: 'OAK-2026-0271', description: 'Waste collection', amount: '₦18,000', paidAt: '5 September 2026 · 8:16 am', method: 'Zvend wallet', transaction: 'ZV-PAY-876220', property: 'Oakwood · 01', payer: 'Amara Okafor' }
};
const maintenanceExamples = {
  'REQ-00318': {
    title: 'Water pressure issue', category: 'Plumbing', status: 'progress', statusLabel: 'In progress', updated: 'Updated today, 9:20 am',
    description: 'Bathroom tap pressure has been low since yesterday.',
    history: [
      ['Today · 9:20 am', 'Work started', 'Samuel from the facilities team is checking the building water line.'],
      ['Today · 8:05 am', 'Assigned to facilities', 'Your request was assigned to the estate facilities team.'],
      ['Today · 7:42 am', 'Request received', 'The estate team received your request.']
    ]
  },
  'REQ-00304': {
    title: 'Porch light replacement', category: 'Electrical', status: 'review', statusLabel: 'Under review', updated: 'Submitted 1 Nov',
    description: 'The porch light needs a new bulb near the front entrance.',
    history: [
      ['1 Nov · 3:12 pm', 'Request received', 'The estate team received your request. It is waiting for review.']
    ]
  },
  'REQ-00291': {
    title: 'Kitchen sink leak', category: 'Plumbing', status: 'resolved', statusLabel: 'Resolved', updated: 'Resolved 28 Oct',
    description: 'The maintenance team replaced the worn tap connector.',
    history: [
      ['28 Oct · 4:10 pm', 'Marked resolved', 'The maintenance team replaced the worn tap connector. Please confirm the repair is complete.'],
      ['27 Oct · 11:30 am', 'Work started', 'A technician inspected the sink and identified a worn connector.'],
      ['26 Oct · 8:45 am', 'Request received', 'The estate team received your request.']
    ]
  }
};

function closeInvoiceDetails() {
  invoiceDetailModal.classList.add('hidden');
}

function openReceiptDetail(receiptId) {
  const receipt = receiptExamples[receiptId];
  if (!receipt) return;
  const lines = document.getElementById('receiptDetailLines');
  lines.replaceChildren();
  [['Receipt reference', receipt.receipt], ['Invoice', receipt.invoice], ['Description', receipt.description], ['Payer', receipt.payer], ['Property', receipt.property], ['Paid via', receipt.method], ['Transaction reference', receipt.transaction], ['Settled on', receipt.paidAt], ['Amount received', receipt.amount]].forEach(([label, value]) => {
    const row = document.createElement('div');
    const name = document.createElement('span');
    name.textContent = label;
    const detail = document.createElement('strong');
    detail.textContent = value;
    row.append(name, detail);
    lines.append(row);
  });
  receiptDetailModal.classList.remove('hidden');
}

function closeReceiptDetail() {
  receiptDetailModal.classList.add('hidden');
}

function filterResidentInvoices(value) {
  let visible = 0;
  document.querySelectorAll('.resident-invoice-card').forEach((card) => {
    const matches = value === 'all' || card.dataset.invoiceState === value;
    card.classList.toggle('hidden', !matches);
    if (matches) visible += 1;
  });
  document.getElementById('residentInvoiceEmpty').classList.toggle('hidden', visible > 0);
}

function closeMaintenanceRequest() {
  maintenanceRequestModal.classList.add('hidden');
}

function closeMaintenanceDetail() {
  if (typeof window.cancelResidentMaintenanceDetail === 'function') window.cancelResidentMaintenanceDetail();
  maintenanceDetailModal.classList.add('hidden');
}

function renderMaintenanceDetail(requestId) {
  const request = maintenanceExamples[requestId];
  if (!request) return;
  document.getElementById('requestDetailReference').textContent = requestId;
  document.getElementById('requestDetailTitle').textContent = request.title;
  document.getElementById('requestDetailProperty').textContent = `Oakwood · 01 · ${request.category}`;
  document.getElementById('requestDetailStatus').textContent = request.statusLabel;
  document.getElementById('requestDetailStatus').className = `mini-status ${request.status === 'progress' ? 'status-progress' : request.status === 'resolved' ? 'status-paid' : 'status-review'}`;
  document.getElementById('requestDetailUpdated').textContent = request.updated;
  document.getElementById('requestDetailDescription').textContent = request.description;
  const timeline = document.getElementById('requestDetailTimeline');
  timeline.replaceChildren();
  request.history.forEach(([dateLabel, title, note]) => {
    const item = document.createElement('article');
    item.className = 'request-history-item';
    const date = document.createElement('time');
    date.textContent = dateLabel;
    const heading = document.createElement('strong');
    heading.textContent = title;
    const detail = document.createElement('p');
    detail.textContent = note;
    item.append(date, heading, detail);
    timeline.append(item);
  });
  document.getElementById('confirmResolution').classList.toggle('hidden', request.status !== 'resolved' || requestId !== 'REQ-00291');
  document.getElementById('reopenRequest').classList.toggle('hidden', request.status !== 'resolved');
  maintenanceDetailModal.classList.remove('hidden');
}

function filterResidentMaintenance(value) {
  let visible = 0;
  document.querySelectorAll('.resident-maintenance-card').forEach((card) => {
    const matches = value === 'all' || (value === 'open' ? card.dataset.requestStatus !== 'resolved' : card.dataset.requestStatus === 'resolved');
    card.classList.toggle('hidden', !matches);
    if (matches) visible += 1;
  });
  document.getElementById('residentRequestEmpty').classList.toggle('hidden', visible > 0);
}

function closeFacilityBooking() {
  facilityBookingModal.classList.add('hidden');
  pendingBooking = null;
  if (typeof window.cancelResidentFacilityBooking === 'function') window.cancelResidentFacilityBooking();
}

function closeIncidentReport() {
  incidentReportModal.classList.add('hidden');
}

function closeJoinRequest() {
  joinRequestModal.classList.add('hidden');
}

function closeStaffInvitation() {
  staffInvitationModal.classList.add('hidden');
}

function decideStaffInvitationPreview(decision) {
  const card = document.getElementById('residentStaffInvitation');
  if (!card || card.dataset.invitationState !== 'pending') {
    closeStaffInvitation();
    return;
  }
  const status = card.querySelector('[data-invitation-status]');
  const accepted = decision === 'accepted';
  card.dataset.invitationState = decision;
  status.className = `mini-status ${accepted ? 'status-checked' : 'status-due'}`;
  status.textContent = accepted ? 'Accepted in preview' : 'Declined in preview';
  card.querySelector('[data-action="review-staff-invitation"]')?.remove();
  closeStaffInvitation();
  residentMessage(accepted
    ? 'Invitation acceptance previewed. The live service must validate the invite before enabling estate access.'
    : 'Invitation marked declined in this preview only.');
}

function updateJoinPropertyOptions() {
  const property = document.getElementById('joinProperty');
  const options = {
    greenfield: [['GF-014', 'Greenfield · 014'], ['GF-B2-06', 'Block B · 06']],
    cedar: [['CR-008', 'Cedar Ridge · 008'], ['CR-A1-12', 'Block A · 12']]
  };
  property.replaceChildren(new Option('No property selected', ''));
  (options[document.getElementById('joinEstate').value] || []).forEach(([id, label]) => {
    property.add(new Option(label, id));
  });
  property.disabled = !document.getElementById('joinEstate').value;
}

function submitJoinRequestPreview() {
  const estate = document.getElementById('joinEstate');
  const property = document.getElementById('joinProperty');
  const relationship = document.getElementById('joinRelationship');
  const note = document.getElementById('joinRequestNote');
  const proof = document.getElementById('joinProofReference');
  const proofFile = proof.files?.[0] ?? null;
  const error = document.getElementById('joinRequestError');
  if (!estate.value || !relationship.value) {
    error.textContent = 'Choose an estate and your relationship before sending the request.';
    return;
  }
  const estateLabel = estate.selectedOptions[0].textContent.split(' · ')[0];
  const propertyLabel = property.value ? property.selectedOptions[0].textContent : 'No property selected';
  const relationshipLabel = relationship.selectedOptions[0].textContent;
  const card = document.createElement('article');
  card.className = 'join-request-card';
  const details = document.createElement('div');
  const heading = document.createElement('strong');
  heading.textContent = estateLabel;
  const propertyLine = document.createElement('span');
  propertyLine.textContent = `${propertyLabel} · ${relationshipLabel}`;
  const reference = document.createElement('small');
  reference.textContent = `Submitted just now · JR-${String(Date.now()).slice(-6)}${proofFile ? ` · ${proofFile.name} selected` : ''}`;
  details.append(heading, propertyLine, reference);
  const status = document.createElement('span');
  status.className = 'mini-status status-review';
  status.textContent = 'Pending review';
  card.append(details, status);
  const requests = document.getElementById('residentJoinRequests');
  requests.querySelector('.join-request-empty')?.remove();
  requests.prepend(card);
  closeJoinRequest();
  note.value = '';
  proof.value = '';
  error.textContent = '';
  residentMessage('Join request added to this preview only.');
}

function localDateTimeValue(date) {
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

function openVisitorPass() {
  const from = new Date(Date.now() + 30 * 60 * 1000);
  from.setSeconds(0, 0);
  const until = new Date(from.getTime() + 60 * 60 * 1000);
  document.getElementById('visitorPassName').value = '';
  document.getElementById('visitorPassFrom').value = localDateTimeValue(from);
  document.getElementById('visitorPassUntil').value = localDateTimeValue(until);
  document.getElementById('visitorPassVehicleEnabled').checked = false;
  document.getElementById('visitorPassVehicle').value = '';
  document.getElementById('visitorVehicleField').classList.add('hidden');
  document.getElementById('visitorPassError').textContent = '';
  document.getElementById('visitorPassFormPanel').classList.remove('hidden');
  document.getElementById('visitorPassResult').classList.add('hidden');
  document.getElementById('visitorPassCredential').textContent = '';
  visitorPassModal.classList.remove('hidden');
  document.getElementById('visitorPassName').focus();
}

function closeVisitorPass() {
  visitorPassModal.classList.add('hidden');
  document.getElementById('visitorPassCredential').textContent = '';
}

function createVisitorPassPreview() {
  const name = document.getElementById('visitorPassName').value.trim();
  const fromValue = document.getElementById('visitorPassFrom').value;
  const untilValue = document.getElementById('visitorPassUntil').value;
  const includeVehicle = document.getElementById('visitorPassVehicleEnabled').checked;
  const vehicle = document.getElementById('visitorPassVehicle').value.trim();
  const error = document.getElementById('visitorPassError');
  const from = new Date(fromValue);
  const until = new Date(untilValue);
  if (!name) { error.textContent = 'Enter your visitor’s name.'; return; }
  if (!fromValue || !untilValue || Number.isNaN(from.getTime()) || Number.isNaN(until.getTime())
    || from.getTime() < Date.now() || until <= from) {
    error.textContent = 'Choose a future start time and an end time after it.';
    return;
  }
  const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const random = new Uint8Array(12);
  window.crypto.getRandomValues(random);
  const credential = Array.from(random, (value) => characters[value % characters.length]).join('');
  const localeOptions = { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' };
  const windowLabel = `${from.toLocaleString('en-NG', localeOptions)} – ${until.toLocaleTimeString('en-NG', { hour: 'numeric', minute: '2-digit' })}`;
  const card = document.createElement('article');
  card.className = 'mobile-list-card visitor-record visitor-preview-record';
  card.dataset.previewPass = 'active';
  const avatar = document.createElement('span');
  avatar.className = 'visitor-record-avatar visitor-violet';
  avatar.textContent = name.split(/\s+/).slice(0, 2).map((part) => part[0].toUpperCase()).join('');
  const copy = document.createElement('div');
  copy.className = 'mobile-list-copy';
  const visitorName = document.createElement('strong');
  visitorName.textContent = name;
  const visitWindow = document.createElement('small');
  visitWindow.textContent = windowLabel;
  const detail = document.createElement('b');
  detail.textContent = includeVehicle && vehicle ? `Single entry · ${vehicle}` : 'Single entry · No vehicle';
  copy.append(visitorName, visitWindow, detail);
  const status = document.createElement('span');
  status.className = 'mini-status status-review';
  status.textContent = 'Preview pass';
  const revoke = document.createElement('button');
  revoke.type = 'button';
  revoke.className = 'visitor-preview-revoke';
  revoke.dataset.action = 'revoke-pass-preview';
  revoke.textContent = 'Revoke';
  card.append(avatar, copy, status, revoke);
  document.getElementById('residentVisitorList').prepend(card);
  document.getElementById('visitorPassResultSummary').textContent = `${name} · ${windowLabel} · Oakwood 01`;
  document.getElementById('visitorPassCredential').textContent = credential;
  document.getElementById('visitorPassFormPanel').classList.add('hidden');
  document.getElementById('visitorPassResult').classList.remove('hidden');
}

async function copyVisitorPassPreview() {
  const credential = document.getElementById('visitorPassCredential').textContent;
  if (!credential) return;
  try {
    await navigator.clipboard.writeText(credential);
    residentMessage('Demo code copied. It does not grant entry in this preview.');
  } catch {
    residentMessage('Select and copy the demo code manually. It does not grant entry in this preview.');
  }
}

function revokeVisitorPassPreview(button) {
  const card = button.closest('[data-preview-pass="active"]');
  if (!card || !window.confirm('Revoke this preview pass?')) return;
  card.dataset.previewPass = 'revoked';
  const status = card.querySelector('.mini-status');
  status.className = 'mini-status status-due';
  status.textContent = 'Revoked';
  button.remove();
  residentMessage('Pass revoked in this page preview only.');
}

function showResidentScreen(screen) {
  document.querySelectorAll('.resident-view').forEach((view) => {
    view.classList.toggle('hidden', view.dataset.screen !== screen);
    view.classList.toggle('active', view.dataset.screen === screen);
  });
  document.querySelectorAll('.bottom-nav [data-tab]').forEach((tab) => {
    const activeTab = screen === 'amenities' || screen === 'announcements' || screen === 'estate-map' ? 'home'
      : screen === 'landlord' ? 'profile'
        : screen === 'incidents' ? 'requests'
          : screen;
    tab.classList.toggle('active', tab.dataset.tab === activeTab);
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

const residentMapPlaces = {
  home: { type: 'YOUR PROPERTY', name: 'Oakwood · 01', description: 'Your linked home · Oakwood Drive, North Gardens', meta: 'Detached house · OW-001' },
  gate: { type: 'ESTATE ACCESS', name: 'Main gate', description: 'Primary vehicle and visitor entrance · Oakwood Drive', meta: 'Estate access point' },
  hall: { type: 'SHARED FACILITY', name: 'Community hall', description: 'Oakwood clubhouse · North Gardens', meta: 'Resident facility' },
  court: { type: 'SHARED FACILITY', name: 'Tennis court', description: 'Oakwood central park · Maple Phase', meta: 'Resident facility' }
};

function selectResidentMapPlace(marker) {
  const place = residentMapPlaces[marker.dataset.mapPlace];
  if (!place) return;
  document.querySelectorAll('[data-map-place]').forEach((item) => item.classList.toggle('selected', item === marker));
  document.getElementById('residentMapPlaceType').textContent = place.type;
  document.getElementById('residentMapPlaceName').textContent = place.name;
  document.getElementById('residentMapPlaceDescription').textContent = place.description;
  document.getElementById('residentMapPlaceMeta').textContent = place.meta;
}

function residentMessage(message) {
  residentToast.textContent = message;
  residentToast.classList.add('show');
  window.clearTimeout(toastTimeout);
  toastTimeout = window.setTimeout(() => residentToast.classList.remove('show'), 2600);
}
window.showResidentMessage = residentMessage;

document.getElementById('residentRequestFilter').addEventListener('change', (event) => {
  filterResidentMaintenance(event.target.value);
});
document.getElementById('residentInvoiceFilter')?.addEventListener('change', (event) => {
  filterResidentInvoices(event.target.value);
});

document.addEventListener('click', (event) => {
  const tab = event.target.closest('[data-tab]');
  if (tab) {
    showResidentScreen(tab.dataset.tab);
    return;
  }

  const screenLink = event.target.closest('[data-screen-link]');
  if (screenLink) {
    showResidentScreen(screenLink.dataset.screenLink);
    return;
  }

  const mapMarker = event.target.closest('[data-map-place]');
  if (mapMarker) {
    selectResidentMapPlace(mapMarker);
    return;
  }

  const noticeFilter = event.target.closest('[data-notice-filter]');
  if (noticeFilter) {
    document.querySelectorAll('[data-notice-filter]').forEach((filter) => filter.classList.toggle('active', filter === noticeFilter));
    document.querySelectorAll('[data-notice-type]').forEach((notice) => {
      notice.classList.toggle('hidden', noticeFilter.dataset.noticeFilter === 'important' && notice.dataset.noticeType !== 'important');
    });
    return;
  }

  const amenityFilter = event.target.closest('[data-amenity-filter]');
  if (amenityFilter) {
    document.querySelectorAll('[data-amenity-filter]').forEach((filter) => filter.classList.toggle('active', filter === amenityFilter));
    if (typeof window.setResidentAmenityFilter === 'function') {
      window.setResidentAmenityFilter(amenityFilter.dataset.amenityFilter);
      return;
    }
    residentMessage(amenityFilter.dataset.amenityFilter === 'available'
      ? 'Showing facilities with available time slots.'
      : 'Showing all estate facilities.');
    return;
  }

  const amenitySlot = event.target.closest('[data-slot]');
  if (amenitySlot) {
    amenitySlot.closest('.amenity-card').querySelectorAll('[data-slot]').forEach((slot) => {
      const selected = slot === amenitySlot;
      slot.classList.toggle('selected', selected);
      slot.setAttribute('aria-pressed', String(selected));
    });
    return;
  }

  const action = event.target.closest('[data-action]');
  if (!action) return;

  if (action.dataset.action === 'pay-now' || action.dataset.action === 'invoice-details') {
    if (typeof window.openResidentInvoice === 'function') {
      window.openResidentInvoice(action.dataset.invoiceId || '');
      return;
    }
    invoiceDetailModal.classList.remove('hidden');
    return;
  }
  if (action.dataset.action === 'open-join-request') {
    document.getElementById('joinEstate').value = '';
    document.getElementById('joinRelationship').value = '';
    document.getElementById('joinRequestNote').value = '';
    document.getElementById('joinProofReference').value = '';
    document.getElementById('joinRequestError').textContent = '';
    updateJoinPropertyOptions();
    window.populateResidentJoinOptions?.();
    joinRequestModal.classList.remove('hidden');
    document.getElementById('joinEstate').focus();
    return;
  }
  if (action.dataset.action === 'close-join-request') {
    closeJoinRequest();
    return;
  }
  if (action.dataset.action === 'submit-join-request') {
    if (typeof window.submitResidentJoinRequest === 'function') {
      window.submitResidentJoinRequest();
      return;
    }
    submitJoinRequestPreview();
    return;
  }
  if (action.dataset.action === 'review-staff-invitation') {
    if (document.getElementById('residentStaffInvitation').dataset.invitationState === 'pending') {
      staffInvitationModal.classList.remove('hidden');
      document.querySelector('[data-action="accept-staff-invitation"]').focus();
    }
    return;
  }
  if (action.dataset.action === 'close-staff-invitation') {
    closeStaffInvitation();
    return;
  }
  if (action.dataset.action === 'accept-staff-invitation') {
    decideStaffInvitationPreview('accepted');
    return;
  }
  if (action.dataset.action === 'decline-staff-invitation') {
    decideStaffInvitationPreview('declined');
    return;
  }
  if (action.dataset.action === 'close-invoice') {
    closeInvoiceDetails();
    return;
  }
  if (action.dataset.action === 'view-payment-history') {
    const history = document.getElementById('residentPaymentHistory');
    history.classList.toggle('hidden');
    if (!history.classList.contains('hidden')) history.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    return;
  }
  if (action.dataset.action === 'receipt-detail') {
    if (typeof window.openResidentReceipt === 'function') {
      window.openResidentReceipt(action.dataset.receiptId || '');
      return;
    }
    openReceiptDetail(action.dataset.receiptId);
    return;
  }
  if (action.dataset.action === 'map-directions') {
    const selected = document.getElementById('residentMapPlaceName').textContent;
    residentMessage(`${selected}: use the estate address in your preferred navigation app. No device location is collected here.`);
    return;
  }
  if (action.dataset.action === 'close-receipt') {
    closeReceiptDetail();
    return;
  }
  if (action.dataset.action === 'begin-payment') {
    if (typeof window.beginResidentInvoicePayment === 'function') {
      window.beginResidentInvoicePayment();
      return;
    }
    closeInvoiceDetails();
    residentMessage('Payment initiation is not connected in this preview. A live payment status must come from Zvend confirmation.');
    return;
  }
  if (action.dataset.action === 'check-payment-status') {
    if (typeof window.refreshResidentPaymentAttempt === 'function') window.refreshResidentPaymentAttempt();
    return;
  }
  if (action.dataset.action === 'create-pass') {
    openVisitorPass();
    return;
  }
  if (action.dataset.action === 'close-pass') {
    closeVisitorPass();
    return;
  }
  if (action.dataset.action === 'close-visitor-revoke') {
    document.getElementById('visitorRevokeModal').classList.add('hidden');
    return;
  }
  if (action.dataset.action === 'issue-pass-preview') {
    if (typeof window.submitResidentVisitorPass === 'function') {
      window.submitResidentVisitorPass();
      return;
    }
    createVisitorPassPreview();
    return;
  }
  if (action.dataset.action === 'copy-pass-preview') {
    if (typeof window.copyResidentVisitorCredential === 'function') {
      window.copyResidentVisitorCredential();
      return;
    }
    copyVisitorPassPreview();
    return;
  }
  if (action.dataset.action === 'open-visitor-revoke') {
    if (typeof window.openResidentVisitorRevoke === 'function') {
      window.openResidentVisitorRevoke(action.dataset.passId || '');
      return;
    }
  }
  if (action.dataset.action === 'confirm-visitor-revoke') {
    if (typeof window.submitResidentVisitorRevocation === 'function') {
      window.submitResidentVisitorRevocation();
      return;
    }
  }
  if (action.dataset.action === 'revoke-pass-preview') {
    revokeVisitorPassPreview(action);
    return;
  }
  if (action.dataset.action === 'new-request') {
    document.getElementById('requestCategory').value = 'Plumbing';
    document.getElementById('requestPriority').value = 'Normal';
    document.getElementById('requestDescription').value = '';
    maintenanceRequestModal.classList.remove('hidden');
    document.getElementById('requestDescription').focus();
    return;
  }
  if (action.dataset.action === 'request-detail') {
    if (typeof window.showResidentMaintenanceDetail === 'function') {
      window.showResidentMaintenanceDetail(action.dataset.requestId);
      return;
    }
    renderMaintenanceDetail(action.dataset.requestId);
    return;
  }
  if (action.dataset.action === 'local-request-detail') {
    residentMessage('This request exists only in the current page preview and was not sent or stored.');
    return;
  }
  if (action.dataset.action === 'close-request-detail') {
    closeMaintenanceDetail();
    return;
  }
  if (action.dataset.action === 'confirm-resolution') {
    residentMessage('Thanks for confirming. Confirmation is preview only and was not sent to the estate team.');
    closeMaintenanceDetail();
    return;
  }
  if (action.dataset.action === 'reopen-request') {
    residentMessage('A reopen request requires a reason and will be submitted to the estate team when connected.');
    return;
  }
  if (action.dataset.action === 'new-incident') {
    document.getElementById('incidentCategory').value = 'security_concern';
    document.getElementById('incidentLocation').value = '';
    document.getElementById('incidentDescription').value = '';
    if (document.getElementById('incidentObservedAt')) {
      document.getElementById('incidentObservedAt').value = localDateTimeValue(new Date());
    }
    document.getElementById('incidentReportError').textContent = '';
    incidentReportModal.classList.remove('hidden');
    document.getElementById('incidentLocation').focus();
    return;
  }
  if (action.dataset.action === 'close-incident') {
    closeIncidentReport();
    return;
  }
  if (action.dataset.action === 'submit-incident') {
    if (typeof window.submitResidentIncidentReport === 'function') {
      window.submitResidentIncidentReport();
      return;
    }
    const location = document.getElementById('incidentLocation').value.trim();
    const description = document.getElementById('incidentDescription').value.trim();
    if (!location || !description) {
      residentMessage('Add a location and describe what happened.');
      document.getElementById(!location ? 'incidentLocation' : 'incidentDescription').focus();
      return;
    }
    const card = document.createElement('article');
    card.className = 'request-card local-request-preview';
    const top = document.createElement('div');
    top.className = 'request-card-top';
    const mark = document.createElement('span');
    mark.className = 'request-kind electrical-kind';
    mark.textContent = '!';
    const status = document.createElement('span');
    status.className = 'mini-status status-review';
    status.textContent = 'Local preview';
    top.append(mark, status);
    const title = document.createElement('strong');
    title.textContent = document.getElementById('incidentCategory').selectedOptions[0].textContent;
    const body = document.createElement('p');
    body.textContent = `${location} · ${description}`;
    const meta = document.createElement('div');
    meta.className = 'request-meta';
    const ref = document.createElement('span');
    ref.textContent = 'LOCAL PREVIEW';
    const note = document.createElement('span');
    note.textContent = 'Not sent';
    meta.append(ref, note);
    card.append(top, title, body, meta);
    document.getElementById('residentIncidentList').prepend(card);
    closeIncidentReport();
    showResidentScreen('incidents');
    residentMessage('Incident added to this preview only.');
    return;
  }
  if (action.dataset.action === 'close-request') {
    closeMaintenanceRequest();
    return;
  }
  if (action.dataset.action === 'submit-request') {
    if (typeof window.submitResidentMaintenanceRequest === 'function') {
      window.submitResidentMaintenanceRequest();
      return;
    }
    const description = document.getElementById('requestDescription').value.trim();
    if (!description) {
      residentMessage('Describe the issue before submitting your request.');
      document.getElementById('requestDescription').focus();
      return;
    }
    const category = document.getElementById('requestCategory').value;
    const priority = document.getElementById('requestPriority').value;
    const request = document.createElement('article');
    request.className = 'request-card resident-maintenance-card local-request-preview';
    request.dataset.requestStatus = 'review';
    const button = document.createElement('button');
    button.className = 'request-card-button';
    button.dataset.action = 'local-request-detail';
    button.type = 'button';
    const top = document.createElement('span');
    top.className = 'request-card-top';
    const mark = document.createElement('span');
    mark.className = 'request-kind plumbing-kind';
    mark.textContent = category.slice(0, 1);
    const badge = document.createElement('span');
    badge.className = 'mini-status status-review';
    badge.textContent = 'Preview only';
    top.append(mark, badge);
    const heading = document.createElement('strong');
    heading.textContent = `${category} request`;
    const body = document.createElement('span');
    body.className = 'request-card-description';
    body.textContent = description;
    const meta = document.createElement('span');
    meta.className = 'request-meta';
    const ref = document.createElement('span');
    ref.textContent = 'LOCAL PREVIEW · Oakwood · 01';
    const state = document.createElement('span');
    state.textContent = 'Submitted just now';
    meta.append(ref, state);
    const priorityLabel = document.createElement('span');
    priorityLabel.className = 'local-request-state';
    priorityLabel.textContent = `${priority} priority · not sent to estate team`;
    button.append(top, heading, body, meta, priorityLabel);
    request.append(button);
    document.getElementById('residentMaintenanceList').prepend(request);
    const filter = document.getElementById('residentRequestFilter');
    filter.value = 'open';
    filterResidentMaintenance('open');
    closeMaintenanceRequest();
    residentMessage('Request added to this preview only.');
    return;
  }
  if (action.dataset.action === 'close-booking') {
    closeFacilityBooking();
    return;
  }
  if (action.dataset.action === 'submit-booking') {
    if (typeof window.submitResidentFacilityBooking === 'function') {
      window.submitResidentFacilityBooking();
      return;
    }
    if (!pendingBooking) return;
    const count = Number(document.getElementById('bookingAttendees').value);
    if (!Number.isInteger(count) || count < 1 || count > pendingBooking.capacity) {
      residentMessage(`Enter an attendee count from 1 to ${pendingBooking.capacity}.`);
      document.getElementById('bookingAttendees').focus();
      return;
    }
    const preview = document.getElementById('residentBookingPreview');
    preview.classList.remove('hidden');
    const card = document.createElement('article');
    card.className = 'resident-booking-confirmation';
    const copy = document.createElement('div');
    const title = document.createElement('strong');
    title.textContent = pendingBooking.facility;
    const time = document.createElement('small');
    const purpose = document.getElementById('bookingPurpose').value.trim();
    time.textContent = `${pendingBooking.slot} · ${count} attendee${count === 1 ? '' : 's'}${purpose ? ` · ${purpose}` : ''}`;
    copy.append(title, time);
    const status = document.createElement('span');
    status.className = 'mini-status status-review';
    status.textContent = 'Request preview';
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.className = 'booking-preview-remove';
    cancel.dataset.action = 'cancel-booking-preview';
    cancel.textContent = 'Remove';
    card.append(copy, status, cancel);
    preview.prepend(card);
    closeFacilityBooking();
    residentMessage('Booking request added to this preview only. The live service must recheck availability.');
    return;
  }
  if (action.dataset.action === 'cancel-booking-preview') {
    action.closest('.resident-booking-confirmation').remove();
    const preview = document.getElementById('residentBookingPreview');
    if (!preview.querySelector('.resident-booking-confirmation')) preview.classList.add('hidden');
    return;
  }

  const messages = {
    notifications: 'Your estate notifications will appear here.',
    'estate-select': 'Estate switching will show estates linked to your Zvend account.',
    'existing-electricity': 'In the live app, this opens Zvend’s existing electricity vending service. Estate Management does not create a separate meter or wallet.',
    'pay-now': 'Payment will open the verified Zvend payment flow.',
    emergency: 'Contact your estate security desk using the verified number in your estate directory.',
    'read-announcement': 'Announcement details will open here.',
    'invoice-filter': 'Invoice filters will use your estate and property permissions.',
    'download-receipts': 'Receipts will be retrieved securely from your payment history.',
    'pass-options': 'You can revoke a pass that has not been used.',
    'new-request': 'A new maintenance request will be submitted to your estate team.',
    'request-filter': 'Request filters will show your own property requests.',
    'add-household': 'Household member access requires estate review.',
    documents: 'Property documents are private and require an authorized access link.',
    'notifications-settings': 'Notification preferences will be managed in your Zvend account.',
    support: 'Estate support contacts will appear here.',
    'landlord-property-list': 'The full property portfolio will use properties linked to your verified landlord membership.',
    'landlord-documents': 'Property documents require an authorized private file link from the estate service.',
    'landlord-charges': 'Property charges will show invoices for properties you own or are authorized to manage.',
    'landlord-tenancy': 'Tenancy agreements will open through a private, permission-checked document service.',
    'landlord-rent-history': 'Rent history will use verified payment allocations and the properties linked to your account.'
  };
  if (action.dataset.action === 'book-facility') {
    const selectedSlot = action.closest('.amenity-card').querySelector('[data-slot].selected');
    if (!selectedSlot) {
      residentMessage('Choose an available time before requesting a booking.');
      return;
    }
    if (typeof window.openResidentFacilityBooking === 'function' && action.dataset.facilityId) {
      window.openResidentFacilityBooking({
        facilityId: action.dataset.facilityId,
        startsAt: selectedSlot.dataset.startsAt,
        endsAt: selectedSlot.dataset.endsAt,
        policyVersion: selectedSlot.dataset.policyVersion,
      });
      return;
    }
    pendingBooking = {
      facility: action.dataset.facility,
      slot: selectedSlot.dataset.slot,
      capacity: action.dataset.facility === 'Tennis court' ? 4 : 80
    };
    document.getElementById('bookingSlotSummary').textContent = `${pendingBooking.facility} · ${pendingBooking.slot}`;
    document.getElementById('bookingAttendees').value = '1';
    document.getElementById('bookingAttendees').max = String(pendingBooking.capacity);
    document.getElementById('bookingPurpose').value = '';
    facilityBookingModal.classList.remove('hidden');
    return;
  }
  residentMessage(messages[action.dataset.action] || 'This action will connect to the estate service.');
});

invoiceDetailModal.addEventListener('click', (event) => {
  if (event.target === invoiceDetailModal) closeInvoiceDetails();
});
receiptDetailModal.addEventListener('click', (event) => {
  if (event.target === receiptDetailModal) closeReceiptDetail();
});
maintenanceRequestModal.addEventListener('click', (event) => {
  if (event.target === maintenanceRequestModal) closeMaintenanceRequest();
});
maintenanceDetailModal.addEventListener('click', (event) => {
  if (event.target === maintenanceDetailModal) closeMaintenanceDetail();
});
facilityBookingModal.addEventListener('click', (event) => {
  if (event.target === facilityBookingModal) closeFacilityBooking();
});
incidentReportModal.addEventListener('click', (event) => {
  if (event.target === incidentReportModal) closeIncidentReport();
});
joinRequestModal.addEventListener('click', (event) => {
  if (event.target === joinRequestModal) closeJoinRequest();
});
staffInvitationModal.addEventListener('click', (event) => {
  if (event.target === staffInvitationModal) closeStaffInvitation();
});
document.getElementById('joinEstate').addEventListener('change', updateJoinPropertyOptions);
visitorPassModal.addEventListener('click', (event) => {
  if (event.target === visitorPassModal) closeVisitorPass();
});
document.getElementById('visitorRevokeModal').addEventListener('click', (event) => {
  if (event.target === event.currentTarget) event.currentTarget.classList.add('hidden');
});
document.getElementById('visitorPassVehicleEnabled').addEventListener('change', (event) => {
  document.getElementById('visitorVehicleField').classList.toggle('hidden', !event.target.checked);
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closeInvoiceDetails();
    closeReceiptDetail();
    closeMaintenanceRequest();
    closeMaintenanceDetail();
    closeFacilityBooking();
    closeIncidentReport();
    closeJoinRequest();
    closeStaffInvitation();
    closeVisitorPass();
  }
});
