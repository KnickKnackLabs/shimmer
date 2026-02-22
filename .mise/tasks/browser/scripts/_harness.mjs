// _harness.mjs — Playwright harness for shimmer browser tasks
//
// Modes:
//   login: Save storageState after authenticating (auto or interactive)
//   run:   Load storageState, run a script module, close browser

import { chromium } from 'playwright';
import { parseArgs } from 'node:util';
import { existsSync, chmodSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const { values, positionals } = parseArgs({
  options: {
    mode:        { type: 'string' },
    site:        { type: 'string' },
    'auth-file': { type: 'string' },
    script:      { type: 'string' },
    headed:      { type: 'string', default: 'false' },
    username:    { type: 'string' },
    password:    { type: 'string' },
  },
  allowPositionals: true,
  strict: false,
});

const mode = values.mode;
const site = values.site;
const authFile = values['auth-file'];
const scriptPath = values.script;
const headed = values.headed === 'true';
const username = values.username;
const password = values.password;

if (mode === 'login') {
  const automated = username && password;

  // Check for a site-specific login script
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const loginScriptPath = join(scriptDir, 'login', `${site}.mjs`);
  const hasLoginScript = existsSync(loginScriptPath);

  // Only go headless if we can actually automate this site
  const canAutomate = automated && hasLoginScript;
  const browser = await chromium.launch({ headless: canAutomate ? true : false });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Save auth state on navigation. For interactive mode, save on every
  // qualifying navigation because login may involve multiple steps
  // (2FA, device verification, etc.) and we want the final state before
  // the user closes the browser.
  let saved = false;
  const saveAuth = async () => {
    saved = true;
    try {
      await context.storageState({ path: authFile });
      chmodSync(authFile, 0o600);
    } catch {
      // Context may be closing
    }
  };

  page.on('framenavigated', async (frame) => {
    if (frame !== page.mainFrame()) return;
    const url = frame.url();
    if (url === 'about:blank') return;
    await saveAuth();
    if (!canAutomate) {
      console.log('Auth captured.');
    }
  });

  if (canAutomate) {
    // Automated login — per-site script handles navigation and form-filling
    const loginModule = await import(pathToFileURL(loginScriptPath).href);
    await loginModule.default({ page, username, password });
    await saveAuth();
    await browser.close();

    if (saved) {
      console.log('Login successful.');
    } else {
      console.error('Login may have failed — no auth state captured.');
      process.exit(1);
    }
  } else {
    // Interactive — navigate to site root and let human log in
    if (automated && !hasLoginScript) {
      console.log(`No automated login script for ${site} — opening interactive login.`);
    }
    await page.goto(`https://${site}`);
    await new Promise(resolve => page.on('close', resolve));
    await browser.close();
  }

} else if (mode === 'run') {
  if (!existsSync(authFile)) {
    console.error(`Auth file not found: ${authFile}`);
    console.error(`Run: shimmer browser:login ${site}`);
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: !headed });
  const context = await browser.newContext({ storageState: authFile });
  const page = await context.newPage();

  const scriptModule = await import(pathToFileURL(scriptPath).href);

  try {
    await scriptModule.default({ page, context, browser, args: positionals });
  } catch (err) {
    console.error(`Script failed: ${err.message}`);
    await browser.close();
    process.exit(1);
  }

  // Save updated auth (cookies may have been refreshed)
  await context.storageState({ path: authFile });
  chmodSync(authFile, 0o600);
  await browser.close();
} else {
  console.error(`Unknown mode: ${mode}`);
  process.exit(1);
}
