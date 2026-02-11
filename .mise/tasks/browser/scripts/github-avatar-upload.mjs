// github-avatar-upload.mjs — Upload a GitHub profile avatar
//
// Usage: shimmer browser:run github-avatar-upload <image-path>

import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

export const site = 'github.com';

export default async function({ page, args }) {
  const imagePath = args[0];
  if (!imagePath) {
    console.error('Usage: shimmer browser:run github-avatar-upload <image-path>');
    process.exit(1);
  }

  const resolvedPath = resolve(imagePath);
  if (!existsSync(resolvedPath)) {
    console.error(`Image not found: ${resolvedPath}`);
    process.exit(1);
  }

  console.log(`Uploading avatar from: ${resolvedPath}`);

  await page.goto('https://github.com/settings/profile');
  await page.waitForLoadState('domcontentloaded');

  // GitHub has a file input for the avatar — find it and upload
  const fileInput = page.locator('input[type="file"]').first();
  await fileInput.waitFor({ state: 'attached', timeout: 15000 });
  await fileInput.setInputFiles(resolvedPath);

  // Wait a moment for crop/confirmation dialog
  await page.waitForTimeout(3000);

  // Look for a confirmation button in the crop dialog
  const confirmButton = page.getByRole('button', { name: /set new profile picture/i });
  if (await confirmButton.isVisible({ timeout: 5000 }).catch(() => false)) {
    await confirmButton.click();
    await page.waitForTimeout(3000);
  } else {
    console.log('No crop dialog — upload may have completed directly.');
    await page.waitForTimeout(2000);
  }

  console.log('Avatar uploaded.');
}
