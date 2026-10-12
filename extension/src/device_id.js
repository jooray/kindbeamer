// Serial and pid of the device this extension registers as — a port of
// lib/src/amazon/device_id.dart. Registration refuses a serial unless the pid
// is the one derived from it (SPECIFICATION.md §3), so each install mints its
// own serial and derives the pid with the Mobipocket PID function.

const SERIAL_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const PID_ALPHABET = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';
const PID_LENGTH = 8;

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c >>> 0;
  }
  return t;
})();

/** Unpadded base32 shape, 32 characters over A-Z2-7, like the reference serial. */
export function generateSerial() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (b) => SERIAL_ALPHABET[b & 31]).join('');
}

export function isValidSerial(serial) {
  return /^[A-Z2-7]{32}$/.test(serial);
}

/** The pid Amazon expects for `serial`. */
export function pidFor(serial) {
  const bytes = new TextEncoder().encode(serial);
  // CRC-32 with neither the initial nor the final inversion.
  let crc = 0;
  for (const b of bytes) crc = CRC_TABLE[(crc ^ b) & 0xff] ^ (crc >>> 8);
  crc >>>= 0;
  const folded = new Uint8Array(PID_LENGTH);
  bytes.forEach((b, i) => (folded[i % PID_LENGTH] ^= b));
  const crcBytes = [(crc >>> 24) & 0xff, (crc >>> 16) & 0xff, (crc >>> 8) & 0xff, crc & 0xff];
  let out = '';
  for (let i = 0; i < PID_LENGTH; i++) {
    const b = (folded[i] ^ crcBytes[i & 3]) & 0xff;
    out += PID_ALPHABET[(b >> 7) + (((b >> 5) & 3) ^ (b & 0x1f))];
  }
  return out;
}
