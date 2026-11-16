// Usage: node make_icon.js <outDir>
// Writes channel-icon.png (800x800 square), channel-icon-2048.png, and channel-icon-round-preview.png.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

(async () => {
  const out = process.argv[2];
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  for (const [name, scale, round] of [['channel-icon.png', 1, false], ['channel-icon-2048.png', 2.56, false], ['channel-icon-round-preview.png', 1, true]]) {
    const page = await browser.newPage({ viewport: { width: 800, height: 800 }, deviceScaleFactor: scale });
    await page.goto('file://' + path.join(__dirname, 'icon.html'));
    await page.evaluate(r => { document.getElementById('root').innerHTML = icon(r); }, round);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(out, name), omitBackground: true });
    await page.close();
  }
  await browser.close();
  console.log('done');
})();
