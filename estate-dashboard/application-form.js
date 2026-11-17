const applicationForm = document.getElementById('estateApplicationForm');
const steps = [...document.querySelectorAll('.application-step')];
const stepIndicators = [...document.querySelectorAll('[data-step-indicator]')];
const nextButton = document.getElementById('nextStep');
const previousButton = document.getElementById('previousStep');
const submitButton = document.getElementById('submitApplication');
const stepMessage = document.getElementById('stepMessage');
const documentsInput = document.getElementById('estateDocuments');
const selectedDocuments = document.getElementById('selectedDocuments');
let currentStep = 0;
const hostConfig = window.ZvendEstateConfig || {};
const apiBaseUrl = typeof hostConfig.applicationApiUrl === 'string'
  ? hostConfig.applicationApiUrl.replace(/\/$/, '')
  : typeof hostConfig.apiBaseUrl === 'string' && hostConfig.apiBaseUrl.trim()
    ? `${hostConfig.apiBaseUrl.replace(/\/$/, '')}/api/estate/applications`
    : '';
const liveSubmissionEnabled = Boolean(apiBaseUrl);
let draftApplicationId = null;
const uploadedDocuments = new Map();
const uploadIdempotencyKeys = new WeakMap();
const previewDocumentCategories = [
  { id: 'management_authorization', label: 'Management authorization' },
  { id: 'company_registration', label: 'Company registration' },
  { id: 'land_or_ownership_record', label: 'Land or ownership record' },
  { id: 'development_approval', label: 'Development approval' },
  { id: 'other', label: 'Other supporting document' },
];

function documentCategories() {
  const configured = hostConfig.applicationDocumentCategories;
  if (Array.isArray(configured) && configured.length && configured.every((category) =>
    category && typeof category.id === 'string' && typeof category.label === 'string')) return configured;
  return previewDocumentCategories;
}

function setAccountMode() {
  if (!liveSubmissionEnabled) return;
  document.querySelector('.application-account .preview-tag')?.remove();
  const note = document.querySelector('.upload-preview-note');
  if (note) note.textContent = typeof hostConfig.uploadApplicationDocument === 'function'
    ? "Secure document upload is connected. Files are sent through Zvend's private storage service when you submit."
    : 'Secure upload is not configured. Your files will remain on this device until Zvend connects its private storage service.';
  const uploadNotice = [...document.querySelectorAll('.form-info-callout span')]
    .find((span) => span.textContent.includes('Never attach payment details'));
  if (uploadNotice && typeof hostConfig.uploadApplicationDocument === 'function') {
    uploadNotice.textContent = "Never attach payment details, passwords or resident lists. Supporting documents are uploaded through Zvend's private storage service."
  } else if (uploadNotice) {
    uploadNotice.textContent = 'Never attach payment details, passwords or resident lists. Secure document upload must be connected before submission.';
  }
}

async function readResponse(response) {
  let body = {};
  try { body = await response.json(); } catch { /* Some successful commands may return no body. */ }
  if (!response.ok) {
    const message = body?.message || body?.error?.message;
    const fallback = response.status === 401 ? 'Sign in to submit an estate application.'
      : response.status === 403 ? 'This account cannot submit an estate application.'
        : response.status === 409 ? 'The application changed. Refresh and try again.'
          : `The application service returned an error (${response.status}).`;
    throw new Error(typeof message === 'string' ? message : fallback);
  }
  return body?.data || body;
}

async function applicationRequest(path, method, payload) {
  if (typeof hostConfig.request === 'function') {
    const result = await hostConfig.request({
      url: `${apiBaseUrl}${path}`,
      method,
      payload,
      credentials: 'same-origin',
    });
    if (typeof Response !== 'undefined' && result instanceof Response) return readResponse(result);
    if (!result || typeof result !== 'object') throw new Error('The application client returned an invalid response.');
    return result.data || result;
  }
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    credentials: 'same-origin',
    headers: { Accept: 'application/json', ...(payload === undefined ? {} : { 'Content-Type': 'application/json' }) },
    ...(payload === undefined ? {} : { body: JSON.stringify(payload) }),
  });
  return readResponse(response);
}

async function ensureApplicationDraft() {
  if (draftApplicationId) return draftApplicationId;
  const result = await applicationRequest('', 'POST', {});
  const applicationId = result.applicationId || result.id;
  if (!['string', 'number'].includes(typeof applicationId) || !applicationId) {
    throw new Error('The application service did not return a draft reference.');
  }
  draftApplicationId = String(applicationId);
  return draftApplicationId;
}

function currentStepChanges() {
  const value = (name) => applicationForm.elements[name].value.trim();
  if (currentStep === 0) return {
    proposedName: value('estateName'),
    estateType: value('estateType'),
    address: value('address'),
    state: value('state'),
    lga: value('lga'),
    applicantContactPhone: value('contactPhone'),
    latitude: value('latitude') ? Number(value('latitude')) : null,
    longitude: value('longitude') ? Number(value('longitude')) : null,
  };
  if (currentStep === 1) return {
    applicantRelationship: value('applicantRole'),
    applicantContactName: value('contactPerson'),
    applicantContactEmail: value('contactEmail'),
    managementEntityName: value('organization'),
    registrationNumber: value('registrationNumber') || null,
  };
  if (currentStep === 2) return {
    homeCount: Number(value('homeCount')),
    phaseCount: value('phaseCount') ? Number(value('phaseCount')) : null,
    structureSummary: value('structureSummary') || null,
  };
  return null;
}

async function saveCurrentStep() {
  if (!liveSubmissionEnabled || currentStep > 2) return true;
  try {
    await ensureApplicationDraft();
    await applicationRequest(`/${encodeURIComponent(draftApplicationId)}`, 'PATCH', currentStepChanges());
    return true;
  } catch (error) {
    stepMessage.textContent = error.message || 'Your draft could not be saved. Try again.';
    return false;
  }
}

function selectedCategoryFor(index) {
  const select = selectedDocuments.querySelector(`[data-document-category="${index}"]`);
  return select?.value || '';
}

function fileUploadKey(file, category) {
  const key = `${file.name}\u0000${file.size}\u0000${file.lastModified}\u0000${category}`;
  if (!uploadIdempotencyKeys.has(file)) uploadIdempotencyKeys.set(file, new Map());
  const perFile = uploadIdempotencyKeys.get(file);
  if (!perFile.has(key)) perFile.set(key, globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`);
  return perFile.get(key);
}

function goToStep(step) {
  currentStep = step;
  steps.forEach((section, index) => section.classList.toggle('hidden', index !== currentStep));
  stepIndicators.forEach((indicator, index) => {
    indicator.classList.toggle('current', index === currentStep);
    indicator.classList.toggle('complete', index < currentStep);
    if (index === currentStep) indicator.setAttribute('aria-current', 'step');
    else indicator.removeAttribute('aria-current');
  });
  previousButton.classList.toggle('hidden', currentStep === 0);
  nextButton.classList.toggle('hidden', currentStep === steps.length - 1);
  submitButton.classList.toggle('hidden', currentStep !== steps.length - 1);
  document.getElementById('formTitle').textContent = currentStep === 3 ? 'Review application' : 'Estate details';
  stepMessage.textContent = currentStep === 3
    ? (liveSubmissionEnabled ? 'Your application will be sent to the platform review team.' : 'Submitting sends this application for platform review.')
    : 'Required fields are marked for each step.';
  if (currentStep === 3) renderReviewSummary();
  document.querySelector('.application-card').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderSelectedDocuments(files) {
  const previousCategories = [...selectedDocuments.querySelectorAll('[data-document-category]')].map((select) => select.value);
  selectedDocuments.replaceChildren();
  files.forEach((file, index) => {
    const item = document.createElement('li');
    const name = document.createElement('span');
    name.textContent = `${file.name} - ${(file.size / 1024 / 1024).toFixed(2)} MB`;
    item.append(name);
    const category = document.createElement('select');
    category.dataset.documentCategory = String(index);
    category.setAttribute('aria-label', `Document category for ${file.name}`);
    category.required = liveSubmissionEnabled;
    const prompt = document.createElement('option');
    prompt.value = '';
    prompt.textContent = 'Choose category';
    category.append(prompt);
    for (const option of documentCategories()) {
      const element = document.createElement('option');
      element.value = option.id;
      element.textContent = option.label;
      category.append(element);
    }
    if (previousCategories[index] && [...category.options].some((option) => option.value === previousCategories[index])) {
      category.value = previousCategories[index];
    }
    if (liveSubmissionEnabled) item.append(category);
    selectedDocuments.append(item);
  });
}

function showApplicationSuccess(reference) {
  const success = document.getElementById('applicationSuccess');
  success.querySelector('.eyebrow').textContent = 'APPLICATION SUBMITTED';
  success.querySelector('h2').textContent = 'Your application is in review.';
  success.querySelector(':scope > p').textContent = reference
    ? `Your application reference is ${reference}. You can follow its status through your Zvend account.`
    : 'Your application has been submitted. You can follow its status through your Zvend account.';
  success.querySelector('.preview-tag')?.remove();
  document.getElementById('applicationFormView').classList.add('hidden');
  success.classList.remove('hidden');
  document.querySelector('.application-card').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function setApplicationModeText() {
  if (!liveSubmissionEnabled) return;
  const account = hostConfig.currentUser || {};
  const accountName = typeof account.displayName === 'string' && account.displayName.trim()
    ? account.displayName.trim()
    : 'Signed-in account';
  const nameElement = document.querySelector('.application-account strong');
  if (nameElement) nameElement.textContent = accountName;
  const accountDescription = document.querySelector('.application-account small');
  if (accountDescription) accountDescription.textContent = 'Connected Zvend account';
  const avatar = document.querySelector('.application-account .account-avatar');
  if (avatar) avatar.textContent = accountName.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
  applicationForm.elements.contactPerson.value = accountName === 'Signed-in account' ? '' : accountName;
  applicationForm.elements.contactEmail.value = typeof account.email === 'string' ? account.email : '';
  applicationForm.elements.contactPhone.value = typeof account.phone === 'string' ? account.phone : '';
  const eyebrow = document.querySelector('#applicationFormView .form-heading .eyebrow');
  if (eyebrow) eyebrow.textContent = 'ESTATE APPLICATION';
}

function validateCurrentStep() {
  const activeSection = steps[currentStep];
  const fields = [...activeSection.querySelectorAll('input,select,textarea')];
  for (const field of fields) {
    if (!field.checkValidity()) {
      field.reportValidity();
      return false;
    }
  }
  if (currentStep === 0) {
    const latitude = applicationForm.elements.latitude.value.trim();
    const longitude = applicationForm.elements.longitude.value.trim();
    if (Boolean(latitude) !== Boolean(longitude)) {
      stepMessage.textContent = 'Enter both map coordinates or leave both blank.';
      applicationForm.elements[latitude ? 'longitude' : 'latitude'].focus();
      return false;
    }
  }
  if (currentStep === 2 && documentsInput.files.length === 0) {
    stepMessage.textContent = 'Select at least one supporting document to continue.';
    documentsInput.focus();
    return false;
  }
  stepMessage.textContent = currentStep === 3
    ? (liveSubmissionEnabled ? 'Your application will be sent to the platform review team.' : 'Submitting sends this application for platform review.')
    : 'Required fields are marked for each step.';
  return true;
}

function addReviewGroup(title, rows) {
  const group = document.createElement('section');
  group.className = 'review-group';
  const heading = document.createElement('div');
  heading.textContent = title;
  group.append(heading);
  for (const [label, value] of rows) {
    const row = document.createElement('div');
    row.className = 'review-row';
    const labelElement = document.createElement('span');
    labelElement.textContent = label;
    const valueElement = document.createElement('strong');
    valueElement.textContent = value || 'Not provided';
    row.append(labelElement, valueElement);
    group.append(row);
  }
  document.getElementById('applicationReviewSummary').append(group);
}

function renderReviewSummary() {
  const summary = document.getElementById('applicationReviewSummary');
  summary.replaceChildren();
  const value = (name) => applicationForm.elements[name].value.trim();
  addReviewGroup('ESTATE', [
    ['Estate name', value('estateName')],
    ['Type', value('estateType')],
    ['Address', [value('address'), value('lga'), value('state')].filter(Boolean).join(', ')],
    ['Contact phone', value('contactPhone')],
    ['Map coordinates', value('latitude') && value('longitude') ? `${value('latitude')}, ${value('longitude')}` : 'Not added']
  ]);
  addReviewGroup('OWNER / OPERATOR', [
    ['Relationship', value('applicantRole')],
    ['Contact', value('contactPerson')],
    ['Email', value('contactEmail')],
    ['Organization', value('organization')],
    ['Registration no.', value('registrationNumber') || 'Not provided']
  ]);
  addReviewGroup('COMMUNITY STRUCTURE', [
    ['Approximate homes', value('homeCount')],
    ['Phases / zones', value('phaseCount') || 'Not provided'],
    ['Structure', value('structureSummary') || 'Not provided'],
    ['Supporting documents', [...documentsInput.files].map((file, index) => {
      const category = documentCategories().find((item) => item.id === selectedCategoryFor(index));
      return category ? `${file.name} (${category.label})` : file.name;
    }).join(', ')]
  ]);
}

documentsInput.addEventListener('change', () => {
  selectedDocuments.replaceChildren();
  const files = [...documentsInput.files];
  const unsupportedFile = files.find((file) => !/\.(pdf|jpe?g|png)$/i.test(file.name));
  if (unsupportedFile) {
    stepMessage.textContent = `${unsupportedFile.name} is not a supported document type.`;
    documentsInput.value = '';
    return;
  }
  const invalidFile = files.find((file) => file.size > 10 * 1024 * 1024);
  if (invalidFile) {
    stepMessage.textContent = `${invalidFile.name} is over the 10 MB preview limit.`;
    documentsInput.value = '';
    return;
  }
  if (files.length > 8) {
    stepMessage.textContent = 'Choose no more than 8 documents for this preview.';
    documentsInput.value = '';
    return;
  }
  renderSelectedDocuments(files);
  stepMessage.textContent = files.length
    ? (liveSubmissionEnabled ? `${files.length} document selected.` : `${files.length} document selected on this device.`)
    : 'Required fields are marked for each step.';
});

setAccountMode();
setApplicationModeText();

nextButton.addEventListener('click', async () => {
  if (!validateCurrentStep()) return;
  nextButton.disabled = true;
  previousButton.disabled = true;
  const saved = await saveCurrentStep();
  nextButton.disabled = false;
  previousButton.disabled = false;
  if (saved) goToStep(Math.min(currentStep + 1, steps.length - 1));
});

previousButton.addEventListener('click', () => goToStep(Math.max(0, currentStep - 1)));

applicationForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (currentStep !== steps.length - 1) return;
  if (!liveSubmissionEnabled) {
    document.getElementById('applicationSuccess').querySelector('h2').textContent = 'Your details are ready for review.';
    document.getElementById('applicationFormView').classList.add('hidden');
    document.getElementById('applicationSuccess').classList.remove('hidden');
    document.querySelector('.application-card').scrollIntoView({ behavior: 'smooth', block: 'start' });
    return;
  }
  const uploader = hostConfig.uploadApplicationDocument;
  if (typeof uploader !== 'function') {
    stepMessage.textContent = 'Secure document upload is not connected. Your application has not been submitted.';
    return;
  }
  const files = [...documentsInput.files];
  if (files.some((_, index) => !selectedCategoryFor(index))) {
    stepMessage.textContent = 'Choose a category for each supporting document before submitting.';
    selectedDocuments.querySelector('select:invalid')?.focus();
    return;
  }
  submitButton.disabled = true;
  nextButton.disabled = true;
  previousButton.disabled = true;
  try {
    stepMessage.textContent = 'Saving your application and uploading supporting documents...';
    await ensureApplicationDraft();
    const documentIds = [];
    for (const [index, file] of files.entries()) {
      const category = selectedCategoryFor(index);
      const cacheKey = `${file.name}\u0000${file.size}\u0000${file.lastModified}\u0000${category}`;
      let uploaded = uploadedDocuments.get(cacheKey);
      if (!uploaded) {
        uploaded = await uploader({
          applicationId: draftApplicationId,
          file,
          category,
          idempotencyKey: fileUploadKey(file, category),
        });
        if (!uploaded || !['string', 'number'].includes(typeof uploaded.documentId) || !uploaded.documentId) {
          throw new Error('Secure storage did not return an application document reference.');
        }
        uploadedDocuments.set(cacheKey, uploaded);
      }
      documentIds.push(uploaded.documentId);
    }
    stepMessage.textContent = 'Submitting your application...';
    const result = await applicationRequest(`/${encodeURIComponent(draftApplicationId)}/submit`, 'POST', { documentIds });
    showApplicationSuccess(result.applicationCode || result.applicationId || draftApplicationId);
  } catch (error) {
    stepMessage.textContent = error.message || 'Your application could not be submitted. Check your connection and try again.';
  } finally {
    submitButton.disabled = false;
    nextButton.disabled = false;
    previousButton.disabled = false;
  }
});
