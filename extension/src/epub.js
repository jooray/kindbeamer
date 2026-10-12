// Packages an extracted article as an EPUB 3 with an EPUB 2 NCX alongside,
// which is what Amazon's converter and older readers both understand. The
// body arrives already serialized as XHTML (article.js); this file only lays
// out the container, so it runs anywhere, Node tests included.

import { zip } from './zip.js';

export function escapeXml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const STYLE = `body { margin: 0 5%; line-height: 1.45; }
h1 { font-size: 1.6em; line-height: 1.2; margin: 0 0 0.4em; }
h2 { font-size: 1.3em; } h3 { font-size: 1.1em; }
p.byline { margin: 0; font-style: italic; }
p.source { margin: 0.2em 0 1.6em; font-size: 0.8em; word-wrap: break-word; }
img { max-width: 100%; height: auto; }
figure { margin: 1em 0; text-align: center; }
figcaption { font-size: 0.85em; font-style: italic; }
blockquote { margin: 1em 1.5em; font-style: italic; }
pre { white-space: pre-wrap; font-size: 0.85em; }
table { border-collapse: collapse; } td, th { border: 1px solid #888; padding: 0.2em 0.4em; }
`;

/**
 * @param {object} a
 * @param {string} a.title
 * @param {string} a.author
 * @param {string} [a.lang]
 * @param {string} [a.url]          the page the article came from
 * @param {string} [a.siteName]
 * @param {string} a.bodyXhtml      well-formed XHTML for inside <body>
 * @param {{id: string, text: string}[]} [a.toc]  section anchors in the body
 * @param {{path: string, mediaType: string, data: Uint8Array}[]} [a.images]
 *   paths relative to the article, e.g. `images/1.jpg`
 * @param {string} [a.coverPath]    one of the image paths, used as the cover
 * @returns {Promise<Uint8Array>}
 */
export async function packageEpub(a, now = new Date()) {
  const lang = a.lang || 'en';
  const id = `urn:uuid:${crypto.randomUUID()}`;
  const title = escapeXml(a.title);
  const author = escapeXml(a.author);
  const modified = now.toISOString().replace(/\.\d{3}Z$/, 'Z');
  const images = a.images ?? [];
  const toc = a.toc ?? [];

  const bylineParts = [a.author !== 'Unknown' ? a.author : '', a.siteName].filter(Boolean);
  const header =
    `<h1>${title}</h1>` +
    (bylineParts.length ? `<p class="byline">${escapeXml(bylineParts.join(' · '))}</p>` : '') +
    (a.url ? `<p class="source"><a href="${escapeXml(a.url)}">${escapeXml(a.url)}</a></p>` : '');

  const article = `<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="${escapeXml(lang)}" xml:lang="${escapeXml(lang)}">
<head><meta charset="utf-8"/><title>${title}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>${header}${a.bodyXhtml}</body>
</html>
`;

  const navItems = [`<li><a href="article.xhtml">${title}</a></li>`]
    .concat(toc.map((t) => `<li><a href="article.xhtml#${escapeXml(t.id)}">${escapeXml(t.text)}</a></li>`))
    .join('');
  const nav = `<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="${escapeXml(lang)}" xml:lang="${escapeXml(lang)}">
<head><meta charset="utf-8"/><title>${title}</title></head>
<body><nav epub:type="toc" id="toc"><h1>Contents</h1><ol>${navItems}</ol></nav></body>
</html>
`;

  const navPoints = [{ src: 'article.xhtml', text: a.title }]
    .concat(toc.map((t) => ({ src: `article.xhtml#${t.id}`, text: t.text })))
    .map(
      (p, i) =>
        `<navPoint id="np${i + 1}" playOrder="${i + 1}"><navLabel><text>${escapeXml(p.text)}</text></navLabel><content src="${escapeXml(p.src)}"/></navPoint>`,
    )
    .join('');
  const ncx = `<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
<head><meta name="dtb:uid" content="${id}"/><meta name="dtb:depth" content="1"/><meta name="dtb:totalPageCount" content="0"/><meta name="dtb:maxPageNumber" content="0"/></head>
<docTitle><text>${title}</text></docTitle>
<navMap>${navPoints}</navMap>
</ncx>
`;

  const imageItems = images
    .map((img, i) => {
      const cover = img.path === a.coverPath ? ' properties="cover-image"' : '';
      return `<item id="img${i + 1}" href="${escapeXml(img.path)}" media-type="${img.mediaType}"${cover}/>`;
    })
    .join('\n    ');
  const coverMeta = a.coverPath
    ? `\n    <meta name="cover" content="img${images.findIndex((i) => i.path === a.coverPath) + 1}"/>`
    : '';
  const opf = `<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="${escapeXml(lang)}">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">${id}</dc:identifier>
    <dc:title>${title}</dc:title>
    <dc:creator>${author}</dc:creator>
    <dc:language>${escapeXml(lang)}</dc:language>${a.siteName ? `\n    <dc:publisher>${escapeXml(a.siteName)}</dc:publisher>` : ''}${a.url ? `\n    <dc:source>${escapeXml(a.url)}</dc:source>` : ''}
    <meta property="dcterms:modified">${modified}</meta>${coverMeta}
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="style" href="style.css" media-type="text/css"/>
    <item id="article" href="article.xhtml" media-type="application/xhtml+xml"/>
    ${imageItems}
  </manifest>
  <spine toc="ncx">
    <itemref idref="article"/>
  </spine>
</package>
`;

  const container = `<?xml version="1.0" encoding="utf-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>
`;

  return zip(
    [
      { name: 'mimetype', data: 'application/epub+zip', store: true },
      { name: 'META-INF/container.xml', data: container },
      { name: 'OEBPS/content.opf', data: opf },
      { name: 'OEBPS/nav.xhtml', data: nav },
      { name: 'OEBPS/toc.ncx', data: ncx },
      { name: 'OEBPS/style.css', data: STYLE },
      { name: 'OEBPS/article.xhtml', data: article },
      // Images are already compressed; deflating them only costs time.
      ...images.map((img) => ({ name: `OEBPS/${img.path}`, data: img.data, store: true })),
    ],
    now,
  );
}

/** A file name for the downloaded book. */
export function epubFileName(title) {
  const base = String(title)
    .replace(/[\\/:*?"<>|\u0000-\u001f]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 120);
  return `${base || 'article'}.epub`;
}
