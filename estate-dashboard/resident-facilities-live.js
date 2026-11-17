(() => {
  const config = () => window.ZvendEstateConfig || {};
  const estateId = () => config().currentEstateId == null ? '' : String(config().currentEstateId);
  const apiBase = () => typeof config().apiBaseUrl === 'string' ? config().apiBaseUrl.replace(/\/$/, '') : '';
  const endpoint = (custom, fallback, params = {}) => {
    let path = typeof custom === 'string' && custom.trim() ? custom.trim() : fallback;
    if (!path) return '';
    for (const [key, value] of Object.entries(params)) {
      const encoded = encodeURIComponent(String(value));
      path = path.replaceAll(`{${key}}`, encoded).replaceAll(`:${key}`, encoded);
    }
    return path;
  };
  const facilitiesUrl = () => endpoint(config().residentFacilitiesUrl, apiBase() ? `${apiBase()}/api/estate/facilities` : '', { estateId: estateId() });
  const availabilityUrl = (id) => endpoint(config().residentFacilityAvailabilityUrl,
    apiBase() ? `${apiBase()}/api/estate/facilities/{facilityId}/availability` : '', { estateId: estateId(), facilityId: id });
  const bookingsUrl = () => endpoint(config().residentFacilityBookingsUrl,
    apiBase() ? `${apiBase()}/api/estate/facility-bookings/mine` : '', { estateId: estateId() });
  const bookingUrl = (id) => endpoint(config().residentFacilityBookingUrl,
    apiBase() ? `${apiBase()}/api/estate/facilities/{facilityId}/bookings` : '', { estateId: estateId(), facilityId: id });
  if (!estateId() || !facilitiesUrl() || !availabilityUrl('__facility__') || !bookingsUrl() || !bookingUrl('__facility__')) return;

  const section = document.querySelector('[data-screen="amenities"]');
  const liveTools = document.getElementById('residentFacilityLiveTools');
  const dateInput = document.getElementById('residentFacilityDate');
  const facilityStatus = document.getElementById('residentFacilityStatus');
  const bookingSection = document.getElementById('residentMyBookings');
  const bookingStatus = document.getElementById('residentMyBookingsStatus');
  const bookingList = document.getElementById('residentMyBookingsList');
  const modal = document.getElementById('facilityBookingModal');
  const submitButton = modal.querySelector('[data-action="submit-booking"]');
  const formNote = modal.querySelector('.resident-form-preview');
  const state = { generation: 0, facilities: [], slots: new Map(), pending: null, pendingKey: '', filter: 'all' };
  let active = true;

  function safeUrl(path) {
    const url = new URL(path, window.location.href);
    if (url.origin !== window.location.origin) throw new Error('Estate services must use the authenticated same-origin host.');
    return url;
  }
  async function request(path, method = 'GET', payload, headers = {}) {
    const url = safeUrl(path).toString();
    const options = { Accept: 'application/json', ...(payload === undefined ? {} : { 'Content-Type': 'application/json' }), ...headers };
    let response;
    if (typeof config().request === 'function') {
      response = await config().request({ url, method, payload, headers: options, credentials: 'same-origin' });
    } else {
      const result = await fetch(url, {
        method, credentials: 'same-origin', headers: options,
        ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
      });
      if (!result.ok) {
        let body = null;
        try { body = await result.json(); } catch {}
        const error = new Error(body?.error?.message || body?.message || 'Estate facilities could not be loaded.');
        error.status = result.status;
        error.code = body?.error?.code || body?.code || '';
        throw error;
      }
      response = result.status === 204 ? null : await result.json();
    }
    if (typeof Response !== 'undefined' && response instanceof Response) {
      if (!response.ok) {
        let body = null;
        try { body = await response.json(); } catch {}
        const error = new Error(body?.error?.message || body?.message || 'Estate facilities could not be loaded.');
        error.status = response.status;
        error.code = body?.error?.code || body?.code || '';
        throw error;
      }
      response = response.status === 204 ? null : await response.json();
    }
    return response?.data ?? response;
  }
  function id(value) { return ['string', 'number'].includes(typeof value) && String(value).trim() !== ''
    && (typeof value !== 'number' || Number.isFinite(value)); }
  function timestamp(value) {
    if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) return false;
    return new Date(value).toISOString() === value;
  }
  function zoneDate(timezone, date = new Date()) {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${values.year}-${values.month}-${values.day}`;
  }
  function zoneTime(value, timezone) {
    return new Intl.DateTimeFormat(undefined, { timeZone: timezone, hour: 'numeric', minute: '2-digit' }).format(new Date(value));
  }
  function formatFee(fee) {
    if (!fee) return 'No booking fee';
    try {
      const [whole, fraction = ''] = fee.amount.split('.');
      const formatter = new Intl.NumberFormat(undefined, {
        style: 'currency', currency: fee.currency,
        minimumFractionDigits: fee.currencyScale, maximumFractionDigits: fee.currencyScale,
      });
      const localDigits = new Intl.NumberFormat(undefined, { useGrouping: false });
      const localFraction = [...fraction.padEnd(fee.currencyScale, '0')]
        .map((digit) => localDigits.format(Number(digit))).join('');
      return formatter.formatToParts(BigInt(whole)).map((part) => part.type === 'fraction' ? localFraction : part.value).join('');
    }
    catch { return `${fee.currency} ${fee.amount}`; }
  }
  function setStatus(message, kind = 'ready') {
    facilityStatus.textContent = message;
    facilityStatus.dataset.state = kind;
    facilityStatus.setAttribute('role', kind === 'error' ? 'alert' : 'status');
  }
  function facilityResponseValid(result, expectedEstate) {
    const fields = new Set(['facilityId', 'estateId', 'name', 'description', 'locationLabel', 'capacity', 'durationMinutes', 'maximumBookingWindowDays', 'policyVersion', 'policySummary', 'timezone', 'approvalMode', 'fee']);
    return Boolean(result && id(result.facilityId) && String(result.estateId) === expectedEstate
      && Object.keys(result).every((key) => fields.has(key))
      && typeof result.name === 'string' && result.name.trim() && result.name.length <= 120
      && (result.description === null || typeof result.description === 'string' && result.description.length <= 300)
      && (result.locationLabel === null || typeof result.locationLabel === 'string' && result.locationLabel.length <= 160)
      && Number.isSafeInteger(result.capacity) && result.capacity > 0 && result.capacity <= 10000
      && Number.isSafeInteger(result.durationMinutes) && result.durationMinutes > 0
      && Number.isInteger(result.maximumBookingWindowDays) && result.maximumBookingWindowDays >= 0 && result.maximumBookingWindowDays <= 365
      && typeof result.policyVersion === 'string' && result.policyVersion.trim() && result.policyVersion.length <= 100
      && typeof result.policySummary === 'string' && result.policySummary.trim() && result.policySummary.length <= 1000
      && typeof result.timezone === 'string' && (() => { try { new Intl.DateTimeFormat('en', { timeZone: result.timezone }); return true; } catch { return false; } })()
      && ['automatic', 'manual'].includes(result.approvalMode)
      && (result.fee === null || result.fee && typeof result.fee === 'object'
        && Object.keys(result.fee).every((key) => ['amount', 'currency', 'currencyScale'].includes(key))
        && typeof result.fee.amount === 'string' && /^\d+(?:\.\d+)?$/.test(result.fee.amount)
        && /^[A-Z]{3}$/.test(result.fee.currency) && Number.isInteger(result.fee.currencyScale)
        && result.fee.currencyScale >= 0 && result.fee.currencyScale <= 6));
  }
  function feeMatches(a, b) {
    if (a === null || b === null) return a === b;
    return Boolean(a && b && a.amount === b.amount && a.currency === b.currency && a.currencyScale === b.currencyScale);
  }
  function slotResponseValid(result, facility, date, expectedEstate) {
    const fields = new Set(['estateId', 'facilityId', 'date', 'timezone', 'policyVersion', 'asOf', 'items']);
    if (!result || Object.keys(result).some((key) => !fields.has(key)) || String(result.estateId) !== expectedEstate
      || String(result.facilityId) !== String(facility.facilityId) || result.date !== date
      || result.timezone !== facility.timezone || result.policyVersion !== facility.policyVersion
      || !timestamp(result.asOf) || !Array.isArray(result.items) || result.items.length > 100) return false;
    const seen = new Set();
    return result.items.every((slot) => {
      const slotFields = new Set(['startsAt', 'endsAt', 'remainingCapacity', 'policyVersion', 'fee']);
      const key = `${slot?.startsAt}/${slot?.endsAt}`;
      if (!slot || Object.keys(slot).some((field) => !slotFields.has(field)) || !timestamp(slot.startsAt) || !timestamp(slot.endsAt)
        || Date.parse(slot.startsAt) <= Date.parse(result.asOf) || Date.parse(slot.endsAt) <= Date.parse(slot.startsAt)
        || zoneDate(facility.timezone, new Date(slot.startsAt)) !== date
        || Date.parse(slot.endsAt) - Date.parse(slot.startsAt) > facility.durationMinutes * 60000
        || slot.policyVersion !== facility.policyVersion || !Number.isSafeInteger(slot.remainingCapacity)
        || slot.remainingCapacity < 1 || slot.remainingCapacity > facility.capacity
        || slot.fee !== null && slot.fee && Object.keys(slot.fee).some((field) => !['amount', 'currency', 'currencyScale'].includes(field))
        || !feeMatches(slot.fee, facility.fee) || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
  function statusLabel(value) {
    return ({ requested: 'Requested', pending_review: 'Awaiting review', pending_payment: 'Payment required', confirmed: 'Confirmed', declined: 'Declined', expired: 'Expired', cancelled: 'Cancelled', completed: 'Completed' })[value] || 'Status unavailable';
  }
  function statusClass(value) {
    return ['confirmed', 'completed'].includes(value) ? 'status-checked' : ['declined', 'cancelled', 'expired'].includes(value) ? 'status-review' : 'status-review';
  }
  function buildBookingCard(item) {
    const card = document.createElement('article');
    card.className = 'resident-booking-confirmation';
    const copy = document.createElement('div');
    const name = document.createElement('strong'); name.textContent = item.facilityLabel;
    const time = document.createElement('small');
    const start = new Date(item.startsAt);
    time.textContent = `${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeZone: item.timezone }).format(start)} · ${zoneTime(item.startsAt, item.timezone)}–${zoneTime(item.endsAt, item.timezone)} · ${item.attendeeCount} attendee${item.attendeeCount === 1 ? '' : 's'}`;
    const location = document.createElement('small');
    if (item.locationLabel) location.textContent = item.locationLabel;
    copy.append(name, time);
    if (location.textContent) copy.append(location);
    const badge = document.createElement('span'); badge.className = `mini-status ${statusClass(item.status)}`; badge.textContent = statusLabel(item.status);
    card.append(copy, badge);
    if (item.fee) {
      const fee = document.createElement('small'); fee.className = 'resident-booking-fee'; fee.textContent = formatFee(item.fee);
      card.append(fee);
    }
    return card;
  }
  function renderBookings(items) {
    bookingList.replaceChildren();
    bookingSection.classList.remove('hidden');
    if (!items.length) {
      const empty = document.createElement('p'); empty.className = 'resident-booking-empty'; empty.textContent = 'You have no facility bookings in this estate.';
      bookingList.append(empty);
      return;
    }
    items.forEach((item) => bookingList.append(buildBookingCard(item)));
  }
  async function loadBookings(generation = state.generation) {
    bookingStatus.textContent = 'Loading your bookings…';
    try {
      const result = await request(bookingsUrl());
      if (generation !== state.generation || !active) return;
      const allowed = new Set(['bookingId', 'estateId', 'facilityId', 'facilityLabel', 'locationLabel', 'timezone', 'startsAt', 'endsAt', 'attendeeCount', 'status', 'policyVersion', 'feeInvoiceId', 'fee']);
      if (!result || String(result.estateId) !== estateId() || !Array.isArray(result.items) || result.items.length > 100
        || result.items.some((item) => !item || Object.keys(item).some((key) => !allowed.has(key))
          || !id(item.bookingId) || String(item.estateId) !== estateId() || !id(item.facilityId)
          || typeof item.facilityLabel !== 'string' || !item.facilityLabel.trim() || item.facilityLabel.length > 160
          || !(item.locationLabel === null || typeof item.locationLabel === 'string' && item.locationLabel.length <= 160)
          || typeof item.timezone !== 'string'
          || !timestamp(item.startsAt) || !timestamp(item.endsAt) || Date.parse(item.endsAt) <= Date.parse(item.startsAt)
          || !Number.isSafeInteger(item.attendeeCount) || item.attendeeCount < 1
          || !['requested', 'pending_review', 'pending_payment', 'confirmed', 'declined', 'expired', 'cancelled', 'completed'].includes(item.status)
          || typeof item.policyVersion !== 'string' || !item.policyVersion.trim()
          || !(item.feeInvoiceId === null || id(item.feeInvoiceId))
          || !(item.fee === null || item.fee && Object.keys(item.fee).every((key) => ['amount', 'currency', 'currencyScale'].includes(key))
            && typeof item.fee.amount === 'string' && /^[A-Z]{3}$/.test(item.fee.currency)
            && Number.isInteger(item.fee.currencyScale) && item.fee.currencyScale >= 0 && item.fee.currencyScale <= 6))) {
        throw new Error('Invalid booking list');
      }
      const seen = new Set();
      if (result.items.some((item) => { const value = String(item.bookingId); if (seen.has(value)) return true; seen.add(value); return false; })) throw new Error('Duplicate booking');
      renderBookings(result.items);
      bookingStatus.textContent = '';
    } catch {
      if (generation !== state.generation || !active) return;
      bookingStatus.textContent = 'Your bookings could not be loaded. Refresh to try again.';
      bookingStatus.dataset.state = 'error';
      bookingStatus.setAttribute('role', 'alert');
      bookingList.replaceChildren();
      bookingSection.classList.remove('hidden');
    }
  }
  function createFacilityCard(facility) {
    const card = document.createElement('article'); card.className = 'amenity-card'; card.dataset.facilityId = String(facility.facilityId);
    card.dataset.hasSlots = 'false';
    const cover = document.createElement('div'); cover.className = `amenity-cover ${/hall|room|club/i.test(facility.name) ? 'hall-cover' : 'court-cover'}`;
    const category = document.createElement('span'); category.textContent = 'SHARED FACILITY'; cover.append(category);
    const art = document.createElement('div'); art.className = /hall|room|club/i.test(facility.name) ? 'hall-illustration' : 'court-lines';
    if (art.className === 'hall-illustration') for (let index = 0; index < 3; index += 1) art.append(document.createElement('i'));
    else for (let index = 0; index < 3; index += 1) art.append(document.createElement('i'));
    cover.append(art);
    const body = document.createElement('div'); body.className = 'amenity-card-body';
    const heading = document.createElement('div'); heading.className = 'amenity-card-heading';
    const headingCopy = document.createElement('div');
    const name = document.createElement('h2'); name.textContent = facility.name;
    const location = document.createElement('p'); location.textContent = facility.locationLabel || facility.description || 'Shared community space';
    headingCopy.append(name, location);
    const available = document.createElement('span'); available.className = 'amenity-available';
    const availableDot = document.createElement('i'); available.append(availableDot, document.createTextNode('Check times'));
    heading.append(headingCopy, available);
    const details = document.createElement('div'); details.className = 'amenity-details';
    const capacity = document.createElement('span'); capacity.textContent = `Up to ${facility.capacity} attendees`;
    const duration = document.createElement('span'); duration.textContent = `${facility.durationMinutes} minute${facility.durationMinutes === 1 ? '' : 's'}`;
    details.append(capacity, duration);
    const fee = document.createElement('div'); fee.className = 'resident-facility-fee'; fee.textContent = formatFee(facility.fee);
    const slots = document.createElement('div'); slots.className = 'amenity-slots';
    const slotsLabel = document.createElement('span'); slotsLabel.textContent = 'Available times';
    const slotItems = document.createElement('div'); slotItems.className = 'resident-facility-slot-items';
    slots.append(slotsLabel, slotItems);
    const book = document.createElement('button'); book.type = 'button'; book.className = 'amenity-book';
    book.dataset.action = 'book-facility'; book.dataset.facilityId = String(facility.facilityId);
    book.dataset.facility = facility.name; book.dataset.capacity = String(facility.capacity);
    book.dataset.policyVersion = facility.policyVersion; book.disabled = true;
    book.append(document.createTextNode('Request a booking '));
    const arrow = document.createElement('span'); arrow.textContent = '→'; book.append(arrow);
    body.append(heading, details, fee, slots, book);
    card.append(cover, body);
    card._facility = facility;
    card._availabilityNodes = { available, slotItems, book };
    return card;
  }
  function renderSlots(card, slots) {
    const { available, slotItems, book } = card._availabilityNodes;
    slotItems.replaceChildren();
    card.dataset.hasSlots = slots.length ? 'true' : 'false';
    available.replaceChildren(document.createElement('i'), document.createTextNode(slots.length ? 'Times available' : 'No times available'));
    available.classList.toggle('amenity-unavailable', !slots.length);
    slots.slice(0, 8).forEach((slot) => {
      const button = document.createElement('button'); button.type = 'button'; button.dataset.slot = slot.startsAt;
      button.dataset.startsAt = slot.startsAt; button.dataset.endsAt = slot.endsAt;
      button.dataset.remainingCapacity = String(slot.remainingCapacity); button.dataset.policyVersion = slot.policyVersion;
      button.setAttribute('aria-pressed', 'false');
      button.textContent = `${zoneTime(slot.startsAt, card._facility.timezone)}–${zoneTime(slot.endsAt, card._facility.timezone)}`;
      slotItems.append(button);
    });
    if (!slots.length) {
      const message = document.createElement('small'); message.textContent = 'Try another date.'; slotItems.append(message);
    }
    book.disabled = !slots.length;
    filterCards();
  }
  function filterCards() {
    section.querySelectorAll('.amenity-card').forEach((card) => {
      card.classList.toggle('hidden', state.filter === 'available' && card.dataset.hasSlots !== 'true');
    });
  }
  async function loadAvailability(date, generation) {
    const cards = [...section.querySelectorAll('.amenity-card')];
    let next = 0; let failures = 0;
    const worker = async () => {
      while (next < cards.length) {
        const index = next; next += 1;
        const card = cards[index]; const facility = card._facility;
        try {
          const url = safeUrl(availabilityUrl(facility.facilityId)); url.searchParams.set('date', date);
          const result = await request(url.toString());
          if (generation !== state.generation || !active) return;
          if (!slotResponseValid(result, facility, date, estateId())) throw new Error('Invalid availability');
          state.slots.set(String(facility.facilityId), result.items);
          renderSlots(card, result.items);
        } catch {
          if (generation !== state.generation || !active) return;
          failures += 1;
          renderSlots(card, []);
          const message = document.createElement('small'); message.textContent = 'Availability could not be refreshed.';
          card.querySelector('.resident-facility-slot-items').replaceChildren(message);
        }
      }
    };
    await Promise.all(Array.from({ length: Math.min(4, cards.length) }, worker));
    if (generation !== state.generation || !active) return;
    setStatus(failures ? `Some availability could not be refreshed. Try again or choose another date.` : `Times shown for ${new Intl.DateTimeFormat(undefined, { dateStyle: 'full', timeZone: state.facilities[0]?.timezone || 'UTC' }).format(new Date(`${date}T12:00:00`))}.`, failures ? 'error' : 'ready');
  }
  async function loadBookingsAndFacilities() {
    const generation = ++state.generation;
    state.facilities = []; state.slots.clear();
    liveTools.classList.remove('hidden');
    bookingSection.classList.remove('hidden');
    section.querySelectorAll('.amenity-card').forEach((card) => card.remove());
    setStatus('Loading estate facilities…', 'loading');
    bookingList.replaceChildren(); bookingStatus.textContent = 'Loading your bookings…';
    try {
      const result = await request(facilitiesUrl());
      if (generation !== state.generation || !active) return;
      if (!result || String(result.estateId) !== estateId() || !Array.isArray(result.items) || result.items.length > 100
        || result.items.some((item) => !facilityResponseValid(item, estateId()))) throw new Error('Invalid facility list');
      const ids = new Set();
      if (result.items.some((item) => { const key = String(item.facilityId); if (ids.has(key)) return true; ids.add(key); return false; })) throw new Error('Duplicate facility');
      if (result.items.length && result.items.some((item) => item.timezone !== result.items[0].timezone)) throw new Error('Mixed facility timezones');
      state.facilities = result.items;
      const cardFragment = document.createDocumentFragment();
      state.facilities.forEach((facility) => cardFragment.append(createFacilityCard(facility)));
      section.querySelector('.amenity-filter-row')?.after(cardFragment);
      if (!state.facilities.length) {
        setStatus('No bookable facilities are available to your account in this estate.');
        dateInput.disabled = true;
      } else {
        const today = zoneDate(state.facilities[0].timezone);
        dateInput.min = today;
        const maxWindow = Math.min(...state.facilities.map((facility) => facility.maximumBookingWindowDays));
        const maxDate = new Date(`${today}T00:00:00.000Z`); maxDate.setUTCDate(maxDate.getUTCDate() + maxWindow);
        dateInput.max = maxDate.toISOString().slice(0, 10);
        if (!dateInput.value || dateInput.value < dateInput.min || dateInput.value > dateInput.max) dateInput.value = today;
        dateInput.disabled = false;
        await loadAvailability(dateInput.value, generation);
      }
      await loadBookings(generation);
    } catch {
      if (generation !== state.generation || !active) return;
      setStatus('Facilities could not be loaded. Refresh to try again.', 'error');
      dateInput.disabled = true;
      bookingStatus.textContent = 'Your bookings could not be loaded.';
      bookingStatus.dataset.state = 'error'; bookingStatus.setAttribute('role', 'alert');
    }
  }
  function newKey() {
    if (!window.crypto?.getRandomValues) throw new Error('Secure booking request keys are unavailable.');
    const bytes = new Uint8Array(24); window.crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  }
  window.openResidentFacilityBooking = (selection) => {
    const facility = state.facilities.find((item) => String(item.facilityId) === String(selection?.facilityId));
    const slot = state.slots.get(String(selection?.facilityId))?.find((item) => item.startsAt === selection?.startsAt && item.endsAt === selection?.endsAt);
    if (!facility || !slot || selection.policyVersion !== slot.policyVersion) return window.showResidentMessage?.('Refresh availability and choose a current time.');
    state.pending = { facility, slot };
    state.pendingKey = '';
    document.getElementById('bookingSlotSummary').textContent = `${facility.name} · ${zoneDate(facility.timezone, new Date(slot.startsAt))} · ${zoneTime(slot.startsAt, facility.timezone)}–${zoneTime(slot.endsAt, facility.timezone)}`;
    document.getElementById('bookingAttendees').value = '1';
    document.getElementById('bookingAttendees').max = String(slot.remainingCapacity);
    document.getElementById('bookingPurpose').value = '';
    document.getElementById('acceptBookingPolicy').checked = false;
    document.getElementById('bookingPolicyAcceptanceText').textContent = `I accept policy ${facility.policyVersion}: ${facility.policySummary}`;
    document.getElementById('bookingPolicyAcceptanceRow').classList.remove('hidden');
    const feeTerms = document.getElementById('bookingFeeTerms');
    feeTerms.textContent = facility.fee ? `Booking fee: ${formatFee(facility.fee)}. Payment and confirmation follow estate policy.` : 'No booking fee applies to this request.';
    feeTerms.classList.remove('hidden');
    document.getElementById('bookingCreateError').textContent = '';
    formNote.textContent = 'Availability and booking terms were returned by the estate service. The request is checked again when submitted.';
    modal.classList.remove('hidden');
  };
  window.cancelResidentFacilityBooking = () => { state.pending = null; state.pendingKey = ''; };
  window.setResidentAmenityFilter = (filter) => { state.filter = filter === 'available' ? 'available' : 'all'; filterCards(); };
  window.submitResidentFacilityBooking = async () => {
    if (!state.pending) return;
    const { facility, slot } = state.pending;
    const attendees = Number(document.getElementById('bookingAttendees').value);
    const purposeInput = document.getElementById('bookingPurpose');
    const purpose = purposeInput.value.trim();
    const accepted = document.getElementById('acceptBookingPolicy').checked;
    const errorNode = document.getElementById('bookingCreateError');
    if (!Number.isSafeInteger(attendees) || attendees < 1 || attendees > slot.remainingCapacity) {
      errorNode.textContent = `Enter between 1 and ${slot.remainingCapacity} attendees.`; return;
    }
    if (purpose.length > 250) { errorNode.textContent = 'Purpose must be 250 characters or fewer.'; return; }
    if (!accepted) { errorNode.textContent = 'Accept the current facility policy to continue.'; document.getElementById('acceptBookingPolicy').focus(); return; }
    if (!state.pendingKey) {
      try { state.pendingKey = newKey(); }
      catch (error) { errorNode.textContent = error.message; return; }
    }
    const fields = [document.getElementById('bookingAttendees'), purposeInput, document.getElementById('acceptBookingPolicy')];
    fields.forEach((field) => { field.disabled = true; });
    submitButton.disabled = true; submitButton.textContent = 'Sending…'; errorNode.textContent = '';
    try {
      const result = await request(bookingUrl(facility.facilityId), 'POST', {
        startsAt: slot.startsAt, endsAt: slot.endsAt, attendeeCount: attendees,
        ...(purpose ? { purpose } : {}), acceptedPolicyVersion: slot.policyVersion,
      }, { 'Idempotency-Key': state.pendingKey });
      const allowed = new Set(['bookingId', 'estateId', 'facilityId', 'status', 'startsAt', 'endsAt', 'attendeeCount', 'policyVersion', 'feeInvoiceId', 'fee', 'replayed']);
      if (!result || Object.keys(result).some((key) => !allowed.has(key)) || !id(result.bookingId)
        || String(result.estateId) !== estateId() || String(result.facilityId) !== String(facility.facilityId)
        || !['requested', 'pending_review', 'pending_payment', 'confirmed'].includes(result.status)
        || result.startsAt !== slot.startsAt || result.endsAt !== slot.endsAt || result.attendeeCount !== attendees
        || result.policyVersion !== slot.policyVersion || !(result.feeInvoiceId === null || id(result.feeInvoiceId))
        || result.fee !== null && result.fee && Object.keys(result.fee).some((key) => !['amount', 'currency', 'currencyScale'].includes(key))
        || !feeMatches(result.fee, facility.fee) || result.replayed !== undefined && typeof result.replayed !== 'boolean') {
        throw new Error('The estate service did not confirm this booking.');
      }
      state.pendingKey = '';
      modal.classList.add('hidden'); state.pending = null;
      window.showResidentMessage?.(result.status === 'confirmed' ? 'Facility booking confirmed.' : `Booking ${statusLabel(result.status).toLowerCase()}.`);
      await Promise.all([loadAvailability(dateInput.value, state.generation), loadBookings(state.generation)]);
    } catch (error) {
      const status = Number.isInteger(error?.status) ? error.status : 0;
      errorNode.textContent = status === 409 ? 'That time is no longer available or this request was already recorded. Refreshing the latest availability.'
        : status === 403 || status === 404 ? 'This facility is not available to your account in this estate.'
          : status === 422 ? 'The booking could not be accepted under the current facility policy.'
            : status === 429 ? 'Too many booking requests. Wait a moment and try again.'
              : 'The booking was not confirmed. Keep the details unchanged and retry safely.';
      if (status === 409) {
        state.pendingKey = '';
        state.pending = null;
        modal.classList.add('hidden');
        window.showResidentMessage?.('Choose from the refreshed facility times.');
        await loadAvailability(dateInput.value, state.generation);
      }
    } finally {
      fields.forEach((field) => { field.disabled = false; });
      submitButton.disabled = false; submitButton.textContent = 'Send request';
    }
  };
  function resetKeyOnEdit() { if (state.pending) state.pendingKey = ''; }
  ['bookingAttendees', 'bookingPurpose', 'acceptBookingPolicy'].forEach((id) => {
    document.getElementById(id)?.addEventListener('input', resetKeyOnEdit);
    document.getElementById(id)?.addEventListener('change', resetKeyOnEdit);
  });
  dateInput.addEventListener('change', () => {
    if (!state.facilities.length || !dateInput.value) return;
    const generation = state.generation;
    state.slots.clear();
    setStatus('Refreshing available times…', 'loading');
    loadAvailability(dateInput.value, generation);
  });
  window.addEventListener('estate:context-changed', () => {
    modal.classList.add('hidden');
    state.pending = null; state.pendingKey = '';
    if (estateId()) loadBookingsAndFacilities();
    else { state.generation += 1; section.querySelectorAll('.amenity-card').forEach((card) => card.remove()); setStatus('Select an estate to view its facilities.', 'error'); }
  });
  window.refreshResidentFacilities = loadBookingsAndFacilities;
  loadBookingsAndFacilities();
})();
