import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { packageEpub, epubFileName } from '../src/epub.js';
import { crc32 } from '../src/zip.js';

// 1×1 transparent PNG.
const PNG = Uint8Array.from(
  atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='),
  (c) => c.charCodeAt(0),
);

async function sample() {
  return packageEpub({
    title: 'Ünïcode & <Things>',
    author: 'A. Writer',
    lang: 'en',
    url: 'https://example.com/a?b=1&c=2',
    siteName: 'Example',
    bodyXhtml:
      '<div xmlns="http://www.w3.org/1999/xhtml"><h2 id="s1">First</h2><p>Body text.</p>' +
      '<figure><img src="images/1.png" alt=""/></figure></div>',
    toc: [{ id: 's1', text: 'First' }],
    images: [{ path: 'images/1.png', mediaType: 'image/png', data: PNG }],
  });
}

test('crc32 matches the standard check value', () => {
  assert.equal(crc32(new TextEncoder().encode('123456789')), 0xcbf43926);
});

test('the archive opens and starts with a stored mimetype', async () => {
  const bytes = await sample();
  assert.equal(new TextDecoder().decode(bytes.subarray(30, 38)), 'mimetype');
  assert.equal(new TextDecoder().decode(bytes.subarray(38, 58)), 'application/epub+zip');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kb-epub-'));
  const file = path.join(dir, 'a.epub');
  fs.writeFileSync(file, bytes);
  execFileSync('unzip', ['-tq', file]);
});

test('epubcheck accepts the book', { skip: !hasEpubcheck() }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kb-epub-'));
  const file = path.join(dir, 'a.epub');
  fs.writeFileSync(file, await sample());
  execFileSync('epubcheck', ['-q', file], { stdio: 'pipe' });
});

test('file names lose path separators and control characters', () => {
  assert.equal(epubFileName('a/b: c?'), 'a b c.epub');
  assert.equal(epubFileName('   '), 'article.epub');
});

function hasEpubcheck() {
  try {
    execFileSync('epubcheck', ['--version'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}
