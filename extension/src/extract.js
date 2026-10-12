// Injected into the page after vendor/Readability.js. Reads the live DOM — so
// whatever the reader is signed in to, or has scrolled into view, is what gets
// extracted — and evaluates to the article, which executeScript hands back.

(() => {
  // Chrome's PDF viewer lets scripts into its wrapper page; there is no
  // article there, but the beam page can fetch the file itself.
  if (document.contentType === 'application/pdf') return { ok: false, pdf: true };

  // Readability works on a copy, where currentSrc no longer means anything, so
  // the source the browser actually chose is noted on the live images first.
  const LAZY = ['data-src', 'data-original', 'data-lazy-src', 'data-url', 'data-hi-res-src'];
  const usable = (u) => u && !u.startsWith('data:') && !u.startsWith('blob:');

  function largestFromSrcset(srcset) {
    let best = null;
    let bestW = -1;
    for (const part of srcset.split(/,\s+/)) {
      const [url, size = '1x'] = part.trim().split(/\s+/);
      const w = parseFloat(size) * (size.endsWith('x') ? 1000 : 1);
      if (url && w > bestW) {
        best = url;
        bestW = w;
      }
    }
    return best;
  }

  function bestSource(img) {
    if (usable(img.currentSrc)) return img.currentSrc;
    for (const attr of LAZY) {
      const v = img.getAttribute(attr);
      if (usable(v)) return new URL(v, document.baseURI).href;
    }
    const set = img.getAttribute('data-srcset') || img.getAttribute('srcset');
    const fromSet = set && largestFromSrcset(set);
    if (usable(fromSet)) return new URL(fromSet, document.baseURI).href;
    return usable(img.src) ? img.src : null;
  }

  const live = Array.from(document.images);
  live.forEach((img) => {
    const src = bestSource(img);
    if (src) img.setAttribute('data-kb-src', src);
  });
  const doc = document.cloneNode(true);
  live.forEach((img) => img.removeAttribute('data-kb-src'));

  for (const img of doc.querySelectorAll('img')) {
    const src = img.getAttribute('data-kb-src');
    if (src) img.setAttribute('src', src);
    img.removeAttribute('srcset');
    img.removeAttribute('sizes');
    img.removeAttribute('data-kb-src');
  }
  // A <picture>'s <source>s would otherwise win over the src chosen above.
  for (const source of doc.querySelectorAll('picture source')) source.remove();

  const meta = (sel) => document.querySelector(sel)?.getAttribute('content')?.trim() || '';
  const leadImage = meta('meta[property="og:image"]') || meta('meta[name="twitter:image"]');

  let article = null;
  try {
    article = new Readability(doc, { charThreshold: 250 }).parse();
  } catch (e) {
    return { ok: false, error: String(e) };
  }
  if (!article || !article.content) {
    return { ok: false, error: 'No article found on this page.' };
  }
  return {
    ok: true,
    url: location.href,
    title: (article.title || document.title || '').trim(),
    byline: (article.byline || meta('meta[name="author"]') || '').trim(),
    siteName: (article.siteName || meta('meta[property="og:site_name"]') || location.hostname).trim(),
    lang: (article.lang || document.documentElement.lang || '').trim(),
    excerpt: (article.excerpt || '').trim(),
    publishedTime: article.publishedTime || meta('meta[property="article:published_time"]') || '',
    leadImage: leadImage ? new URL(leadImage, document.baseURI).href : '',
    content: article.content,
  };
})();
