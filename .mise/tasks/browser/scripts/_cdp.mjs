// _cdp.mjs — CDP connector + action dispatch for browser primitives
//
// Usage: node _cdp.mjs --action <name> --agent <agent> [action-specific args]
//
// Connects to a running Chromium via CDP, performs one action, disconnects.
// The browser keeps running after disconnect.

import { chromium } from 'playwright';
import { parseArgs } from 'node:util';
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { chmodSync } from 'node:fs';
import { join } from 'node:path';

const { values, positionals } = parseArgs({
  options: {
    action:   { type: 'string' },
    agent:    { type: 'string' },
    // content
    selector: { type: 'string' },
    depth:    { type: 'string', default: '1' },
    // fill
    value:    { type: 'string' },
    // screenshot
    stdout:   { type: 'boolean', default: false },
    // wait
    timeout:  { type: 'string', default: '30000' },
    // save-auth / load-auth
    site:     { type: 'string' },
  },
  allowPositionals: true,
  strict: false,
});

const action = values.action;
const agent = values.agent;

if (!action) {
  console.error('Usage: node _cdp.mjs --action <name> --agent <agent> [args]');
  process.exit(1);
}

// --- CDP connection ---

function pidFilePath(agentName) {
  return `/tmp/shimmer-browser-${agentName}.json`;
}

async function connect(agentName) {
  const pidFile = pidFilePath(agentName);
  if (!existsSync(pidFile)) {
    console.error(`No browser running for ${agentName}. Run: shimmer browser:launch`);
    process.exit(1);
  }

  const info = JSON.parse(readFileSync(pidFile, 'utf-8'));
  const port = info.port;

  const browser = await chromium.connectOverCDP(`http://localhost:${port}`);
  const contexts = browser.contexts();
  let context = contexts[0];
  if (!context) {
    context = await browser.newContext();
  }
  const pages = context.pages();
  let page = pages[0];
  if (!page) {
    page = await context.newPage();
  }

  return { browser, context, page };
}

// --- Auth file helpers ---

function authFilePath(agentName, site) {
  const dir = join(process.env.HOME, '.config', 'shimmer', 'browser', agentName);
  mkdirSync(dir, { recursive: true });
  return join(dir, `${site}.json`);
}

// --- Actions ---

if (action === 'goto') {
  const url = positionals[0];
  if (!url) {
    console.error('Usage: --action goto <url>');
    process.exit(1);
  }
  const { browser, page } = await connect(agent);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  console.log(page.url());
  await browser.close();

} else if (action === 'content') {
  const selector = values.selector || positionals[0] || 'body';
  const depth = parseInt(values.depth, 10);
  const { browser, page } = await connect(agent);

  const html = await page.evaluate(({ selector, depth }) => {
    const SKIP_TAGS = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'SVG']);

    function serialize(el, currentDepth, maxDepth, indent) {
      if (el.nodeType === Node.TEXT_NODE) {
        const text = el.textContent.trim();
        if (!text) return '';
        return indent + text + '\n';
      }
      if (el.nodeType !== Node.ELEMENT_NODE) return '';
      if (SKIP_TAGS.has(el.tagName)) return '';
      if (el.hidden || el.getAttribute('aria-hidden') === 'true') return '';

      const tag = el.tagName.toLowerCase();
      // Build attribute string (only useful ones)
      const attrs = [];
      for (const name of ['id', 'class', 'name', 'type', 'value', 'href', 'src', 'action', 'method', 'placeholder', 'role', 'aria-label', 'for']) {
        const val = el.getAttribute(name);
        if (val) attrs.push(`${name}="${val}"`);
      }
      const attrStr = attrs.length ? ' ' + attrs.join(' ') : '';

      // Self-closing tags
      if (['input', 'img', 'br', 'hr', 'meta', 'link'].includes(tag)) {
        return indent + `<${tag}${attrStr}>\n`;
      }

      // At max depth, collapse children
      if (currentDepth >= maxDepth) {
        const hasChildren = el.children.length > 0 || el.textContent.trim();
        if (hasChildren) {
          return indent + `<${tag}${attrStr}>...</${tag}>\n`;
        }
        return indent + `<${tag}${attrStr}></${tag}>\n`;
      }

      // Recurse into children
      let inner = '';
      for (const child of el.childNodes) {
        inner += serialize(child, currentDepth + 1, maxDepth, indent + '  ');
      }

      if (!inner.trim()) {
        const text = el.textContent.trim();
        if (text) {
          return indent + `<${tag}${attrStr}>${text}</${tag}>\n`;
        }
        return indent + `<${tag}${attrStr}></${tag}>\n`;
      }

      return indent + `<${tag}${attrStr}>\n` + inner + indent + `</${tag}>\n`;
    }

    const root = document.querySelector(selector);
    if (!root) return `No element found for selector: ${selector}`;
    return serialize(root, 0, depth, '');
  }, { selector, depth });

  process.stdout.write(html);
  await browser.close();

} else if (action === 'fill') {
  const selector = values.selector || positionals[0];
  const fillValue = values.value || positionals[1];
  if (!selector || fillValue === undefined) {
    console.error('Usage: --action fill --selector <sel> --value <val>');
    process.exit(1);
  }
  const { browser, page } = await connect(agent);
  await page.fill(selector, fillValue);
  await browser.close();

} else if (action === 'click') {
  const selector = values.selector || positionals[0];
  if (!selector) {
    console.error('Usage: --action click --selector <sel>');
    process.exit(1);
  }
  const { browser, page } = await connect(agent);
  await page.click(selector);
  await browser.close();

} else if (action === 'screenshot') {
  const { browser, page } = await connect(agent);
  if (values.stdout) {
    const buf = await page.screenshot({ type: 'png' });
    process.stdout.write(buf);
  } else {
    const dir = '/tmp/shimmer-screenshots';
    mkdirSync(dir, { recursive: true });
    const path = join(dir, `${agent}-${Date.now()}.png`);
    await page.screenshot({ path, type: 'png' });
    console.log(path);
  }
  await browser.close();

} else if (action === 'save-auth') {
  const site = values.site || positionals[0];
  if (!site) {
    console.error('Usage: --action save-auth --site <site>');
    process.exit(1);
  }
  const { browser, context } = await connect(agent);
  const authPath = authFilePath(agent, site);
  await context.storageState({ path: authPath });
  chmodSync(authPath, 0o600);
  console.log(`Auth saved: ${authPath}`);
  await browser.close();

} else if (action === 'load-auth') {
  const site = values.site || positionals[0];
  if (!site) {
    console.error('Usage: --action load-auth --site <site>');
    process.exit(1);
  }
  const authPath = authFilePath(agent, site);
  if (!existsSync(authPath)) {
    console.error(`No auth found: ${authPath}`);
    console.error(`Run: shimmer browser:login ${site}`);
    process.exit(1);
  }

  // Load auth by adding cookies from the stored state
  const { browser, context } = await connect(agent);
  const state = JSON.parse(readFileSync(authPath, 'utf-8'));
  if (state.cookies && state.cookies.length > 0) {
    await context.addCookies(state.cookies);
  }
  console.log(`Auth loaded from: ${authPath}`);
  await browser.close();

} else if (action === 'wait') {
  const selector = values.selector || positionals[0];
  if (!selector) {
    console.error('Usage: --action wait --selector <sel> [--timeout <ms>]');
    process.exit(1);
  }
  const timeout = parseInt(values.timeout, 10);
  const { browser, page } = await connect(agent);
  await page.waitForSelector(selector, { timeout });
  await browser.close();

} else {
  console.error(`Unknown action: ${action}`);
  process.exit(1);
}
