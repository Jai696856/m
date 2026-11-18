// Usage:
//   node render.js <episode.json> <narration.mp3> <out.mp4>
//   node render.js <episode.json> <narration.mp3> --stills <dir> <t1,t2,...>
const { chromium } = require('playwright');
const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

(async () => {
  const [epPath, audio, out, ...rest] = process.argv.slice(2);
  const episode = JSON.parse(fs.readFileSync(epPath, 'utf8'));
  const tlJson = execFileSync('python3', [path.join(__dirname, 'timeline.py'), epPath, audio]).toString();
  const { timeline, duration } = JSON.parse(tlJson);
  for (const s of timeline) console.log(s.t0.toFixed(2), s.t1.toFixed(2), s.scene, s.text.slice(0, 40));

  const browser = await chromium.launch({ args: ['--allow-file-access-from-files', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  page.on('pageerror', e => console.error('PAGE ERROR', e.message));
  page.on('console', m => { if (m.type() === 'error') console.error('CONSOLE', m.text()); });
  await page.goto('file://' + path.join(__dirname, 'episode.html'));
  await page.evaluate(d => init(d), { timeline, episode });
  if (episode.render3d) await page.waitForFunction(() => window.bg3dReady === true, null, { timeout: 60000 });
  await page.evaluate(() => document.fonts.ready);

  if (out === '--stills') {
    const [dir, times] = rest;
    fs.mkdirSync(dir, { recursive: true });
    for (const t of times.split(',').map(Number)) {
      await page.evaluate(tt => render(tt), t);
      await page.screenshot({ path: path.join(dir, `t_${String(t.toFixed(1)).padStart(5, '0')}.png`) });
    }
    await browser.close();
    return;
  }

  const fps = 30, n = Math.floor(duration * fps);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
    '-i', audio, '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '192k', '-t', duration.toFixed(3), '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  for (let i = 0; i < n; i++) {
    await page.evaluate(t => render(t), i / fps);
    const buf = await page.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (i % 300 === 0) console.log(`frame ${i}/${n}`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await browser.close();
  console.log('wrote', out);
})();
