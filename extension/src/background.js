// Toolbar button and sign-in. The button reads the article out of the page
// and opens the beam page beside it; sign-in watches the Amazon tab for the
// redirect carrying the authorization code (SPECIFICATION.md §3), then
// exchanges and registers here, so it completes even if the beam tab is
// closed meanwhile.

import { authorizationCodeFrom, newSignin, registerDevice, tokenExchange } from './amazon.js';
import { generateSerial, isValidSerial, pidFor } from './device_id.js';

const api = globalThis.browser ?? globalThis.chrome;

api.action.onClicked.addListener((tab) => beam(tab));

async function beam(tab) {
  const id = crypto.randomUUID();
  let article;
  try {
    const [res] = await api.scripting.executeScript({
      target: { tabId: tab.id },
      files: ['vendor/Readability.js', 'extract.js'],
    });
    article = res?.result ?? { ok: false, error: 'The page returned nothing to read.' };
  } catch (e) {
    article = {
      ok: false,
      error:
        'Browsers keep extensions out of their own pages, the extension stores and some ' +
        `built-in viewers. (${e.message ?? e})`,
    };
  }
  article.url ??= tab.url;
  // A tab Readability can't read may be a PDF — Firefox keeps extensions out
  // of its PDF viewer entirely — so the beam page gets to try fetching it.
  if (!article.ok && /^(https?|file):/.test(tab.url)) {
    article.tryPdf = true;
    article.tabTitle = tab.title ?? '';
  }
  // Older beams are only worth keeping while their tabs are open; session
  // storage is gone with the browser anyway.
  await pruneArticles();
  await api.storage.session.set({ [`article:${id}`]: article });
  await api.tabs.create({
    url: api.runtime.getURL(`beam.html#${id}`),
    index: tab.index + 1,
    openerTabId: tab.id,
  });
}

async function pruneArticles() {
  const all = await api.storage.session.get(null);
  const keys = Object.keys(all).filter((k) => k.startsWith('article:'));
  if (keys.length > 8) await api.storage.session.remove(keys.slice(0, keys.length - 8));
}

// ── sign-in ────────────────────────────────────────────

api.runtime.onMessage.addListener((message) => {
  if (message?.type === 'signin') return startSignin();
  return undefined;
});

async function startSignin() {
  const { verifier, url } = await newSignin();
  await api.storage.session.remove('signinError');
  const tab = await api.tabs.create({ url });
  await api.storage.session.set({ signin: { verifier, tabId: tab.id } });
  return true;
}

api.tabs.onUpdated.addListener(async (tabId, change) => {
  const code = change.url && authorizationCodeFrom(change.url);
  if (!code) return;
  const { signin } = await api.storage.session.get('signin');
  if (!signin || signin.tabId !== tabId) return;
  await api.storage.session.remove('signin');
  // Close before the landing page bounces to sendtokindle://, which would
  // otherwise ask to open the official app.
  api.tabs.remove(tabId).catch(() => {});
  try {
    const token = await tokenExchange(code, signin.verifier);
    const serial = await deviceSerial();
    const info = await registerDevice(token, { serial, pid: pidFor(serial), model: deviceModel() });
    await api.storage.local.set({ credentials: { version: 1, device_info: info } });
  } catch (e) {
    await api.storage.session.set({ signinError: readable(e) });
  }
});

/** The error in a sentence: Amazon's own description where its body has one. */
function readable(e) {
  let detail = '';
  try {
    detail = JSON.parse(e.body).error_description ?? '';
  } catch {
    detail = /<message>([^<]*)<\/message>/.exec(e.body ?? '')?.[1] ?? '';
  }
  return detail ? `${e.message} (${detail})` : e.message;
}

/**
 * This install's device serial, minted once and kept across sign-outs, so
 * signing in again re-registers the same device rather than adding another.
 */
async function deviceSerial() {
  const { deviceSerial } = await api.storage.local.get('deviceSerial');
  if (deviceSerial && isValidSerial(deviceSerial)) return deviceSerial;
  const serial = generateSerial();
  await api.storage.local.set({ deviceSerial: serial });
  return serial;
}

/** How this browser appears in the account's device list (51 characters at most). */
function deviceModel() {
  const ua = navigator.userAgent;
  const browser = api.runtime.getURL('').startsWith('moz-extension:')
    ? 'Firefox'
    : /Edg\//.test(ua)
      ? 'Edge'
      : 'Chrome';
  const os = /Android/.test(ua)
    ? 'Android'
    : /CrOS/.test(ua)
      ? 'ChromeOS'
      : /Mac OS X|Macintosh/.test(ua)
        ? 'macOS'
        : /Windows/.test(ua)
          ? 'Windows'
          : /Linux/.test(ua)
            ? 'Linux'
            : '';
  return `KindBeamer (${browser}${os ? ` on ${os}` : ''})`.slice(0, 51);
}
