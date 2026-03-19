// _harness.mjs — Patchright harness for shimmer browser tasks
//
// Runs a script module against either an ephemeral or persistent browser.
// Auth (storageState) is loaded if provided, and updated after the script runs.
// With --browser: attach to a persistent browser via CDP instead of launching.

import { chromium } from 'patchright';
import { parseArgs } from 'node:util';
import { existsSync, readFileSync, chmodSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const { values, positionals } = parseArgs({
  options: {
    site:        { type: 'string' },
    'auth-file': { type: 'string' },
    script:      { type: 'string' },
    headed:      { type: 'string', default: 'false' },
    browser:     { type: 'string' },
  },
  allowPositionals: true,
  strict: false,
});

const site = values.site;
const authFile = values['auth-file'];
const scriptPath = values.script;
const headed = values.headed === 'true';
const browserId = values.browser;

const hasAuth = authFile && existsSync(authFile);

if (browserId) {
  // --- Persistent browser mode: connect via CDP ---
  const pidFile = `/tmp/shimmer-browser-id-${browserId}.json`;
  if (!existsSync(pidFile)) {
    console.error(`No browser found with ID ${browserId}. Run: shimmer browser:launch`);
    process.exit(1);
  }

  const info = JSON.parse(readFileSync(pidFile, 'utf-8'));
  const browser = await chromium.connectOverCDP(`http://localhost:${info.port}`);

  // Reuse existing context/page if available, otherwise create with auth
  const contexts = browser.contexts();
  let context = contexts[0];
  let page;

  if (context) {
    // Existing context — reuse it (preserves cookies, navigation state)
    const pages = context.pages();
    page = pages[0] || await context.newPage();
  } else {
    // No context yet — create one, with auth if available
    context = hasAuth
      ? await browser.newContext({ storageState: authFile })
      : await browser.newContext();
    page = await context.newPage();
  }

  const scriptModule = await import(pathToFileURL(scriptPath).href);

  try {
    await scriptModule.default({ page, context, browser, args: positionals });
  } catch (err) {
    console.error(`Script failed: ${err.message}`);
    // Disconnect but don't kill the browser
    await browser.close();
    process.exit(1);
  }

  // Save updated auth if we started with it (cookies may have been refreshed)
  if (hasAuth) {
    await context.storageState({ path: authFile });
    chmodSync(authFile, 0o600);
  }

  // Disconnect — browser stays running
  await browser.close();
} else {
  // --- Ephemeral browser mode (default) ---
  const browser = await chromium.launch({ headless: !headed });
  const context = hasAuth
    ? await browser.newContext({ storageState: authFile })
    : await browser.newContext();
  const page = await context.newPage();

  const scriptModule = await import(pathToFileURL(scriptPath).href);

  try {
    await scriptModule.default({ page, context, browser, args: positionals });
  } catch (err) {
    console.error(`Script failed: ${err.message}`);
    await browser.close();
    process.exit(1);
  }

  // Save updated auth if we started with it (cookies may have been refreshed)
  if (hasAuth) {
    await context.storageState({ path: authFile });
    chmodSync(authFile, 0o600);
  }
  await browser.close();
}
