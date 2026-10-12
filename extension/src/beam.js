// The beam page: the article the toolbar button extracted, the label to
// address it, and the send. Builds the EPUB here rather than in the
// background, because image re-encoding needs a DOM and the upload wants
// XMLHttpRequest's progress events.

import { ApiError, StkClient } from './amazon.js';
import { embedImages, sanitize, sections, toXhtml } from './article.js';
import { epubFileName, packageEpub } from './epub.js';

const api = globalThis.browser ?? globalThis.chrome;
const $ = (id) => document.getElementById(id);
const ALL_SITES = { origins: ['<all_urls>'] };
const AMAZON = { origins: ['https://*.amazon.com/*'] };

const state = {
  article: null,
  root: null,
  toc: [],
  client: null,
  devices: [],
  selected: new Set(),
  busy: false,
  sent: false,
  // Access to every site, which images hosted elsewhere need: undefined until
  // known, and asked for at most once per page.
  allSites: undefined,
  asked: false,
  imageCache: new Map(),
  inFlight: new Map(),
  blobUrls: new Map(),
};

// ── article ────────────────────────────────────────────

async function loadArticle() {
  const id = location.hash.slice(1);
  const key = `article:${id}`;
  const stored = id ? (await api.storage.session.get(key))[key] : null;
  if (!stored) {
    return showUnreadable(
      'Nothing to beam here.',
      'Open an article and press the KindBeamer button in the toolbar.',
    );
  }
  state.article = stored;
  if (!stored.ok && stored.tryPdf) return loadPdf(stored);
  if (!stored.ok) return showUnreadable("This page can't be read.", stored.error, stored.url);

  const a = stored;
  state.root = sanitize(a.content, { baseUrl: a.url, leadImage: a.leadImage });
  state.toc = sections(state.root);
  $('title').value = a.title || new URL(a.url).hostname;
  $('author').value = a.byline || a.siteName || '';
  document.title = `${a.title || 'Article'} · KindBeamer`;
  $('source').textContent = new URL(a.url).hostname.replace(/^www\./, '');

  renderPreview();
  const imgs = state.root.querySelectorAll('img');
  const lead = state.root.querySelector('img[data-lead]');
  const count = imgs.length - (lead ? 1 : 0);
  $('images-label').textContent = count
    ? `Include images (${count})`
    : 'Include images (none in the article)';
  $('lead-row').hidden = !lead;
  if (!imgs.length) {
    $('images').checked = false;
    $('images').disabled = true;
  }
  $('download').disabled = false;
  updateFranking();
}

// ── PDF ────────────────────────────────────────────────

/**
 * The tab shows something Readability can't read; if it is a PDF, send the
 * file itself. Fetched here rather than in the background, because the
 * fetch may need access to the PDF's site, and only a click here can ask.
 */
async function loadPdf(a) {
  const url = a.url;
  const local = url.startsWith('file:');
  let bytes;
  try {
    const res = await fetch(url, { credentials: 'include' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    bytes = new Uint8Array(await res.arrayBuffer());
  } catch (e) {
    if (local) {
      return showUnreadable(
        "This PDF can't be read.",
        'The browser keeps extensions away from files on your disk. Send it with the KindBeamer app instead, or open it from the web.',
        url,
      );
    }
    if (!/\.pdf($|[?#])/i.test(url) && !a.pdf) {
      return showUnreadable("This page can't be read.", a.error ?? e.message, url);
    }
    return showPdfAccess(a);
  }
  if (new TextDecoder().decode(bytes.subarray(0, 1024)).indexOf('%PDF-') === -1) {
    return showUnreadable("This page can't be read.", a.error ?? 'No article found on this page.', url);
  }
  enterPdfMode(a, bytes);
}

/** A PDF on a site the extension may not read yet: one click asks for just that site. */
function showPdfAccess(a) {
  const origin = new URL(a.url).origin;
  const note = paragraph(
    `To send this PDF, KindBeamer needs to download it from ${new URL(a.url).hostname}.`,
    'empty',
  );
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'press solid';
  button.textContent = 'Allow and load the PDF';
  button.addEventListener('click', async () => {
    const granted = await api.permissions.request({ origins: [`${origin}/*`] }).catch(() => false);
    if (granted) loadPdf(a);
  });
  $('preview').replaceChildren(note, button);
  $('source').textContent = a.url;
  setSentence('Allow access to load the PDF.', '');
}

function pdfTitle(a) {
  const file = decodeURIComponent(new URL(a.url).pathname.split('/').pop() || '');
  const base = file.replace(/\.pdf$/i, '');
  // Firefox titles the tab with the PDF's own title when it has one; Chrome
  // with the file name.
  // Firefox titles a PDF's tab "<title> - <file name>".
  const tab = (a.tabTitle || '')
    .replace(/\s*[-–—]\s*(Mozilla Firefox|Google Chrome)$/, '')
    .replace(new RegExp(`\\s+[-–—]\\s+${file.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), '')
    .trim();
  return tab && tab !== file && tab !== a.url ? tab : base || new URL(a.url).hostname;
}

function enterPdfMode(a, bytes) {
  state.pdf = { bytes };
  state.unreadable = false;
  document.body.classList.add('pdf-mode');
  $('images-row').hidden = true;
  $('layout-row').hidden = false;
  $('download').hidden = true;
  $('title').value = pdfTitle(a);
  $('author').placeholder = 'Unknown';
  document.title = `${$('title').value} · KindBeamer`;
  $('source').textContent = a.url;
  $('legend-a').firstChild.nextSibling.textContent = 'PDF ';
  const frame = document.createElement('iframe');
  frame.className = 'preview-pdf';
  frame.title = 'PDF preview';
  frame.src = URL.createObjectURL(new Blob([bytes], { type: 'application/pdf' }));
  $('preview').classList.add('pdf');
  $('preview').replaceChildren(frame);
  updateFranking();
}

function pdfLayout() {
  return document.querySelector('input[name="layout"]:checked')?.value ?? 'original';
}

function setPdfLayout(value) {
  for (const input of document.querySelectorAll('input[name="layout"]')) input.checked = input.value === value;
  api.storage.local.set({ pdfLayout: value });
}

function showUnreadable(sentence, detail, url) {
  $('preview').replaceChildren(paragraph(detail ?? '', 'empty'));
  if (url) $('source').textContent = url;
  setSentence(sentence, '');
  $('postmark').dataset.state = 'held';
  $('postmark-word').textContent = 'Held';
  $('download').disabled = true;
  state.unreadable = true;
  updateFranking();
}

function paragraph(text, cls) {
  const p = document.createElement('p');
  p.textContent = text;
  if (cls) p.className = cls;
  return p;
}

function renderPreview() {
  const preview = $('preview');
  const h1 = document.createElement('h1');
  h1.textContent = $('title').value;
  const byline = paragraph($('author').value, 'byline');
  // The sanitized tree is inert (DOMParser); importing it is what loads images.
  const body = document.importNode(state.root, true);
  body.removeAttribute('id');
  preview.replaceChildren(h1, byline, ...body.childNodes);
  preview.lang = state.article.lang || 'en';
  preview.classList.toggle('no-images', !$('images').checked);
  preview.classList.toggle('no-lead', !$('lead').checked);
  for (const img of preview.querySelectorAll('img')) img.dataset.orig = img.getAttribute('src');
  hydratePreview();
}

/**
 * Show the preview's images from the bytes the book will carry. Loaded
 * straight from the site, an <img> in an extension page goes without the
 * site's cookies and is turned away by hotlink checks and
 * Cross-Origin-Resource-Policy, so the preview could miss images the EPUB
 * has. The extension's own fetch gets them; an image it cannot get keeps its
 * remote URL as a last try.
 */
async function hydratePreview() {
  const imgs = Array.from($('preview').querySelectorAll('img[data-orig]:not([data-local])'));
  await Promise.all(
    imgs.map(async (img) => {
      const url = img.dataset.orig;
      try {
        await fetchBytes(url);
      } catch {
        return;
      }
      if (!state.blobUrls.has(url)) {
        const bytes = state.imageCache.get(url);
        // Raster formats are sniffed from the bytes; SVG is only drawn when typed.
        const svg = /^\s*(<\?xml|<svg)/i.test(new TextDecoder().decode(bytes.subarray(0, 64)));
        state.blobUrls.set(url, URL.createObjectURL(new Blob([bytes], svg ? { type: 'image/svg+xml' } : {})));
      }
      img.src = state.blobUrls.get(url);
      img.dataset.local = '1';
    }),
  );
}

// ── book ───────────────────────────────────────────────

async function fetchBytes(url) {
  if (state.imageCache.has(url)) return state.imageCache.get(url);
  // The preview and the book ask for the same images at the same time; one
  // request each.
  if (state.inFlight.has(url)) return state.inFlight.get(url);
  const pending = fetchOnce(url).finally(() => state.inFlight.delete(url));
  state.inFlight.set(url, pending);
  return pending;
}

async function fetchOnce(url) {
  const res = await fetch(url, { credentials: 'include', referrerPolicy: 'no-referrer' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const bytes = new Uint8Array(await res.arrayBuffer());
  state.imageCache.set(url, bytes);
  return bytes;
}

async function buildEpub() {
  const a = state.article;
  const root = state.root.cloneNode(true);
  if (!$('lead').checked) root.querySelector('img[data-lead]')?.closest('figure')?.remove();
  let files = [];
  let skipped = 0;
  if ($('images').checked && root.querySelector('img')) {
    ({ files, skipped } = await embedImages(root, fetchBytes, (done, total) => {
      if (total) setSentence(`Collecting images… ${done} of ${total}`);
    }));
  } else {
    for (const img of root.querySelectorAll('img')) {
      const figure = img.closest('figure');
      img.remove();
      if (figure && !figure.querySelector('img')) figure.remove();
    }
  }
  const bytes = await packageEpub({
    title: $('title').value.trim() || a.title || 'Untitled',
    author: $('author').value.trim() || 'Unknown',
    lang: a.lang,
    url: a.url,
    siteName: a.siteName,
    bodyXhtml: toXhtml(root),
    toc: state.toc,
    images: files,
  });
  hydratePreview();
  return { bytes, skipped, imageCount: files.length };
}

/**
 * Asks for access to every site, which images on other hosts need. Must be
 * the first thing a click handler does: Firefox only honours the request
 * while the click's user gesture is still current.
 */
function requestImageAccess() {
  if (state.allSites !== false || state.asked) return Promise.resolve();
  if (!$('images').checked || !state.root?.querySelector('img')) return Promise.resolve();
  state.asked = true;
  return api.permissions
    .request(ALL_SITES)
    .then((granted) => {
      state.allSites = granted;
      if (granted) hydratePreview();
      return granted;
    })
    .catch(() => false);
}

async function download() {
  const asked = requestImageAccess();
  if (state.busy) return;
  await asked;
  state.busy = true;
  updateFranking();
  try {
    const { bytes, skipped } = await buildEpub();
    const url = URL.createObjectURL(new Blob([bytes], { type: 'application/epub+zip' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = epubFileName($('title').value.trim() || 'article');
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
    setSentence('EPUB saved.', facts(bytes.length, skipped));
  } catch (e) {
    setSentence(`Couldn't build the EPUB: ${e.message}`, '');
  } finally {
    state.busy = false;
    updateFranking(true);
  }
}

// ── account and devices ────────────────────────────────

async function loadAccount() {
  const { credentials } = await api.storage.local.get('credentials');
  if (!credentials?.device_info) {
    state.client = null;
    showSignin();
    return;
  }
  try {
    state.client = new StkClient(credentials.device_info);
  } catch (e) {
    await api.storage.local.remove('credentials');
    showSignin('The stored sign-in was unreadable. Sign in again.');
    return;
  }
  $('account').hidden = false;
  $('account-name').textContent = state.client.accountName;
  $('signin').hidden = true;
  await loadDevices();
}

async function loadDevices() {
  hideTrouble();
  $('lanes').replaceChildren(...Array.from({ length: 2 }, () => div('skeleton')));
  try {
    state.devices = await state.client.devices();
  } catch (e) {
    $('lanes').replaceChildren();
    return handleError(e, 'list');
  }
  const { selected = [] } = await api.storage.local.get('selected');
  const known = new Set(state.devices.map((d) => d.serial));
  state.selected = new Set(selected.filter((s) => known.has(s)));
  if (!state.selected.size && state.devices.length) state.selected.add(state.devices[0].serial);
  renderLanes();
}

function div(cls) {
  const d = document.createElement('div');
  d.className = cls;
  return d;
}

function renderLanes() {
  const lanes = $('lanes');
  if (!state.devices.length) {
    lanes.replaceChildren(paragraph('No Kindles on this account yet.', 'signin-note'));
  } else {
    lanes.replaceChildren(
      ...state.devices.map((d, i) => {
        const row = document.createElement('label');
        row.className = 'tick-row';
        const input = document.createElement('input');
        input.type = 'checkbox';
        input.checked = state.selected.has(d.serial);
        input.addEventListener('change', () => toggle(d.serial, input.checked));
        const tick = document.createElement('span');
        tick.className = 'tick';
        tick.setAttribute('aria-hidden', 'true');
        const number = document.createElement('span');
        number.className = 'lane-number';
        number.textContent = i < 10 ? String((i + 1) % 10) : '';
        const name = document.createElement('span');
        name.className = 'lane-name';
        name.textContent = d.name || d.serial;
        row.append(input, number, tick, name);
        return row;
      }),
    );
  }
  $('all').hidden = state.devices.length < 2;
  updateFranking();
}

function toggle(serial, on) {
  if (on) state.selected.add(serial);
  else state.selected.delete(serial);
  api.storage.local.set({ selected: [...state.selected] });
  renderLanes();
}

function toggleAll() {
  const all = state.selected.size === state.devices.length;
  state.selected = new Set(all ? [] : state.devices.map((d) => d.serial));
  api.storage.local.set({ selected: [...state.selected] });
  renderLanes();
}

function showSignin(note) {
  $('account').hidden = true;
  $('lanes').replaceChildren();
  $('all').hidden = true;
  $('count').textContent = '';
  $('signin').hidden = false;
  $('signin-note').hidden = !note;
  $('signin-note').textContent = note ?? '';
  updateFranking();
}

async function signin() {
  // Firefox lets the user withhold host permissions, and every call to Amazon
  // needs this one. Asked first, while the click still counts as a gesture.
  const granted = await api.permissions.request(AMAZON).catch(() => true);
  if (!granted) {
    $('signin-note').hidden = false;
    $('signin-note').textContent = 'KindBeamer needs access to amazon.com to sign in and send.';
    return;
  }
  $('signin-button').disabled = true;
  $('signin-note').hidden = false;
  $('signin-note').textContent = 'Finish signing in on the Amazon tab. This page picks it up from there.';
  try {
    await api.runtime.sendMessage({ type: 'signin' });
  } catch (e) {
    $('signin-note').textContent = `Couldn't open the sign-in page: ${e.message}`;
  } finally {
    $('signin-button').disabled = false;
  }
}

async function signout() {
  const client = state.client;
  await api.storage.local.remove('credentials');
  // Best effort: unregistering frees the device slot, but a failure here
  // must not keep the user signed in.
  client?.logout().catch(() => {});
}

// ── sending ────────────────────────────────────────────

async function send() {
  const asked = requestImageAccess();
  if (!canSend()) return;
  await asked;
  state.busy = true;
  hideTrouble();
  $('postmark').dataset.state = 'sending';
  $('postmark-word').textContent = 'Sending';
  updateFranking();
  const targets = [...state.selected];
  try {
    let bytes;
    let skipped = 0;
    if (state.pdf) {
      bytes = state.pdf.bytes;
    } else {
      setSentence('Packing the article…', '');
      ({ bytes, skipped } = await buildEpub());
    }
    setSentence('Uploading…', facts(bytes.length, skipped));
    await state.client.send(bytes, {
      targets,
      title: $('title').value.trim() || state.article.title,
      author: $('author').value.trim() || 'Unknown',
      format: state.pdf ? 'PDF' : 'EPUB',
      archive: $('archive').checked,
      // A PDF goes out the way the official client sends one (SPECIFICATION.md §5).
      forceConvert: state.pdf ? pdfLayout() === 'reformat' : undefined,
      onProgress: (sent, total) => setProgress(sent / total),
    });
    state.sent = true;
    setProgress(1);
    $('postmark').dataset.state = 'sent';
    $('postmark-word').textContent = 'Sent';
    const names = state.devices.filter((d) => targets.includes(d.serial)).map((d) => d.name);
    setSentence(`Sent to ${names.join(', ')}.`, facts(bytes.length, skipped));
    if ($('close-after').checked) setTimeout(closeTab, 1400);
  } catch (e) {
    setProgress(0);
    $('postmark').dataset.state = 'held';
    $('postmark-word').textContent = 'Held';
    handleError(e, 'send');
  } finally {
    state.busy = false;
    updateFranking(true);
  }
}

function handleError(e, during) {
  if (e instanceof ApiError && e.isRegistrationRejected) {
    api.storage.local.remove('credentials');
    showSignin('Amazon no longer accepts this browser’s registration. Sign in again to re-register it.');
    setSentence('Not sent: sign in again.', '');
    return;
  }
  const what = during === 'list' ? 'Couldn’t load your Kindles.' : 'Not sent.';
  const reason = e instanceof ApiError ? e.message : `${e.message ?? e}`;
  showTrouble(`${what} ${reason}`, e.body ?? '', 'Try again', during === 'list' ? loadDevices : send);
  if (during === 'send') setSentence(`Not sent. ${reason}`, '');
}

function showTrouble(text, raw, action, run) {
  $('trouble').hidden = false;
  $('trouble-text').textContent = text;
  $('trouble-details').hidden = !raw;
  $('trouble-raw').textContent = raw;
  $('trouble-action').textContent = action;
  $('trouble-action').onclick = () => {
    hideTrouble();
    run();
  };
}

function hideTrouble() {
  $('trouble').hidden = true;
}

async function closeTab() {
  const tab = await api.tabs.getCurrent();
  if (tab) api.tabs.remove(tab.id);
}

// ── franking ───────────────────────────────────────────

function canSend() {
  return (
    !state.busy &&
    !state.unreadable &&
    (!!state.root || !!state.pdf) &&
    !!state.client &&
    state.selected.size > 0 &&
    $('title').value.trim() !== ''
  );
}

function setSentence(sentence, factsLine) {
  $('sentence').textContent = sentence;
  if (factsLine !== undefined) $('facts').textContent = factsLine;
}

function setProgress(fraction) {
  $('progress').style.transform = `scaleX(${Math.max(0, Math.min(1, fraction))})`;
}

function size(n) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  return `${(n / 1024 / 1024).toFixed(2)} MB`;
}

function facts(bytes, skipped) {
  const parts = [state.pdf ? 'PDF' : 'EPUB', size(bytes)];
  if (skipped) parts.push(`${skipped} image${skipped === 1 ? '' : 's'} unavailable`);
  return parts.join(' · ');
}

/** Refresh the sentence and buttons; `keepSentence` leaves a result showing. */
function updateFranking(keepSentence = false) {
  const n = state.selected.size;
  $('count').textContent = state.devices.length ? `${n} of ${state.devices.length}` : '';
  $('all').textContent = n === state.devices.length ? 'None' : 'All';
  $('send').disabled = !canSend();
  $('download').disabled = state.busy || !state.root;
  if (state.busy || keepSentence || state.unreadable) return;
  if (state.sent) return;
  const postmark = $('postmark');
  if (!state.root && !state.pdf) return;
  const kind = state.pdf ? `PDF · ${size(state.pdf.bytes.length)}` : 'EPUB';
  if (!state.client) {
    setSentence('Sign in to send.', `${kind} · from ${new URL(state.article.url).hostname}`);
  } else if (!n) {
    setSentence('Tick a Kindle to send to.', kind);
  } else {
    setSentence('Ready to send.', `${kind} · to ${n} device${n === 1 ? '' : 's'}`);
  }
  postmark.dataset.state = canSend() ? 'ready' : 'idle';
  $('postmark-word').textContent = 'Ready';
}

// ── wiring ─────────────────────────────────────────────

function wire() {
  const date = new Date();
  $('postmark-date').textContent = `${date.getDate()} ${date
    .toLocaleString('en', { month: 'short' })
    .toUpperCase()}`;

  $('send').addEventListener('click', send);
  $('download').addEventListener('click', download);
  $('all').addEventListener('click', toggleAll);
  $('signin-button').addEventListener('click', signin);
  $('signout').addEventListener('click', signout);
  for (const id of ['title', 'author']) {
    $(id).addEventListener('input', () => {
      const target = $('preview').querySelector(id === 'title' ? 'h1' : '.byline');
      if (state.root && target) target.textContent = $(id).value;
      updateFranking();
    });
  }
  api.permissions.contains(ALL_SITES).then((granted) => (state.allSites = granted));
  $('images').addEventListener('change', () => {
    // Ticking images on is a gesture, so it may ask for the access they need.
    if ($('images').checked) requestImageAccess();
    $('preview').classList.toggle('no-images', !$('images').checked);
    hydratePreview();
  });
  $('lead').addEventListener('change', () =>
    $('preview').classList.toggle('no-lead', !$('lead').checked),
  );

  api.storage.local.get(['archive', 'closeAfter', 'pdfLayout']).then(({ archive, closeAfter, pdfLayout }) => {
    if (archive !== undefined) $('archive').checked = archive;
    if (closeAfter !== undefined) $('close-after').checked = closeAfter;
    if (pdfLayout) setPdfLayout(pdfLayout);
  });
  for (const input of document.querySelectorAll('input[name="layout"]')) {
    input.addEventListener('change', () => setPdfLayout(input.value));
  }
  $('archive').addEventListener('change', () => api.storage.local.set({ archive: $('archive').checked }));
  $('close-after').addEventListener('change', () =>
    api.storage.local.set({ closeAfter: $('close-after').checked }),
  );

  // Sign-in finishes in the background script; credentials landing in storage
  // is how this page hears about it, and so does every other open beam tab.
  api.storage.onChanged.addListener((changes, area) => {
    if (area === 'local' && 'credentials' in changes) loadAccount();
    if (area === 'session' && changes.signinError?.newValue) {
      showSignin(`Sign-in failed: ${changes.signinError.newValue}`);
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.isComposing || e.metaKey || e.ctrlKey || e.altKey) return;
    const inField = e.target instanceof HTMLInputElement && e.target.type === 'text';
    if (e.key === 'Enter' && !(e.target instanceof HTMLButtonElement)) {
      e.preventDefault();
      if (canSend()) send();
      else if (!state.client && !$('signin').hidden) signin();
    } else if (e.key === 'Escape') {
      closeTab();
    } else if (!inField && /^[0-9]$/.test(e.key)) {
      const i = e.key === '0' ? 9 : Number(e.key) - 1;
      const d = state.devices[i];
      if (d) toggle(d.serial, !state.selected.has(d.serial));
    } else if (!inField && e.key.toLowerCase() === 'a' && state.devices.length > 1) {
      toggleAll();
    } else if (!inField && e.key.toLowerCase() === 'r' && state.pdf) {
      setPdfLayout(pdfLayout() === 'original' ? 'reformat' : 'original');
    }
  });
}

wire();
loadArticle();
loadAccount();
