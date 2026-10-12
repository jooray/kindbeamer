// Turns Readability's HTML into something an EPUB can carry: a whitelist of
// elements and attributes (the page is untrusted, and the preview renders it
// inside the extension), absolute links, ids only where the table of contents
// needs them, and every image fetched and re-encoded into a format Kindle
// takes. Needs a DOM — it runs in the beam page.

const DROP = new Set([
  'script', 'style', 'noscript', 'iframe', 'object', 'embed', 'form', 'input',
  'button', 'select', 'textarea', 'svg', 'math', 'canvas', 'video', 'audio',
  'template', 'link', 'meta', 'source', 'track', 'dialog', 'map', 'area',
]);

const KEEP = new Set([
  'p', 'br', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'a', 'em', 'strong', 'b',
  'i', 'u', 's', 'sub', 'sup', 'small', 'mark', 'code', 'pre', 'kbd', 'samp',
  'var', 'blockquote', 'q', 'cite', 'abbr', 'dfn', 'ul', 'ol', 'li', 'dl', 'dt',
  'dd', 'figure', 'figcaption', 'img', 'table', 'thead', 'tbody', 'tfoot', 'tr',
  'th', 'td', 'caption', 'div', 'section', 'article', 'aside', 'header',
  'footer', 'span', 'del', 'ins',
]);

const ATTRS = {
  '*': ['lang', 'dir', 'title'],
  a: ['href'],
  img: ['src', 'alt'],
  td: ['colspan', 'rowspan'],
  th: ['colspan', 'rowspan'],
  ol: ['start'],
};

// Characters XML 1.0 does not allow, which pages do occasionally carry.
const BAD_XML_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]/g;

const MAX_SIDE = 1600;

function unwrap(el) {
  el.replaceWith(...el.childNodes);
}

function cleanUrl(value, base, schemes) {
  try {
    const u = new URL(value, base);
    return schemes.includes(u.protocol) ? u.href : null;
  } catch {
    return null;
  }
}

/**
 * Parse and whitelist `html`. Returns a detached `<div>` in an inert
 * document; images still point at their original URLs.
 */
export function sanitize(html, { baseUrl, leadImage } = {}) {
  const doc = new DOMParser().parseFromString(`<div id="kb-root">${html}</div>`, 'text/html');
  const root = doc.getElementById('kb-root');

  // Walk a snapshot, deepest first, so unwrapping never skips a node.
  const all = Array.from(root.querySelectorAll('*')).reverse();
  for (const el of all) {
    const tag = el.localName;
    if (DROP.has(tag)) {
      el.remove();
      continue;
    }
    if (!KEEP.has(tag)) {
      unwrap(el);
      continue;
    }
    const allowed = [...ATTRS['*'], ...(ATTRS[tag] ?? [])];
    for (const attr of Array.from(el.attributes)) {
      if (!allowed.includes(attr.name)) el.removeAttribute(attr.name);
    }
    if (tag === 'a') {
      const href = el.getAttribute('href');
      const abs = href && !href.startsWith('#') && cleanUrl(href, baseUrl, ['http:', 'https:', 'mailto:']);
      if (abs) el.setAttribute('href', abs);
      else unwrap(el);
    } else if (tag === 'img') {
      const src = cleanUrl(el.getAttribute('src') ?? '', baseUrl, ['http:', 'https:']);
      if (src) el.setAttribute('src', src);
      else el.remove();
    } else if (tag === 'h1') {
      // The book's own <h1> is the title.
      const h2 = doc.createElement('h2');
      h2.append(...el.childNodes);
      el.replaceWith(h2);
    }
  }

  const walker = doc.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (BAD_XML_CHARS.test(n.data)) n.data = n.data.replace(BAD_XML_CHARS, '');
  }

  const lead = leadImage && cleanUrl(leadImage, baseUrl, ['http:', 'https:']);
  if (lead && !hasImage(root, lead)) {
    const figure = doc.createElement('figure');
    const img = doc.createElement('img');
    img.setAttribute('src', lead);
    img.setAttribute('alt', '');
    img.dataset.lead = '1';
    figure.append(img);
    root.prepend(figure);
  }
  return root;
}

/**
 * Whether `root` already shows the image at `url`. Sites hand out one image
 * at many sizes (`1200px-x.png`, `x-800x600.jpg`, `x@2x.png`, `?w=…`), so
 * compare file names with the size marks taken out.
 */
function hasImage(root, url) {
  const key = (u) => {
    try {
      const name = new URL(u).pathname.split('/').pop().toLowerCase();
      return name
        .replace(/^\d+px-/, '')
        .replace(/[-_]\d+x\d+(?=\.\w+$)/, '')
        .replace(/@\dx(?=\.\w+$)/, '');
    } catch {
      return u;
    }
  };
  const want = key(url);
  return Array.from(root.querySelectorAll('img')).some((i) => key(i.getAttribute('src')) === want);
}

/** Give each `<h2>` an id and return them as table-of-contents entries. */
export function sections(root) {
  return Array.from(root.querySelectorAll('h2'))
    .map((h, i) => {
      const text = h.textContent.replace(/\s+/g, ' ').trim();
      if (!text) return null;
      h.id = `s${i + 1}`;
      return { id: h.id, text };
    })
    .filter(Boolean);
}

function sniff(b) {
  if (b[0] === 0xff && b[1] === 0xd8) return 'image/jpeg';
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return 'image/png';
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return 'image/gif';
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 && b[8] === 0x57) return 'image/webp';
  const head = new TextDecoder().decode(b.subarray(0, 256)).trimStart().toLowerCase();
  if (head.startsWith('<svg') || (head.startsWith('<?xml') && head.includes('<svg'))) return 'image/svg+xml';
  return 'other';
}

function loadImage(blob) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => resolve({ img, release: () => URL.revokeObjectURL(url) });
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('undecodable image'));
    };
    img.src = url;
  });
}

/**
 * The image as Kindle wants it: JPEG, PNG or GIF, no side over 1600px.
 * Returns null for images not worth keeping (tracking pixels, undecodable).
 */
async function normalize(bytes) {
  const type = sniff(bytes);
  let loaded;
  try {
    loaded = await loadImage(new Blob([bytes], { type: type === 'other' ? '' : type }));
  } catch {
    return null;
  }
  const { img, release } = loaded;
  try {
    let w = img.naturalWidth || (type === 'image/svg+xml' ? 800 : 0);
    let h = img.naturalHeight || (type === 'image/svg+xml' ? 600 : 0);
    if (w < 8 || h < 8) return null;
    const fits = Math.max(w, h) <= MAX_SIDE;
    if (fits && (type === 'image/jpeg' || type === 'image/png' || type === 'image/gif')) {
      return { data: bytes, mediaType: type };
    }
    const scale = Math.min(1, MAX_SIDE / Math.max(w, h));
    w = Math.round(w * scale);
    h = Math.round(h * scale);
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    // PNG keeps line art and transparency crisp; everything else is a photo
    // as far as an e-reader cares, and goes out as JPEG on white.
    const asPng = type === 'image/png' || type === 'image/svg+xml';
    if (!asPng) {
      ctx.fillStyle = '#fff';
      ctx.fillRect(0, 0, w, h);
    }
    ctx.drawImage(img, 0, 0, w, h);
    const mediaType = asPng ? 'image/png' : 'image/jpeg';
    const blob = await new Promise((r) => canvas.toBlob(r, mediaType, 0.85));
    if (!blob) return null;
    return { data: new Uint8Array(await blob.arrayBuffer()), mediaType };
  } finally {
    release();
  }
}

const EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/gif': 'gif' };

/**
 * Fetch every image under `root`, point each `<img>` at its file in the book
 * and drop the ones that could not be had. Returns the image files and how
 * many were skipped.
 *
 * @param {(url: string) => Promise<Uint8Array>} fetchBytes
 * @param {(done: number, total: number) => void} [onProgress]
 */
export async function embedImages(root, fetchBytes, onProgress) {
  const imgs = Array.from(root.querySelectorAll('img'));
  const urls = [...new Set(imgs.map((i) => i.getAttribute('src')))];
  const byUrl = new Map();
  const files = [];
  let done = 0;
  onProgress?.(0, urls.length);

  // A few at a time: enough to overlap the network, few enough to be polite.
  const queue = [...urls];
  async function worker() {
    for (let url = queue.shift(); url; url = queue.shift()) {
      try {
        const out = await normalize(await fetchBytes(url));
        if (out) byUrl.set(url, out);
      } catch {
        // Unreachable images are skipped and counted, not fatal.
      }
      onProgress?.(++done, urls.length);
    }
  }
  await Promise.all(Array.from({ length: 4 }, worker));

  let skipped = 0;
  for (const url of urls) {
    const out = byUrl.get(url);
    if (!out) {
      skipped++;
      continue;
    }
    out.path = `images/${files.length + 1}.${EXT[out.mediaType]}`;
    files.push({ path: out.path, mediaType: out.mediaType, data: out.data });
  }
  for (const img of imgs) {
    const out = byUrl.get(img.getAttribute('src'));
    if (!out) {
      const figure = img.closest('figure');
      img.remove();
      if (figure && !figure.querySelector('img')) figure.remove();
      continue;
    }
    img.setAttribute('src', out.path);
    if (!img.hasAttribute('alt')) img.setAttribute('alt', '');
    delete img.dataset.lead;
  }
  return { files, skipped };
}

/** Well-formed XHTML for the book's body. */
export function toXhtml(root) {
  const copy = root.cloneNode(true);
  copy.removeAttribute('id');
  for (const el of copy.querySelectorAll('[data-lead]')) el.removeAttribute('data-lead');
  return new XMLSerializer().serializeToString(copy);
}
