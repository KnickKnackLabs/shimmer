// _harness.mjs — Playwright harness for shimmer browser tasks
//
// Modes:
//   login: Save storageState after authenticating (auto or interactive)
//   run:   Load storageState, run a script module, close browser

import { chromium } from 'playwright';
import { parseArgs } from 'node:util';
import { existsSync, chmodSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

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

  const browser = await chromium.launch({ headless: automated ? true : false });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`https://${site}/login`);

  // Save auth state when navigating away from the login page.
  // For interactive mode: save on EVERY qualifying navigation (not just the first),
  // because login may involve multiple steps (device verification, 2FA, etc.)
  // and we want the final state before the user closes the browser.
  // We can't save after browser disconnect because the context is already gone.
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
    if (url.includes('/login') || url.includes('/sessions/') || url === 'about:blank') return;
    await saveAuth();
    if (!automated) {
      console.log('Auth captured.');
    }
  });

  if (automated) {
    // Fill login form automatically (site-specific)
    if (site === 'github.com') {
      await page.fill('input[name="login"]', username);
      await page.fill('input[name="password"]', password);
      await page.click('input[type="submit"], button[type="submit"]');
    } else {
      // Generic: try common selectors
      await page.fill('input[type="email"], input[name="username"], input[name="login"]', username);
      await page.fill('input[type="password"], input[name="password"]', password);
      await page.click('button[type="submit"], input[type="submit"]');
    }

    // Wait for navigation away from login page
    await page.waitForURL((url) => !url.toString().includes('/login'), { timeout: 30000 });
    await saveAuth();
    await browser.close();

    if (saved) {
      console.log('Login successful.');
    } else {
      console.error('Login may have failed — no auth state captured.');
      process.exit(1);
    }
  } else {
    // Interactive: wait for user to close browser
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
