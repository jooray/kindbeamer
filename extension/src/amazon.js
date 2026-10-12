// Amazon sign-in and Send to Kindle calls — the extension's port of
// lib/src/amazon/{oauth,api,client}.dart. SPECIFICATION.md §3–§5 is the
// reference; what differs here is only what a browser forces: the browser
// supplies User-Agent and Accept-Encoding itself, and responses are parsed
// without DOMParser, which a service worker does not have.

import { AdpSigner, bytesToBase64 } from './signer.js';

const FIRS_URL = 'https://firs-ta-g7g.amazon.com';
const STK_URL = 'https://stkservice.amazon.com';
export const CLIENT_ID =
  '658490dfb190e494030082836775981fa23be0c2425441860352ba0f55915b43002d';
export const RETURN_TO = 'https://www.amazon.com/sendtokindle/maplanding';

export class ApiError extends Error {
  constructor(message, body = '', status = 0) {
    super(message);
    this.body = body;
    this.status = status;
  }

  /** A retired registration: sign in again rather than retry. */
  get isRegistrationRejected() {
    return this.status === 401 || this.status === 403 || this.body.includes('DeviceInfoToken');
  }
}

function snippet(body, max = 400) {
  const flat = body.replace(/\s+/g, ' ').trim();
  return flat.length <= max ? flat : `${flat.slice(0, max)}…`;
}

function base64Url(bytes) {
  return bytesToBase64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** PKCE verifier and the sign-in URL carrying its challenge. */
export async function newSignin() {
  const verifier = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const challenge = base64Url(
    new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))),
  );
  const q = new URLSearchParams({
    'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.ns.oa2': 'http://www.amazon.com/ap/ext/oauth/2',
    'openid.ns': 'http://specs.openid.net/auth/2.0',
    'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
    'openid.oa2.client_id': `device:${CLIENT_ID}`,
    'openid.mode': 'checkid_setup',
    'openid.oa2.scope': 'device_auth_access',
    'openid.oa2.response_type': 'code',
    'openid.oa2.code_challenge': challenge,
    'openid.oa2.code_challenge_method': 'S256',
    'openid.return_to': RETURN_TO,
    'openid.ns.pape': 'http://specs.openid.net/extensions/pape/1.0',
    'openid.pape.max_auth_age': '0',
    accountStatusPolicy: 'P1',
    'openid.assoc_handle': 'amzn_device_na',
    pageId: 'amzn_device_common_dark',
    disableLoginPrepopulate: '1',
  });
  return { verifier, url: `https://www.amazon.com/ap/signin?${q}` };
}

/** The authorization code in a sign-in redirect, or null for any other URL. */
export function authorizationCodeFrom(url) {
  let u;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  const code = u.searchParams.get('openid.oa2.authorization_code');
  if (!code) return null;
  if (u.protocol === 'sendtokindle:') return code;
  const landing =
    u.hostname === 'www.amazon.com' &&
    (u.pathname.startsWith('/sendtokindle/maplanding') || u.pathname.startsWith('/gp/sendtokindle'));
  return landing ? code : null;
}

export async function tokenExchange(code, verifier) {
  const res = await fetch('https://api.amazon.com/auth/token', {
    method: 'POST',
    headers: {
      'Accept-Language': 'en-US',
      'x-amzn-identity-auth-domain': 'api.amazon.com',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      app_name: 'Unknown',
      client_domain: 'DeviceLegacy',
      client_id: CLIENT_ID,
      code_algorithm: 'SHA-256',
      code_verifier: verifier,
      requested_token_type: 'access_token',
      source_token: code,
      source_token_type: 'authorization_code',
    }),
  });
  const text = await res.text();
  if (res.status !== 200) {
    throw new ApiError(`token exchange failed: HTTP ${res.status}`, text, res.status);
  }
  const token = JSON.parse(text).access_token;
  if (!token) throw new ApiError('token exchange returned no access token', snippet(text));
  return token;
}

function unescapeXml(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&amp;/g, '&');
}

function escapeXml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/**
 * Every leaf element of the registration answer, wherever it is nested —
 * Amazon has moved these fields between levels before.
 */
export function flattenXml(xml) {
  const out = {};
  for (const m of xml.matchAll(/<([A-Za-z_][\w.-]*)(?:\s[^>]*)?>([^<]*)<\/\1>/g)) {
    if (!(m[1] in out)) out[m[1]] = unescapeXml(m[2]).trim();
  }
  return out;
}

export async function registerDevice(accessToken, { serial, pid, model }) {
  const body =
    "<?xml version='1.0' encoding='UTF-8'?>\n" +
    '<request><parameters>' +
    '<deviceType>A1K6D1WRW0MALS</deviceType>' +
    `<deviceSerialNumber>${serial}</deviceSerialNumber>` +
    `<pid>${pid}</pid>` +
    `<authToken>${escapeXml(accessToken)}</authToken>` +
    '<authTokenType>AccessToken</authTokenType>' +
    '<softwareVersion>253</softwareVersion>' +
    '<os_version>MacOSX_10.14.6_x64</os_version>' +
    `<device_model>${escapeXml(model.slice(0, 51))}</device_model>` +
    '</parameters></request>';
  // A Blob with an explicit type keeps the header bare `text/xml`: the
  // endpoint answers `Internal Error` to `text/xml; charset=utf-8`.
  const res = await fetch(`${FIRS_URL}/FirsProxy/registerDeviceWithToken`, {
    method: 'POST',
    headers: { 'Content-Type': 'text/xml', 'Accept-Language': 'en-US,*' },
    body: new Blob([body], { type: 'text/xml' }),
  });
  const text = await res.text();
  if (res.status !== 200) {
    throw new ApiError(`device registration failed: HTTP ${res.status}`, text, res.status);
  }
  const info = flattenXml(text);
  const missing = ['device_private_key', 'adp_token', 'device_type'].filter((k) => !info[k]);
  if (missing.length) {
    throw new ApiError(
      `device registration returned no credentials (missing ${missing.join(', ')})`,
      snippet(text),
    );
  }
  return info;
}

function clientInfo() {
  const ua = (globalThis.navigator?.userAgent ?? '').toLowerCase();
  if (ua.includes('android')) {
    return { appName: 'ShellExtension', appVersion: '1.1.1.253', os: 'Android_13_arm64', osArchitecture: 'arm64' };
  }
  if (ua.includes('windows')) {
    return { appName: 'ShellExtension', appVersion: '1.1.1.253', os: 'Windows10_10.0_x64', osArchitecture: 'x64' };
  }
  if (ua.includes('linux') || ua.includes('cros')) {
    return { appName: 'ShellExtension', appVersion: '1.1.1.253', os: 'Linux_5.15_x64', osArchitecture: 'x64' };
  }
  return { appName: 'ShellExtension', appVersion: '1.1.1.253', os: 'MacOSX_10.14.6_x64', osArchitecture: 'x64' };
}

/**
 * The `SendToKindle` body: stkclient's for everything but PDF, which goes out
 * the way the official client sends it (SPECIFICATION.md §5).
 */
export function sendToKindleBody({ stkToken, targets, author, title, format, archive, forceConvert }) {
  return {
    DocumentMetadata: {
      author: (author || 'Unknown').slice(0, 255),
      crc32: 0,
      inputFormat: format,
      title: (title || 'Untitled').slice(0, 255),
    },
    archive,
    ...(forceConvert == null
      ? { deliveryMechanism: 'WIFI', outputFormat: 'MOBI' }
      : { forceConvert }),
    stkToken,
    targetDevices: targets,
  };
}

export class StkClient {
  constructor(deviceInfo) {
    this.deviceInfo = deviceInfo;
    this.signer = AdpSigner.fromDeviceInfo(deviceInfo);
  }

  get accountName() {
    return this.deviceInfo.name || this.deviceInfo.user_device_name || '';
  }

  async _request(path, body) {
    const data = JSON.stringify({ ClientInfo: clientInfo(), ...body }, null, 4);
    const res = await fetch(STK_URL + path, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US,*',
        'X-ADP-Request-Digest': await this.signer.digestHeader('POST', path, data),
        'X-ADP-Authentication-Token': this.signer.adpToken,
      },
      body: data,
    });
    const text = await res.text();
    if (res.status !== 200) throw new ApiError(`HTTP ${res.status} for ${path}`, text, res.status);
    return JSON.parse(text);
  }

  /** Owned devices, duplicates under one serial collapsed. */
  async devices() {
    const res = await this._request('/GetListOfOwnedDevices', {});
    const seen = new Set();
    return (res.ownedDevices ?? [])
      .map((d) => ({ name: d.deviceName ?? '', serial: d.deviceSerialNumber ?? '' }))
      .filter((d) => d.serial && !seen.has(d.serial) && seen.add(d.serial));
  }

  async uploadUrl(fileSize) {
    const res = await this._request('/GetUploadUrl', { fileSize });
    return { uploadUrl: res.uploadUrl, stkToken: res.stkToken };
  }

  /** Upload `bytes` and deliver them; resolves to the document's sku. */
  async send(bytes, { targets, title, author, format, archive, forceConvert, onProgress }) {
    const { uploadUrl, stkToken } = await this.uploadUrl(bytes.byteLength);
    await upload(uploadUrl, bytes, onProgress);
    const res = await this._request(
      '/SendToKindle',
      sendToKindleBody({ stkToken, targets, author, title, format, archive, forceConvert }),
    );
    return res.sku ?? '';
  }

  async logout() {
    const path = '/FirsProxy/disownFiona?contentDeleted=false';
    const res = await fetch(FIRS_URL + path, {
      headers: {
        'Content-Type': 'text/xml',
        'Accept-Language': 'en-US,*',
        'X-ADP-Request-Digest': await this.signer.digestHeader('GET', path, ''),
        'X-ADP-Authentication-Token': this.signer.adpToken,
      },
    });
    if (res.status !== 200) {
      throw new ApiError(`logout failed: HTTP ${res.status}`, await res.text(), res.status);
    }
  }
}

/**
 * PUT to the presigned S3 URL. XMLHttpRequest where there is one, because
 * fetch reports no upload progress; a service worker falls back to fetch.
 */
function upload(url, bytes, onProgress) {
  // An untyped Blob sends no Content-Type, as the desktop client does.
  const body = new Blob([bytes]);
  if (typeof XMLHttpRequest === 'undefined') {
    return fetch(url, { method: 'PUT', body }).then(async (res) => {
      if (res.status !== 200) {
        throw new ApiError(`upload failed: HTTP ${res.status}`, await res.text(), res.status);
      }
    });
  }
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', url);
    xhr.upload.onprogress = (e) => onProgress?.(e.loaded, e.total || bytes.byteLength);
    xhr.onload = () =>
      xhr.status === 200
        ? resolve()
        : reject(new ApiError(`upload failed: HTTP ${xhr.status}`, xhr.responseText, xhr.status));
    xhr.onerror = () => reject(new ApiError('upload failed: network error'));
    xhr.send(body);
  });
}
