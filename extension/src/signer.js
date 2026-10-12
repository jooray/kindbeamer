// X-ADP-Request-Digest signing — a port of lib/src/amazon/signer.dart. Read
// SPECIFICATION.md §4 before touching the padding: the block is k - 1 bytes
// (255 for a 2048-bit key), with no DigestInfo prefix, and getting either
// wrong has every signed call refused.

function base64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function bytesToBase64(bytes) {
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return btoa(bin);
}

/** Modulus and private exponent of a PKCS#1 `RSA PRIVATE KEY` PEM. */
export function parsePkcs1Pem(pem) {
  const body = pem
    .split(/\r?\n/)
    .filter((l) => l.trim() && !l.startsWith('-----'))
    .join('');
  const der = base64ToBytes(body);
  let pos = 0;
  const readTL = () => {
    const tag = der[pos++];
    let len = der[pos++];
    if (len & 0x80) {
      const n = len & 0x7f;
      len = 0;
      for (let i = 0; i < n; i++) len = (len << 8) | der[pos++];
    }
    return [tag, len];
  };
  const readInt = () => {
    const [tag, len] = readTL();
    if (tag !== 0x02) throw new Error('expected INTEGER in private key');
    let v = 0n;
    for (let i = 0; i < len; i++) v = (v << 8n) | BigInt(der[pos++]);
    return v;
  };
  if (readTL()[0] !== 0x30) throw new Error('expected SEQUENCE in private key');
  readInt(); // version
  const n = readInt();
  readInt(); // public exponent
  const d = readInt();
  return { n, d };
}

function modPow(base, exp, mod) {
  let result = 1n;
  base %= mod;
  while (exp > 0n) {
    if (exp & 1n) result = (result * base) % mod;
    base = (base * base) % mod;
    exp >>= 1n;
  }
  return result;
}

function bitLength(v) {
  return v.toString(2).length;
}

export function formatDate(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export class AdpSigner {
  constructor({ n, d }, adpToken) {
    this.n = n;
    this.d = d;
    this.adpToken = adpToken;
  }

  static fromDeviceInfo(info) {
    return new AdpSigner(parsePkcs1Pem(info.device_private_key), info.adp_token);
  }

  async digestHeader(method, path, body, date = new Date()) {
    const dateStr = formatDate(date);
    const sigData = new TextEncoder().encode(
      [method, path, dateStr, body, this.adpToken].join('\n'),
    );
    const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', sigData));

    const k = Math.ceil(bitLength(this.n) / 8);
    const block = new Uint8Array(k - 1);
    block[0] = 0x01;
    block.fill(0xff, 1, k - 1 - digest.length - 1);
    block[k - 2 - digest.length] = 0x00;
    block.set(digest, k - 1 - digest.length);

    let m = 0n;
    for (const b of block) m = (m << 8n) | BigInt(b);
    let s = modPow(m, this.d, this.n);
    const sig = new Uint8Array(k);
    for (let i = k - 1; i >= 0 && s > 0n; i--) {
      sig[i] = Number(s & 0xffn);
      s >>= 8n;
    }
    return `${bytesToBase64(sig)}:${dateStr}`;
  }
}
