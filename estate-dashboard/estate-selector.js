(() => {
  const modal = document.getElementById('estateContextModal');
  const message = document.getElementById('estateContextMessage');
  const list = document.getElementById('estateContextList');
  const switcher = document.querySelector('.estate-switcher');
  if (!modal || !message || !list || !switcher) return;

  function closeSelector() {
    modal.classList.add('hidden');
    switcher.focus();
  }

  function showEmpty(messageText) {
    message.textContent = '';
    const empty = document.createElement('div');
    empty.className = 'estate-context-empty';
    empty.textContent = messageText;
    list.replaceChildren(empty);
  }

  async function requestEstates(config, url) {
    if (typeof config.request === 'function') {
      const result = await config.request({ url, method: 'GET', credentials: 'same-origin' });
      if (typeof Response !== 'undefined' && result instanceof Response) {
        if (!result.ok) throw new Error(`The estate service returned an error (${result.status}).`);
        return result.json();
      }
      return result;
    }
    const response = await fetch(url, {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) {
      const errorMessage = response.status === 401 ? 'Sign in to view your estates.'
        : response.status === 403 ? 'Your account cannot view estate memberships.'
          : `The estate service returned an error (${response.status}).`;
      throw new Error(errorMessage);
    }
    return response.json();
  }

  function renderChoice(estate, currentEstateId, selectEstateContext) {
    const isCurrent = String(estate.id) === currentEstateId;
    const option = document.createElement('button');
    option.type = 'button';
    option.className = 'estate-context-option';
    option.disabled = isCurrent || typeof selectEstateContext !== 'function';

    const avatar = document.createElement('span');
    avatar.className = 'estate-context-avatar';
    avatar.textContent = estate.name.trim().slice(0, 1).toUpperCase();
    const copy = document.createElement('span');
    copy.className = 'estate-context-copy';
    const name = document.createElement('strong');
    name.textContent = estate.name.trim();
    const location = document.createElement('small');
    location.textContent = typeof estate.locationLabel === 'string' && estate.locationLabel.trim()
      ? estate.locationLabel.trim()
      : [estate.lga, estate.state].filter((part) => typeof part === 'string' && part.trim()).join(', ');
    copy.append(name, location);
    option.append(avatar, copy);

    if (isCurrent) {
      const current = document.createElement('span');
      current.className = 'estate-context-current';
      current.textContent = 'Current';
      option.append(current);
    }
    option.addEventListener('click', async () => {
      if (isCurrent || typeof selectEstateContext !== 'function') return;
      option.disabled = true;
      message.textContent = `Opening ${estate.name.trim()}...`;
      try {
        const result = await selectEstateContext({ estateId: estate.id, estate });
        if (result === false) throw new Error('The estate workspace could not be opened.');
        closeSelector();
      } catch (error) {
        option.disabled = false;
        message.textContent = error.message || 'The estate workspace could not be opened.';
      }
    });
    list.append(option);
  }

  async function openSelector() {
    const config = window.ZvendEstateConfig || {};
    const apiBase = typeof config.apiBaseUrl === 'string' && config.apiBaseUrl.trim()
      ? config.apiBaseUrl.replace(/\/$/, '')
      : '';
    const url = typeof config.accessibleEstatesUrl === 'string'
      ? config.accessibleEstatesUrl.replace(/\/$/, '')
      : apiBase ? `${apiBase}/api/estate/estates` : '';
    if (!url) {
      if (typeof window.notify === 'function') window.notify('Estate selection will be available when the authenticated estate service is connected.');
      return;
    }

    list.replaceChildren();
    message.textContent = 'Loading estates available to your account...';
    modal.classList.remove('hidden');
    modal.querySelector('.modal-close').focus();
    try {
      const body = await requestEstates(config, url);
      const data = body?.data || body;
      const estates = Array.isArray(data) ? data : Array.isArray(data?.estates) ? data.estates : null;
      if (!estates) throw new Error('The estate service returned an invalid estate list.');
      const seen = new Set();
      const choices = estates.filter((estate) => {
        if (!estate || !['string', 'number'].includes(typeof estate.id)
          || !String(estate.id).trim() || typeof estate.name !== 'string' || !estate.name.trim()) return false;
        const id = String(estate.id);
        if (seen.has(id)) return false;
        seen.add(id);
        return true;
      });
      if (!choices.length) {
        showEmpty('No active estates are available to this account.');
        return;
      }
      const currentEstateId = config.currentEstateId === undefined || config.currentEstateId === null
        ? '' : String(config.currentEstateId);
      const selectEstateContext = config.selectEstateContext;
      message.textContent = typeof selectEstateContext === 'function'
        ? 'Choose an estate to open its workspace.'
        : 'Your active estates are listed below. Workspace switching is not connected yet.';
      for (const estate of choices) renderChoice(estate, currentEstateId, selectEstateContext);
      if (typeof selectEstateContext !== 'function') {
        const help = document.createElement('p');
        help.className = 'estate-context-help';
        help.textContent = 'The host application must refresh the full estate workspace after a selection. Sample dashboard data is not changed here.';
        list.append(help);
      }
    } catch (error) {
      message.textContent = error.message || 'Estates could not be loaded. Try again.';
      const retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'button button-secondary';
      retry.textContent = 'Try again';
      retry.addEventListener('click', openSelector);
      list.replaceChildren(retry);
    }
  }

  modal.querySelector('[data-action="close-estate-context"]').addEventListener('click', closeSelector);
  modal.addEventListener('click', (event) => {
    if (event.target === modal) closeSelector();
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !modal.classList.contains('hidden')) closeSelector();
  });
  window.openEstateContextSelector = openSelector;
})();
