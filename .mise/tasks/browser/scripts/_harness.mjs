// _harness.mjs — Patchright harness for shimmer browser tasks
//
// Modes:
//   login: Save storageState after authenticating (auto or interactive)
//   run:   Load storageState, run a script module, close browser
//          With --browser: attach to persistent browser via CDP instead

import { chromium } from 'patchright';
import { parseArgs } from 'node:util';
import { existsSync, readFileSync, chmodSync } from 'node:fs';
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
    browser:     { type: 'string' },
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
const browserId = values.browser;

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
} else {
  console.error(`Unknown mode: ${mode}`);
  process.exit(1);
}
