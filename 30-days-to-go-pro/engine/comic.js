// Comic-book art style (Day 3+): thick outlines, halftone, speed lines, action bursts,
// and an articulated athlete that can run, juggle, kick and celebrate.
const INK = '#111';
const COMIC_DEFS = `<defs>
<pattern id="ht" width="16" height="16" patternUnits="userSpaceOnUse" patternTransform="rotate(30)"><circle cx="8" cy="8" r="3.2" fill="#000" opacity=".22"/></pattern>
<pattern id="htL" width="22" height="22" patternUnits="userSpaceOnUse" patternTransform="rotate(30)"><circle cx="11" cy="11" r="4.5" fill="#fff" opacity=".18"/></pattern>
<linearGradient id="cSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d6cdf"/><stop offset=".65" stop-color="#7fb3ff"/><stop offset="1" stop-color="#ffe2a8"/></linearGradient>
<linearGradient id="cDusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a1c71"/><stop offset=".55" stop-color="#d76d77"/><stop offset="1" stop-color="#ffaf7b"/></linearGradient>
<linearGradient id="cPop" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff3d6e"/><stop offset="1" stop-color="#ff9a3d"/></linearGradient>
<linearGradient id="cBlue" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1e3c72"/><stop offset="1" stop-color="#2a5298"/></linearGradient>
<linearGradient id="cGreen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#11998e"/><stop offset="1" stop-color="#38ef7d"/></linearGradient>
</defs>`;

const ink = (w = 8) => `stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
const ctext = (x, y, s, size, fill, extra = '') =>
  `<text ${extra} x="${x}" y="${y}" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fill}" stroke="${INK}" stroke-width="${Math.max(6, size * 0.12)}" stroke-linejoin="round" paint-order="stroke" text-anchor="middle" dominant-baseline="central">${s}</text>`;

function burst(x, y, label, size, fill, t0, t, rot = -8, pts = 14) {
  const p = (t - t0) / 0.28;
  if (p <= 0) return '';
  const sc = eb(p), wob = 1 + 0.03 * Math.sin(t * 20);
  const R = label.length * size * 0.42 + 70, r = R * 0.72;
  let poly = '';
  for (let i = 0; i < pts * 2; i++) {
    const a = i * Math.PI / pts, rr = i % 2 ? r : R * (0.92 + 0.08 * ((i * 7) % 3));
    poly += `${Math.cos(a) * rr},${Math.sin(a) * rr * 0.62} `;
  }
  return `<g transform="translate(${x},${y}) rotate(${rot}) scale(${sc * wob})"><polygon points="${poly}" fill="${fill}" ${ink(10)}/>
  <polygon points="${poly}" fill="url(#ht)" opacity=".6"/>${ctext(0, 4, label, size, '#fff')}</g>`;
}

function speedLines(cx, cy, t, col = '#fff', op = .5, n = 26) {
  let s = `<g opacity="${op}">`;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + (i % 3) * 0.05, r0 = 420 + ((i * 97 + Math.floor(t * 12) * 31) % 160), r1 = 1500;
    const w = 6 + (i % 4) * 5;
    s += `<path d="M${cx + Math.cos(a) * r0},${cy + Math.sin(a) * r0} L${cx + Math.cos(a + 0.012) * r1},${cy + Math.sin(a + 0.012) * r1} L${cx + Math.cos(a - 0.012) * r1},${cy + Math.sin(a - 0.012) * r1}Z" fill="${col}" stroke="${col}" stroke-width="${w}"/>`;
  }
  return s + '</g>';
}

function captionBox(x, y, label, t0, t, bg = Y, fg = '#111', size = 46) {
  const p = eb((t - t0) / 0.3);
  if (p <= 0) return '';
  const w = label.length * size * 0.66 + 60;
  return `<g transform="translate(${x},${y}) rotate(-2) scale(${p})"><rect x="${-w / 2}" y="${-size * 0.85}" width="${w}" height="${size * 1.7}" fill="${bg}" ${ink(8)}/>
  <rect x="${-w / 2 + 12}" y="${size * 0.85}" width="${w}" height="12" fill="${INK}"/>
  <text x="0" y="4" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fg}" text-anchor="middle" dominant-baseline="central">${label}</text></g>`;
}

function comicBall(x, y, r, rot = 0) {
  return `<g transform="translate(${x},${y})"><circle r="${r + 4}" fill="${INK}"/>${soccerBall(0, 0, r, rot)}</g>`;
}

// ------------------------------------------------------------- athlete rig ---
// Angles in degrees: 0 = straight down, positive = toward the direction he faces.
const P = (x, y, a, L) => [x + L * Math.sin(a * Math.PI / 180), y + L * Math.cos(a * Math.PI / 180)];

function pose(name, t, k = 0) {
  const base = { lean: 4, hipY: 0, tL: 4, sL: 2, tR: -4, sR: -2, aL: 10, fL: 30, aR: -10, fR: 20, expr: 'det' };
  if (name === 'run') {
    const p = t * 13;
    const tf = 45 * Math.sin(p), tb = -45 * Math.sin(p);
    return { ...base, lean: 14, hipY: -10 * Math.abs(Math.cos(p)),
      tL: tf, sL: tf - 25 - 55 * Math.max(0, -Math.cos(p)), tR: tb, sR: tb - 25 - 55 * Math.max(0, Math.cos(p)),
      aL: -50 * Math.sin(p), fL: -50 * Math.sin(p) + 95, aR: 50 * Math.sin(p), fR: 50 * Math.sin(p) + 95, expr: k ? 'tired' : 'det' };
  }
  if (name === 'juggle') {
    const up = Math.max(0, Math.sin(k * Math.PI));
    return { ...base, lean: 6, tL: 15 + 55 * up, sL: 15 + 55 * up - 75 * up, tR: -2, sR: -2, aL: 55, fL: 85, aR: -40, fR: -20, expr: 'focus' };
  }
  if (name === 'kick') {
    const sw = k < 0.45 ? lerp(0, -55, eo(k / 0.45)) : lerp(-55, 95, eo((k - 0.45) / 0.3));
    const bend = k < 0.45 ? lerp(0, 80, k / 0.45) : lerp(80, 0, clamp((k - 0.45) / 0.25));
    return { ...base, lean: k > 0.45 ? -8 : 10, tL: sw, sL: sw - bend, tR: -6, sR: -10, aL: -60, fL: -30, aR: 70, fR: 110, expr: 'focus' };
  }
  if (name === 'celebrate') {
    const j = Math.abs(Math.sin(t * 7));
    return { ...base, lean: 0, hipY: -40 * j, tL: 10 + 20 * j, sL: -10 * j, tR: -10 - 20 * j, sR: 10 * j, aL: 160, fL: 175, aR: -160, fR: -175, expr: 'happy' };
  }
  if (name === 'tired') {
    return { ...base, lean: 42, hipY: 18, tL: 30, sL: -12, tR: 18, sR: -18, aL: 30, fL: 8, aR: 22, fR: 2, expr: 'tired' };
  }
  if (name === 'sad') return { ...base, lean: 10, aL: 5, fL: 5, aR: -5, fR: -5, expr: 'sad' };
  if (name === 'dribble') {
    const r = pose('run', t * 0.7);
    return { ...r, lean: 18, expr: 'focus' };
  }
  const br = Math.sin(t * 2.5) * 2;
  return { ...base, aL: 10 + br, aR: -10 - br };
}

const LOOKS = {
  marcus: { top: '#7b8396', topD: '#5d6475', pants: '#25304a', skin: '#8a5638', hair: '#1b120d', shoe: '#ffffff', twists: true },
  kid1: { top: '#e74c3c', topD: '#b83a2e', pants: '#1d1d1d', skin: '#6a3f27', hair: '#140c08', shoe: '#ffd60a' },
  kid2: { top: '#2f80ed', topD: '#215fb3', pants: '#2a2a2a', skin: '#c68e6a', hair: '#3b2416', shoe: '#ffffff' },
  kid3: { top: '#27ae60', topD: '#1d8148', pants: '#1d1d1d', skin: '#4a2c1a', hair: '#0d0806', shoe: '#ff3d6e' },
};

function athlete(x, y, s, who, ps, t, face = 1, blink = false) {
  const L = LOOKS[who];
  const hip = [0, -200 + ps.hipY];
  const sh = P(hip[0], hip[1], 180 - ps.lean, 150);
  const neck = P(sh[0], sh[1], 180 - ps.lean, 26);
  const head = P(neck[0], neck[1], 180 - ps.lean * 0.6, 44);
  const limb = (a, b, w, col) => `<path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${INK}" stroke-width="${w + 12}" stroke-linecap="round"/><path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${col}" stroke-width="${w}" stroke-linecap="round"/>`;
  const leg = (tA, sA, col, shoe) => {
    const kn = P(hip[0], hip[1], tA, 98), ft = P(kn[0], kn[1], sA, 96), toe = P(ft[0], ft[1], sA + 90, 30);
    return limb(hip, kn, 40, col) + limb(kn, ft, 34, col) + limb(ft, toe, 24, shoe);
  };
  const arm = (aA, fA, col) => {
    const el = P(sh[0], sh[1], aA, 74), hd = P(el[0], el[1], fA, 66);
    return limb(sh, el, 28, col) + limb(el, hd, 24, col) + `<circle cx="${hd[0]}" cy="${hd[1]}" r="15" fill="${L.skin}" ${ink(5)}/>`;
  };
  let g = `<g transform="translate(${x},${y}) scale(${s * face},${s})">
  <ellipse cx="0" cy="6" rx="${80 + Math.abs(ps.hipY)}" ry="14" fill="#000" opacity=".28"/>`;
  g += arm(ps.aR, ps.fR, L.topD) + leg(ps.tR, ps.sR, L.pants, L.shoe);
  // torso
  const tw = 54;
  g += `<path d="M${hip[0] - tw * 0.8},${hip[1] + 10} L${sh[0] - tw},${sh[1] + 6} Q${sh[0]},${sh[1] - 22} ${sh[0] + tw},${sh[1] + 6} L${hip[0] + tw * 0.8},${hip[1] + 10} Z" fill="${L.top}" ${ink(8)}/>`;
  g += `<path d="M${hip[0] - tw * 0.8 + 10},${hip[1] - 4} L${hip[0] + tw * 0.8 - 10},${hip[1] - 4}" stroke="${L.topD}" stroke-width="14"/>`;
  g += leg(ps.tL, ps.sL, L.pants, L.shoe);
  g += `<rect x="${neck[0] - 13}" y="${neck[1] - 6}" width="26" height="30" fill="${L.skin}" ${ink(5)}/>`;
  g += comicHead(head[0], head[1], L, ps.expr, blink);
  g += arm(ps.aL, ps.fL, L.top);
  return g + '</g>';
}

function comicHead(x, y, L, expr, blink) {
  let s = `<g transform="translate(${x},${y})"><ellipse cx="-44" cy="4" rx="9" ry="14" fill="${L.skin}" ${ink(5)}/><ellipse cx="44" cy="4" rx="9" ry="14" fill="${L.skin}" ${ink(5)}/>
  <ellipse cx="0" cy="0" rx="44" ry="52" fill="${L.skin}" ${ink(7)}/>
  <path d="M10,-48 C40,-40 46,0 40,30 C30,50 12,52 0,52 C30,30 32,-10 10,-48Z" fill="#000" opacity=".16"/>`;
  s += `<path d="M-46,-8 C-50,-52 -22,-62 0,-62 C24,-62 50,-52 46,-8 C38,-30 22,-36 0,-36 C-22,-36 -38,-30 -46,-8Z" fill="${L.hair}" ${ink(5)}/>`;
  if (L.twists) for (let i = 0; i < 7; i++) { const a = Math.PI * (0.15 + i * 0.12); s += `<circle cx="${-Math.cos(a) * 40}" cy="${-30 - Math.sin(a) * 30}" r="12" fill="${L.hair}" ${ink(4)}/>`; }
  const eyeY = -4;
  if (blink || expr === 'tired') s += `<path d="M-24,${eyeY} h18 M6,${eyeY} h18" ${ink(5)}/>`;
  else s += `<ellipse cx="-15" cy="${eyeY}" rx="10" ry="12" fill="#fff" ${ink(4)}/><ellipse cx="15" cy="${eyeY}" rx="10" ry="12" fill="#fff" ${ink(4)}/>
    <circle cx="-13" cy="${eyeY + 1}" r="5" fill="${INK}"/><circle cx="17" cy="${eyeY + 1}" r="5" fill="${INK}"/>`;
  const brow = { det: 'M-28,-22 L-6,-16 M6,-16 L28,-22', focus: 'M-28,-20 L-6,-18 M6,-18 L28,-20', happy: 'M-28,-26 Q-17,-32 -6,-26 M6,-26 Q17,-32 28,-26', sad: 'M-28,-16 L-6,-24 M6,-24 L28,-16', tired: 'M-28,-16 L-6,-22 M6,-22 L28,-16' }[expr] || 'M-28,-22 L-6,-20 M6,-20 L28,-22';
  s += `<path d="${brow}" ${ink(7)} fill="none"/>`;
  const mouth = {
    det: `<path d="M-14,24 Q2,30 16,20" ${ink(5)} fill="none"/>`,
    focus: `<path d="M-10,26 H10" ${ink(5)}/>`,
    happy: `<path d="M-20,18 Q0,48 20,18 Z" fill="#5a1a10" ${ink(5)}/><path d="M-14,21 Q0,27 14,21" stroke="#fff" stroke-width="5"/>`,
    sad: `<path d="M-14,30 Q0,20 14,30" ${ink(5)} fill="none"/>`,
    tired: `<ellipse cx="0" cy="28" rx="12" ry="9" fill="#5a1a10" ${ink(4)}/>`,
  }[expr] || `<path d="M-12,26 H12" ${ink(5)}/>`;
  s += mouth + `<path d="M0,2 Q-6,14 2,16" ${ink(4)} fill="none"/>`;
  if (expr === 'tired') s += `<path d="M52,-24 q8,14 0,20 q-8,-6 0,-20Z" fill="#7fd3ff" ${ink(3)}/><path d="M-58,-10 q8,14 0,20 q-8,-6 0,-20Z" fill="#7fd3ff" ${ink(3)}/>`;
  return s + '</g>';
}

// ------------------------------------------------------------ backgrounds ---
function comicPitch(t, opt = {}) {
  const horizon = opt.horizon || 980, scroll = opt.scroll || 0;
  let s = `<rect width="${W}" height="${H}" fill="url(#${opt.sky || 'cSky'})"/><rect width="${W}" height="${horizon}" fill="url(#htL)"/>`;
  s += `<circle cx="820" cy="${horizon - 330}" r="120" fill="#fff4c2" ${ink(8)}/>`;
  const sky = [[0, 70, 260], [70, 90, 340], [160, 60, 230], [220, 110, 400], [330, 70, 300], [400, 90, 360], [490, 60, 250], [550, 120, 420], [670, 70, 290], [740, 90, 350], [830, 60, 240], [890, 110, 380], [1000, 80, 300]];
  s += `<g transform="translate(${-((scroll * 0.3) % 1080)},0)">`;
  for (const k of [0, 1080]) for (const [x, w, h] of sky) {
    s += `<rect x="${x + k}" y="${horizon - h}" width="${w}" height="${h}" fill="#3b4a7a" ${ink(6)}/>`;
    for (let wy = horizon - h + 30; wy < horizon - 30; wy += 46) s += `<rect x="${x + k + 16}" y="${wy}" width="${w - 32}" height="14" fill="#ffd166" opacity=".55"/>`;
  }
  s += `</g>`;
  // fence
  s += `<g opacity=".55" stroke="#dfe6f3" stroke-width="3">`;
  for (let i = -20; i < 40; i++) { const x = i * 46 - (scroll % 46); s += `<path d="M${x},${horizon - 230} L${x + 230},${horizon}"/><path d="M${x + 230},${horizon - 230} L${x},${horizon}"/>`; }
  s += `</g><rect y="${horizon - 236}" width="${W}" height="12" fill="#9aa4b8" ${ink(5)}/>`;
  // turf
  s += `<rect y="${horizon}" width="${W}" height="${H - horizon}" fill="#2e9e4f" ${ink(8)}/>`;
  for (let i = -2; i < 14; i++) { const x = i * 160 - (scroll % 320); s += `<rect x="${x}" y="${horizon}" width="80" height="${H - horizon}" fill="#38b25c"/>`; }
  s += `<rect y="${horizon}" width="${W}" height="${H - horizon}" fill="url(#ht)" opacity=".5"/>`;
  s += `<path d="M0,${horizon + 60} H${W}" stroke="#fff" stroke-width="8" opacity=".85"/>`;
  return s;
}

function lapMap(x, y, laps, t, running) {
  const a = running ? t * 3.2 : -Math.PI / 2;
  return `<g transform="translate(${x},${y})"><rect x="-150" y="-110" width="300" height="220" rx="24" fill="#fff" ${ink(8)}/>
  <ellipse cx="0" cy="-10" rx="100" ry="58" fill="#2e9e4f" stroke="#e8743b" stroke-width="22"/><ellipse cx="0" cy="-10" rx="100" ry="58" fill="none" ${ink(5)}/>
  <circle cx="${Math.cos(a) * 100}" cy="${-10 + Math.sin(a) * 58}" r="14" fill="${Y}" ${ink(5)}/>
  ${ctext(0, 82, `LAPS: ${laps}`, 40, Y)}</g>`;
}

function ruleBanner(label, t0, t) {
  const p = eo((t - t0) / 0.35);
  if (p <= 0) return '';
  return `<g transform="translate(${-600 * (1 - p)},0)"><path d="M0,190 H760 L720,260 H0Z" fill="${RED}" ${ink(8)}/>
  <text x="40" y="226" font-family="${FONT}" font-size="40" font-weight="900" fill="#fff" dominant-baseline="central">${label}</text></g>`;
}

function commentCard(x, y, w, c, t0, t, highlight = []) {
  const p = eb((t - t0) / 0.45);
  if (p <= 0) return '';
  const size = 40, maxc = Math.floor((w - 170) / (size * 0.5));
  const words = c.text.split(' '); const lines = []; let cur = '';
  for (const wd of words) { if ((cur + ' ' + wd).trim().length > maxc) { lines.push(cur.trim()); cur = wd; } else cur += ' ' + wd; }
  lines.push(cur.trim());
  const h = 150 + lines.length * size * 1.25;
  let s = `<g transform="translate(${x},${y}) scale(${p}) rotate(${-1.5 * (1 - p)})">
  <rect x="${-w / 2 + 14}" y="14" width="${w}" height="${h}" rx="30" fill="${INK}"/>
  <rect x="${-w / 2}" y="0" width="${w}" height="${h}" rx="30" fill="#1f1f24" ${ink(8)}/>
  <circle cx="${-w / 2 + 70}" cy="70" r="40" fill="${c.color}" ${ink(5)}/>${ctext(-w / 2 + 70, 72, c.handle[1].toUpperCase(), 40, '#fff')}
  <text x="${-w / 2 + 130}" y="62" font-family="${FONT}" font-size="34" font-weight="800" fill="#bdbdc7" dominant-baseline="central">${c.handle} · ${c.ago}</text>`;
  lines.forEach((ln, i) => {
    let lineSvg = ln;
    for (const hl of highlight) lineSvg = lineSvg.replace(hl, `<tspan fill="${Y}">${hl}</tspan>`);
    s += `<text x="${-w / 2 + 130}" y="${120 + i * size * 1.25}" font-family="${FONT}" font-size="${size}" font-weight="700" fill="#fff" dominant-baseline="central">${lineSvg}</text>`;
  });
  s += `<text x="${-w / 2 + 130}" y="${h - 36}" font-family="${FONT}" font-size="32" font-weight="700" fill="#bdbdc7" dominant-baseline="central">♡ ${c.likes || ''}   Reply</text></g>`;
  return s;
}

const NUM = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12 };
const norm = w => w.toLowerCase().replace(/[^a-z]/g, '');
const kwN = (seg, k, n = 1) => { let c = 0; for (const [w, a] of seg.words) if (norm(w) === k && ++c === n) return a; return 1e9; };
const halftoneFX = () => `<rect width="${W}" height="${H}" fill="url(#ht)" opacity=".18"/>`;

// ----------------------------------------------------------------- scenes ---
function sC3open(t, seg) {
  const lt = t - seg.t0, cm = EP.comments.voice;
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cPop)"/>` + speedLines(540, 700, t, '#fff', .35);
  s += burst(540, 470, `DAY ${EP.day}`, 170, Y, seg.t0, t, -6, 16);
  s += commentCard(540, 760, 940, cm, kw(seg, 'asked') - 0.2, t, ['change the voice']);
  s += burst(540, 1300, 'NEW VOICE ✓', 72, '#38c172', kw(seg, 'Here'), t, 5, 12);
  s += athlete(220, 1720, 0.95, 'marcus', pose(t > kw(seg, 'Here') ? 'celebrate' : 'idle', t), t, 1, blinking(t));
  return s + halftoneFX();
}

function sRecap(t, seg) {
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cBlue)"/><rect width="${W}" height="${H}" fill="url(#htL)"/>`;
  s += ctext(540, 270, 'DAY 3 VOTE', 110, '#fff');
  const tBoth = kw(seg, 'both');
  const cards = [['A', 'SPEED', '⚡ 5 AM sprints', '#2f80ed'], ['B', 'SHOOTING', '🎯 100 shots a day', '#e74c3c'], ['C', 'BOTH', '💬 from the comments', '#27ae60']];
  cards.forEach(([l, ti, sub, col], i) => {
    const appear = eb((t - seg.t0 - i * 0.25) / 0.45);
    if (appear <= 0) return;
    const y = 470 + i * 290, chosen = i === 2 && t > tBoth, dim = t > tBoth && i < 2;
    s += `<g transform="translate(540,${y + 110}) scale(${appear * (chosen ? 1.06 : 1)}) translate(-540,-110)" opacity="${dim ? 0.5 : 1}">
      <rect x="100" y="0" width="880" height="230" rx="30" fill="#fff" ${ink(10)}/>
      <rect x="130" y="30" width="170" height="170" rx="26" fill="${col}" ${ink(8)}/>${ctext(215, 117, l, 120, '#fff')}
      ${ctext(330, 85, ti, 76, chosen ? Y : '#fff', 'text-anchor="start"')}
      <text x="332" y="160" font-family="${FONT}" font-size="38" font-weight="800" fill="#444" dominant-baseline="central">${sub}</text></g>`;
  });
  s += burst(780, 1060, 'CHOSEN!', 70, RED, tBoth, t, 10, 12);
  return s + halftoneFX();
}

function sRules(t, seg) {
  const cm = EP.comments.workout;
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cDusk)"/><rect width="${W}" height="${H}" fill="url(#htL)"/>`;
  s += commentCard(540, 230, 960, cm, seg.t0, t, ['run 1', 'lap around', "can't bounce"]);
  const r1 = kw(seg, 'lap'), r2 = kw(seg, 'bounce');
  const panel = (y, n, label, icon, t0, col) => {
    const p = eb((t - t0) / 0.4);
    if (p <= 0) return '';
    return `<g transform="translate(540,${y}) scale(${p}) rotate(${n === 1 ? -2 : 2})"><rect x="-440" y="-95" width="880" height="190" fill="${col}" ${ink(10)}/>
      <rect x="-440" y="-95" width="880" height="190" fill="url(#ht)" opacity=".35"/>
      ${ctext(-330, 0, icon, 100, '#fff')}${ctext(-230, -34, `RULE ${n}`, 40, Y, 'text-anchor="start"')}${ctext(-230, 30, label, 54, '#fff', 'text-anchor="start"')}</g>`;
  };
  s += panel(1000, 1, 'BALL DROPS = 1 LAP', '🏃', r1 - 0.6, '#2f80ed');
  s += panel(1230, 2, 'NO BOUNCE ON SHOTS', '⚽', r2 - 0.4, RED);
  s += athlete(900, 1700, 0.75, 'marcus', pose(t > kw(seg, 'after') ? 'sad' : 'idle', t), t, -1, blinking(t, .3));
  return s + halftoneFX();
}

function sJuggle(t, seg) {
  const tDrop = kw(seg, 'dropped'), tLap = Math.max(...seg.words.filter(([w]) => norm(w) === 'lap').map(([, a]) => a), seg.t0);
  const jStart = kwN(seg, 'juggling') < 1e9 ? kwN(seg, 'juggling') : seg.t0;
  const nums = seg.words.filter(([w, a]) => NUM[norm(w)] && a > jStart).map(([w, a]) => [NUM[norm(w)], a]);
  const count = nums.filter(([, a]) => a <= t).length;
  const lapsBefore = seg.lapsBefore || 0, laps = lapsBefore + (t >= tLap ? 1 : 0);
  const running = t > tDrop + 0.7;
  const scroll = running ? (t - tDrop - 0.7) * 900 : 0;
  let s = COMIC_DEFS + comicPitch(t, { scroll });
  s += ruleBanner('RULE: DROP = 1 LAP 🏃', seg.t0, t);
  if (!running) {
    // juggling beat: each spoken number is one touch
    const touches = nums.map(([, a]) => a);
    let last = seg.t0, next = touches[0] ?? seg.t0 + 0.6;
    for (const a of touches) { if (a <= t) last = a; else { next = a; break; } }
    if (last >= (touches[touches.length - 1] ?? 0) && t > last) next = last + 0.55;
    const ph = clamp((t - last) / Math.max(0.3, next - last));
    let bx = 610, by = 1450 - Math.sin(ph * Math.PI) * 360;
    let ps = pose('juggle', t, clamp(1 - ph * 3) + clamp((ph - 0.8) * 5));
    if (t > tDrop) { const f = clamp((t - tDrop) / 0.5); by = lerp(1300, 1690, eo(f)); bx = lerp(610, 760, f); ps = pose('sad', t); }
    s += athlete(470, 1720, 1.05, 'marcus', ps, t, 1, blinking(t, .5));
    s += comicBall(bx, by, 34, t * 400);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'JUGGLES', 64, '#fff')}${ctext(0, 130, count, 190, Y)}</g>`;
    s += burst(780, 1560, 'DROP!', 80, RED, tDrop + 0.35, t, 8);
  } else {
    s += speedLines(900, 1300, t, '#fff', .25, 18);
    s += athlete(480, 1720, 1.05, 'marcus', pose('run', t), t, 1);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'RUN IT!', 120, Y)}</g>`;
  }
  s += lapMap(860, 470, laps, t, running);
  s += captionBox(260, 420, seg.lapsBefore ? 'AGAIN…' : 'ROUND 1: JUGGLING', seg.t0, t);
  return s + halftoneFX();
}

function sLaps(t, seg) {
  const tJelly = kw(seg, 'jelly'), tTwelve = kw(seg, 'twelve');
  let s = COMIC_DEFS;
  if (t < tTwelve - 0.2) {
    const f = clamp((t - seg.t0) / Math.max(0.5, tJelly - seg.t0));
    const laps = Math.round(lerp(2, 10, f));
    s += comicPitch(t, { scroll: (t - seg.t0) * 1100, sky: 'cDusk' }) + speedLines(900, 1300, t, '#fff', .3, 18);
    s += athlete(480, 1720, 1.05, 'marcus', t > tJelly ? pose('tired', t) : pose('run', t, f > 0.6 ? 1 : 0), t, 1);
    s += lapMap(860, 470, laps, t, t < tJelly);
    s += `<g transform="translate(540,700)">${ctext(0, 0, `LAP ${laps}`, 170, Y)}</g>`;
    s += burst(300, 1050, 'LEGS = JELLY', 56, '#9b59b6', tJelly, t, -8);
  } else {
    const lt = t - tTwelve + 0.2, n = Math.min(12, 1 + Math.floor(lt * 8));
    const ph = (lt * 8) % 1;
    s += comicPitch(t, {}) + speedLines(540, 1000, t, Y, .35);
    s += athlete(470, 1720, 1.05, 'marcus', pose('juggle', t, clamp(1 - ph * 3)), t, 1);
    s += comicBall(610, 1450 - Math.sin(ph * Math.PI) * 300, 34, t * 600);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'JUGGLES', 64, '#fff')}${ctext(0, 130, n, 190, Y)}</g>`;
    s += burst(540, 900, 'NEW RECORD: 12', 64, '#38c172', tTwelve + 1.2, t, -6);
  }
  return s + halftoneFX();
}

function sVolley(t, seg) {
  const shots = [kw(seg, 'First'), kw(seg, 'Second'), kw(seg, 'Third')];
  let s = COMIC_DEFS + comicPitch(t, { horizon: 900 });
  // goal on the right
  const gx = 640, gy = 760, gw = 380, gh = 300;
  let bulge = 0;
  if (t > shots[2] + 0.7) bulge = Math.max(0, 1 - (t - shots[2] - 0.7) / 0.6) * 30;
  s += `<g><rect x="${gx}" y="${gy}" width="${gw}" height="${gh}" fill="#fff" opacity=".12"/>`;
  for (let i = 1; i < 12; i++) s += `<path d="M${gx + i * gw / 12},${gy} Q${gx + i * gw / 12 + bulge * 0.3},${gy + gh / 2} ${gx + i * gw / 12},${gy + gh}" stroke="#fff" stroke-width="3" opacity=".7" fill="none"/>`;
  for (let i = 1; i < 9; i++) s += `<path d="M${gx},${gy + i * gh / 9} Q${gx + gw / 2},${gy + i * gh / 9 - bulge} ${gx + gw},${gy + i * gh / 9}" stroke="#fff" stroke-width="3" opacity=".7" fill="none"/>`;
  const postShake = t > shots[1] + 0.6 && t < shots[1] + 1.0 ? Math.sin(t * 90) * 6 : 0;
  s += `<path d="M${gx},${gy + gh + 140} V${gy} H${gx + gw} V${gy + gh + 140}" transform="translate(${postShake},0)" fill="none" stroke="#fff" stroke-width="22"/><path d="M${gx},${gy + gh + 140} V${gy} H${gx + gw} V${gy + gh + 140}" transform="translate(${postShake},0)" fill="none" ${ink(5)}/></g>`;
  s += ruleBanner('RULE: NO BOUNCE ⚽', seg.t0, t);
  s += captionBox(300, 420, 'ROUND 2: VOLLEYS', seg.t0, t, '#38c172');
  // current shot
  let si = -1;
  shots.forEach((a, i) => { if (t > a - 0.45) si = i; });
  const a0 = si >= 0 ? shots[si] - 0.45 : seg.t0, k = clamp((t - a0) / 1.0);
  s += athlete(260, 1720, 1.05, 'marcus', si >= 0 ? pose('kick', t, k) : pose('idle', t), t, 1);
  if (si >= 0) {
    const f = clamp((k - 0.62) / 0.45);
    const targets = [[900, 400], [gx + gw - 10, gy + 20], [gx + gw - 60, gy + 50]];
    const start = [380, 1500];
    let bx, by;
    if (k < 0.62) { bx = 380; by = lerp(1200, 1500, clamp(k / 0.62)); }
    else if (si === 1 && f > 0.85) { const r = clamp((f - 0.85) / 0.15 + (t - (a0 + 1.07)) * 1.2); bx = lerp(targets[1][0], 760, r); by = lerp(targets[1][1], 1200, r); }
    else { bx = lerp(start[0], targets[si][0], f); by = lerp(start[1], targets[si][1], f) - Math.sin(f * Math.PI) * 220; }
    if (f > 0 && f < 1) s += `<path d="M${start[0]},${start[1]} Q${(start[0] + bx) / 2},${Math.min(start[1], by) - 200} ${bx},${by}" stroke="#fff" stroke-width="10" stroke-dasharray="4 26" stroke-linecap="round" fill="none" opacity=".8"/>`;
    s += comicBall(bx, by, 32, t * 900);
    const tHit = a0 + 0.62 + 0.45;
    if (si === 0) s += burst(700, 420, 'OVER! 😂', 70, '#9b59b6', tHit - 0.2, t, -6);
    if (si === 1) s += burst(gx + gw - 30, gy - 60, 'PING!', 80, '#f39c12', tHit - 0.1, t, 10);
    if (si === 2) s += speedLines(gx + gw - 60, gy + 50, t, Y, clamp((t - tHit) * 2) * .5) + burst(540, 520, 'TOP BIN!!', 100, RED, tHit, t, -8, 16);
  }
  return s + halftoneFX();
}

function sTally(t, seg) {
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cBlue)"/><rect width="${W}" height="${H}" fill="url(#htL)"/>`;
  s += ctext(540, 300, 'TODAY’S DAMAGE', 92, Y);
  const rows = [['SHOTS', 20, kw(seg, 'Twenty'), '#2f80ed'], ['GOALS', 7, kw(seg, 'Seven'), '#38c172'], ['LAPS', 14, kw(seg, 'Fourteen'), RED]];
  rows.forEach(([lab, n, a, col], i) => {
    const p = eb((t - a + 0.1) / 0.4);
    if (p <= 0) return;
    const v = Math.round(n * clamp((t - a + 0.1) / 0.5));
    s += `<g transform="translate(540,${560 + i * 300}) scale(${p})"><rect x="-420" y="-110" width="840" height="220" fill="#fff" ${ink(10)}/>
      <rect x="-420" y="-110" width="300" height="220" fill="${col}" ${ink(10)}/>${ctext(-270, 0, v, 130, '#fff')}${ctext(140, 0, lab, 96, '#111')}</g>`;
  });
  s += athlete(880, 1680, 0.7, 'marcus', pose('tired', t), t, -1);
  return s + halftoneFX();
}

function sPlay(t, seg) {
  const tNut = kw(seg, 'nutmegged'), tPlay = kw(seg, 'play');
  let s = COMIC_DEFS + comicPitch(t, { scroll: Math.min(t - seg.t0, tNut - seg.t0 + 0.6) * 300, sky: 'cDusk' });
  s += captionBox(330, 420, 'THE STREET KIDS ARE BACK', seg.t0, t, '#fff');
  if (t < tPlay - 0.3) {
    const f = clamp((t - (tNut - 1.0)) / 1.4);
    const mx = lerp(230, 820, eo(f));
    const ballX = lerp(mx + 120, mx + 160, 0.5), nutBall = f > 0.25 && f < 0.75;
    s += athlete(620, 1700, 1.0, 'kid1', pose(f > 0.4 ? 'sad' : 'idle', t), t, -1, blinking(t, .4));
    s += athlete(mx, 1730, 1.05, 'marcus', pose('dribble', t), t, 1);
    s += comicBall(nutBall ? lerp(560, 690, (f - 0.25) / 0.5) : ballX, nutBall ? 1690 : 1700, 30, t * 700);
    s += burst(620, 1150, 'NUTMEG! 🥜', 90, Y, tNut + 0.2, t, -10, 16);
    s += athlete(940, 1600, 0.75, 'kid2', pose(t > tNut + 0.3 ? 'celebrate' : 'idle', t + 1), t, -1);
  } else {
    s += athlete(330, 1720, 1.0, 'marcus', pose('celebrate', t), t, 1);
    s += athlete(560, 1680, 0.9, 'kid1', pose('celebrate', t + 0.3), t, -1);
    s += athlete(760, 1690, 0.9, 'kid2', pose('celebrate', t + 0.6), t, -1);
    s += athlete(940, 1700, 0.85, 'kid3', pose('celebrate', t + 0.9), t, -1);
    s += burst(540, 900, 'YOU’RE IN!', 96, '#38c172', tPlay - 0.3, t, 6, 16);
  }
  return s + halftoneFX();
}

function statCardC(t, x, y, sc, stats, ovr, glow, ovrUp) {
  let s = `<g transform="translate(${x},${y}) scale(${sc})">`;
  if (glow) s += `<rect x="-340" y="-480" width="680" height="960" rx="70" fill="${Y}" opacity="${glow * .5}" filter="url(#b30)"/>`;
  s += `<path d="M-300,-400 Q-300,-440 -260,-440 L260,-440 Q300,-440 300,-400 L300,330 Q300,380 250,400 L20,450 Q0,455 -20,450 L-250,400 Q-300,380 -300,330Z" fill="#ffe08a" ${ink(14)}/>
  <path d="M-300,-400 Q-300,-440 -260,-440 L260,-440 Q300,-440 300,-400 L300,330 Q300,380 250,400 L20,450 Q0,455 -20,450 L-250,400 Q-300,380 -300,330Z" fill="url(#ht)" opacity=".5"/>
  <g transform="translate(90,-150)">${comicHead(0, -80, LOOKS.marcus, ovrUp ? 'happy' : 'det', blinking(t, .9))}
  <path d="M-110,90 Q0,20 110,90 L120,140 H-120Z" fill="${LOOKS.marcus.top}" ${ink(7)}/></g>
  ${ctext(-200, -330, ovr, 130, ovrUp ? '#38c172' : '#fff')}${ctext(-200, -230, 'OVR', 44, '#fff')}${ctext(-200, -170, 'ST', 44, '#fff')}
  <rect x="-260" y="20" width="520" height="8" fill="${INK}"/>${ctext(0, 75, 'MARCUS', 66, '#fff')}`;
  stats.forEach(([name, val, up], i) => {
    const col = i < 3 ? -130 : 130, row = i % 3;
    s += `<g transform="translate(${col},${160 + row * 80})">${ctext(-40, 0, val, 58, up ? '#38c172' : '#fff')}${ctext(48, 0, name, 44, '#fff')}${up ? ctext(105, 0, '▲', 34, '#38c172') : ''}</g>`;
  });
  return s + '</g>';
}

function sUpgrade(t, seg) {
  const tS = kw(seg, 'Speed'), tSh = kw(seg, 'Shooting'), tO = kwN(seg, 'seventeen');
  const p = eb((t - seg.t0) / 0.5);
  const before = Object.fromEntries(EP.statsBefore), stats = EP.statsAfter.map(([n, v, kwd]) => {
    if (!kwd) return [n, v, false];
    const a = n === 'SPD' ? tS : tSh, f = clamp((t - a - 0.4) / 1.0);
    return [n, Math.round(lerp(before[n], v, f)), f > 0];
  });
  const of = clamp((t - tO) / 0.6), ovr = Math.round(lerp(EP.ovrBefore, EP.ovrAfter, of));
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cPop)"/>` + speedLines(540, 950, t, '#fff', .3);
  s += statCardC(t, 540, 960, 0.98 * p, stats, ovr, t > tO && t - tO < 1.2 ? 1 - (t - tO) / 1.2 : 0, of > 0);
  s += burst(820, 520, '+5 SPD', 56, '#2f80ed', tS + 0.5, t, 8);
  s += burst(260, 1480, '+7 SHO', 56, RED, tSh + 0.5, t, -8);
  s += burst(540, 300, 'OVR 15 → 17', 72, '#38c172', tO, t, -4, 16);
  return s + halftoneFX();
}

function sGoalbar(t, seg) {
  const p = eo((t - seg.t0) / 0.8);
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cBlue)"/><rect width="${W}" height="${H}" fill="url(#htL)"/>`;
  s += ctext(540, 320, 'ROAD TO PRO', 110, Y);
  const x0 = 120, x1 = 960, y = 760, val = 17 / 75;
  s += `<rect x="${x0}" y="${y - 50}" width="${x1 - x0}" height="100" rx="50" fill="#fff" ${ink(10)}/>
  <rect x="${x0 + 8}" y="${y - 42}" width="${(x1 - x0 - 16) * val * p}" height="84" rx="42" fill="#38c172"/>
  ${ctext(x0 + (x1 - x0) * val * p, y - 120, '17', 80, '#38c172')}${ctext(x1, y + 120, '75', 80, Y)}${ctext(x1, y + 200, 'PRO', 44, '#fff')}${ctext(x0, y + 120, '0', 60, '#fff')}`;
  s += athlete(x0 + (x1 - x0) * val * p, y - 170, 0.45, 'marcus', pose('run', t), t, 1);
  s += burst(540, 1150, '58 TO GO', 80, RED, kw(seg, 'long'), t, -6);
  s += burst(540, 1430, 'WHAT’S NEXT?', 76, '#9b59b6', kw(seg, 'next'), t, 6);
  return s + halftoneFX();
}

function artTryout(t) {
  return `<rect width="420" height="392" fill="#1b3a8a"/>${[60, 200, 340].map(x => `<rect x="${x - 6}" y="10" width="12" height="90" fill="#ddd"/><circle cx="${x}" cy="20" r="26" fill="#fff8c2" opacity=".9"/>`).join('')}
  <rect y="120" width="420" height="80" fill="#24305a"/>${Array.from({ length: 30 }, (_, i) => `<circle cx="${10 + i * 14}" cy="${140 + (i % 3) * 18}" r="7" fill="${['#e74c3c', '#f1c40f', '#3498db', '#ecf0f1'][i % 4]}"/>`).join('')}
  <rect y="200" width="420" height="192" fill="#2e9e4f"/><path d="M0,250 H420 M210,200 V392" stroke="#fff" stroke-width="4"/>
  ${athlete(150, 380, 0.42, 'marcus', pose('run', t), t, 1)}${athlete(300, 370, 0.38, 'kid2', pose('run', t + .3), t, -1)}${comicBall(220, 360, 12, t * 300)}
  <rect x="270" y="215" width="130" height="44" rx="8" fill="#111"/><text x="335" y="238" font-family="${FONT}" font-size="22" font-weight="900" fill="${Y}" text-anchor="middle" dominant-baseline="central">TRYOUT</text>`;
}
function artDribble(t) {
  const x = 60 + ((t * 120) % 300);
  return `<rect width="420" height="392" fill="url(#cDusk)"/><rect y="230" width="420" height="162" fill="#c0603a"/>
  ${[90, 170, 250, 330].map(cx => `<path d="M${cx - 14},360 L${cx},320 L${cx + 14},360Z" fill="#ff7a1a" stroke="#111" stroke-width="3"/>`).join('')}
  ${athlete(x, 380, 0.42, 'marcus', pose('dribble', t), t, 1)}${comicBall(x + 40, 372, 11, t * 600)}
  ${athlete(360, 300, 0.32, 'kid1', pose('celebrate', t), t, -1)}${athlete(40, 300, 0.32, 'kid3', pose('idle', t), t, 1)}`;
}

function sCta3(t, seg) {
  const lt = t - seg.t0, opts = TL.filter(o => o.scene === 'options');
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="url(#cPop)"/>` + speedLines(540, 700, t, '#fff', .3);
  s += commentCard(540, 230, 940, { handle: '@you', text: 'drop your craziest workout here 💡', likes: '', ago: 'now', color: '#9b59b6' }, seg.t0, t);
  s += ctext(540, 640, 'COMMENT', 140, '#fff');
  opts.forEach((o, i) => {
    const p = eb((t - kwN(seg, 'comment') - i * 0.15) / 0.4);
    if (p <= 0) return;
    const x = 330 + i * 420, yb = 900 + 12 * Math.sin(lt * 4 + i * 1.5);
    s += `<g transform="translate(${x},${yb}) scale(${p})"><rect x="-140" y="-140" width="280" height="280" rx="40" fill="${Y}" ${ink(12)}/>${ctext(0, 6, o.letter, 190, '#fff')}</g>${ctext(x, 1110, o.title, 54, '#fff')}`;
  });
  s += burst(540, 1340, `DAY ${EP.day + 1} 👀`, 90, '#38c172', kwN(seg, 'day'), t, -5);
  s += athlete(180, 1720, 0.8, 'marcus', pose('celebrate', t), t, 1);
  return s + halftoneFX();
}

Object.assign(SCENES, { c3open: sC3open, recap: sRecap, rules: sRules, juggle: sJuggle, laps: sLaps, volley: sVolley, tally: sTally, play: sPlay, upgrade: sUpgrade, goalbar: sGoalbar, cta3: sCta3 });
