// Builds the extension for each browser into dist/<browser>/ and zips it.
//
//   node build.mjs            both
//   node build.mjs firefox    one
//
// The sources are shared; only the manifest differs. Chrome runs the
// background as a service worker, Firefox as an event page, and only Firefox
// takes browser_specific_settings.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const base = JSON.parse(fs.readFileSync(path.join(here, 'manifest.json'), 'utf8'));

const targets = {
  chrome: {
    ...base,
    background: { service_worker: 'background.js', type: 'module' },
    minimum_chrome_version: '116',
  },
  firefox: {
    ...base,
    background: { scripts: ['background.js'], type: 'module' },
    browser_specific_settings: {
      gecko: {
        id: 'kindbeamer@stkn.dev',
        strict_min_version: '128.0',
        data_collection_permissions: { required: ['none'] },
      },
      gecko_android: { strict_min_version: '128.0' },
    },
  },
};

const wanted = process.argv.slice(2);
for (const [name, manifest] of Object.entries(targets)) {
  if (wanted.length && !wanted.includes(name)) continue;
  const out = path.join(here, 'dist', name);
  fs.rmSync(out, { recursive: true, force: true });
  fs.cpSync(path.join(here, 'src'), out, { recursive: true });
  fs.writeFileSync(path.join(out, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  const zip = path.join(here, 'dist', `kindbeamer-${name}-${base.version}.zip`);
  fs.rmSync(zip, { force: true });
  execFileSync('zip', ['-qr', '-X', zip, '.'], { cwd: out });
  console.log(`${name}: ${path.relative(here, out)}  ${path.relative(here, zip)}`);
}
