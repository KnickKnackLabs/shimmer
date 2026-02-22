// github.com login — navigate to login page, fill form, submit
export default async function({ page, username, password }) {
  await page.goto('https://github.com/login');
  await page.fill('input[name="login"]', username);
  await page.fill('input[name="password"]', password);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForURL((url) => !url.toString().includes('/login'), { timeout: 30000 });
}
